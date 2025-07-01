import 'package:beam_drop/di/injectable.dart';
import 'package:beam_drop/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:signals/signals.dart';

void main() {
  configureDependencies();
  SignalsObserver.instance = null;
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.light();

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: Color.fromRGBO(244, 244, 246, 1.0),
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: Color.fromARGB(255, 93, 111, 230),
              brightness: Brightness.light,
            ).copyWith(
              surface: Colors.white,
              background: Colors.white,
              surfaceTint: Colors.transparent,
            ),

        textTheme: GoogleFonts.interTextTheme(base.textTheme),
        primaryTextTheme: GoogleFonts.interTextTheme(base.primaryTextTheme),
      ),
      routerConfig: getIt<AppRouter>().config(),
    );
  }
}
