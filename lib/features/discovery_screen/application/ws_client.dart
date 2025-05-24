// lib/features/discovery_screen/application/ws_client.dart
import 'dart:io';
import 'package:injectable/injectable.dart';

@LazySingleton()
class WsClient {
  Future<WebSocket> connect(String ip, int port) =>
      WebSocket.connect('ws://$ip:$port');
}
