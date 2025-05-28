// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [DiscoveryScreen]
class DiscoveryRoute extends PageRouteInfo<void> {
  const DiscoveryRoute({List<PageRouteInfo>? children})
    : super(DiscoveryRoute.name, initialChildren: children);

  static const String name = 'DiscoveryRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const DiscoveryScreen();
    },
  );
}

/// generated route for
/// [TransferScreen]
class TransferRoute extends PageRouteInfo<TransferRouteArgs> {
  TransferRoute({
    Key? key,
    required DeviceInfo deviceInfo,
    required WebSocket socket,
    List<PageRouteInfo>? children,
  }) : super(
         TransferRoute.name,
         args: TransferRouteArgs(
           key: key,
           deviceInfo: deviceInfo,
           socket: socket,
         ),
         initialChildren: children,
       );

  static const String name = 'TransferRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<TransferRouteArgs>();
      return TransferScreen(
        key: args.key,
        deviceInfo: args.deviceInfo,
        socket: args.socket,
      );
    },
  );
}

class TransferRouteArgs {
  const TransferRouteArgs({
    this.key,
    required this.deviceInfo,
    required this.socket,
  });

  final Key? key;

  final DeviceInfo deviceInfo;

  final WebSocket socket;

  @override
  String toString() {
    return 'TransferRouteArgs{key: $key, deviceInfo: $deviceInfo, socket: $socket}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TransferRouteArgs) return false;
    return key == other.key &&
        deviceInfo == other.deviceInfo &&
        socket == other.socket;
  }

  @override
  int get hashCode => key.hashCode ^ deviceInfo.hashCode ^ socket.hashCode;
}
