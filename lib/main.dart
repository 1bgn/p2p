import 'package:beam_drop/di/injectable.dart';
import 'package:beam_drop/router/app_router.dart';
import 'package:flutter/material.dart';


void main() {
  configureDependencies();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: getIt<AppRouter>().config(),
    );
  }
}
