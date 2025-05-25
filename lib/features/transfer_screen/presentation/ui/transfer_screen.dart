// lib/features/transfer_screen/presentation/ui/transfer_screen.dart
//
// WebSocket-чат + файлообмен, с обёрткой парсера в изоляте,
// length-prefixed JSON-заголовки + streaming bodies,
// «Save As…» на macOS и iOS (non-image) через file_selector.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:auto_route/auto_route.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:downloads_path_provider_28/downloads_path_provider_28.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';

import '../../domain/model/file_entry.dart';

@RoutePage()
class TransferScreen extends StatefulWidget {
  final WebSocket socket;
  final String remoteRoomCode;

  const TransferScreen({
    super.key,
    required this.socket,
    required this.remoteRoomCode,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}



class _TransferScreenState extends State<TransferScreen> {
  final _messages = <String>[];
  final _files = <FileEntry>[];
  final _txt = TextEditingController();

  late ReceivePort _uiReceivePort;
  SendPort? _isolateSendPort;
  Isolate? _parserIsolate;

  @override
  void initState() {
    super.initState();

    // 1) Prepare ReceivePort for isolate → UI messages
    _uiReceivePort = ReceivePort();
    _uiReceivePort.listen(_handleIsolateMessage);

    // 2) Spawn parser isolate, pass SendPort + root token
    final token = ui.RootIsolateToken.instance!;
    Isolate.spawn(
      _parserEntry,
      [_uiReceivePort.sendPort, token],
      // errors forwarded?
    ).then((iso) => _parserIsolate = iso);

    // 3) Forward incoming socket data to isolate
    final router = AutoRouter.of(context);
    widget.socket.listen(
          (data) {
        if (_isolateSendPort != null) {
          _isolateSendPort!.send(data);
        }
      },
      onDone: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) router.pop();
        });
      },
    );
  }

  void _handleIsolateMessage(dynamic msg) {
    if (msg is SendPort) {
      _isolateSendPort = msg;
    } else if (msg is Map<String, dynamic>) {
      switch (msg['event']) {
        case 'text':
          _addMessage('Remote: ${msg['text']}');
          break;
        case 'file':
          _addFile(msg['name'], msg['path'], false);
          _addMessage('📥 ${msg['name']} received');
          break;
        case 'error':
          debugPrint('Parser isolate error: ${msg['error']}');
          break;
      }
    }
  }

  void _addMessage(String m) {
    if (!mounted) return;
    setState(() => _messages.add(m));
  }

  void _addFile(String name, String path, bool sent) {
    if (!mounted) return;
    setState(() => _files.add(
      FileEntry(name: name, path: path, sent: sent, saved: sent),
    ));
  }

  @override
  void dispose() {
    _txt.dispose();
    widget.socket.close();
    _uiReceivePort.close();
    _parserIsolate?.kill(priority: Isolate.immediate);
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _txt.text.trim();
    if (text.isEmpty) return;
    final hdr = jsonEncode({'type': 'text', 'text': text});
    final hdrBytes = utf8.encode(hdr);
    final pre = ByteData(4)..setUint32(0, hdrBytes.length, Endian.big);
    widget.socket.add(pre.buffer.asUint8List());
    widget.socket.add(Uint8List.fromList(hdrBytes));
    _addMessage('Me: $text');
    _txt.clear();
  }

  Future<void> _sendFile(File f) async {
    final name = f.uri.pathSegments.last;
    final size = await f.length();
    final hdr = jsonEncode({'type': 'file', 'name': name, 'size': size});
    final hdrBytes = utf8.encode(hdr);
    final pre = ByteData(4)..setUint32(0, hdrBytes.length, Endian.big);

    // header
    widget.socket.add(pre.buffer.asUint8List());
    widget.socket.add(Uint8List.fromList(hdrBytes));

    // body
    await for (final chunk in f.openRead()) {
      widget.socket.add(
          chunk is Uint8List ? chunk : Uint8List.fromList(chunk));
    }

    _addFile(name, f.path, true);
    _addMessage('Me: Sent $name');
  }

  Future<void> _pickAndSend() async {
    if (Platform.isIOS) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pick images'),
              onTap: () => Navigator.pop(context, 'images'),
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Pick files'),
              onTap: () => Navigator.pop(context, 'files'),
            ),
          ]),
        ),
      );
      if (choice == 'images') {
        final imgs = await ImagePicker().pickMultiImage();
        if (imgs != null) {
          for (final img in imgs) {
            await _sendFile(File(img.path));
          }
        }
        return;
      }
    }

    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (res != null) {
      for (final p in res.files) {
        if (p.path != null) {
          await _sendFile(File(p.path!));
        }
      }
    }
  }

  Future<void> _download(FileEntry e) async {
    if (e.saved) return;
    final bytes = await File(e.path).readAsBytes();
    String dest = e.path;

    if (Platform.isMacOS) {
      // Save As… via file_selector
      final FileSaveLocation? loc = await getSaveLocation(
        suggestedName: e.name,
        acceptedTypeGroups: [XTypeGroup(label: 'All', extensions: ['*'])],
      );
      if (loc != null) {
        final f = File(loc.path);
        await f.writeAsBytes(bytes, flush: true);
        dest = loc.path;
      }
    } else if (Platform.isIOS) {
      if (e.isImage) {
        await Permission.photos.request();
        final r = await ImageGallerySaver.saveImage(bytes, name: e.name);
        if (r['filePath'] != null) dest = r['filePath'];
      } else {
        final FileSaveLocation? loc = await getSaveLocation(
          suggestedName: e.name,
          acceptedTypeGroups: [XTypeGroup(label: 'All', extensions: ['*'])],
        );
        if (loc != null) {
          final f = File(loc.path);
          await f.writeAsBytes(bytes, flush: true);
          dest = loc.path;
        }
      }
    } else if (Platform.isAndroid) {
      final dir = await DownloadsPathProvider.downloadsDirectory;
      if (dir != null) {
        final f = File('${dir.path}/${e.name}');
        await f.writeAsBytes(bytes, flush: true);
        dest = f.path;
      }
    }

    if (mounted) setState(() {
      e.path = dest;
      e.saved = true;
    });
  }

  Widget _buildChatTab() => ListView.builder(
    padding: const EdgeInsets.all(8),
    itemCount: _messages.length,
    itemBuilder: (_, i) => Text(_messages[i]),
  );

  Widget _buildFilesTab() => ListView.separated(
    padding: const EdgeInsets.all(8),
    itemCount: _files.length,
    separatorBuilder: (_, __) => const Divider(),
    itemBuilder: (_, i) {
      final f = _files[i];
      return ListTile(
        leading: f.isImage
            ? Image.file(File(f.path),
            width: 48, height: 48, fit: BoxFit.cover)
            : Icon(f.sent
            ? Icons.upload_file
            : Icons.insert_drive_file),
        title: Text(f.name, overflow: TextOverflow.ellipsis),
        subtitle: Text(f.sent
            ? 'sent'
            : f.saved
            ? 'received'
            : 'tap ↓ to save'),
        trailing: (!f.sent && !f.saved)
            ? IconButton(
          icon: const Icon(Icons.download),
          onPressed: () => _download(f),
        )
            : null,
        onTap: () {
          if (f.isImage) {
            showDialog(
              context: context,
              builder: (_) => Dialog(
                child: InteractiveViewer(child: Image.file(File(f.path))),
              ),
            );
          } else {
            OpenFilex.open(f.path);
          }
        },
      );
    },
  );

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.remoteRoomCode}'),
        bottom: const TabBar(tabs: [Tab(text: 'Chat'), Tab(text: 'Files')]),
      ),
      body: TabBarView(children: [_buildChatTab(), _buildFilesTab()]),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _txt,
              onSubmitted: (_) => _sendText(),
              decoration:
              const InputDecoration(labelText: 'Say something'),
            ),
          ),
          IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _pickAndSend),
          IconButton(icon: const Icon(Icons.send), onPressed: _sendText),
        ]),
      ),
    ),
  );
}

/// Parser isolate entrypoint.
/// Length-prefixed JSON headers + streaming binary bodies.
Future<void> _parserEntry(List<dynamic> init) async {
  final SendPort uiSendPort = init[0] as SendPort;
  final ui.RootIsolateToken rootToken =
  init[1] as ui.RootIsolateToken;

  BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);

  final rp = ReceivePort();
  uiSendPort.send(rp.sendPort);

  Uint8List stash = Uint8List(0);
  int? headerLen;
  Map<String, dynamic>? header;
  int? bodyRemaining;
  IOSink? fileSink;

  await for (final msg in rp) {
    try {
      final chunk = msg is Uint8List
          ? msg
          : Uint8List.fromList((msg as List<int>));
      stash = Uint8List.fromList([...stash, ...chunk]);

      while (true) {
        if (headerLen == null) {
          if (stash.length < 4) break;
          headerLen =
              ByteData.sublistView(stash, 0, 4).getUint32(0, Endian.big);
          stash = stash.sublist(4);
        }
        if (header == null) {
          if (stash.length < headerLen!) break;
          final jsonStr = utf8.decode(stash.sublist(0, headerLen!));
          header = jsonDecode(jsonStr);
          stash = stash.sublist(headerLen!);
          if (header!['type'] == 'file') {
            bodyRemaining = header!['size'] as int;
            final tmp = await getTemporaryDirectory();
            final path = '${tmp.path}/${header!['name']}';
            fileSink = File(path).openWrite();
          }
        }
        if (header!['type'] == 'text') {
          uiSendPort.send({'event': 'text', 'text': header!['text']});
          header = null;
          headerLen = null;
          continue;
        }
        if (header!['type'] == 'file') {
          if (fileSink == null) {
            header = null;
            headerLen = null;
            bodyRemaining = null;
            break;
          }
          final need = bodyRemaining!;
          if (stash.isEmpty) break;
          final take = need < stash.length ? need : stash.length;
          fileSink.add(stash.sublist(0, take));
          stash = stash.sublist(take);
          bodyRemaining = need - take;
          if (bodyRemaining == 0) {
            await fileSink.flush();
            await fileSink.close();
            final name = header!['name'] as String;
            final tmp = await getTemporaryDirectory();
            final path = '${tmp.path}/$name';
            uiSendPort.send({'event': 'file', 'name': name, 'path': path});
            header = null;
            headerLen = null;
            bodyRemaining = null;
            fileSink = null;
            continue;
          }
        }
        break;
      }
    } catch (e) {
      uiSendPort.send({'event': 'error', 'error': e.toString()});
      header = null;
      headerLen = null;
      bodyRemaining = null;
      await fileSink?.close();
      fileSink = null;
    }
  }
}
