// lib/features/discovery_screen/application/ws_server.dart
import 'dart:async';
import 'dart:io';
import 'package:injectable/injectable.dart';

@LazySingleton()
class WsServer {
  final _ctrl = StreamController<WebSocket>.broadcast();
  Stream<WebSocket> get stream => _ctrl.stream;
  final _sockets = <WebSocket, String>{}; // WebSocket → IP

  late HttpServer _http;

  Future<int> start({int preferredPort = 0}) async {
    _http = await HttpServer.bind(InternetAddress.anyIPv4, preferredPort);

    _http.listen((req) async {
      if (WebSocketTransformer.isUpgradeRequest(req)) {
        final ip = req.connectionInfo?.remoteAddress.address ?? '0.0.0.0';
        final ws = await WebSocketTransformer.upgrade(req);
        _sockets[ws] = ip;
        _ctrl.add(ws);
      } else {
        req.response..statusCode = HttpStatus.badRequest..close();
      }
    });

    return _http.port;
  }
  String getIpForSocket(WebSocket ws) => _sockets[ws] ?? '0.0.0.0';


  Future<void> stop() async => _http.close(force: true);
}

