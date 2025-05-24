import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../features/discovery_screen/presentation/ui/discovery_screen.dart';
import '../features/transfer_screen/presentation/ui/transfer_sceren.dart';




part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen|Page,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    // AutoRoute(page: LoginRoute.page, initial: true),
    // AutoRoute(page: HomeRoute.page),
    // AutoRoute(page: ProfileRoute.page),
    AutoRoute(page: DiscoveryRoute.page,initial: true),
    AutoRoute(page: TransferRoute.page),
  ];
}
