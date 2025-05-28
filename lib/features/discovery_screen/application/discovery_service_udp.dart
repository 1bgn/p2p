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

/// Через сколько считать устройство “мертвым”
 const _ttl = Duration(seconds: 5);

@lazySingleton
class DiscoveryServiceUdp {
  final _ctrl = StreamController<List<DeviceInfo>>.broadcast();
  Stream<List<DeviceInfo>> get stream => _ctrl.stream;

  /// карту ключ→DeviceInfo теперь будем чистить по TTL
  final _map = <String, DeviceInfo>{};

  RawDatagramSocket? _recv, _send;
  Timer? _broadcastTimer, _purgeTimer;
  List<InternetAddress> _targets = [InternetAddress('255.255.255.255')];
  static Future<List<InternetAddress>> _calcBroadcast() async {
    if (kIsWeb) return [InternetAddress('255.255.255.255')];
    final info = NetworkInfo();
    final ip   = await info.getWifiIP();
    final mask = await info.getWifiSubmask();
    if (ip == null || mask == null) {
      return [InternetAddress('255.255.255.255')];
    }
    final ipBytes   = ip.split('.').map(int.parse).toList();
    final maskBytes = mask.split('.').map(int.parse).toList();
    final bcBytes   = List<int>.generate(
        4, (i) => ipBytes[i] | (255 ^ maskBytes[i])
    );
    return [InternetAddress(bcBytes.join('.'))];
  }
  Future<void> start(String room, int tcpPort) async {
    _targets = await _calcBroadcast();

    // Настраиваем приёмник
    _recv = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4, discoveryPort,
      reuseAddress: true, reusePort: true,
    )..listen(_onRead);

    // Настраиваем отправитель
    _send = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)
      ..broadcastEnabled = true;

    // Периодическая рассылка DISCOVER
    _broadcastTimer = Timer.periodic(discoveryInterval,
            (_) => _broadcast(room, tcpPort));

    // И — очень важно — чистим _map чаще, чем TTL,
    // чтобы удалять “мертвые” устройства
    _purgeTimer = Timer.periodic(Duration(seconds: 1), (_) => _purge());

    debugPrint('[UDP] started. Targets: $_targets');
  }

  void _broadcast(String room, int port) {
    final msg = 'DISCOVER:$room:$port';
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
    if (!text.startsWith('DISCOVER:')) return;

    final parts = text.split(':');
    if (parts.length < 3) return;

    final key = '${dg.address.address}:${parts[1]}';
    final dev = DeviceInfo(
      roomCode: parts[1],
      ip: dg.address.address,
      tcpPort: int.tryParse(parts[2]) ?? 0,
      lastSeen: DateTime.now(),
    );
    _map[key] = dev;

    // сразу отдаём клиенту свежий список
    _ctrl.add(_map.values.toList());
  }

  /// удаляем все записи, у которых lastSeen устарел сильнее, чем _ttl
  void _purge() {
    final now = DateTime.now();
    final removed = _map.keys
        .where((k) => now.difference(_map[k]!.lastSeen) > _ttl)
        .toList();
    if (removed.isNotEmpty) {
      for (final k in removed) {
        _map.remove(k);
        debugPrint('[UDP] purged → $k');
      }
      // и снова отдадим обновлённый список
      _ctrl.add(_map.values.toList());
    }
  }

  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _purgeTimer?.cancel();
    _send?.close();
    _recv?.close();
    _map.clear();
  }
}
