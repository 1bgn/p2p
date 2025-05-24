import 'package:beam_drop/router/app_router.dart';
import 'package:injectable/injectable.dart';

@module
abstract class InjectableModule{
  @lazySingleton
  AppRouter get appRouter =>AppRouter();
}