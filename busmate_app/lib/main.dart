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
  
  print('🔔 ============================================');
  print('🔔 FCM BACKGROUND HANDLER CALLED');
  print('🔔 Message ID: ${message.messageId}');
  print('🔔 Type: ${message.data['type']}');
  print('🔔 Platform: ${message.data['platform'] ?? 'unknown'}');
  print('🔔 Display Method: ${message.data['displayMethod'] ?? 'unknown'}');
  print('🔔 Has notification field: ${message.notification != null}');
  print('🔔 Data: ${message.data}');
  print('🔔 ============================================');
  
  // Handle bus arrival notifications
  if (message.data['type'] == 'bus_arrival') {
    String studentId = message.data['studentId'];
    String? selectedLanguage = message.data['selectedLanguage'];
    final displayMethod = message.data['displayMethod'] ?? 'system';
    
    // Update notification timer
    try {
      await FirebaseFirestore.instance
          .collection('notificationTimers')
          .doc(studentId)
          .update({
        "smsSent": true,
      });
      print('✅ Updated notificationTimers for $studentId');
    } catch (e) {
      print('❌ Failed to update notificationTimers: $e');
    }
    
    // ✅ Platform-specific notification display
    // Android: System already displayed from android.notification → DON'T show again
    // iOS: Data-only message, Flutter MUST display it
    if (displayMethod == 'flutter') {
      print('🔔 iOS: Flutter will display notification');
      try {
        await NotificationHelper.showCustomNotification(message);
        print('✅ showCustomNotification completed');
      } catch (e) {
        print('❌ Failed to show custom notification: $e');
      }
    } else {
      print('🔔 Android: System already displayed notification, skipping Flutter display');
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
      
      // ✅ CRITICAL FOR iOS: Get APNS token first before FCM can work
      // iOS requires APNS token to be available before FCM registration
      String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken == null) {
        // Wait a bit and retry - APNS token may take time on first launch
        await Future.delayed(const Duration(seconds: 2));
        apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      }
      debugPrint('✅ iOS APNS Token: ${apnsToken != null ? "Available" : "NOT Available"}');
    }
    await BackgroundLocator.initialize();
  }

  // ✅ Request notification permission with critical alert for iOS
  FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    criticalAlert: true, // ✅ For time-sensitive bus arrival notifications
    provisional: false,
    announcement: true,  // ✅ Announce notifications via Siri
    carPlay: true,       // ✅ Show notifications in CarPlay
  );

  FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const BusMate());
}
