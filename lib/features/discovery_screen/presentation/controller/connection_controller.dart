import 'dart:io';

import 'package:beam_drop/features/discovery_screen/presentation/controller/discovery_controller.dart';
import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_core.dart';

import '../../application/tcp_client.dart';
import '../../application/tcp_server.dart';
import '../../domain/models/device_info.dart';
@LazySingleton()
class ConnectionController {
  final DiscoveryController discoveryController;
  ConnectionController({required this.client,required this.server,required this.discoveryController});

  final TcpServer server;
  final TcpClient client;

  /// Сокет входящего коннекта (когда кто‑то подключился к нам)
  final incomingSocket = signal<Socket?>(null);

  Future<int> startServer({int preferredPort = 8080}) async {
    final port = await server.start(preferredPort: preferredPort);
    server.clientStream.listen((sock) {
      incomingSocket.value = sock;
      discoveryController.injectPeer('unknown', sock.remoteAddress.address, sock.remotePort);
    });
    return port;
  }


  Future<Socket> connect(DeviceInfo target) async {
    return client.connect(target.ip, target.tcpPort);
  }

  void dispose() {
    server.stop();
    incomingSocket.dispose();
  }
}