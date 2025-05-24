// lib/features/transfer_screen/presentation/ui/transfer_screen.dart
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
  bool get isImage => name.toLowerCase().endsWith('.png') ||
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
  final _fileEntries = <_FileEntry>[];
  final _txt = TextEditingController();

  Uint8List _buf = Uint8List(0);
  bool _readingBody = false;
  int _need = 0;
  IOSink? _sink;
  late String _fname, _tmp;

  void _ui(VoidCallback f) => mounted ? setState(f) : null;

  @override
  void initState() {
    super.initState();
    final r = AutoRouter.of(context);
    widget.socket.listen(_onData, onDone: () {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => mounted ? r.pop() : null);
    });
  }

  /* ---------- parser 'FILE:name:size\\n' + payload ---------- */
  void _onData(dynamic data) async {
    if (data is String) data = utf8.encode(data);
    _buf = Uint8List.fromList([..._buf, ...data as Uint8List]);

    while (_buf.isNotEmpty) {
      if (_readingBody) {
        if (_buf.length < _need) {
          _sink!.add(_buf);
          _need -= _buf.length;
          _buf = Uint8List(0);
          break;
        }
        _sink!.add(_buf.sublist(0, _need));
        await _sink!.close();
        _buf = _buf.sublist(_need);
        _readingBody = false;
        _ui(() {
          _fileEntries
              .add(_FileEntry(name: _fname, path: _tmp, sent: false));
          _messages.add('📥 $_fname received');
        });
        continue;
      }

      final nl = _buf.indexOf(10);
      if (nl == -1) break;
      final line = utf8.decode(_buf.sublist(0, nl)).trim();
      _buf = _buf.sublist(nl + 1);

      final m = RegExp(r'^FILE:([^:]+):(\d+)$').firstMatch(line);
      if (m != null) {
        _fname = m.group(1)!;
        _need = int.parse(m.group(2)!);
        _tmp = '${(await getTemporaryDirectory()).path}/$_fname';
        _sink = File(_tmp).openWrite();
        _readingBody = true;
      } else {
        _ui(() => _messages.add('Remote: $line'));
      }
    }
  }

  /* ===================== multi-send ===================== */
  Future<void> _pickAndSendFiles() async {
    if (Platform.isIOS) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
                leading: const Icon(Icons.photo),
                title: const Text('Pick image (one)'),
                onTap: () => Navigator.pop(context, 'gallery')),
            ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Pick files (multi)'),
                onTap: () => Navigator.pop(context, 'files')),
          ]),
        ),
      );
      if (choice == 'gallery') {
        final img =
        await ImagePicker().pickImage(source: ImageSource.gallery);
        if (img != null) await _sendLocal(File(img.path));
        return;
      }
    }

    final res =
    await FilePicker.platform.pickFiles(allowMultiple: true); // ✅
    if (res == null) return;
    for (final p in res.files) {
      if (p.path != null) await _sendLocal(File(p.path!));
    }
  }

  Future<void> _sendLocal(File f) async {
    final bytes = await f.readAsBytes();
    widget.socket.add('FILE:${f.uri.pathSegments.last}:${bytes.length}\n');
    widget.socket.add(bytes);
    _ui(() {
      _fileEntries.add(_FileEntry(
          name: f.uri.pathSegments.last,
          path: f.path,
          sent: true,
          saved: true));
      _messages.add('Me: Sent file ${f.uri.pathSegments.last}');
    });
  }

  /* ---------------- sending text ---------------- */
  Future<void> _sendText() async {
    final t = _txt.text.trim();
    if (t.isEmpty) return;
    widget.socket.add('$t\n');
    _ui(() => _messages.add('Me: $t'));
    _txt.clear();
  }

  /* ---------------- download ---------------- */
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

  /* ---------------- UI ---------------- */
  void _show(_FileEntry f) => f.isImage
      ? showDialog(
      context: context,
      builder: (_) => Dialog(
          child: InteractiveViewer(child: Image.file(File(f.path)))))
      : OpenFilex.open(f.path);

  Widget _chat() => ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => Text(_messages[i]));

  Widget _files() => ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _fileEntries.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (_, i) {
        final f = _fileEntries[i];
        return ListTile(
          leading: f.isImage
              ? Image.file(File(f.path),
              width: 48, height: 48, fit: BoxFit.cover)
              : Icon(f.sent ? Icons.upload_file : Icons.insert_drive_file),
          title: Text(f.name),
          subtitle: Text(
              f.sent ? 'sent' : f.saved ? 'received' : 'tap ↓ to save'),
          trailing: (!f.sent && !f.saved)
              ? IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _download(f))
              : null,
          onTap: () => _show(f),
        );
      });

  Widget _bar() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
    child: Row(children: [
      Expanded(
          child: TextField(
              controller: _txt,
              onSubmitted: (_) => _sendText(),
              decoration:
              const InputDecoration(labelText: 'Say something'))),
      IconButton(
          icon: const Icon(Icons.attach_file),
          onPressed: _pickAndSendFiles),             // ← multi-file
      IconButton(icon: const Icon(Icons.send), onPressed: _sendText),
    ]),
  );

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
          title: Text('Chat with ${widget.remoteRoomCode}'),
          bottom:
          const TabBar(tabs: [Tab(text: 'Chat'), Tab(text: 'Files')])),
      body: TabBarView(children: [_chat(), _files()]),
      bottomNavigationBar: _bar(),
    ),
  );

  @override
  void dispose() {
    _txt.dispose();
    widget.socket.close();
    super.dispose();
  }
}
