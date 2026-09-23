import 'package:busmate_web/app_bootstrap.dart';
import 'package:busmate_web/meta/config/app_environment.dart';

void main() async {
  await bootstrapApp(
    firebaseOptions: AppEnvironment.firebaseOptionsFor(AppEnvironment.prod),
    appEnv: AppEnvironment.prod,
  );
}


