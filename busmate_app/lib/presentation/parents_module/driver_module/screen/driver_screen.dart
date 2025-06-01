import 'package:busmate/meta/nav/pages.dart';
import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:busmate/meta/utils/constant/app_images.dart';
import 'package:busmate/presentation/parents_module/driver_module/controller/driver.controller.dart';
import 'package:busmate/presentation/parents_module/driver_module/widget/driver_info.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class DriverScreen extends GetView<DriverController> {
  const DriverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightblue,
      body: GetBuilder<DriverController>(
        builder: (controller) {
          return Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 250.h,
                    decoration: BoxDecoration(
                      color: Colors.white60,
                      image: const DecorationImage(
                        image: AssetImage(AppImages.backgroungdriver),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.white60,
                          BlendMode.lighten,
                        ),
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30.r),
                        bottomRight: Radius.circular(30.r),
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        EdgeInsets.only(top: 30.h, left: 16.w, right: 16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: 65.h),
                        Obx(
                          () => Text(
                            controller.school.value?.schoolName ?? 'N/A',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 25.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Obx(() => infoCard("BUS NUMBER",
                                controller.busDetail.value?.busNo ?? 'N/A')),
                            Obx(() => infoCard(
                                "BUS VEHICLE NUMBER",
                                controller.busDetail.value?.busVehicleNo ??
                                    'N/A')),
                          ],
                        ),
                        Container(
                          margin: EdgeInsets.only(top: 20.h),
                          child: Obx(() {
                            final profileImageUrl =
                                controller.driver.value?.profileImageUrl;
                            return CircleAvatar(
                              radius: 60.r,
                              backgroundColor: Colors.grey,
                              backgroundImage: profileImageUrl != null &&
                                      profileImageUrl.isNotEmpty
                                  ? NetworkImage(
                                      profileImageUrl) // Fetch image from Firebase Storage
                                  : null,
                              child: profileImageUrl == null ||
                                      profileImageUrl.isEmpty
                                  ? Icon(
                                      Icons.person,
                                      size: 60.sp,
                                      color: Colors.white,
                                    )
                                  : null,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 60.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(() => infoText(
                        "Driver Name", controller.driver.value?.name ?? 'N/A')),
                    Obx(
                      () => infoText("License Number",
                          controller.driver.value?.licenseNumber ?? 'N/A',
                          bold: true),
                    ),
                    Obx(() => infoText("Bus Route",
                        controller.busDetail.value?.routeName ?? 'N/A',
                        bold: true)),
                    SizedBox(height: 50.h),
                    Center(
                      child: Obx(() {
                        bool isActive = controller.isTripActive.value;
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isActive ? Colors.red : Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            padding: EdgeInsets.symmetric(
                                vertical: 10.h, horizontal: 100.w),
                          ),
                          onPressed: () async {
                            if (isActive) {
                              await controller.stopTrip();
                            } else {
                              await controller.startTrip();
                            }
                            // Refresh bus details after status change
                            await controller.fetchBusDetail(
                              GetStorage().read('driverSchoolId'),
                              GetStorage().read('driverBusId'),
                            );
                          },
                          child: Text(
                            isActive ? "Stop Trip" : "Start Trip",
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 15.h),
                    // Logout Button
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          // await getLogin.logout();
                          FirebaseAuth.instance.signOut();
                          // clear local storage
                          GetStorage().erase();
                          // navigate to sign in screen
                          Get.offAllNamed(Routes.sigIn);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lightblue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        child: Text(
                          'logout'.tr,
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),
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
