import 'package:busmate/meta/language/language_constant.dart';
import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;

Widget languageList() => AnimatedContainer(
      width: double.infinity,
      margin: EdgeInsets.all(10.w),
      duration: const Duration(
        seconds: 10,
      ),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.r),
            topRight: Radius.circular(20.r),
          )),
      curve: Curves.fastOutSlowIn,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  Get.back();
                },
                icon: Icon(
                  Icons.clear_sharp,
                  size: 24.sp,
                ),
              ),
              SizedBox(
                width: 27.w,
              ),
              Text(
                'select'.tr,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 15.h,
          ),
          ...List.generate(
            LanguageConstants.languages.length,
            (index) => ListTile(
              leading: Text(LanguageConstants.languages[index].imageUrl, 
                  style: TextStyle(
                    fontSize: 14.sp,
                  )),
                  
              title: Text(LanguageConstants.languages[index].languageName,
                  style: TextStyle(
                    fontSize: 12.sp,
                  )),
              onTap: () {
                final storage = GetStorage();
                storage.write('langCode',
                    LanguageConstants.languages[index].languageCode);
                storage.write('langCountryCode',
                    LanguageConstants.languages[index].countryCode);
                storage.write('langName',
                    LanguageConstants.languages[index].languageName);
                storage.write('selectedLangIndex', index);
                String langName = "english";
                if (LanguageConstants.languages[index].languageName ==
                    "English") {
                  langName = "english";
                  storage.write('sound', "notification_english");
                } else if (LanguageConstants.languages[index].languageName ==
                    "हिंदी") {
                  langName = "hindi";
                  storage.write('sound', "notification_hindi");
                } else if (LanguageConstants.languages[index].languageName ==
                    "தமிழ்") {
                  langName = "tamil";
                  storage.write('sound', "notification_tamil");
                } else if (LanguageConstants.languages[index].languageName ==
                    "తెలుగు") {
                  langName = "telugu";
                  storage.write('sound', "notification_telugu");
                } else if (LanguageConstants.languages[index].languageName ==
                    "ಕನ್ನಡ") {
                  langName = "kannada";
                  storage.write('sound', "notification_kannada");
                } else if (LanguageConstants.languages[index].languageName ==
                    "മലയാളം") {
                  langName = "malayalam";
                  storage.write('sound', "notification_malayalam");
                }
                // Update Firebase
                final studentId = GetStorage().read('studentId');
                if (studentId != null) {
                  try {
                    FirebaseFirestore.instance
                        .collection('students')
                        .doc(studentId)
                        .update({
                      'languagePreference': langName,
                    });
                  } catch (e) {
                    print('⚠️ Firebase update skipped (demo mode or offline): $e');
                  }
                }
                
                // Send test notification in selected language
                _sendTestNotification(langName);
                
                Get.updateLocale(Locale(
                  storage.read('langCode'),
                  storage.read('langCountryCode'),
                ));
                Get.back();
              },
              textColor: GetStorage().read('selectedLangIndex') == index
                  ? Colors.blue
                  : Colors.black,
            ),
          ),
        ],
      ),
    );

// Function to send test notification in selected language
Future<void> _sendTestNotification(String language) async {
  try {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // Language-specific notification messages
    final Map<String, Map<String, String>> messages = {
      'english': {
        'title': '🔔 Language Changed!',
        'body': 'Your notification language is now set to English',
      },
      'hindi': {
        'title': '🔔 भाषा बदली गई!',
        'body': 'आपकी अधिसूचना भाषा अब हिंदी में सेट है',
      },
      'tamil': {
        'title': '🔔 மொழி மாற்றப்பட்டது!',
        'body': 'உங்கள் அறிவிப்பு மொழி இப்போது தமிழில் அமைக்கப்பட்டுள்ளது',
      },
      'kannada': {
        'title': '🔔 ಭಾಷೆ ಬದಲಾಯಿಸಲಾಗಿದೆ!',
        'body': 'ನಿಮ್ಮ ಅಧಿಸೂಚನೆ ಭಾಷೆ ಈಗ ಕನ್ನಡಕ್ಕೆ ಹೊಂದಿಸಲಾಗಿದೆ',
      },
      'telugu': {
        'title': '🔔 భాష మార్చబడింది!',
        'body': 'మీ నోటిఫికేషన్ భాష ఇప్పుడు తెలుగుకు సెట్ చేయబడింది',
      },
      'malayalam': {
        'title': '🔔 ഭാഷ മാറ്റി!',
        'body': 'നിങ്ങളുടെ അറിയിപ്പ് ഭാഷ ഇപ്പോൾ മലയാളത്തിലേക്ക് സജ്ജീകരിച്ചിരിക്കുന്നു',
      },
    };

    final message = messages[language.toLowerCase()] ?? messages['english']!;
    final soundFile = 'notification_${language.toLowerCase()}';

    if (Platform.isAndroid) {
      // Android notification with custom sound
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'busmate',
        'BusMate Notifications',
        channelDescription: 'Bus arrival notifications',
        importance: Importance.high,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('notification_english'),
        playSound: true,
      );

      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidDetails);

      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        message['title']!,
        message['body']!,
        notificationDetails,
      );
    } else if (Platform.isIOS) {
      // iOS notification with custom sound
      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        sound: '$soundFile.wav',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails notificationDetails =
          NotificationDetails(iOS: iosDetails);

      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        message['title']!,
        message['body']!,
        notificationDetails,
      );
    }

    print('✅ Test notification sent in $language');
  } catch (e) {
    print('⚠️ Error sending test notification: $e');
  }
}
