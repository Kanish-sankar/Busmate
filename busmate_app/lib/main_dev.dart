import 'package:busmate/app_bootstrap.dart';
import 'package:busmate/meta/config/app_environment.dart';

Future<void> main() async {
  await bootstrapApp(
    firebaseOptions: AppEnvironment.firebaseOptionsFor(AppEnvironment.dev),
    appEnv: AppEnvironment.dev,
  );
}
