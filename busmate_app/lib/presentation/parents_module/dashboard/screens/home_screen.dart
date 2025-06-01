import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:busmate/meta/utils/constant/app_images.dart';
import 'package:busmate/presentation/parents_module/dashboard/controller/dashboard.controller.dart';
import 'package:busmate/presentation/parents_module/dashboard/widgets/student_details.dart';
import 'package:busmate/presentation/parents_module/sigin/controller/signin_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class HomeScreen extends GetView<DashboardController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DashboardController>(
      builder: (controller) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 15.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: AppColors.lightblue,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("home".tr,
                            style: TextStyle(
                                fontSize: 20.sp, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: Icon(
                            Icons.logout_rounded,
                            size: 20.sp,
                          ),
                          onPressed: () {
                            SigInController().logout();
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17.r),
                      child: Image.asset(
                        AppImages.jupentaLogoFront,
                        height: 280.h,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Center(
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(vertical: 8.h, horizontal: 15.w),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          10.r,
                        ),
                        border: Border.all(
                          color: AppColors.lightblue,
                          width: 2,
                        ),
                      ),
                      child: Obx(
                        () => Text(
                            '${controller.getGreeting()} ${controller.student.value?.name ?? 'N/A'}',
                            style: TextStyle(fontSize: 16.sp)),
                      ),
                    ),
                  ),
                  SizedBox(height: 15.h),
                  Obx(
                    () => studentDetails(
                      studentName: controller.student.value?.name ?? 'N/A',
                      studentClass:
                          controller.student.value?.studentClass ?? 'N/A',
                      schoolName: controller.school.value?.schoolName ?? 'N/A',
                      busNumber: controller.busDetail.value?.busNo ?? 'N/A',
                      location: controller.student.value?.stopping ?? 'N/A',
                    ),
                  ),
                  SizedBox(height: 15.h),
                  // Logout Button
                  // Center(
                  //   child: ElevatedButton(
                  //     onPressed: () {
                  //       SigInController().logout();
                  //     },
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: AppColors.lightblue,
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(10.r),
                  //       ),
                  //     ),
                  //     child: Text(
                  //       'logout'.tr,
                  //       style: TextStyle(
                  //         fontSize: 16.sp,
                  //         color: Colors.white,
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
