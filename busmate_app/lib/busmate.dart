import 'package:busmate/meta/language/language_constant.dart';
import 'package:busmate/meta/language/languages.dart';
import 'package:busmate/meta/nav/pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';

class BusMate extends StatelessWidget {
  const BusMate({super.key});

  @override
  Widget build(BuildContext context) {
    if (GetStorage().read('langName') == null) {
      GetStorage()
          .write('langName', LanguageConstants.languages[0].languageName);
    }
    if (GetStorage().read('selectedLangIndex') == null) {
      GetStorage().write('selectedLangIndex', 0);
    }
    return ScreenUtilInit(
        designSize: const Size(414, 896),
        minTextAdapt: true,
        splitScreenMode: true,
        useInheritedMediaQuery: true,
        builder: (_, child) {
          return GetMaterialApp(
            locale: Locale(
              GetStorage().read('langCode') ??
                  LanguageConstants.languages[0].languageCode,
              GetStorage().read('langCountryCode') ??
                  LanguageConstants.languages[0].countryCode,
            ),
            fallbackLocale: Locale(
              LanguageConstants.languages[0].languageCode,
              LanguageConstants.languages[0].countryCode,
            ),
            translations: Languages(),
            theme: ThemeData(
              fontFamily: GoogleFonts.poppins().fontFamily,
            ),
            initialRoute: Routes.splash,
            // initialRoute: Routes.driverScreen,
            getPages: AppPages.routes,
            debugShowCheckedModeBanner: false,
            // home: const TestScreen(),
          );
        });
  }
}
