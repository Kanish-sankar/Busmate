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
    final NotificationSettings settings = await firebaseMessaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: true,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );
    
    print('🔔 Notification permission status: ${settings.authorizationStatus}');
    print('   Alert: ${settings.alert}');
    print('   Badge: ${settings.badge}');
    print('   Sound: ${settings.sound}');

    // ✅ SHOW NOTIFICATIONS EVEN WHEN APP IS OPEN (FOREGROUND)
    await firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,  // Show notification banner even when app is open
      badge: true,  // Update badge count
      sound: true,  // Play notification sound even when app is open
    );
    print('✅ Foreground notification presentation enabled');

    // Configure notification channels for Android
    // ⚠️ DO NOT set sound in channel - set it per notification for language flexibility!

// Channel with sound (sound set per notification, not in channel)
// ✅ USING NEW CHANNEL ID to force Android to recreate with proper settings
    const AndroidNotificationChannel soundChannel = AndroidNotificationChannel(
      'busmate_v2', // ✅ Changed from 'busmate' to force recreation
      'Busmate Notifications',
      description: 'Plays voice alerts when bus is near',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      // NO sound parameter - allows per-notification sound changes
    );

// Channel without sound
    const AndroidNotificationChannel silentChannel = AndroidNotificationChannel(
      'busmate_silent_v2', // ✅ Changed to match
      'Busmate Silent Notifications',
      description: 'Silent text alerts',
      importance: Importance.high,
      playSound: false,
    );

    // Create channels
    final androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Delete old channels first to clear cached sound
    await androidPlugin?.deleteNotificationChannel('busmate');
    await androidPlugin?.deleteNotificationChannel('busmate_silent');
    await androidPlugin?.deleteNotificationChannel('busmate_v2');
    await androidPlugin?.deleteNotificationChannel('busmate_silent_v2');
    
    // Recreate channels without hardcoded sounds
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

    // ✅ Foreground notification handling - SHOW EVEN WHEN APP IS OPEN
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("📬 ==========================================");
      print("📬 FOREGROUND NOTIFICATION RECEIVED");
      print("📬 ==========================================");
      print("   Notification title: ${message.notification?.title}");
      print("   Notification body: ${message.notification?.body}");
      print("   Data: ${message.data}");
      print("   Data title: ${message.data['title']}");
      print("   Data body: ${message.data['body']}");
      print("   Type: ${message.data['type']}");
      print("   Notification Type: ${message.data['notificationType']}");
      print("   Selected Language: ${message.data['selectedLanguage']}");
      print("   Message ID: ${message.messageId}");
      print("   Sent time: ${message.sentTime}");
      
      // ✅ ALWAYS show notification when app is open - regardless of platform
      if (!kIsWeb) {
        try {
          if (message.data['type'] == 'bus_arrival') {
            print("   🚌 Calling showCustomNotification for bus arrival...");
            showCustomNotification(message);
            print("   ✅ showCustomNotification called successfully");
          } else {
            print("   📱 Calling showLocalNotification...");
            showLocalNotification(message);
            print("   ✅ showLocalNotification called successfully");
          }
        } catch (e) {
          print("   ❌ ERROR showing notification: $e");
          print("   Stack trace: ${StackTrace.current}");
        }
      } else {
        print("   ⚠️ Web platform - notifications not supported");
      }
      
      // Acknowledge notification
      final studentId = message.data['studentId'];
      if (studentId != null && studentId.isNotEmpty) {
        acknowledgeNotification(studentId);
      }
      print("📬 ==========================================");
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
    print("🔔 ==========================================");
    print("🔔 SHOWING CUSTOM NOTIFICATION");
    print("🔔 ==========================================");
    
    String notificationType =
        message.data['notificationType'] ?? 'Text Notification';
    String selectedLanguage = message.data['selectedLanguage'] ?? 'english';
    
    print("   Notification Type: $notificationType");
    print("   Selected Language: $selectedLanguage");

    // ✅ ALWAYS use voice notification sound for bus arrival messages
    // Bus arrival is urgent and should always play sound
    String soundName = getSoundName(selectedLanguage);
    print("   🔊 Sound Name: $soundName");
    print("   📁 Android sound path: android/app/src/main/res/raw/$soundName.wav");
    print("   📁 Expected Android reference: RawResourceAndroidNotificationSound('$soundName')");
    
    // Check notification type preference (but always play sound for bus arrival)
    bool isVoiceNotification = notificationType.toLowerCase().contains("voice");
    print("   🎵 Is Voice Notification: $isVoiceNotification");
    print("   🔊 Playing sound: $soundName (always for bus arrival)");

    final largeIconBitmap = await _loadBusmateLargeIcon();

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'busmate_v2', // ✅ Use new channel ID
      'Busmate Notifications',
      channelDescription: 'Notification for bus arrival',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      playSound: true, // ✅ ALWAYS play sound for bus arrival
      sound: RawResourceAndroidNotificationSound(soundName), // ✅ Use language-specific sound
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
    
    print("   ✅ Android notification details configured:");
    print("      - Channel: busmate_v2");
    print("      - Play Sound: true");
    print("      - Sound Resource: RawResourceAndroidNotificationSound('$soundName')");
    print("      - Importance: max");
    print("      - Priority: high");

    final DarwinNotificationDetails iosPlatformChannelSpecifics =
        DarwinNotificationDetails(
      categoryIdentifier: 'BUSMATE_CATEGORY',
      sound: "$soundName.wav", // ✅ Always use language-specific sound
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
      threadIdentifier: 'bus_arrival',
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    // ✅ Get title/body from data if notification field is null (data-only messages)
    final title = message.notification?.title ?? message.data['title'] ?? 'Bus Approaching!';
    final body = message.notification?.body ?? message.data['body'] ?? 'The bus will arrive soon.';
    
    print("   📱 Calling flutterLocalNotificationsPlugin.show()...");
    print("   ID: $notificationId");
    print("   Title: $title");
    print("   Body: $body");
    
    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      platformChannelSpecifics,
      payload: message.data['studentId'],
    );
    
    print("   ✅ Notification displayed successfully");
    print("🔔 ==========================================");
  }

  static Future<void> showLocalNotification(RemoteMessage message) async {
    final largeIconBitmap = await _loadBusmateLargeIcon();

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'busmate_silent_v2', // ✅ Use new channel ID
      'Busmate Silent Notifications',
      channelDescription: 'Silent text alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      icon: '@drawable/ic_busmate_notification',
      largeIcon:
          largeIconBitmap ?? const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    // ✅ Add iOS notification details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_english.wav',
      categoryIdentifier: 'BUSMATE_CATEGORY',
      interruptionLevel: InterruptionLevel.timeSensitive,
      threadIdentifier: 'bus_general',
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
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