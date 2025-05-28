import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:beam_drop/di/injectable.dart';
import 'package:beam_drop/features/transfer_screen/presentation/ui/widget/chat_tab.dart';
import 'package:beam_drop/features/transfer_screen/presentation/ui/widget/file_tab.dart';
import 'package:beam_drop/features/transfer_screen/presentation/ui/widget/input_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../controller/transfer_controller.dart';

@RoutePage()
class TransferScreen extends StatefulWidget {
  final String remoteRoomCode;
  final WebSocket socket;
   const TransferScreen({super.key, required this.remoteRoomCode, required this.socket});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> with SignalsMixin {
  final controller = getIt<TransferController>();

  @override
  void initState() {
    super.initState();
    controller.init(widget.remoteRoomCode, widget.socket);
    effect((){
      if(controller.disconnected.value){
        AutoRouter.of(context).pop();
      }
    });
  }
  @override
  void dispose() {
    controller.dispose();
    getIt.resetLazySingleton(instance: controller);
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: WatchBuilder(
        builder: (context,c) {
          final fls = watchSignal(context, controller.files);
          final msgs = watchSignal(context, controller.messages);
          return Scaffold(
            appBar: AppBar(
              title: Text('Chat with ${widget.remoteRoomCode}'),
              bottom: const TabBar(tabs: [Tab(text: 'Chat'), Tab(text: 'Files')]),
            ),
            body: TabBarView(children: [
              ChatTab(controller: controller),
              FilesTab(controller: controller),
            ]),
            bottomNavigationBar: InputBar(controller: controller),
          );
        }
      ),
    );
  }
}