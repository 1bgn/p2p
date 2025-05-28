import 'dart:io';

import 'package:flutter/material.dart';

import '../../controller/transfer_controller.dart';

class InputBar extends StatelessWidget {
  final TransferController controller;

  const InputBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)),borderSide: BorderSide.none);
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Builder(
                builder: (_) => TextFormField(
                  controller: TextEditingController(
                    text: controller.text.value,
                  ),

                  onChanged: (v) => controller.text.value = v,
                  // onEditingComplete: () {
                  //   controller.sendText();
                  // },
                  onFieldSubmitted: (t){
                    controller.sendText();

                  },
                  // onSubmitted: (_) => ,/**/
                  decoration: InputDecoration(
                    hintText: 'Type a message',
                    border: border,
                    filled: true,
                    fillColor: Color.fromRGBO(244, 244, 246, 1.0),
                    
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: () async {
                if (Platform.isMacOS || Platform.isWindows) {
                  await controller.pickFiles();
                } else {
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
