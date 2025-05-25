import 'package:flutter/material.dart';
import '../../controller/transfer_controller.dart';

class InputBar extends StatelessWidget {
  final TransferController controller;
  const InputBar({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Builder(
                builder: (_) => TextField(
                  controller: TextEditingController(text: controller.text.value),
                  onChanged: (v) => controller.text.value = v,
                  onSubmitted: (_) => controller.sendText(),
                  decoration: const InputDecoration(labelText: 'Say something'),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: () async {
                final choice = await showModalBottomSheet<String>(
                  context: context,
                  builder: (_) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: const Text('Gallery'),
                          onTap: () => Navigator.pop(context, 'images'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.folder),
                          title: const Text('Files'),
                          onTap: () => Navigator.pop(context, 'files'),
                        ),
                      ],
                    ),
                  ),
                );
                if (choice == 'images') {
                  await controller.pickImages();
                } else if (choice == 'files') {
                  await controller.pickFiles();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: controller.sendText,
            ),
          ],
        ),
      ),
    );
  }
}