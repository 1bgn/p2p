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
      return DiscoveryScreen();
    },
  );
}

/// generated route for
/// [TransferScreen]
class TransferRoute extends PageRouteInfo<TransferRouteArgs> {
  TransferRoute({
    Key? key,
    required Socket socket,
    required String remoteRoomCode,
    List<PageRouteInfo>? children,
  }) : super(
         TransferRoute.name,
         args: TransferRouteArgs(
           key: key,
           socket: socket,
           remoteRoomCode: remoteRoomCode,
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
        socket: args.socket,
        remoteRoomCode: args.remoteRoomCode,
      );
    },
  );
}

class TransferRouteArgs {
  const TransferRouteArgs({
    this.key,
    required this.socket,
    required this.remoteRoomCode,
  });

  final Key? key;

  final Socket socket;

  final String remoteRoomCode;

  @override
  String toString() {
    return 'TransferRouteArgs{key: $key, socket: $socket, remoteRoomCode: $remoteRoomCode}';
  }
}
