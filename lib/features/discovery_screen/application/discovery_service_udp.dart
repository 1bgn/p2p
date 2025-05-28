// lib/services/discovery_service_udp.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:injectable/injectable.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../domain/models/device_info.dart';

const discoveryPort = 12345;
const discoveryInterval = Duration(seconds: 1);
const prefix = 'DISCOVER:';                 // DISCOVER:<room>:<port>

/// Возвращает список broadcast-адресов всех IPv4-интерфейсов.
Future<List<InternetAddress>> _calcBroadcast() async {
  if (kIsWeb) return [InternetAddress('255.255.255.255')];
  final info = NetworkInfo();
  final ip   = await info.getWifiIP();
  final mask = await info.getWifiSubmask();
  if (ip == null || mask == null) {
    return [InternetAddress('255.255.255.255')];
  }
  // simple bitwise-or: broadcast = ip | ~mask
  final ipBytes   = ip.split('.').map(int.parse).toList();
  final maskBytes = mask.split('.').map(int.parse).toList();
  final bcBytes   = List<int>.generate(4, (i) => ipBytes[i] | (255 ^ maskBytes[i]));
  return [InternetAddress(bcBytes.join('.'))];
}
@lazySingleton
class DiscoveryServiceUdp {
  // DiscoveryServiceUdp._();
  // static final instance = DiscoveryServiceUdp._();

  final _ctrl = StreamController<List<DeviceInfo>>.broadcast();
  Stream<List<DeviceInfo>> get stream => _ctrl.stream;
  Stream<List<DeviceInfo>> get devicesStream => _ctrl.stream;
  final _map = <String, DeviceInfo>{};
  RawDatagramSocket? _recv, _send;
  Timer? _timer;
  List<InternetAddress> _targets = [InternetAddress('255.255.255.255')];

  Future<void> start(String room, int tcpPort) async {
    _targets = await _calcBroadcast();

    _recv = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4, discoveryPort,
      reuseAddress: true, reusePort: true,
    );
    _recv!.listen(_onRead);

    _send = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _send!.broadcastEnabled = true;

    _timer = Timer.periodic(discoveryInterval,
            (_) => _broadcast(room, tcpPort));

    debugPrint('[UDP] started. Targets: $_targets');
  }

  void _broadcast(String room, int port) {
    final msg = '$prefix$room:$port';
    for (final t in _targets) {
      _send!.send(utf8.encode(msg), t, discoveryPort);
    }
    debugPrint('[UDP] send → $msg');
  }

  void _onRead(RawSocketEvent e) {
    final dg = _recv!.receive();
    if (dg == null) return;
    final text = utf8.decode(dg.data);
    debugPrint('[UDP] recv ← $text');
    if (!text.startsWith(prefix)) return;
    final p = text.split(':');
    if (p.length < 3) return;
    final dev = DeviceInfo(
      roomCode: p[1],
      ip: dg.address.address,
      tcpPort: int.tryParse(p[2]) ?? 0,
      lastSeen: DateTime.now(),
    );
    _map['${dev.ip}:${dev.roomCode}'] = dev;
    _ctrl.add(_map.values.toList());
  }

  Future<void> stop() async {
     _timer?.cancel();
    _send?.close();
    _recv?.close();
    _map.clear();
  }
}
