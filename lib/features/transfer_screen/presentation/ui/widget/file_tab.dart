import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../../controller/transfer_controller.dart';


class FilesTab extends StatelessWidget {
  final TransferController controller;
  const FilesTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final fileList = controller.files.value;

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: fileList.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (_, i) {
        final f = fileList[i];
        return ListTile(
          leading: f.isImage
              ? Image.file(
            File(f.path),
            width: 48,
            height: 48,
            fit: BoxFit.cover,
          )
              : Icon(
            f.sent ? Icons.upload_file : Icons.insert_drive_file,
          ),
          title: Text(
            f.name,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            f.sent
                ? 'sent'
                : f.saved
                ? 'received'
                : 'not saved',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => controller.download(f),
          ),
          onTap: () {
            if (f.isImage) {
              showDialog(
                context: context,
                builder: (_) => Dialog(
                  child: InteractiveViewer(
                    child: Image.file(File(f.path)),
                  ),
                ),
              );
            } else {
              OpenFilex.open(f.path);
            }
          },
        );
      },
    );
  }
}