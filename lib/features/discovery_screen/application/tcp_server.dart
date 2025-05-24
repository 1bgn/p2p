import 'dart:async';
import 'dart:io';

import 'package:injectable/injectable.dart';
@LazySingleton()
class TcpServer {
  late final ServerSocket _server;
  final _clientController = StreamController<Socket>.broadcast();
  Stream<Socket> get clientStream => _clientController.stream;

  Future<int> start({int preferredPort = 8080}) async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, preferredPort);
    _server.listen((client) => _clientController.add(client));
    return _server.port; // Might differ if preferredPort was 0
  }

  Future<void> stop() async {
    await _server.close();
  }
}