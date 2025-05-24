// lib/features/discovery_screen/presentation/ui/discovery_screen.dart
import 'dart:math';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
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
  late final String _myRoom;

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
    await requestNecessaryPermissions();
    final port = await _conn.startServer();
    await _disc.start(_myRoom, port);

    _conn.incomingSocket.addListener(() {
      final sock = _conn.incomingSocket.value;
      if (sock != null) context.router.push(
        TransferRoute(socket: sock, remoteRoomCode: 'Unknown'),
      );
    });
  }

  void _connect(DeviceInfo dev) async {
    final sock = await _conn.connect(dev);
    if (!mounted) return;
    context.router.push(
      TransferRoute(socket: sock, remoteRoomCode: dev.roomCode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devices = watchSignal(context,_disc.discovered);
    return Scaffold(
      appBar: AppBar(
        title: const Text('P2P Discovery'),
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
