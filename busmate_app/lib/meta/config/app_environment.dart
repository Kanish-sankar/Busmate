import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

import 'package:busmate/firebase_options.dart';
import 'package:busmate/firebase_options_dev.dart';

class AppEnvironment {
  static const String prod = 'prod';
  static const String dev = 'dev';

  static String normalize(String? env) {
    final value = (env ?? '').trim().toLowerCase();
    if (value == dev || value == 'development') {
      return dev;
    }
    return prod;
  }

  static FirebaseOptions firebaseOptionsFor(String? env) {
    final normalized = normalize(env);
    if (normalized == dev) {
      return DefaultFirebaseOptionsDev.currentPlatform;
    }
    return DefaultFirebaseOptions.currentPlatform;
  }
}
