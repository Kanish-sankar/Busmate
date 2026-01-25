import 'package:busmate/meta/language/language_list.dart';
import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:busmate/meta/utils/text/text_constants.dart';
import 'package:busmate/meta/utils/text/textstyle_constants.dart';
import 'package:busmate/presentation/parents_module/dashboard/controller/dashboard.controller.dart';
import 'package:busmate/presentation/parents_module/dashboard/widgets/kid_table.dart';
import 'package:busmate/presentation/parents_module/dashboard/widgets/location_list.dart';
import 'package:busmate/presentation/parents_module/dashboard/widgets/notification_list.dart';
import 'package:busmate/presentation/parents_module/dashboard/widgets/notification_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ManageDetailScreen extends GetView<DashboardController> {
  const ManageDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DashboardController>(
      builder: (controller) {
        return SafeArea(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding:
                        EdgeInsets.symmetric(horizontal: 15.w, vertical: 7.h),
                    decoration: BoxDecoration(
                      color: AppColors.lightblue,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("mngdetail".tr,
                              style: TextStyle(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 25.h,
                  ),
                  appText(text: "stplocation".tr, textStyle: size16TextStyle()),
                  SizedBox(
                    height: 5.h,
                  ),
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(top: 5.h),
                    padding:
                        EdgeInsets.symmetric(horizontal: 11.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppColors.lightblue,
                      borderRadius: BorderRadius.circular(7.r),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Obx(
                              () => Text(
                                "${'stplocationpref'.tr} : ${controller.student.value?.stopping ?? "N/A"}",
                                style: TextStyle(fontSize: 12.sp),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.edit_note,
                            size: 25.sp,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            // changing language
                            showModalBottomSheet(
                              context: context,
                              enableDrag: true,
                              isScrollControlled: true,
                              builder: (context) => locationList(
                                  controller.student.value!.id,
                                  controller.currentTripStopsPickupOrder
                                          .isNotEmpty
                                      ? controller.currentTripStopsPickupOrder
                                      : controller.busDetail.value!.stoppings),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 18.h,
                  ),
                  appText(text: "notfsetting".tr, textStyle: size16TextStyle()),
                  SizedBox(
                    height: 5.h,
                  ),
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(top: 5.h),
                    padding:
                        EdgeInsets.symmetric(horizontal: 11.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppColors.lightblue,
                      borderRadius: BorderRadius.circular(7.r),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Obx(
                            () => Text(
                              "${'notfpref'.tr} : ${controller.student.value!.notificationPreferenceByTime} Mins",
                              style: TextStyle(fontSize: 12.sp),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.edit_note,
                            size: 25.sp,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            // changing language
                            showModalBottomSheet(
                              context: context,
                              enableDrag: true,
                              isScrollControlled: true,
                              builder: (context) => notificationList(
                                  controller.student.value!.id,
                                  controller.currentTripStopsPickupOrder
                                          .isNotEmpty
                                      ? controller.currentTripStopsPickupOrder
                                      : controller.busDetail.value!.stoppings),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 18.h,
                  ),
                  appText(
                      text: "notificationType".tr,
                      textStyle: size16TextStyle()),
                  SizedBox(
                    height: 5.h,
                  ),
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(top: 5.h),
                    padding:
                        EdgeInsets.symmetric(horizontal: 11.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppColors.lightblue,
                      borderRadius: BorderRadius.circular(7.r),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Obx(
                            () => Text(
                              "${'notType'.tr} : ${controller.student.value!.notificationType}",
                              style: TextStyle(fontSize: 12.sp),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.edit_note,
                            size: 25.sp,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            // changing language
                            showModalBottomSheet(
                                context: context,
                                enableDrag: true,
                                isScrollControlled: true,
                                builder: (context) => notificationType(
                                      controller.student.value!.id,
                                    ));
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 18.h,
                  ),
                  appText(text: "langsetting".tr, textStyle: size16TextStyle()),
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(top: 5.h),
                    padding:
                        EdgeInsets.symmetric(horizontal: 11.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppColors.lightblue,
                      borderRadius: BorderRadius.circular(7.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Obx(
                          () => Text(
                            "${'Current Language'} : ${controller.student.value?.languagePreference ?? GetStorage().read('langName') ?? 'English'}",
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.edit_note,
                            size: 25.sp,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            // changing language
                            showModalBottomSheet(
                              context: context,
                              enableDrag: true,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => languageList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 30.h,
                  ),
                  appText(text: "kidmanage".tr, textStyle: size16TextStyle()),
                  SizedBox(
                    height: 7.h,
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 10.w),
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: AppColors.lightblue,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Obx(
                      () => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              tableHeader("stdname".tr),
                              tableHeader("stdid".tr),
                              tableHeader("stdclass".tr),
                              tableHeader("stdschool".tr),
                            ],
                          ),
                          const Divider(color: Colors.black),
                          tableStudentData(
                              controller.student.value?.name ?? "N/A",
                              controller.student.value?.rollNumber ?? "N/A",
                              controller.student.value?.studentClass ?? "N/A",
                              controller.school.value?.schoolName ?? "N/A"),
                          ...List.generate(controller.siblings.length, (index) {
                            if (controller.siblings.isNotEmpty) {
                              return tableStudentData(
                                controller.siblings[index].name,
                                controller.siblings[index].rollNumber,
                                controller.siblings[index].studentClass,
                                controller.school.value?.schoolName ?? "N/A",
                              );
                            } else {
                              return const SizedBox();
                            }
                          })
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(
                              horizontal: 25.w, vertical: 10.h),
                        ),
                        onPressed: controller.addStudent,
                        child:
                            Text("add".tr, style: TextStyle(fontSize: 16.sp)),
                      ),
                      SizedBox(width: 20.w),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(
                              horizontal: 15.w, vertical: 10.h),
                        ),
                        onPressed: controller.removeStudent,
                        child: Text("remove".tr,
                            style: TextStyle(fontSize: 16.sp)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
