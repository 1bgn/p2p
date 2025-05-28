import 'dart:async';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import '../../application/transfer_service.dart';
import '../../domain/model/file_entry.dart';

@LazySingleton()
class TransferController {
  final TransferService service;
  StreamSubscription<TransferEvent>? _sub;
  final messages = signal<List<String>>([]);
  final files = signal<List<FileEntry>>([]);
  final text = signal('');
  final disconnected = signal(false);
  final autoSaveEnabled = signal(false);

  TransferController(this.service) {
    _loadAutoSaveSetting();
  }

  Future<void> _loadAutoSaveSetting() async {
    final prefs = await SharedPreferences.getInstance();
    autoSaveEnabled.value = prefs.getBool('auto_save_files') ?? false;
  }

  Future<void> toggleAutoSave() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !autoSaveEnabled.value;
    await prefs.setBool('auto_save_files', newValue);
    autoSaveEnabled.value = newValue;
  }

  void init(String roomCode, WebSocket socket) {
    service.connect(roomCode, socket);
    _sub = service.messageStream.listen(_handleEvent);
    socket.done.then((_) {
      disconnected.value = true;
    });
  }

  void _handleEvent(TransferEvent event) {
    if (event is TextEvent) {
      final ms = 'Remote: ${event.text}';
      messages.value = [...messages.value, ms];
    } else if (event is FileEvent) {
      final entry = event.entry;
      if (!entry.sent) {
        // полученный файл
        final ms = '📥 ${entry.name} received';
        files.value = [...files.value, entry];
        messages.value = [...messages.value, ms];

        if (autoSaveEnabled.value) {
          _autoSave(entry);
        }
      } else {
        // свой отправленный файл (без автосейва)
        final ms = '📤 ${entry.name} sent';
        files.value = [...files.value, entry];
        messages.value = [...messages.value, ms];
      }
    }
  }

  /// Ручное скачивание с диалогом
  Future<void> download(FileEntry entry) => service.download(entry);

  /// Автосохранение внутрь папки «Загрузки» (или документов), без диалога
  Future<void> _autoSave(FileEntry entry) async {
    final bytes = await File(entry.path).readAsBytes();

    Directory dir;
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux ) {
      dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    } else if (Platform.isAndroid) {
    await  download(entry);
    return;
    } else {
      // iOS и прочие — в папку документов
      dir = await getApplicationDocumentsDirectory();
    }

    final savePath = '${dir.path}/${entry.name}';
    final file = File(savePath);
    await file.writeAsBytes(bytes, flush: true);

    entry.path = savePath;
    entry.saved = true;
    // при желании: можно добавить уведомление об успехе
  }

  void sendText() {
    final t = text.value.trim();
    if (t.isEmpty) return;
    service.sendText(t);
    messages.value = [...messages.value, 'Me: $t'];
    text.value = '';
  }

  Future<void> pickImages() => service.pickImages();
  Future<void> pickFiles() => service.pickFiles();
  Future<void> pickAndSend() => service.pickAndSend();

  void dispose() {
    _sub?.cancel();
    service.close();
  }
}
