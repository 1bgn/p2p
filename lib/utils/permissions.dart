import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

Future<void> requestNecessaryPermissions() async {
 if(Platform.isAndroid){
   await [
     Permission.storage,
     Permission.nearbyWifiDevices, // Android 13+
   ].request();
 }
}