import 'dart:async';
import 'dart:isolate';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_selector/file_selector.dart';
// import 'package:image_gallery_saver/image_gallery_saver.dart';
// import 'package:downloads_path_provider_28/downloads_path_provider_28.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';
import '../domain/model/file_entry.dart';

/// Events emitted from parser isolate
abstract class TransferEvent {}
class TextEvent extends TransferEvent { final String text; TextEvent(this.text); }
class FileEvent extends TransferEvent { final FileEntry entry; FileEvent(this.entry); }
@LazySingleton()
class TransferService {
  late WebSocket _socket;
  final _eventCtrl = StreamController<TransferEvent>.broadcast();
  Stream<TransferEvent> get messageStream => _eventCtrl.stream;

  late Isolate _parserIsolate;
  late SendPort _parserSend;
  final ReceivePort _receivePort = ReceivePort();
  Future<void> pickImages() async {
    final imgs = await ImagePicker().pickMultiImage();
    for (var img in imgs) {
      await sendFile(File(img.path));
    }
    }

  Future<void> pickFiles() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple:true);
    if (res != null) {
      for (var p in res.files) {
        if (p.path!=null) await sendFile(File(p.path!));
      }
    }
  }
  Future<void> connect(String roomCode,WebSocket socket) async {
    final rootToken = RootIsolateToken.instance!;
    _parserIsolate = await Isolate.spawn(parserEntry, [_receivePort.sendPort, rootToken]);

    _receivePort.listen((msg) {
      if (msg is SendPort) {
        _parserSend = msg;
      } else if (msg is Map<String, dynamic>) {
        if (msg['type'] == 'text') {
          _eventCtrl.add(TextEvent(msg['text'] as String));
        } else if (msg['type'] == 'file') {
          final entry = FileEntry(name: msg['name'] as String, path: msg['path'] as String, sent: false);
          _eventCtrl.add(FileEvent(entry));
        }
      }
    });

    _socket = socket;
    _socket.listen((data) {
      final bytes = data is Uint8List ? data : Uint8List.fromList(data as List<int>);
      _parserSend.send(bytes);
    }, onDone: _cleanup);
  }

  void _cleanup() {
    _socket.close();
    _receivePort.close();
    _parserIsolate.kill(priority: Isolate.immediate);
  }

  void sendText(String text) {
    final header = jsonEncode({'type': 'text', 'text': text});
    final hdrBytes = utf8.encode(header);
    final pre = ByteData(4)..setUint32(0, hdrBytes.length, Endian.big);
    _socket.add(pre.buffer.asUint8List());
    _socket.add(Uint8List.fromList(hdrBytes));
  }

  Future<void> sendFile(File file) async {
    final name = file.uri.pathSegments.last;
    final size = await file.length();
    final header = jsonEncode({'type': 'file', 'name': name, 'size': size});
    final hdrBytes = utf8.encode(header);
    final pre = ByteData(4)..setUint32(0, hdrBytes.length, Endian.big);
    _socket.add(pre.buffer.asUint8List());
    _socket.add(Uint8List.fromList(hdrBytes));
    await for (final chunk in file.openRead()) {
      final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
      _socket.add(bytes);
    }
    _eventCtrl.add(FileEvent(FileEntry(name: name, path: file.path, sent: true)));
  }

  Future<void> pickAndSend() async {
    if (Platform.isIOS) {
      final imgs = await ImagePicker().pickMultiImage();
      for (final img in imgs) {
        await sendFile(File(img.path));
      }
          return;
    }
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res != null) {
      for (final p in res.files) {
        if (p.path != null) await sendFile(File(p.path!));
      }
    }
  }

  Future<void> download(FileEntry entry) async {
    // if (entry.saved) return;
    final bytes = await File(entry.path).readAsBytes();
    String dest = entry.path;

    // выделим расширение
    final parts = entry.name.split('.');
    final ext = parts.length > 1 ? parts.last : '';

    if (Platform.isMacOS) {
      final loc = await getSaveLocation(
        suggestedName: entry.name,
        acceptedTypeGroups: [
          XTypeGroup(label: 'All Files', extensions: ext.isNotEmpty ? [ext] : ['*'])
        ],
      );
      if (loc != null) {
        var savePath = loc.path;
        if (ext.isNotEmpty && !savePath.endsWith('.$ext')) {
          savePath += '.$ext';
        }
        final file = File(savePath);
        await file.writeAsBytes(bytes, flush: true);
        dest = file.path;
      }

    } else if (Platform.isIOS) {
      // запрос прав на запись в фото-библиотеку
      await Permission.photos.request();

      if (entry.isImage) {
        // final res = await ImageGallerySaver.saveImage(bytes, name: entry.name);
        final res = await SaverGallery.saveImage(
   bytes,
    quality: 100,
    fileName: entry.name,
    androidRelativePath: "Pictures/BeamDrop/images",
    skipIfExists: false,
  );
        // if (res['filePath'] != null) dest = res['filePath'];
        if(res.isSuccess ){

        }
      } else {
        // для остальных файлов – сохраняем в «Файлы» через диалог
        final loc = await getSaveLocation(
          suggestedName: entry.name,
          acceptedTypeGroups: [
            XTypeGroup(label: 'All Files', extensions: ext.isNotEmpty ? [ext] : ['*'])
          ],
        );
        if (loc != null) {
          var savePath = loc.path;
          if (ext.isNotEmpty && !savePath.endsWith('.$ext')) {
            savePath += '.$ext';
          }
          final file = File(savePath);
          await file.writeAsBytes(bytes, flush: true);
          dest = file.path;
        }
      }

    } else if (Platform.isAndroid) {
      if (entry.isImage) {
        print("save on android");
        // сохраняем в «Загрузки» (или можно сразу в галерею через ImageGallerySaver)
         final res = await SaverGallery.saveImage(
   bytes,
    quality: 100,
    fileName: entry.name,
    androidRelativePath: "Pictures/BeamDrop/images",
    skipIfExists: false,
  );
      } else {
        // пусть пользователь выберет папку
        final directory = await FilePicker.platform.getDirectoryPath();
        if (directory != null) {
          final file = File('$directory/${entry.name}');
          await file.writeAsBytes(bytes, flush: true);
          dest = file.path;
        }
      }

    } else {
      // fallback: временный каталог
      final tmp = await getTemporaryDirectory();
      final file = File('${tmp.path}/${entry.name}');
      await file.writeAsBytes(bytes, flush: true);
      dest = file.path;
    }

    entry.path = dest;
    entry.saved = true;
  }
}


Future<void> parserEntry(List<dynamic> args) async {
  final SendPort uiPort = args[0] as SendPort;
  final RootIsolateToken token = args[1] as RootIsolateToken;
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);

  final rp = ReceivePort();
  uiPort.send(rp.sendPort);
  Uint8List stash = Uint8List(0);
  int? hLen;
  Map<String, dynamic>? header;
  int? remaining;
  IOSink? sink;

  await for (final msg in rp) {
    final chunk = msg is Uint8List ? msg : Uint8List.fromList(msg as List<int>);
    stash = Uint8List.fromList([...stash, ...chunk]);
    while (true) {
      if (hLen == null) {
        if (stash.length < 4) break;
        hLen = ByteData.sublistView(stash, 0, 4).getUint32(0, Endian.big);
        stash = stash.sublist(4);
      }
      if (header == null) {
        if (stash.length < hLen) break;
        final str = utf8.decode(stash.sublist(0, hLen));
        header = jsonDecode(str) as Map<String, dynamic>;
        stash = stash.sublist(hLen);
        if (header['type'] == 'file') {
          remaining = header['size'] as int;
          final tmp = await getTemporaryDirectory();
          sink = File('${tmp.path}/${header['name']}').openWrite();
        }
      }
      final type = header['type'] as String;
      if (type == 'text') {
        final text = header['text'] as String;
        uiPort.send({'type': 'text', 'text': text});
        header = null;
        hLen = null;
        continue;
      }
      if (type == 'file') {
        if (stash.isEmpty) break;
        final need = remaining!;
        final take = need < stash.length ? need : stash.length;
        sink!.add(stash.sublist(0, take));
        stash = stash.sublist(take);
        remaining = need - take;
        if (remaining == 0) {
          await sink.flush();
          await sink.close();
          final tmp = await getTemporaryDirectory();
          uiPort.send({'type': 'file', 'name': header['name'], 'path': '${tmp.path}/${header['name']}'});
          header = null;
          hLen = null;
          continue;
        }
      }
      break;
    }
  }
}
