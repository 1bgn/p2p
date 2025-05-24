// lib/features/discovery_screen/application/ws_server.dart
import 'dart:async';
import 'dart:io';
import 'package:injectable/injectable.dart';

@LazySingleton()
class WsServer {
  final _ctrl = StreamController<WebSocket>.broadcast();
  Stream<WebSocket> get stream => _ctrl.stream;

  late HttpServer _http;

  Future<int> start({int preferredPort = 0}) async {
    _http = await HttpServer.bind(InternetAddress.anyIPv4, preferredPort);
    _http.listen((req) async {
      if (WebSocketTransformer.isUpgradeRequest(req)) {
        final ws = await WebSocketTransformer.upgrade(req);
        _ctrl.add(ws);
      } else {
        req.response..statusCode = HttpStatus.badRequest..close();
      }
    });
    return _http.port;
  }

  Future<void> stop() async => _http.close(force: true);
}
