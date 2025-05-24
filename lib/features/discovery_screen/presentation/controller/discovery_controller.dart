import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:flutter_nsd/flutter_nsd.dart';
import 'package:signals_core/signals_core.dart';
import '../../application/discovery_service_udp.dart';
import '../../domain/models/device_info.dart';


@LazySingleton()
class DiscoveryController {
  final _udp = DiscoveryServiceUdp.instance;
  final _nsd = FlutterNsd();

  final discovered = Signal<List<DeviceInfo>>([]);
  final _cache = <String, DeviceInfo>{};
  static const _grace = Duration(seconds: 2);
  StreamSubscription? _udpSub, _nsdSub;
  Timer? _ttlTimer;
  static const _ttl = Duration(seconds: 5);

  Future<void> start(String room, int tcpPort) async {
    await _udp.start(room, tcpPort);
    _udpSub = _udp.stream.listen(_mergeList);

    _nsdSub = _nsd.stream.listen((s) {
      if (s.hostname == null) return;
      _merge(DeviceInfo(
        roomCode: s.txt?['room']as String? ?? 'unknown',
        ip: s.hostname!,
        tcpPort: s.port ?? 0,
        lastSeen: DateTime.now(),
      ));
    });

    await _nsd.discoverServices('_p2ptransfer._tcp.');
    _ttlTimer = Timer.periodic(const Duration(seconds: 5), (_) => _purge());
  }

  void _mergeList(List<DeviceInfo> list) => list.forEach(_merge);
  void injectPeer(String room, String ip, int port) {
    _merge(DeviceInfo(
      roomCode: room,
      ip: ip,
      tcpPort: port,
      lastSeen: DateTime.now(),
    ));
  }
  void _merge(DeviceInfo d) {
    _cache[d.ip] = d;
    _refresh();
  }

  void _purge() {
    final now = DateTime.now();
    _cache.removeWhere(
            (_, d) => now.difference(d.lastSeen) > _ttl + _grace
    );
    _refresh();
  }

  void _refresh() => discovered.value = _cache.values.toList();

  void dispose() {
    _udpSub?.cancel();
    _nsdSub?.cancel();
    _ttlTimer?.cancel();
    _udp.stop();
    _nsd.stopDiscovery();
    discovered.dispose();
  }
}
