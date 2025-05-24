// lib/features/transfer_screen/presentation/ui/transfer_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:auto_route/auto_route.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:downloads_path_provider_28/downloads_path_provider_28.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

@RoutePage()
class TransferScreen extends StatefulWidget {
  final WebSocket socket;
  final String remoteRoomCode;
  const TransferScreen(
      {super.key, required this.socket, required this.remoteRoomCode});
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

/* ---------------- model ---------------- */
class _FileEntry {
  final String name;
  String path;
  final bool sent;
  bool saved;
  bool get isImage =>
      name.toLowerCase().endsWith('.png') ||
          name.toLowerCase().endsWith('.jpg') ||
          name.toLowerCase().endsWith('.jpeg') ||
          name.toLowerCase().endsWith('.gif') ||
          name.toLowerCase().endsWith('.webp');
  _FileEntry(
      {required this.name,
        required this.path,
        required this.sent,
        this.saved = false});
}

/* ---------------- state ---------------- */
class _TransferScreenState extends State<TransferScreen> {
  final _messages = <String>[];
  final _files = <_FileEntry>[];
  final _txt = TextEditingController();

  /* streaming-parser state */
  final _headerBuf = StringBuffer();
  bool _readingBody = false;
  int _remaining = 0;
  IOSink? _sink;
  String _fileName = '';
  String _tempPath = '';

  void _ui(VoidCallback fn) => mounted ? setState(fn) : null;

  @override
  void initState() {
    super.initState();
    final router = AutoRouter.of(context);
    widget.socket.listen(_onData,
        onDone: () =>
            WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? router.pop() : null));
  }

  /* -------- memory-efficient parser: processes chunk in place -------- */
  void _onData(dynamic data) async {
    final Uint8List chunk =
    data is String ? Uint8List.fromList(utf8.encode(data)) : data;

    int pos = 0;
    while (pos < chunk.length) {
      // ── receiving file body ──
      if (_readingBody) {
        final take = (_remaining < (chunk.length - pos))
            ? _remaining
            : (chunk.length - pos);
        _sink!.add(chunk.sublist(pos, pos + take));
        _remaining -= take;
        pos += take;
        if (_remaining == 0) {
          await _sink!.close();
          _sink = null;
          _readingBody = false;
          _ui(() {
            _files.add(
                _FileEntry(name: _fileName, path: _tempPath, sent: false));
            _messages.add('📥 $_fileName received');
          });
        }
        continue;
      }

      // ── reading header line ──
      final byte = chunk[pos++];
      if (byte == 10) {
        final line = _headerBuf.toString().trim();
        _headerBuf.clear();
        final m = RegExp(r'^FILE:([^:]+):(\d+)$').firstMatch(line);
        if (m != null) {
          _fileName = m.group(1)!;
          _remaining = int.parse(m.group(2)!);
          _tempPath =
          '${(await getTemporaryDirectory()).path}/$_fileName';
          _sink = File(_tempPath).openWrite();
          _readingBody = true;
        } else if (line.isNotEmpty) {
          _ui(() => _messages.add('Remote: $line'));
        }
      } else {
        _headerBuf.writeCharCode(byte);
      }
    }
  }

  /* ============= streaming sender (no RAM blow-up) ============== */
  final _sendQueue = <File>[];
  bool _sending = false;

  Future<void> _enqueueFile(File f) async {
    _sendQueue.add(f);
    if (!_sending) {
      _sending = true;
      while (_sendQueue.isNotEmpty) {
        final file = _sendQueue.removeAt(0);
        await _sendFileStream(file);
      }
      _sending = false;
    }
  }

  Future<void> _sendFileStream(File f) async {
    final len = await f.length();
    widget.socket.add('FILE:${f.uri.pathSegments.last}:$len\n');
    await for (final chunk in f.openRead()) {
      widget.socket.add(chunk);
    }
    _ui(() {
      _files.add(_FileEntry(
          name: f.uri.pathSegments.last,
          path: f.path,
          sent: true,
          saved: true));
      _messages.add('Me: Sent file ${f.uri.pathSegments.last}');
    });
  }

  /* ============= pickers ============== */
  Future<void> _pickAndSend() async {
    // iOS choose
    if (Platform.isIOS) {
      final ch = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pick images'),
                onTap: () => Navigator.pop(context, 'images')),
            ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Pick files'),
                onTap: () => Navigator.pop(context, 'files')),
          ]),
        ),
      );
      if (ch == 'images') {
        final imgs = await ImagePicker().pickMultiImage();
        for (final x in imgs) {
          await _enqueueFile(File(x.path));
        }
        return;
      }
    }
    final res =
    await FilePicker.platform.pickFiles(allowMultiple: true, withData: false);
    if (res == null) return;
    for (final p in res.files) {
      if (p.path != null) await _enqueueFile(File(p.path!));
    }
  }

  /* ============= text send ============== */
  Future<void> _sendText() async {
    final txt = _txt.text.trim();
    if (txt.isEmpty) return;
    widget.socket.add('$txt\n');
    _ui(() => _messages.add('Me: $txt'));
    _txt.clear();
  }

  /* ============= download ============== */
  Future<void> _download(_FileEntry e) async {
    if (e.saved) return;
    final bytes = await File(e.path).readAsBytes();
    String dest = e.path;
    if (Platform.isIOS && e.isImage) {
      await Permission.photos.request();
      final res = await ImageGallerySaver.saveImage(bytes, name: e.name);
      dest = res['filePath'] ?? dest;
    } else if (Platform.isAndroid) {
      final dir = await DownloadsPathProvider.downloadsDirectory;
      if (dir != null) {
        final d = File('${dir.path}/${e.name}');
        await d.writeAsBytes(bytes, flush: true);
        dest = d.path;
      }
    }
    _ui(() {
      e.path = dest;
      e.saved = true;
    });
  }

  /* ============= UI ============== */
  void _show(_FileEntry f) => f.isImage
      ? showDialog(
      context: context,
      builder: (_) =>
          Dialog(child: InteractiveViewer(child: Image.file(File(f.path)))))
      : OpenFilex.open(f.path);

  Widget _chat() => ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => Text(_messages[i]));

  Widget _filesTab() => ListView.separated(
    padding: const EdgeInsets.all(8),
    itemCount: _files.length,
    separatorBuilder: (_, __) => const Divider(),
    itemBuilder: (_, i) {
      final f = _files[i];
      return ListTile(
        leading: f.isImage
            ? Image.file(File(f.path),
            width: 48, height: 48, fit: BoxFit.cover)
            : Icon(f.sent ? Icons.upload : Icons.insert_drive_file),
        title: Text(f.name),
        subtitle:
        Text(f.sent ? 'sent' : f.saved ? 'received' : 'tap ↓ to save'),
        trailing: (!f.sent && !f.saved)
            ? IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _download(f))
            : null,
        onTap: () => _show(f),
      );
    },
  );

  Widget _inputBar() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
    child: Row(children: [
      Expanded(
          child: TextField(
              controller: _txt,
              onSubmitted: (_) => _sendText(),
              decoration:
              const InputDecoration(labelText: 'Say something'))),
      IconButton(icon: const Icon(Icons.attach_file), onPressed: _pickAndSend),
      IconButton(icon: const Icon(Icons.send), onPressed: _sendText),
    ]),
  );

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
          title: Text('Chat with ${widget.remoteRoomCode}'),
          bottom: const TabBar(tabs: [Tab(text: 'Chat'), Tab(text: 'Files')])),
      body: TabBarView(children: [_chat(), _filesTab()]),
      bottomNavigationBar: _inputBar(),
    ),
  );

  @override
  void dispose() {
    _txt.dispose();
    widget.socket.close();
    super.dispose();
  }
}
