import 'dart:developer';

import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:busmate/presentation/parents_module/dashboard/controller/dashboard.controller.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class DashboardScreen extends GetView<DashboardController> {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final DashboardController dashcontroller = Get.put(DashboardController());
    return Scaffold(
      backgroundColor: AppColors.white,
      bottomNavigationBar: Obx(
        () => CurvedNavigationBar(
            height: 61.h,
          backgroundColor: AppColors.white,
          color: AppColors.lightblue,
          items: [
            CurvedNavigationBarItem(
              child: Icon(
                Icons.home_rounded,
                size: 25.sp,
                color: dashcontroller.isTrue[0].value
                    ? Colors.black
                    : Colors.white,
              ),
              label: 'home'.tr,
              labelStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: dashcontroller.isTrue[0].value
                    ? Colors.black
                    : Colors.white,
              ),
            ),
            CurvedNavigationBarItem(
              child: Icon(
                Icons.location_pin,
                size: 25.sp,
                color: dashcontroller.isTrue[1].value
                    ? Colors.black
                    : Colors.white,
              ),
              label: 'live'.tr,
              labelStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: dashcontroller.isTrue[1].value
                    ? Colors.black
                    : Colors.white,
              ),
            ),
            CurvedNavigationBarItem(
              child: Icon(
                Icons.manage_accounts_rounded,
                size: 25.sp,
                color: dashcontroller.isTrue[2].value
                    ? Colors.black
                    : Colors.white,
              ),
              label: 'managing'.tr,
              labelStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: dashcontroller.isTrue[2].value
                    ? Colors.black
                    : Colors.white,
              ),
            ),
            CurvedNavigationBarItem(
              child: Icon(
                Icons.question_mark_rounded,
                size: 25.sp,
                color: dashcontroller.isTrue[3].value
                    ? Colors.black
                    : Colors.white,
              ),
              label: 'f&q'.tr,
              labelStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: dashcontroller.isTrue[3].value
                    ? Colors.black
                    : Colors.white,
              ),
            ),
          ],
          onTap: (index) {
            controller.selectedIndex.value = index;
            log("index$index");
            dashcontroller.isButtonPress(index);
          },
        ),
      ),
      body: GetBuilder<DashboardController>(
        builder: (controller) {
          return Obx(() => controller.screens[controller.selectedIndex.value]);
        },
      ),
    );
  }
}
