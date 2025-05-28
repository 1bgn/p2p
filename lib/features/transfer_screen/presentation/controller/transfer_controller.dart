import 'dart:async';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_core.dart';

import '../../application/transfer_service.dart';
import '../../domain/model/file_entry.dart';
@LazySingleton()
class TransferController {
  final TransferService service;
  StreamSubscription<TransferEvent>? _sub;
  final messages = signal(List<String>.empty());
  final files = signal(List<FileEntry>.empty());
  final text = signal('');
  final disconnected = signal(false);
  TransferController(this.service);

  void init(String roomCode, WebSocket socket) {
    service.connect(roomCode, socket);
    _sub = service.messageStream.listen(_handleEvent);
    socket.done.then((_) {
      disconnected.value = true;
    });
  }
  Future<void> pickImages() => service.pickImages();

  Future<void> pickFiles() => service.pickFiles();
  void _handleEvent(TransferEvent event) {
    if (event is TextEvent) {
      final ms = 'Remote: ${event.text}';
      messages.value = [...messages.value, ms];
    } else if (event is FileEvent) {
      final ms = '📥 ${event.entry.name} received';
      files.value = [...files.value, event.entry];
      messages.value = [...messages.value, ms];
    }
  }

  void sendText() {
    final t = text.value.trim();
    if (t.isEmpty) return;
    service.sendText(t);
    final ms = 'Me: $t';
    messages.value = [...messages.value, ms];
    text.value = '';
  }

  Future<void> pickAndSend() => service.pickAndSend();
  Future<void> download(FileEntry entry) => service.download(entry);

  /// Dispose controller and cancel subscriptions
  void dispose() {
    _sub?.cancel();
    service.close();
    // Optionally shut down service if needed
  }
}
