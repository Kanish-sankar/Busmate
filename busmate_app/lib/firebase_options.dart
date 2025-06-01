import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCBFLvMISWAg7IACMaGv3YV6J1oRxGdQhs',
    appId: '1:6712109665:android:d5dfbd1fd7fe54939c9820',
    messagingSenderId: '6712109665',
    projectId: 'busmate-b80e8',
    databaseURL: 'https://busmate-b80e8-default-rtdb.firebaseio.com',
    storageBucket: 'busmate-b80e8.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAMNSripQpTc3mKMYrF_hxitLtruZ0GEBY',
    appId: '1:6712109665:ios:2faf846225e934269c9820',
    messagingSenderId: '6712109665',
    projectId: 'busmate-b80e8',
    databaseURL: 'https://busmate-b80e8-default-rtdb.firebaseio.com',
    storageBucket: 'busmate-b80e8.firebasestorage.app',
    iosBundleId: 'com.jupenta.busmate',
  );

}