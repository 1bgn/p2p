import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:signals/signals.dart';

import '../../application/ws_client.dart';
import '../../application/ws_server.dart';
import '../../domain/models/device_info.dart';
@LazySingleton()
class ConnectionController {
  ConnectionController(this._client, this._server);
  final WsClient _client;
  final WsServer _server;

  final incoming = signal<WebSocket?>(null);

  Future<int> startServer() async {
    final port = await _server.start(preferredPort: 0);
    _server.stream.listen((ws) => incoming.value = ws);
    return port;
  }


  Future<WebSocket> connect(DeviceInfo d) =>
      _client.connect(d.ip, d.tcpPort);


  void dispose() {
    _server.stop();
    incoming.dispose();
  }
}