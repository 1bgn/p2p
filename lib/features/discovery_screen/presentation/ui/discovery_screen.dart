// lib/features/discovery_screen/presentation/ui/discovery_screen.dart
import 'dart:math';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../../di/injectable.dart';
import '../../../../router/app_router.dart';
import '../../../../utils/permissions.dart';
import '../../domain/models/device_info.dart';
import '../controller/connection_controller.dart';
import '../controller/discovery_controller.dart';

@RoutePage()
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> with SignalsMixin {
  final _conn = getIt<ConnectionController>();
  final _disc = getIt<DiscoveryController>();
  String _myRoom = "";
   String _myIp = "";
  bool _transferOpen = false;

  @override
  void initState() {
    super.initState();
    _myRoom = _generateRoomCode();
    _boot();
  }

  String _generateRoomCode() {
    final r = Random(DateTime.now().millisecondsSinceEpoch & 0xFFFF);
    return (100000 + r.nextInt(900000)).toString(); // six-digit
  }

  Future<void> _boot() async {
    final ip = await NetworkInfo().getWifiIP();
    _myIp = ip ?? '0.0.0.0';
    await requestNecessaryPermissions();

    final port = await _conn.startServer();
    await _disc.start(_myRoom, port);

    _conn.incomingSocket.addListener(() async {
      final sock = _conn.incomingSocket.value;
      if (sock != null && !_transferOpen) {
        _transferOpen = true;
        context.router.push(
          TransferRoute(socket: sock, remoteRoomCode: 'Unknown'),
        ).then((_) => _transferOpen = false);
      }
    });
  }

  Future<void> _connect(DeviceInfo d) async {
    if (_transferOpen) return;                     // уже открыт чат
    final sock = await _conn.connect(d);
    if (!mounted) return;
    _transferOpen = true;
    context.router.push(
      TransferRoute(socket: sock, remoteRoomCode: d.roomCode),
    ).then((_) => _transferOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final all = watchSignal(context,_disc.discovered);
    final devices = all.where((d) => d.ip != _myIp).toList(); // ← NEW
    return Scaffold(
      appBar: AppBar(
        title: const Text('P2P Discovery'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('My IP $_myIp   Room $_myRoom',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ),
      ),
      body: ListView.separated(
        itemCount: devices.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (_, i) {
          final d = devices[i];
          return ListTile(
            leading: const Icon(Icons.computer),
            title: Text('Room: ${d.roomCode}'),
            subtitle: Text('${d.ip}:${d.tcpPort}'),
            trailing: ElevatedButton(
              onPressed: () => _connect(d),
              child: const Text('Connect'),
            ),
          );
        },
      ),
    );
  }


  @override
  void dispose() {
    _disc.dispose();
    _conn.dispose();
    super.dispose();
  }
}
