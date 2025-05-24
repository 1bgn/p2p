import 'dart:convert';
import 'dart:io';

import 'package:injectable/injectable.dart';
@LazySingleton()
class TcpClient {
  Future<Socket> connect(String ip, int port) async {
    final socket = await Socket.connect(ip, port);
    return socket;
  }

  /// Returns a stream of UTF‑8 lines arriving from [socket].
  ///
  /// We cast the underlying `Uint8List` chunks to `List<int>` so that
  /// `utf8.decoder` fits the generic constraints of `Stream.transform`.
  Stream<String> readLines(Socket socket) {
    return socket
        .cast<List<int>>()              // make the type compatible
        .transform(utf8.decoder)        // bytes → string
        .transform(const LineSplitter());
  }
}