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

  // Channel specs per language because Android 8+ ties sound to the channel, not the notification.
  static const List<_VoiceChannelSpec> _voiceChannels = [
    _VoiceChannelSpec(
      id: 'busmate_voice_english',
      name: 'Busmate Voice (English)',
      sound: 'notification_english',
      languageKey: 'english',
    ),
    _VoiceChannelSpec(
      id: 'busmate_voice_hindi',
      name: 'Busmate Voice (Hindi)',
      sound: 'notification_hindi',
      languageKey: 'hindi',
    ),
    _VoiceChannelSpec(
      id: 'busmate_voice_tamil',
      name: 'Busmate Voice (Tamil)',
      sound: 'notification_tamil',
      languageKey: 'tamil',
    ),
    _VoiceChannelSpec(
      id: 'busmate_voice_telugu',
      name: 'Busmate Voice (Telugu)',
      sound: 'notification_telugu',
      languageKey: 'telugu',
    ),
    _VoiceChannelSpec(
      id: 'busmate_voice_kannada',
      name: 'Busmate Voice (Kannada)',
      sound: 'notification_kannada',
      languageKey: 'kannada',
    ),
    _VoiceChannelSpec(
      id: 'busmate_voice_malayalam',
      name: 'Busmate Voice (Malayalam)',
      sound: 'notification_malayalam',
      languageKey: 'malayalam',
    ),
  ];

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
    // ✅ SHOW NOTIFICATIONS EVEN WHEN APP IS OPEN (FOREGROUND)
    await firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,  // Show notification banner even when app is open
      badge: true,  // Update badge count
      sound: true,  // Play notification sound even when app is open
    );
    // Configure notification channels for Android (sound is tied to channel on Android 8+)
    final androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Delete ONLY old legacy channels to migrate to new structure
      await androidPlugin.deleteNotificationChannel('busmate');
      await androidPlugin.deleteNotificationChannel('busmate_silent');
      await androidPlugin.deleteNotificationChannel('busmate_v2');
      // Voice channels: one per language so each can keep its own sound
      // Create channels (will update if already exists)
      for (final spec in _voiceChannels) {
        await androidPlugin.createNotificationChannel(
          AndroidNotificationChannel(
            spec.id,
            spec.name,
            description: 'Voice alert (${spec.languageKey})',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            sound: RawResourceAndroidNotificationSound(spec.sound),
          ),
        );
      }

      // Silent channel for text-only alerts
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'busmate_silent_v2',
          'Busmate Silent Notifications',
          description: 'Silent text alerts',
          importance: Importance.high,
          playSound: false,
        ),
      );
    }


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
        }
        if (details.actionId == "ACKNOWLEDGE_ACTION") {
        } else {
        }
      },
    );

    // ✅ Foreground notification handling - ALWAYS TRIGGERS FOR DATA-ONLY MESSAGES
    // Android: Data-only messages ALWAYS call onMessage, even in foreground
    // iOS: notification field in APNS ensures listener wakes up
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // ✅ CRITICAL: ALWAYS show notification when app is open
      // Android: This is the ONLY way notification will be shown (data-only message)
      // iOS: System may show notification, but we show custom one with correct sound
      if (!kIsWeb) {
        try {
          if (message.data['type'] == 'bus_arrival') {
            showCustomNotification(message);
          } else {
            showLocalNotification(message);
          }
        } catch (e) {
        }
      } else {
      }
      
      // Acknowledge notification
      final studentId = message.data['studentId'];
      if (studentId != null && studentId.isNotEmpty) {
        acknowledgeNotification(studentId);
      }
    });

    // Background (when app opened by tapping notification)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
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

  static _VoiceChannelSpec _channelForLanguage(String language) {
    final String normalized = language.toLowerCase();
    return _voiceChannels.firstWhere(
      (spec) => spec.languageKey == normalized,
      orElse: () => _voiceChannels.first,
    );
  }

  static Future<void> showCustomNotification(RemoteMessage message) async {
    String notificationType =
      message.data['notificationType'] ?? 'Text Notification';
    String selectedLanguage = message.data['selectedLanguage'] ?? 'english';
    final _VoiceChannelSpec channelSpec =
      _channelForLanguage(selectedLanguage.toLowerCase());
    // ✅ ALWAYS use voice notification sound for bus arrival messages
    // Bus arrival is urgent and should always play sound (channel holds the sound)
    String soundName = channelSpec.sound;
    // Check notification type preference (but always play sound for bus arrival)
    bool isVoiceNotification = notificationType.toLowerCase().contains("voice");
    final largeIconBitmap = await _loadBusmateLargeIcon();

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelSpec.id,
      channelSpec.name,
      channelDescription: 'Notification for bus arrival (${channelSpec.languageKey})',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      playSound: true, // ✅ Let channel handle the sound (Android 8+ ignores individual notification sound)
      // DO NOT specify sound here - channel already has it bound
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
    // ✅ iOS notification with proper sound handling
    final DarwinNotificationDetails iosPlatformChannelSpecifics =
        DarwinNotificationDetails(
      categoryIdentifier: 'BUSMATE_CATEGORY',
      sound: Platform.isIOS ? "$soundName.wav" : soundName, // ✅ iOS needs .wav extension
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
    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      platformChannelSpecifics,
      payload: message.data['studentId'],
    );
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
      print('🔔 showTestNotification called with language: $language, isVoice: $isVoice');
      
      // Skip notifications on web - not supported
      if (kIsWeb) {
        print('⚠️ Notifications not supported on web platform');
        return;
      }
      
      // Re-initialize if needed (safety check)
      try {
        await flutterLocalNotificationsPlugin.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(),
          ),
        );
      } catch (e) {
        print('⚠️ Notification re-initialization skipped: $e');
      }
      
      final _VoiceChannelSpec channelSpec =
          _channelForLanguage(language.toLowerCase());
      final String channelId = isVoice ? channelSpec.id : 'busmate_silent_v2';
      final String channelTitle =
          isVoice ? channelSpec.name : 'Busmate Silent Notifications';
      // Get language-specific notification message
      final languageMessages = _getLanguageUpdateMessage(language.toLowerCase());
      final notificationTitle = languageMessages['title']!;
      final notificationBody = languageMessages['body']!;
      
      print('📝 Notification details: $notificationTitle - $notificationBody');
      print('🔊 Channel: $channelId, Sound: ${channelSpec.sound}');
      
      final largeIconBitmap = await _loadBusmateLargeIcon();

      // On Android 8+, sound is determined by the channel, NOT the notification
      // We only specify the channelId and let the channel handle the sound
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        channelId,  // This is all that matters for sound on Android 8+
        channelTitle,
        channelDescription: 'Language update notification',
        importance: Importance.max,
        priority: Priority.high,
        ongoing: false,  // Allow notification to be dismissed
        autoCancel: true,  // Auto-dismiss when tapped
        playSound: true,  // Let channel handle the actual sound
        // DO NOT specify sound here - channel already has it bound
        enableVibration: true,
        icon: '@drawable/ic_busmate_notification',
        largeIcon:
            largeIconBitmap ?? const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      );

      // ✅ iOS notification with proper sound handling
      final DarwinNotificationDetails iosPlatformChannelSpecifics =
          DarwinNotificationDetails(
        categoryIdentifier: 'busmate',
        sound: isVoice ? (Platform.isIOS ? "${channelSpec.sound}.wav" : channelSpec.sound) : null,
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
      print('📤 Sending notification with ID: $notificationId');
      
      await flutterLocalNotificationsPlugin.show(
        notificationId,
        notificationTitle,
        notificationBody,
        platformChannelSpecifics,
      );
      
      print('✅ Notification show() called successfully');
    } catch (e) {
      print('❌ Error in showTestNotification: $e');
      rethrow;
    }
  }

  /// Get language-specific message for language update notification
  static Map<String, String> _getLanguageUpdateMessage(String language) {
    switch (language.toLowerCase()) {
      case 'english':
        return {
          'title': 'Language Updated',
          'body': 'Your language has been updated successfully!',
        };
      case 'hindi':
        return {
          'title': 'भाषा अपडेट की गई',
          'body': 'आपकी भाषा सफलतापूर्वक अपडेट कर दी गई है!',
        };
      case 'tamil':
        return {
          'title': 'மொழி புதுப்பிக்கப்பட்டது',
          'body': 'உங்கள் மொழி வெற்றிகரமாக புதுப்பிக்கப்பட்டது!',
        };
      case 'telugu':
        return {
          'title': 'భాష నవీకరించబడింది',
          'body': 'మీ భాష విజయవంతంగా నవీకరించబడింది!',
        };
      case 'kannada':
        return {
          'title': 'ಭಾಷೆ ನವೀಕರಿಸಲಾಗಿದೆ',
          'body': 'ನಿಮ್ಮ ಭಾಷೆಯನ್ನು ಯಶಸ್ವಿಯಾಗಿ ನವೀಕರಿಸಲಾಗಿದೆ!',
        };
      case 'malayalam':
        return {
          'title': 'ഭാഷ അപ്ഡേറ്റ് ചെയ്തു',
          'body': 'നിങ്ങളുടെ ഭാഷ വിജയകരമായി അപ്ഡേറ്റ് ചെയ്തു!',
        };
      default:
        return {
          'title': 'Language Updated',
          'body': 'Your language has been updated successfully!',
        };
    }
  }
}

class _VoiceChannelSpec {
  final String id;
  final String name;
  final String sound;
  final String languageKey;

  const _VoiceChannelSpec({
    required this.id,
    required this.name,
    required this.sound,
    required this.languageKey,
  });
}