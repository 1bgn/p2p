// lib/features/transfer_screen/presentation/ui/transfer_screen.dart
//
// Length-prefixed JSON headers + binary bodies framing protocol.
// Renamed files-view builder to avoid name collision with `_files` list.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:auto_route/auto_route.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:downloads_path_provider_28/downloads_path_provider_28.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';

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

class _FileEntry {
  final String name;
  String path;
  final bool sent;
  bool saved;
  _FileEntry({
    required this.name,
    required this.path,
    required this.sent,
    this.saved = false,
  });
  bool get isImage =>
      RegExp(r'\.(png|jpe?g|gif|webp)$').hasMatch(name.toLowerCase());
}

class _TransferScreenState extends State<TransferScreen> {
  final _messages = <String>[];
  final _files = <_FileEntry>[];
  final _txt = TextEditingController();

  // framing parser state
  Uint8List _stash = Uint8List(0);
  int? _headerLen;
  Map<String, dynamic>? _header;
  int? _bodyRemaining;
  IOSink? _fileSink;

  void _addMessage(String msg) {
    if (!mounted) return;
    setState(() => _messages.add(msg));
  }

  void _addFile(String name, String path, bool sent) {
    if (!mounted) return;
    setState(() => _files.add(_FileEntry(name: name, path: path, sent: sent, saved: sent)));
  }

  @override
  void initState() {
    super.initState();
    final router = AutoRouter.of(context);
    widget.socket.listen(_handleFrame, onDone: () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) router.pop();
      });
    });
  }

  Future<void> _handleFrame(dynamic data) async {
    final chunk = data is String
        ? Uint8List.fromList(utf8.encode(data))
        : (data as Uint8List);
    _stash = Uint8List.fromList([..._stash, ...chunk]);

    // parse as many complete messages as possible
    while (true) {
      if (_headerLen == null) {
        if (_stash.length < 4) break;
        final dv = ByteData.sublistView(_stash, 0, 4);
        _headerLen = dv.getUint32(0, Endian.big);
        _stash = _stash.sublist(4);
      }
      if (_header == null) {
        if (_stash.length < _headerLen!) break;
        final hdrJson = utf8.decode(_stash.sublist(0, _headerLen!));
        _header = jsonDecode(hdrJson);
        _stash = _stash.sublist(_headerLen!);
        if (_header!['type'] == 'file') {
          _bodyRemaining = _header!['size'] as int;
          final tmp = await getTemporaryDirectory();
          final path = '${tmp.path}/${_header!['name']}';
          _fileSink = File(path).openWrite();
        }
      }
      if (_header!['type'] == 'text') {
        _addMessage('Remote: ${_header!['text']}');
        _headerLen = null;
        _header = null;
        continue;
      }
      if (_header!['type'] == 'file') {
        final need = _bodyRemaining!;
        if (_stash.isEmpty) break;
        final take = need < _stash.length ? need : _stash.length;
        _fileSink!.add(_stash.sublist(0, take));
        _stash = _stash.sublist(take);
        _bodyRemaining = need - take;
        if (_bodyRemaining == 0) {
          await _fileSink!.flush();
          await _fileSink!.close();
          final name = _header!['name'] as String;
          final tmp = await getTemporaryDirectory();
          final path = '${tmp.path}/$name';
          _addFile(name, path, false);
          _addMessage('📥 $name received');
          _headerLen = null;
          _header = null;
          _bodyRemaining = null;
          _fileSink = null;
          continue;
        }
      }
      break;
    }
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
    widget.socket.add(pre.buffer.asUint8List());
    widget.socket.add(Uint8List.fromList(hdrBytes));
    await for (final chunk in f.openRead()) {
      widget.socket.add(chunk is Uint8List ? chunk : Uint8List.fromList(chunk));
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
                onTap: () => Navigator.pop(context, 'img')),
            ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Pick files'),
                onTap: () => Navigator.pop(context, 'files')),
          ]),
        ),
      );
      if (choice == 'img') {
        final imgs = await ImagePicker().pickMultiImage();
        if (imgs != null) {
          for (final x in imgs) {
            await _sendFile(File(x.path));
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

  Future<void> _download(_FileEntry e) async {
    if (e.saved) return;
    final data = await File(e.path).readAsBytes();
    String dest = e.path;
    if (Platform.isIOS && e.isImage) {
      await Permission.photos.request();
      final r = await ImageGallerySaver.saveImage(data, name: e.name);
      if (r['filePath'] != null) dest = r['filePath'];
    } else if (Platform.isAndroid) {
      final dir = await DownloadsPathProvider.downloadsDirectory;
      if (dir != null) {
        final f = File('${dir.path}/${e.name}');
        await f.writeAsBytes(data, flush: true);
        dest = f.path;
      }
    }
    if (mounted) setState(() => e.saved = true);
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
            ? Image.file(File(f.path), width: 48, height: 48, fit: BoxFit.cover)
            : Icon(f.sent ? Icons.upload_file : Icons.insert_drive_file),
        title: Text(f.name, overflow: TextOverflow.ellipsis),
        subtitle: Text(f.sent ? 'sent' : f.saved ? 'received' : 'tap ↓ to save'),
        trailing: (!f.sent && !f.saved)
            ? IconButton(icon: const Icon(Icons.download), onPressed: () => _download(f))
            : null,
        onTap: () {
          if (f.isImage) {
            showDialog(
              context: context,
              builder: (_) => Dialog(child: InteractiveViewer(child: Image.file(File(f.path)))),
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
      body: TabBarView(children: [
        _buildChatTab(),
        _buildFilesTab(),
      ]),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Row(children: [
          Expanded(
              child: TextField(
                  controller: _txt,
                  onSubmitted: (_) => _sendText(),
                  decoration: const InputDecoration(labelText: 'Say something'))),
          IconButton(icon: const Icon(Icons.attach_file), onPressed: _pickAndSend),
          IconButton(icon: const Icon(Icons.send), onPressed: _sendText),
        ]),
      ),
    ),
  );

  @override
  void dispose() {
    _txt.dispose();
    widget.socket.close();
    super.dispose();
  }
}
