import 'dart:io';
import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../../di/injectable.dart';
import '../../../../router/app_router.dart';

import '../../../../utils/permissions.dart';
import '../../domain/models/device_info.dart';
import '../controller/discovery_controller.dart';

@RoutePage()
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> with SignalsMixin {
  final _disc = getIt<DiscoveryController>();

  String _myIp = '0.0.0.0';
  bool _transferOpen = false;
  DeviceInfo? _incomingDevice;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final ip = await NetworkInfo().getWifiIP();
    _myIp = ip ?? '0.0.0.0';
    setState(() {});

    await requestNecessaryPermissions();

    final port = await _disc.startServer();

    await _disc.start(Platform.localHostname, port);

    effect(() {
      final ws = _disc.incoming.value;
      if (ws != null && !_transferOpen) {
        final remoteIp = (ws.remoteAddress?.address ?? '');

        // Найди deviceInfo по IP
        final dev = _disc.discovered.value
            .firstWhere((d) => d.ip == remoteIp, orElse: () => DeviceInfo.fallback(remoteIp));

        _transferOpen = true;
        context.router
            .push(TransferRoute(socket: ws, deviceInfo: dev))
            .then((_) => _transferOpen = false);
      }
    });
  }

  Future<void> _connect(DeviceInfo d) async {
    if (_transferOpen) return;
    _incomingDevice = d;
    final ws = await _disc.connect(d);
    if (!mounted) return;
    _transferOpen = true;
    context.router
        .push(TransferRoute(socket: ws, deviceInfo: d))
        .then((_) => _transferOpen = false);
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'ПК':
        return Icons.computer;
      case 'Телефон':
        return Icons.smartphone;
      case 'Планшет':
        return Icons.tablet;
      default:
        return Icons.devices_other;
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = watchSignal(context, _disc.discovered);
    final devices = all.where((d) => d.ip != _myIp).toList();

    return Scaffold(
      // appBar: AppBar(title: const Text('P2P Discovery')),
      body: Column(
        children: [
          SizedBox(height: 32),

          Image.asset("assets/logo.png", height: 200),
          Row(
            children: [
              Expanded(
                child: Text(
                  "BeamDrop",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 32),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: devices.length,
                // separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final d = devices[i];
                  return GestureDetector(
                    onTap: () {
                      _connect(d);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey)),
                      ),
                      child: ListTile(
                        leading: Icon(_iconForType(d.deviceType)),
                        title: Text(d.name),
                        subtitle: Text('${d.ip}:${d.tcpPort}'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _disc.dispose();
    super.dispose();
  }
}
