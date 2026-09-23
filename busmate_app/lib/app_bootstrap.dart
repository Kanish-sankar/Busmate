import 'dart:io' show Platform;

import 'package:background_locator_2/background_locator.dart';
import 'package:busmate/busmate.dart';
import 'package:busmate/meta/firebase_helper/notification_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  if (message.data['type'] == 'bus_arrival') {
    final String? studentId = message.data['studentId'];
    if (studentId != null && studentId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('notificationTimers')
            .doc(studentId)
            .update({
          'smsSent': true,
        });
      } catch (_) {}
    }
  }
}

Future<void> bootstrapApp({
  required FirebaseOptions firebaseOptions,
  required String appEnv,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: firebaseOptions);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await GetStorage.init();
  // Persist active environment for background isolate initialization.
  GetStorage().write('app_env', appEnv);
  await NotificationHelper.initialize();

  if (!kIsWeb) {
    if (Platform.isIOS) {
      Permission.location.request();
      Permission.locationAlways.request();

      String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken == null) {
        await Future.delayed(const Duration(seconds: 2));
        apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      }
    }
    await BackgroundLocator.initialize();
  }

  FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    criticalAlert: true,
    provisional: false,
    announcement: true,
    carPlay: true,
  );

  FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const BusMate());
}
