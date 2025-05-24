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
  final Socket socket;
  final String remoteRoomCode;
  const TransferScreen({super.key, required this.socket, required this.remoteRoomCode});
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

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
  _FileEntry({required this.name, required this.path, required this.sent, this.saved = false});
}

class _TransferScreenState extends State<TransferScreen> {
  /* -------- chat/file state -------- */
  final _messages = <String>[];
  final _entries = <_FileEntry>[];
  final _txt = TextEditingController();
  final _pending = <VoidCallback>[];
  bool   _scheduled = false;
  /* -------- stream parser state ---- */
  final _headerBuf = BytesBuilder(copy: false);
  bool   _readingBody = false;
  int    _need = 0;
  IOSink? _sink;
  late String _temp, _fname;

  /* -------- debounce setState ------ */
  bool _busy = false;
  void _ui(VoidCallback fn) {
    _pending.add(fn);
    if (_scheduled) return;           // уже запланирован post-frame
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        for (final f in _pending) f();
        _pending.clear();
      });
      _scheduled = false;
    });
  }

  @override
  void initState() {
    super.initState();
    final r = AutoRouter.of(context);
    widget.socket.listen(_on, onDone: () => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) r.pop(); }));
  }

  /* ================= stream parser ================= */
  void _on(Uint8List chunk) async {
    var buf = chunk;
    while (buf.isNotEmpty) {
      /* ----- binary body ----- */
      if (_readingBody) {
        final part = buf.length > _need ? buf.sublist(0, _need) : buf;
        _sink!.add(part);
        _need -= part.length;
        buf = buf.sublist(part.length);
        if (_need == 0) {
          await _sink!.close();
          _ui(() {
            _entries.add(_FileEntry(name: _fname, path: _temp, sent: false));
            _messages.add('📥 $_fname received');
          });
          _readingBody = false;
        }
        continue;
      }

      /* ----- header accumulation ----- */
      final nl = buf.indexOf(10); // '\n'
      if (nl == -1) { _headerBuf.add(buf); break; }
      _headerBuf.add(buf.sublist(0, nl));
      buf = buf.sublist(nl + 1);

      final line = utf8.decode(_headerBuf.takeBytes());
      if (line.startsWith('FILE:')) {
        final p = line.split(':');
        if (p.length >= 3) {
          _fname = p[1];
          _need  = int.parse(p[2]);
          _temp  = '${(await getTemporaryDirectory()).path}/$_fname';
          _sink  = File(_temp).openWrite();
          _readingBody = true;
        }
      } else {
        _ui(() => _messages.add('Remote: $line'));
      }
    }
  }

  /* ================= sending ======================= */
  Future<void> _sendText() async {
    final t = _txt.text.trim();
    if (t.isEmpty) return;
    widget.socket.write('$t\n');
    await widget.socket.flush();
    _ui(() => _messages.add('Me: $t'));
    _txt.clear();
  }

  Future<void> _sendFile() async {
    if (Platform.isIOS) {
      final ch = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Icons.photo),
                title: const Text('Pick from gallery'),
                onTap: () => Navigator.pop(context, 'gallery')),
            ListTile(leading: const Icon(Icons.folder),
                title: const Text('Pick any file'),
                onTap: () => Navigator.pop(context, 'file')),
          ]),
        ),
      );
      if (ch == 'gallery') {
        final img = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (img != null) return _sendLocal(File(img.path));
      }
    }
    final res = await FilePicker.platform.pickFiles();
    if (res?.files.single.path != null) _sendLocal(File(res!.files.single.path!));
  }

  Future<void> _sendLocal(File f) async {
    final b = await f.readAsBytes();
    widget.socket.add(utf8.encode('FILE:${f.uri.pathSegments.last}:${b.length}\n'));
    widget.socket.add(b);
    await widget.socket.flush();
    _ui(() {
      _entries.add(_FileEntry(name: f.uri.pathSegments.last, path: f.path, sent: true, saved: true));
      _messages.add('Me: Sent file ${f.uri.pathSegments.last}');
    });
  }

  /* =============== download helper ================= */
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
    _ui(() { e.path = dest; e.saved = true; });
  }

  /* ====================== UI ======================= */
  void _show(_FileEntry e) {
    if (e.isImage) {
      showDialog(context: context, builder: (_) =>
          Dialog(child: InteractiveViewer(child: Image.file(File(e.path)))));
    } else {
      OpenFilex.open(e.path);
    }
  }

  Widget _chat()  => ListView.builder(padding: const EdgeInsets.all(8), itemCount: _messages.length, itemBuilder: (_, i) => Text(_messages[i]));
  Widget _files() => ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _entries.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (_, i) {
        final f = _entries[i];
        return ListTile(
          leading: f.isImage
              ? Image.file(File(f.path), width: 48, height: 48, fit: BoxFit.cover)
              : Icon(f.sent ? Icons.upload_file : Icons.insert_drive_file),
          title: Text(f.name),
          subtitle: Text(f.sent ? 'sent' : f.saved ? 'received' : 'tap ↓ to save'),
          trailing: (!f.sent && !f.saved)
              ? IconButton(icon: const Icon(Icons.download), onPressed: () => _download(f))
              : null,
          onTap: () => _show(f),
        );
      });

  Widget _bar() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
    child: Row(children: [
      Expanded(child: TextField(controller: _txt, onSubmitted: (_) => _sendText(), decoration: const InputDecoration(labelText: 'Say something'))),
      IconButton(icon: const Icon(Icons.attach_file), onPressed: _sendFile),
      IconButton(icon: const Icon(Icons.send),       onPressed: _sendText),
    ]),
  );

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
          title: Text('Chat with ${widget.remoteRoomCode}'),
          bottom: const TabBar(tabs: [Tab(text: 'Chat'), Tab(text: 'Files')])),
      body: TabBarView(children: [_chat(), _files()]),
      bottomNavigationBar: _bar(),
    ),
  );

  @override
  void dispose() {
    _txt.dispose();
    widget.socket.destroy();
    super.dispose();
  }
}
