import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:busmate/meta/utils/text/text_constants.dart';
import 'package:busmate/meta/utils/text/textstyle_constants.dart';
import 'package:busmate/presentation/parents_module/stoplocation/controller/stoplocation.controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:searchable_paginated_dropdown/searchable_paginated_dropdown.dart';

class StopLocation extends GetView<StoplocationController> {
  const StopLocation({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightblue,
      body: GetBuilder<StoplocationController>(
        builder: (controller) {
          return SafeArea(
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
                    text: 'verifystlocation'.tr,
                    textStyle: size18TextStyle(
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30.w),
                  child: Obx(
                    () => controller.isLoading.value
                        ? const Center(child: CircularProgressIndicator())
                        : controller.locationLength.value == 0
                            ? Center(
                                child: Text(
                                  'No stopping locations available',
                                  style: size14TextStyle(),
                                ),
                              )
                            : SearchableDropdown<int>(
                                trailingIcon: Icon(
                                  Icons.arrow_drop_down_sharp,
                                  color: AppColors.yellow,
                                  size: 35.sp,
                                ),
                                hintText: Text(
                                  '${'selectlocation'.tr} ${controller.student.value?.stopping ?? "N/A"}',
                                  style: size12TextStyle(),
                                ),
                                margin: const EdgeInsets.all(15),
                                items: List.generate(
                                  controller.locationLength.value,
                                  (i) => SearchableDropdownMenuItem(
                                    value: i,
                                    label: controller.busDetail.value
                                            ?.stoppings[i].name ??
                                        '',
                                    child: Text(
                                        controller.busDetail.value?.stoppings[i]
                                                .name ??
                                            '',
                                        style: size12TextStyle()),
                                  ),
                                ),
                                onChanged: (int? value) {
                                  if (value != null) {
                                    FirebaseFirestore.instance
                                        .collection('students')
                                        .doc(GetStorage().read('studentId'))
                                        .update({
                                      'stopping': controller.busDetail.value!
                                          .stoppings[value].name,
                                      'stopLocation': {
                                        'latitude': controller.busDetail.value!
                                            .stoppings[value].latitude,
                                        'longitude': controller.busDetail.value!
                                            .stoppings[value].longitude,
                                      }
                                    });
                                  }
                                },
                              ),
                  ),
                ),
                const Spacer(),

                /// Confirm Button
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      // Handle confirm action
                      controller.selectLoctionButton();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.yellow,
                      padding: EdgeInsets.symmetric(
                          horizontal: 40.w, vertical: 12.h),
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
                  height: 100.h,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
