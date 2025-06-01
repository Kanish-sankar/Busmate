import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:busmate/meta/utils/constant/app_images.dart';
import 'package:busmate/meta/utils/text/text_constants.dart';
import 'package:busmate/meta/utils/text/textstyle_constants.dart';
import 'package:busmate/presentation/parents_module/splash/controller/splash_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class SplashScreen extends GetView<SplashController> {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GetBuilder<SplashController>(
        builder: (splashController) {
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  AppImages.backgroungmap,
                  fit: BoxFit.cover,
                ),
              ),
              Opacity(
                opacity: 0.7,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.lightblue,
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20.r),
                      child: Image.asset(
                        AppImages.jupentaLogo,
                        height: 180.w,
                        width: 180.w,
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Icon(
                      Icons.location_on,
                      size: 47.sp,
                    ),
                    SizedBox(height: 20.h),
                    appText(
                      text: 'tagLine'.tr,
                      textStyle: size20TextStyle(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
