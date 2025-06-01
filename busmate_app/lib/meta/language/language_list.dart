import 'package:busmate/meta/language/language_constant.dart';
import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

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
                FirebaseFirestore.instance
                    .collection('students')
                    .doc(GetStorage().read('studentId'))
                    .update({
                  'languagePreference': langName,
                });
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
