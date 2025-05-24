// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:beam_drop/di/injectable_module.dart' as _i965;
import 'package:beam_drop/features/discovery_screen/application/tcp_client.dart'
    as _i919;
import 'package:beam_drop/features/discovery_screen/application/tcp_server.dart'
    as _i206;
import 'package:beam_drop/features/discovery_screen/application/ws_client.dart'
    as _i970;
import 'package:beam_drop/features/discovery_screen/application/ws_server.dart'
    as _i203;
import 'package:beam_drop/features/discovery_screen/presentation/controller/connection_controller.dart'
    as _i970;
import 'package:beam_drop/features/discovery_screen/presentation/controller/discovery_controller.dart'
    as _i305;
import 'package:beam_drop/router/app_router.dart' as _i413;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final injectableModule = _$InjectableModule();
    gh.lazySingleton<_i413.AppRouter>(() => injectableModule.appRouter);
    gh.lazySingleton<_i206.TcpServer>(() => _i206.TcpServer());
    gh.lazySingleton<_i203.WsServer>(() => _i203.WsServer());
    gh.lazySingleton<_i970.WsClient>(() => _i970.WsClient());
    gh.lazySingleton<_i919.TcpClient>(() => _i919.TcpClient());
    gh.lazySingleton<_i305.DiscoveryController>(
      () => _i305.DiscoveryController(),
    );
    gh.lazySingleton<_i970.ConnectionController>(
      () => _i970.ConnectionController(
        gh<_i970.WsClient>(),
        gh<_i203.WsServer>(),
      ),
    );
    return this;
  }
}

class _$InjectableModule extends _i965.InjectableModule {}
