import 'package:flutter/cupertino.dart';

import '../../controller/transfer_controller.dart';

class ChatTab extends StatelessWidget {
  final TransferController controller;
  const ChatTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: controller.messages.value.length,
      itemBuilder: (_, i) => Text(controller.messages.value[i]),
    );
  }
}
