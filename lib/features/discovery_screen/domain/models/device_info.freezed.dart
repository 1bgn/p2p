// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DeviceInfo {

 String get roomCode; String get ip; String get name; int get tcpPort; DateTime get lastSeen; String get deviceType;
/// Create a copy of DeviceInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceInfoCopyWith<DeviceInfo> get copyWith => _$DeviceInfoCopyWithImpl<DeviceInfo>(this as DeviceInfo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceInfo&&(identical(other.roomCode, roomCode) || other.roomCode == roomCode)&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.name, name) || other.name == name)&&(identical(other.tcpPort, tcpPort) || other.tcpPort == tcpPort)&&(identical(other.lastSeen, lastSeen) || other.lastSeen == lastSeen)&&(identical(other.deviceType, deviceType) || other.deviceType == deviceType));
}


@override
int get hashCode => Object.hash(runtimeType,roomCode,ip,name,tcpPort,lastSeen,deviceType);

@override
String toString() {
  return 'DeviceInfo(roomCode: $roomCode, ip: $ip, name: $name, tcpPort: $tcpPort, lastSeen: $lastSeen, deviceType: $deviceType)';
}


}

/// @nodoc
abstract mixin class $DeviceInfoCopyWith<$Res>  {
  factory $DeviceInfoCopyWith(DeviceInfo value, $Res Function(DeviceInfo) _then) = _$DeviceInfoCopyWithImpl;
@useResult
$Res call({
 String roomCode, String ip, String name, int tcpPort, DateTime lastSeen, String deviceType
});




}
/// @nodoc
class _$DeviceInfoCopyWithImpl<$Res>
    implements $DeviceInfoCopyWith<$Res> {
  _$DeviceInfoCopyWithImpl(this._self, this._then);

  final DeviceInfo _self;
  final $Res Function(DeviceInfo) _then;

/// Create a copy of DeviceInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? roomCode = null,Object? ip = null,Object? name = null,Object? tcpPort = null,Object? lastSeen = null,Object? deviceType = null,}) {
  return _then(_self.copyWith(
roomCode: null == roomCode ? _self.roomCode : roomCode // ignore: cast_nullable_to_non_nullable
as String,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,tcpPort: null == tcpPort ? _self.tcpPort : tcpPort // ignore: cast_nullable_to_non_nullable
as int,lastSeen: null == lastSeen ? _self.lastSeen : lastSeen // ignore: cast_nullable_to_non_nullable
as DateTime,deviceType: null == deviceType ? _self.deviceType : deviceType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// @nodoc


class _DeviceInfo implements DeviceInfo {
  const _DeviceInfo({required this.roomCode, required this.ip, required this.name, required this.tcpPort, required this.lastSeen, required this.deviceType});
  

@override final  String roomCode;
@override final  String ip;
@override final  String name;
@override final  int tcpPort;
@override final  DateTime lastSeen;
@override final  String deviceType;

/// Create a copy of DeviceInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceInfoCopyWith<_DeviceInfo> get copyWith => __$DeviceInfoCopyWithImpl<_DeviceInfo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceInfo&&(identical(other.roomCode, roomCode) || other.roomCode == roomCode)&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.name, name) || other.name == name)&&(identical(other.tcpPort, tcpPort) || other.tcpPort == tcpPort)&&(identical(other.lastSeen, lastSeen) || other.lastSeen == lastSeen)&&(identical(other.deviceType, deviceType) || other.deviceType == deviceType));
}


@override
int get hashCode => Object.hash(runtimeType,roomCode,ip,name,tcpPort,lastSeen,deviceType);

@override
String toString() {
  return 'DeviceInfo(roomCode: $roomCode, ip: $ip, name: $name, tcpPort: $tcpPort, lastSeen: $lastSeen, deviceType: $deviceType)';
}


}

/// @nodoc
abstract mixin class _$DeviceInfoCopyWith<$Res> implements $DeviceInfoCopyWith<$Res> {
  factory _$DeviceInfoCopyWith(_DeviceInfo value, $Res Function(_DeviceInfo) _then) = __$DeviceInfoCopyWithImpl;
@override @useResult
$Res call({
 String roomCode, String ip, String name, int tcpPort, DateTime lastSeen, String deviceType
});




}
/// @nodoc
class __$DeviceInfoCopyWithImpl<$Res>
    implements _$DeviceInfoCopyWith<$Res> {
  __$DeviceInfoCopyWithImpl(this._self, this._then);

  final _DeviceInfo _self;
  final $Res Function(_DeviceInfo) _then;

/// Create a copy of DeviceInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? roomCode = null,Object? ip = null,Object? name = null,Object? tcpPort = null,Object? lastSeen = null,Object? deviceType = null,}) {
  return _then(_DeviceInfo(
roomCode: null == roomCode ? _self.roomCode : roomCode // ignore: cast_nullable_to_non_nullable
as String,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,tcpPort: null == tcpPort ? _self.tcpPort : tcpPort // ignore: cast_nullable_to_non_nullable
as int,lastSeen: null == lastSeen ? _self.lastSeen : lastSeen // ignore: cast_nullable_to_non_nullable
as DateTime,deviceType: null == deviceType ? _self.deviceType : deviceType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
