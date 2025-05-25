import 'package:signals_flutter/signals_core.dart';

import '../../domain/model/file_entry.dart';

class TransferController {
  final String roomCode;
  final service = TransferService();
  final messages = ReactiveList<String>();
  final files = signal(List<FileEntry>.empty);
  final text = signal(List<String>.empty);

  TransferController(this.roomCode) {
    service.connect(roomCode);
    service.textStream.listen(_onTextReceived);
    service.fileStream.listen(_onFileReceived);
  }

  void _onTextReceived(String msg) {
    messages.add('Remote: \$msg');
  }

  void _onFileReceived(FileEntry entry) {
    files.add(entry);
    messages.add('📥 \${entry.name} received');
  }

  void sendText() {
    final t = text.value.trim();
    if (t.isEmpty) return;
    service.sendText(t);
    messages.add('Me: \$t');
    text.value = '';
  }

  Future<void> pickAndSend() => service.pickAndSend();
  Future<void> download(FileEntry entry) => service.download(entry);
}