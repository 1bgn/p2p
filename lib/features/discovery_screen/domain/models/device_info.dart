import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_info.freezed.dart';

@freezed
abstract class DeviceInfo  with _$DeviceInfo{
  const factory DeviceInfo({
   required final String roomCode,
   required  final String ip,
   required  final String name,
   required final int tcpPort,
   required  final DateTime lastSeen,
   required String deviceType,
  }) = _DeviceInfo;
}