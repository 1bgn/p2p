// lib/services/discovery_service_udp.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:injectable/injectable.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../domain/models/device_info.dart';

const discoveryPort = 12345;
const discoveryInterval = Duration(seconds: 1);

/// Через сколько считать устройство “мертвым”
 const _ttl = Duration(seconds: 5);

// lib/services/discovery_service_udp.dart






@lazySingleton
class DiscoveryServiceUdp {
  final _ctrl = StreamController<List<DeviceInfo>>.broadcast();
  Stream<List<DeviceInfo>> get stream => _ctrl.stream;

  final _map = <String, DeviceInfo>{};
  late final String _myName;
  late final String _myType;

  RawDatagramSocket? _recv, _send;
  Timer? _broadcastTimer, _purgeTimer;
  List<InternetAddress> _targets = [InternetAddress('255.255.255.255')];

  static Future<List<InternetAddress>> _calcBroadcast() async {
    if (kIsWeb) return [InternetAddress('255.255.255.255')];
    final info = NetworkInfo();
    final ip = await info.getWifiIP();
    final mask = await info.getWifiSubmask();
    if (ip == null || mask == null) {
      return [InternetAddress('255.255.255.255')];
    }
    final ipBytes = ip.split('.').map(int.parse).toList();
    final maskBytes = mask.split('.').map(int.parse).toList();
    final bcBytes = List<int>.generate(
        4, (i) => ipBytes[i] | (255 ^ maskBytes[i]));
    return [InternetAddress(bcBytes.join('.'))];
  }

  Future<String> getDeviceName() async {
    final plugin = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return info.model ?? 'Android-устройство';
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return info.name ?? 'iOS-устройство';
      } else if (Platform.isMacOS) {
        final info = await plugin.macOsInfo;
        return info.model ?? 'macOS-устройство';
      } else if (Platform.isWindows) {
        final info = await plugin.windowsInfo;
        return info.computerName ?? 'Windows-ПК';
      } else if (Platform.isLinux) {
        final info = await plugin.linuxInfo;
        return info.name ?? 'Linux-ПК';
      }
    } catch (_) { }
    return 'Неизвестное устройство';
  }

  Future<String> getDeviceType() async {
    // Определяем тип: ПК, телефон или планшет
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        return 'ПК';
      }
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        final features = info.systemFeatures ?? [];
        return features.contains('android.hardware.telephony')
            ? 'Телефон'
            : 'Планшет';
      }
      if (Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        final model = (info.model ?? '').toLowerCase();
        return model.contains('ipad') ? 'Планшет' : 'Телефон';
      }
    } catch (_) {}
    return 'Неизвестно';
  }

  Future<void> start(String room, int tcpPort) async {
    _targets = await _calcBroadcast();
    _myName = await getDeviceName();
    _myType = await getDeviceType();

    _recv = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4, discoveryPort,
      reuseAddress: true, reusePort: true,
    )..listen(_onRead);

    _send = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)
      ..broadcastEnabled = true;

    _broadcastTimer =
        Timer.periodic(discoveryInterval, (_) => _broadcast(room, tcpPort));
    _purgeTimer = Timer.periodic(Duration(seconds: 1), (_) => _purge());

    debugPrint('[UDP] started. Targets: $_targets');
  }

  void _broadcast(String room, int port) {
    final msg = jsonEncode({
      'room': room,
      'port': port,
      'name': _myName,
      'type': _myType,
    });
    for (final t in _targets) {
      _send!.send(utf8.encode(msg), t, discoveryPort);
    }
    // debugPrint('[UDP] send → $msg');
  }

  void _onRead(RawSocketEvent event) {
    final dg = _recv!.receive();
    if (dg == null) return;

    final text = utf8.decode(dg.data);
    // debugPrint('[UDP] recv ← $text');

    Map<String, dynamic> obj;
    try {
      obj = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return; // не JSON — пропустить
    }
    if (!obj.containsKey('room') ||
        !obj.containsKey('port') ||
        !obj.containsKey('name') ||
        !obj.containsKey('type')) {
      return;
    }

    final room = obj['room'] as String;
    final port = (obj['port'] as num).toInt();
    final name = obj['name'] as String;
    final type = obj['type'] as String;

    final key = '${dg.address.address}:$room';
    final dev = DeviceInfo(
      name: name,
      roomCode: room,
      ip: dg.address.address,
      tcpPort: port,
      lastSeen: DateTime.now(),
      deviceType: type,
    );

    _map[key] = dev;
    _ctrl.add(_map.values.toList());
  }

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