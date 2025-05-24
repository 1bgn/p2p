import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/models/device_info.dart';

const int discoveryPort = 12345; // UDP discovery port
const Duration discoveryInterval = Duration(seconds: 2);
const String discoveryMessagePrefix = 'DISCOVER:';
final InternetAddress _broadcastAddress = InternetAddress('255.255.255.255');
class DiscoveryService {
  DiscoveryService._internal();
  static final DiscoveryService instance = DiscoveryService._internal();

  final _controller = StreamController<List<DeviceInfo>>.broadcast();
  RawDatagramSocket? _listenSocket;
  RawDatagramSocket? _broadcastSocket;
  Timer? _broadcastTimer;
  final Map<String, DeviceInfo> _devices = {};

  Stream<List<DeviceInfo>> get devicesStream => _controller.stream;

  Future<void> start(String myRoomCode, int tcpPort) async {
    await _startListening();
    await _startBroadcasting(myRoomCode, tcpPort);
  }

  Future<void> stop() async {
     _broadcastTimer?.cancel();
    _broadcastSocket?.close();
    _listenSocket?.close();
    _devices.clear();
  }

  Future<void> _startListening() async {
    _listenSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort, reuseAddress: true, reusePort: true);
    _listenSocket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = _listenSocket!.receive();
        if (dg == null) return;
        final msg = utf8.decode(dg.data);
        if (!msg.startsWith(discoveryMessagePrefix)) return;
        // DISCOVER:<roomCode>:<tcpPort>
        final parts = msg.split(':');
        if (parts.length < 3) return;
        final room = parts[1];
        final tcpPort = int.tryParse(parts[2]) ?? 0;
        final key = '${dg.address.address}:$room';
        _devices[key] = DeviceInfo(
          roomCode: room,
          ip: dg.address.address,
          tcpPort: tcpPort,
          lastSeen: DateTime.now(),
        );
        _controller.add(_devices.values.toList());
      }
    });
  }

  Future<void> _startBroadcasting(String myRoomCode, int tcpPort) async {
    _broadcastSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _broadcastSocket!.broadcastEnabled = true;
    _broadcastTimer = Timer.periodic(discoveryInterval, (_) {
      final msg = '$discoveryMessagePrefix$myRoomCode:$tcpPort';
      final dg = Datagram(utf8.encode(msg), _broadcastAddress, discoveryPort);
      _broadcastSocket!.send(dg.data, dg.address, dg.port);
    });
  }
}