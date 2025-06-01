import 'dart:developer';

import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:busmate/meta/utils/text/text_constants.dart';
import 'package:busmate/meta/utils/text/textstyle_constants.dart';
import 'package:busmate/presentation/parents_module/stopnotify/controller/stopnotify.controller.dart';
import 'package:busmate/presentation/parents_module/stopnotify/widget/selection_box.dart';
import 'package:busmate/presentation/parents_module/stopnotify/widget/selection_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class StopNotifyScreen extends GetView<StopNotifyController> {
  const StopNotifyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightblue,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 15.w),
                child: Obx(
                  () => appText(
                    text:
                        "${'hello'.tr} ${controller.student.value?.name ?? "N/A"},",
                    textStyle: size18TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 15.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 30.w),
                child: appText(
                  text: 'selectnotify1'.tr,
                  textStyle: size14TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 30.w),
                child: appText(
                  text: 'selectnotify2'.tr,
                  textStyle: size14TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(height: 15.h),

              // Time Selection Box

              selectionBox(
                title: 'selectnotifytime'.tr,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 15.h,
                    crossAxisSpacing: 10.w,
                    childAspectRatio: 2.3,
                  ),
                  itemCount: controller.timeOptions.length,
                  itemBuilder: (context, index) {
                    return Obx(() {
                      return selectionButton(
                        text: "${controller.timeOptions[index]} Mins",
                        isSelected: controller.selectedTime?.value ==
                            controller.timeOptions[index],
                        onTap: () {
                          controller.selectTime(controller.timeOptions[index]);
                          FirebaseFirestore.instance
                              .collection('students')
                              .doc(GetStorage().read('studentId'))
                              .update({
                            'notificationPreferenceByTime':
                                controller.selectedTime!.value,
                          });
                          log(controller.selectedTime!.value.toString());
                          log(controller.selectedStop!.value.toString());
                        },
                      );
                    });
                  },
                ),
              ),

              SizedBox(height: 15.h),

              // /// **OR Divider**
              // Center(
              //   child: Text(
              //     'or'.tr,
              //     style: TextStyle(
              //       fontSize: 14.sp,
              //       fontWeight: FontWeight.w600,
              //     ),
              //   ),
              // ),
              // SizedBox(height: 20.h),

              // /// **Stop Selection Box**
              // selectionBox(
              //   title: 'selectnotify1'.tr,
              //   child: GridView.builder(
              //     shrinkWrap: true,
              //     physics: const NeverScrollableScrollPhysics(),
              //     gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              //       crossAxisCount: 2,
              //       mainAxisSpacing: 10.h,
              //       crossAxisSpacing: 10.w,
              //       childAspectRatio: 3.3,
              //     ),
              //     itemCount: controller.stopOptions.length,
              //     itemBuilder: (context, index) {
              //       return Obx(() {
              //         return selectionButton(
              //           text: controller.stopOptions[index],
              //           isSelected: controller.selectedStop?.value == index,
              //           onTap: () {
              //             controller.selectStop(index);
              //             log(controller.selectedTime!.value.toString());
              //             log(controller.selectedStop!.value.toString());
              //           },
              //         );
              //       });
              //     },
              //   ),
              // ),
              // SizedBox(height: 15.h),

              // confirm Button
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    // Handle confirm action
                    controller.selectConfirmButton();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.yellow,
                    padding:
                        EdgeInsets.symmetric(horizontal: 40.w, vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      appText(
                        text: 'confirm'.tr,
                        textStyle: size14TextStyle(),
                      ),
                      SizedBox(
                        width: 15.w,
                      ),
                      const Icon(
                        Icons.send,
                        color: Colors.black,
                        // size: 25.sp,
                      )
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 20.h,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
