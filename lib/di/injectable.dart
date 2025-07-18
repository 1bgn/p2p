import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'injectable.config.dart'; // будет сгенерирован автоматически

final getIt = GetIt.instance;

@injectableInit
void configureDependencies() => getIt.init();