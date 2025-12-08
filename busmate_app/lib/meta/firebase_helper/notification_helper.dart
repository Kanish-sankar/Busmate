import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
  static ByteArrayAndroidBitmap? _cachedBusmateLargeIcon;
  static const String _busmateLogoAsset = 'assets/images/BUSMATE.FRONT.png';

  static Future<AndroidBitmap<Object>?> _loadBusmateLargeIcon() async {
    if (_cachedBusmateLargeIcon != null) {
      return _cachedBusmateLargeIcon;
    }
    try {
      final ByteData byteData = await rootBundle.load(_busmateLogoAsset);
      _cachedBusmateLargeIcon =
          ByteArrayAndroidBitmap(byteData.buffer.asUint8List());
      return _cachedBusmateLargeIcon;
    } catch (e) {
      print('⚠️ Failed to load BusMate logo for notification: $e');
      return null;
    }
  }

  static Future<void> initialize() async {
    // Request notification permissions
    await firebaseMessaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: true,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    await firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    // Configure notification channels for Android

    final soundName = GetStorage().read('sound') ?? "notification_english";

// Channel with sound
    final AndroidNotificationChannel soundChannel = AndroidNotificationChannel(
      'busmate',
      'Busmate Notifications',
      description: 'Plays voice alerts when bus is near',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(soundName),
    );

// Channel without sound
    const AndroidNotificationChannel silentChannel = AndroidNotificationChannel(
      'busmate_silent',
      'Busmate Silent Notifications',
      description: 'Silent text alerts',
      importance: Importance.high,
      playSound: true,
    );

    // Create channels
    final androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(soundChannel);
    await androidPlugin?.createNotificationChannel(silentChannel);


    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'BUSMATE_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'ACKNOWLEDGE_ACTION',
              'Acknowledge',
            ),
          ],
        ),
      ],
    );

    InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) async {
        final studentId = GetStorage().read("studentId");
        if (studentId != null) {
          FirebaseFirestore.instance
              .collection("notificationTimers")
              .doc(studentId)
              .update({"smsSent": true});
          print("✅ Firestore updated from push-tap initialize");
        }
        if (details.actionId == "ACKNOWLEDGE_ACTION") {
          print("✅ User clicked Acknowledge");
        } else {
          print("✅ Notification clicked normally");
        }
      },
    );

    // Foreground notification handling
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (!kIsWeb && Platform.isAndroid) {
        if (message.data['type'] == 'bus_arrival') {
          showCustomNotification(message);
        } else {
          showLocalNotification(message);
        }
      }
      acknowledgeNotification(message.data['studentId']);
      print("📬 Notification received: ${message.data} foreground");
    });

    // Background (when app opened by tapping notification)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("📬 Notification opened: ${message.data}");
      // if (message.data['type'] == 'bus_arrival') {
      //   showCustomNotification(message);
      // }
      acknowledgeNotification(message.data['studentId']);
    });

    // Terminated state (when app is terminated)
    firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null && message.data['type'] == 'bus_arrival') {
        // showCustomNotification(message); // Show again on tap from terminated
        acknowledgeNotification(message.data['studentId']);
      }
    });
  }

  static Future<void> showCustomNotification(RemoteMessage message) async {
    String notificationType =
        message.data['notificationType'] ?? 'Text Notification';
    String selectedLanguage = message.data['selectedLanguage'] ?? 'english';
    String? soundName;

    if (notificationType == "Voice Notification") {
      soundName = getSoundName(selectedLanguage);
    }

    final largeIconBitmap = await _loadBusmateLargeIcon();

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'busmate',
      'Busmate Notifications',
      channelDescription: 'Notification for bus arrival',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      playSound: soundName != null,
      sound: soundName != null
          ? RawResourceAndroidNotificationSound(soundName)
          : null,
      enableVibration: true,
      icon: '@drawable/ic_busmate_notification',
      largeIcon:
          largeIconBitmap ?? const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'ACKNOWLEDGE_ACTION',
          'Acknowledge',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    final DarwinNotificationDetails iosPlatformChannelSpecifics =
        DarwinNotificationDetails(
      categoryIdentifier: 'busmate', // Add this line
      sound: soundName != null ? "$soundName.wav" : null,
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await flutterLocalNotificationsPlugin.show(
      notificationId,
      message.notification?.title ?? 'Bus Approaching!',
      message.notification?.body ?? 'The bus will arrive soon.',
      platformChannelSpecifics,
      payload: message.data['studentId'],
    );
  }

  static Future<void> showLocalNotification(RemoteMessage message) async {
    final largeIconBitmap = await _loadBusmateLargeIcon();

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'busmate_silent',
      'Busmate Silent Notifications',
      channelDescription: 'Silent text alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      icon: '@drawable/ic_busmate_notification',
      largeIcon:
          largeIconBitmap ?? const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await flutterLocalNotificationsPlugin.show(
      notificationId,
      message.notification?.title ?? '',
      message.notification?.body ?? '',
      platformDetails,
    );
  }

  static Future<void> acknowledgeNotification(String studentId) async {
    final url =
        Uri.parse('https://acknowledgenotification-gnxzq4evda-uc.a.run.app');
    await http.post(url, body: {'studentId': studentId});
  }

  static String getSoundName(String language) {
    // Language-specific notification sound mapping (Original WAV Files)
    switch (language.toLowerCase()) {
      case "english":
        return "notification_english";
      case "hindi":
        return "notification_hindi";
      case "tamil":
        return "notification_tamil";
      case "telugu":
        return "notification_telugu";
      case "kannada":
        return "notification_kannada";
      case "malayalam":
        return "notification_malayalam";
      default:
        return "notification_english";
    }
  }

  // Test notification function to preview voice notifications
  static Future<void> showTestNotification({
    String language = 'tamil',
    bool isVoice = true,
  }) async {
    try {
      String? soundName = isVoice ? getSoundName(language) : null;
      print('🔊 Preparing notification - Language: $language, Sound: $soundName');
      
      final largeIconBitmap = await _loadBusmateLargeIcon();

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'busmate',
        'Busmate Notifications',
        channelDescription: 'Test notification for bus arrival',
        importance: Importance.max,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        playSound: soundName != null,
        sound: soundName != null
            ? RawResourceAndroidNotificationSound(soundName)
            : null,
        enableVibration: true,
        icon: '@drawable/ic_busmate_notification',
        largeIcon:
            largeIconBitmap ?? const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'ACKNOWLEDGE_ACTION',
            'Acknowledge',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      );

      final DarwinNotificationDetails iosPlatformChannelSpecifics =
          DarwinNotificationDetails(
        categoryIdentifier: 'busmate',
        sound: soundName != null ? "$soundName.wav" : null,
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosPlatformChannelSpecifics,
      );

      int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await flutterLocalNotificationsPlugin.show(
        notificationId,
        '🚍 Bus Approaching Your Stop!',
        'The bus will arrive at Udyog Vihar Phase 4 in approximately 5 minutes. Please be ready!',
        platformChannelSpecifics,
      );
      
      print('✅ Voice notification sent: Language=$language, Voice=$isVoice, Sound=$soundName');
    } catch (e) {
      print('❌ Error in showTestNotification: $e');
      rethrow;
    }
  }
}
