import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptionsDev {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      _validate(
        platform: 'web',
        values: {
          'DEV_FIREBASE_WEB_API_KEY': _webApiKey,
          'DEV_FIREBASE_WEB_APP_ID': _webAppId,
          'DEV_FIREBASE_MESSAGING_SENDER_ID': _messagingSenderId,
          'DEV_FIREBASE_PROJECT_ID': _projectId,
          'DEV_FIREBASE_STORAGE_BUCKET': _storageBucket,
        },
      );
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        _validate(
          platform: 'android',
          values: {
            'DEV_FIREBASE_ANDROID_API_KEY': _androidApiKey,
            'DEV_FIREBASE_ANDROID_APP_ID': _androidAppId,
            'DEV_FIREBASE_MESSAGING_SENDER_ID': _messagingSenderId,
            'DEV_FIREBASE_PROJECT_ID': _projectId,
            'DEV_FIREBASE_STORAGE_BUCKET': _storageBucket,
            'DEV_FIREBASE_DATABASE_URL': _databaseUrl,
          },
        );
        return android;
      case TargetPlatform.iOS:
        _validate(
          platform: 'ios',
          values: {
            'DEV_FIREBASE_IOS_API_KEY': _iosApiKey,
            'DEV_FIREBASE_IOS_APP_ID': _iosAppId,
            'DEV_FIREBASE_MESSAGING_SENDER_ID': _messagingSenderId,
            'DEV_FIREBASE_PROJECT_ID': _projectId,
            'DEV_FIREBASE_STORAGE_BUCKET': _storageBucket,
            'DEV_FIREBASE_DATABASE_URL': _databaseUrl,
            'DEV_FIREBASE_IOS_BUNDLE_ID': _iosBundleId,
          },
        );
        return ios;
      case TargetPlatform.windows:
        _validate(
          platform: 'windows',
          values: {
            'DEV_FIREBASE_WINDOWS_API_KEY': _windowsApiKey,
            'DEV_FIREBASE_WINDOWS_APP_ID': _windowsAppId,
            'DEV_FIREBASE_MESSAGING_SENDER_ID': _messagingSenderId,
            'DEV_FIREBASE_PROJECT_ID': _projectId,
            'DEV_FIREBASE_STORAGE_BUCKET': _storageBucket,
            'DEV_FIREBASE_DATABASE_URL': _databaseUrl,
          },
        );
        return windows;
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      default:
        throw UnsupportedError(
          'Dev Firebase options are not configured for this platform.',
        );
    }
  }

  static const String _projectId =
      String.fromEnvironment('DEV_FIREBASE_PROJECT_ID');
  static const String _messagingSenderId =
      String.fromEnvironment('DEV_FIREBASE_MESSAGING_SENDER_ID');
  static const String _storageBucket =
      String.fromEnvironment('DEV_FIREBASE_STORAGE_BUCKET');
  static const String _databaseUrl =
      String.fromEnvironment('DEV_FIREBASE_DATABASE_URL');

  static const String _androidApiKey =
      String.fromEnvironment('DEV_FIREBASE_ANDROID_API_KEY');
  static const String _androidAppId =
      String.fromEnvironment('DEV_FIREBASE_ANDROID_APP_ID');

  static const String _iosApiKey =
      String.fromEnvironment('DEV_FIREBASE_IOS_API_KEY');
  static const String _iosAppId =
      String.fromEnvironment('DEV_FIREBASE_IOS_APP_ID');
  static const String _iosBundleId =
      String.fromEnvironment('DEV_FIREBASE_IOS_BUNDLE_ID');

  static const String _windowsApiKey =
      String.fromEnvironment('DEV_FIREBASE_WINDOWS_API_KEY');
  static const String _windowsAppId =
      String.fromEnvironment('DEV_FIREBASE_WINDOWS_APP_ID');

  static const String _webApiKey =
      String.fromEnvironment('DEV_FIREBASE_WEB_API_KEY');
  static const String _webAppId =
      String.fromEnvironment('DEV_FIREBASE_WEB_APP_ID');

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _androidApiKey,
    appId: _androidAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    databaseURL: _databaseUrl,
    storageBucket: _storageBucket,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _iosApiKey,
    appId: _iosAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    databaseURL: _databaseUrl,
    storageBucket: _storageBucket,
    iosBundleId: _iosBundleId,
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: _windowsApiKey,
    appId: _windowsAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    databaseURL: _databaseUrl,
    storageBucket: _storageBucket,
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _webApiKey,
    appId: _webAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    databaseURL: _databaseUrl,
    storageBucket: _storageBucket,
  );

  static void _validate({
    required String platform,
    required Map<String, String> values,
  }) {
    final missing = values.entries
        .where((entry) => entry.value.trim().isEmpty)
        .map((entry) => entry.key)
        .toList();

    if (missing.isNotEmpty) {
      throw UnsupportedError(
        'Missing dev Firebase dart-defines for $platform: ${missing.join(', ')}',
      );
    }
  }
}
