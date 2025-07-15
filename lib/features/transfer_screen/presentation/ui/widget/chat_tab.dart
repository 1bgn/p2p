import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controller/transfer_controller.dart';

class ChatTab extends StatelessWidget {
  final TransferController controller;

  const ChatTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: controller.messages.value.length,
      itemBuilder: (_, i) => Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.symmetric(horizontal: 12,vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [Expanded(child: SelectableText(controller.messages.value[i],style: TextStyle(fontSize: 16),),),InkWell(onTap: (){
          Clipboard.setData( ClipboardData(text: controller.messages.value[i])).then((_) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Скопировано')));
          });
        },child: Icon(Icons.copy))],)
      ),
    );
  }
}
