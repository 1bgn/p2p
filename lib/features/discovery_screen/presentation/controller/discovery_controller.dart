import 'dart:async';
import 'dart:io';
import 'package:beam_drop/features/discovery_screen/application/ws_client.dart';
import 'package:beam_drop/features/discovery_screen/application/ws_server.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_nsd/flutter_nsd.dart';
import 'package:signals_core/signals_core.dart';
import '../../application/discovery_service_udp.dart';
import '../../domain/models/device_info.dart';


@LazySingleton()
class DiscoveryController {
  final DiscoveryServiceUdp _udp;
  final _nsd = FlutterNsd();

  final discovered = Signal<List<DeviceInfo>>([]);
  final _cache = <String, DeviceInfo>{};
  static const _grace = Duration(seconds: 2);

  StreamSubscription? _udpSub, _nsdSub;
  final WsClient client;
  final WsServer server;

  DiscoveryController(this.client, this.server, this._udp);

  final incoming = signal<WebSocket?>(null);

  Future<int> startServer() async {
    final port = await server.start(preferredPort: 0);
    server.stream.listen((ws) {
      print("create socket connection");
      incoming.value = ws;
    });
    return port;
  }

  Future<WebSocket> connect(DeviceInfo d) =>
      client.connect(d.ip, d.tcpPort);

  Timer? _ttlTimer;
  static const _ttl = Duration(seconds: 5);

  Future<void> start(String room, int tcpPort) async {
    // Запускаем альтернативный UDP-Discovery
    await _udp.start(room, tcpPort);

    _udpSub = _udp.stream.listen(_mergeList);
    // Подписываемся на mDNS

    // _nsdSub = _nsd.stream.listen((s) async {
    //
    //   if (s.hostname == null) return;
    //   // Получаем тип устройства так же, как и в UDP
    //   final type = await _udp.getDeviceType();
    //
    //   // Имя может приходить в TXT, иначе — локальный hostname
    //   final name = s.txt?['name'] as String? ?? Platform.localHostname;
    //   final roomCode = s.txt?['room'] as String? ?? 'unknown';
    //   final port = s.port ?? 0;
    //   final dev = DeviceInfo(
    //     name: name,
    //     roomCode: roomCode,
    //     ip: s.hostname!,
    //     tcpPort: port,
    //     lastSeen: DateTime.now(),
    //     deviceType: type,
    //   );
    //
    //   _merge(dev);
    // });

    await _nsd.discoverServices('_p2ptransfer._tcp.');
    _ttlTimer = Timer.periodic(const Duration(seconds: 5), (_) => _purge());
  }

  void _mergeList(List<DeviceInfo> list) => list.forEach(_merge);

  void _merge(DeviceInfo d) {
    _cache[d.ip] = d;
    _refresh();

  }

  void _purge() {
    final now = DateTime.now();
    _cache.removeWhere(
          (_, d) => now.difference(d.lastSeen) > _ttl + _grace,
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
    server.stop();
    incoming.dispose();
    discovered.dispose();
  }
}