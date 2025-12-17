import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:background_locator_2/background_locator.dart';
import 'package:busmate/busmate.dart';
import 'package:busmate/firebase_options.dart';
import 'package:busmate/meta/firebase_helper/notification_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Background message handler - Handles notifications when app is in background/terminated
/// ✅ This handler is called for ALL FCM messages when app is not in foreground
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Handle bus arrival notifications
  if (message.data['type'] == 'bus_arrival') {
    String studentId = message.data['studentId'];
    String? selectedLanguage = message.data['selectedLanguage'];
    // Update notification timer
    try {
      await FirebaseFirestore.instance
          .collection('notificationTimers')
          .doc(studentId)
          .update({
        "smsSent": true,
      });
    } catch (e) {
    }
    
    // ✅ Show custom notification with language-specific voice
    // This works for both Android and iOS in background
    try {
      await NotificationHelper.showCustomNotification(message);
    } catch (e) {
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await GetStorage.init();

  await NotificationHelper.initialize();

  // Platform-specific permissions and background location
  if (!kIsWeb) {
    if (Platform.isIOS) {
      Permission.location.request();
      Permission.locationAlways.request();
    }
    await BackgroundLocator.initialize();
  }

  FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const BusMate());
}
