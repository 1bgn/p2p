// lib/features/transfer_screen/presentation/ui/transfer_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:auto_route/auto_route.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

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
  final String path;
  final bool sent;
  bool get isImage => name.toLowerCase().endsWith('.png') || name.toLowerCase().endsWith('.jpg') || name.toLowerCase().endsWith('.jpeg') || name.toLowerCase().endsWith('.gif') || name.toLowerCase().endsWith('.webp');
  const _FileEntry({required this.name, required this.path, required this.sent});
}

class _TransferScreenState extends State<TransferScreen> {
  final _messages = <String>[];
  final _files = <_FileEntry>[];
  final _textCtrl = TextEditingController();
  // stream-parser state
  bool _receivingFile = false;
  int _bytesLeft = 0;
  IOSink? _fileSink;
  String _fileName = '';
  Uint8List _stash = Uint8List(0);

  // safe setState
  bool _pendingRefresh = false;
  void _fast(VoidCallback fn) {
    if (_pendingRefresh) return;
    _pendingRefresh = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingRefresh = false;
      if (mounted) setState(fn);
    });
  }

  @override
  void initState() {
    super.initState();
    final router = AutoRouter.of(context);
    widget.socket.listen(_onData, onDone: () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) router.pop();
      });
    });
  }

  void _onData(Uint8List chunk) async {
    var buf = Uint8List.fromList([..._stash, ...chunk]);
    _stash = Uint8List(0);
    while (buf.isNotEmpty) {
      if (_receivingFile) {
        final part = buf.length > _bytesLeft ? buf.sublist(0, _bytesLeft) : buf;
        _fileSink!.add(part);
        _bytesLeft -= part.length;
        buf = buf.sublist(part.length);
        if (_bytesLeft == 0) {
          await _fileSink!.flush();
          await _fileSink!.close();
          final saved = await _localPath(_fileName);
          _fast(() {
            _files.add(_FileEntry(name: _fileName, path: saved, sent: false));
            _messages.add('📥 $_fileName received');
          });
          _receivingFile = false;
        }
        continue;
      }
      final nl = buf.indexOf(10);
      if (nl == -1) {
        _stash = buf;
        break;
      }
      final lineBytes = buf.sublist(0, nl);
      buf = buf.sublist(nl + 1);
      String line;
      try {
        line = utf8.decode(lineBytes);
      } on FormatException {
        print("erresrra");
        // бинарные данные попали вместо текста — вернём bytes в stash
        _stash = Uint8List.fromList([...lineBytes, 10, ...buf]);
        break; // ждём следующего чанка
      }
      if (line.startsWith('FILE:')) {
        final p = line.split(':');
        if (p.length >= 3) {
          _fileName = p[1];
          _bytesLeft = int.parse(p[2]);
          final path = await _localPath(_fileName);
          _fileSink = File(path).openWrite();
          _receivingFile = true;
        }
      } else {
        _fast(() => _messages.add('Remote: $line'));
      }
    }
  }

  Future<void> _sendText() async {
    final txt = _textCtrl.text.trim();
    if (txt.isEmpty) return;
    widget.socket.write('$txt\n');
    await widget.socket.flush();
    _fast(() => _messages.add('Me: $txt'));
    _textCtrl.clear();
  }

  Future<void> _sendFile() async {
    final res = await FilePicker.platform.pickFiles();
    if (res == null || res.files.single.path == null) return;
    final file = File(res.files.single.path!);
    final bytes = await file.readAsBytes();
    final header = 'FILE:${file.uri.pathSegments.last}:${bytes.length}\n';
    widget.socket.add(utf8.encode(header));
    widget.socket.add(bytes);
    await widget.socket.flush();
    _fast(() {
      _files.add(_FileEntry(name: file.uri.pathSegments.last, path: file.path, sent: true));
      _messages.add('Me: Sent file ${file.uri.pathSegments.last}');
    });
  }

  Future<String> _localPath(String name) async {
    final dir = (Platform.isAndroid || Platform.isIOS) ? (await getApplicationDocumentsDirectory()).path : Directory.current.path;
    return '$dir/$name';
  }

  void _preview(_FileEntry e) {
    if (e.isImage) {
      showDialog(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: Image.file(File(e.path)))));
    } else {
      OpenFilex.open(e.path);
    }
  }

  Widget _chatTab() => ListView.builder(padding: const EdgeInsets.all(8), itemCount: _messages.length, itemBuilder: (_, i) => Text(_messages[i]));

  Widget _filesTab() => ListView.separated(padding: const EdgeInsets.all(8), itemCount: _files.length, separatorBuilder: (_, __) => const Divider(), itemBuilder: (_, i) {
    final f = _files[i];
    return ListTile(leading: f.isImage ? Image.file(File(f.path), width: 48, height: 48, fit: BoxFit.cover) : Icon(f.sent ? Icons.upload_file : Icons.download), title: Text(f.name), subtitle: Text(f.sent ? 'sent' : 'received'), onTap: () => _preview(f));
  });

  Widget _inputBar() => Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: Row(children: [Expanded(child: TextField(controller: _textCtrl, onSubmitted: (_) => _sendText(), decoration: const InputDecoration(labelText: 'Say something'))), IconButton(onPressed: _sendFile, icon: const Icon(Icons.attach_file)), IconButton(onPressed: _sendText, icon: const Icon(Icons.send))]));

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(length: 2, child: Scaffold(appBar: AppBar(title: Text('Chat with ${widget.remoteRoomCode}'), bottom: const TabBar(tabs: [Tab(text: 'Chat'), Tab(text: 'Files')])), body: TabBarView(children: [_chatTab(), _filesTab()]), bottomNavigationBar: _inputBar()));
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    widget.socket.destroy();
    super.dispose();
  }
}
