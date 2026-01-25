import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:busmate/meta/utils/constant/app_images.dart';
import 'package:busmate/presentation/parents_module/driver_module/controller/driver.controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class DriverScreen extends GetView<DriverController> {
  const DriverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: GetBuilder<DriverController>(
        builder: (controller) {
          return CustomScrollView(
            slivers: [
              // App Bar with Gradient
              SliverAppBar(
                expandedHeight: 280.h,
                floating: false,
                pinned: true,
                backgroundColor: AppColors.lightblue,
                actions: [
                  // Logout Button in Top Right
                  Padding(
                    padding: EdgeInsets.only(right: 8.w, top: 8.h),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          await controller.handleDriverLogout();
                        },
                        borderRadius: BorderRadius.circular(8.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.logout,
                                color: Colors.white,
                                size: 18.sp,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                'logout'.tr,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.lightblue,
                          AppColors.lightblue.withOpacity(0.8),
                          Colors.blue.shade300,
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Background Pattern
                        Opacity(
                          opacity: 0.1,
                          child: Image.asset(
                            AppImages.backgroungdriver,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                        // Content
                        SafeArea(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(height: 20.h),
                                // School Name
                                Obx(
                                  () => Text(
                                    controller.school.value?.schoolName ?? 'N/A',
                                    style: TextStyle(
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 4,
                                          color: Colors.black26,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(height: 20.h),
                                // Profile Avatar with Border
                                Obx(() {
                                  final profileImageUrl =
                                      controller.driver.value?.profileImageUrl;
                                  return Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 4,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 50.r,
                                      backgroundColor: Colors.grey.shade300,
                                      backgroundImage: profileImageUrl != null &&
                                              profileImageUrl.isNotEmpty
                                          ? NetworkImage(profileImageUrl)
                                          : null,
                                      child: profileImageUrl == null ||
                                              profileImageUrl.isEmpty
                                          ? Icon(
                                              Icons.person,
                                              size: 50.sp,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  );
                                }),
                                SizedBox(height: 15.h),
                                // Driver Name
                                Obx(
                                  () => Text(
                                    controller.driver.value?.name ?? 'N/A',
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    children: [
                      // Bus Info Cards
                      Row(
                        children: [
                          Expanded(
                            child: Obx(() => _buildInfoCard(
                                  icon: Icons.directions_bus,
                                  title: "Bus Number",
                                  value: controller.busDetail.value?.busNo ?? 'N/A',
                                  color: Colors.blue,
                                )),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Obx(() => _buildInfoCard(
                                  icon: Icons.confirmation_number,
                                  title: "Vehicle Number",
                                  value: controller.busDetail.value?.busVehicleNo ?? 'N/A',
                                  color: Colors.orange,
                                )),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),
                      // Driver Details Card
                      _buildDetailsCard(controller),
                      SizedBox(height: 20.h),
                      // Trip Control Button
                      Obx(() {
                        bool isActive = controller.isTripActive.value;
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          child: Material(
                            elevation: isActive ? 8 : 4,
                            borderRadius: BorderRadius.circular(16.r),
                            child: InkWell(
                              onTap: () async {
                                if (isActive) {
                                  await controller.stopTrip();
                                } else {
                                  await controller.startTrip();
                                }
                              },
                              borderRadius: BorderRadius.circular(16.r),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isActive
                                        ? [Colors.red.shade400, Colors.red.shade600]
                                        : [Colors.green.shade400, Colors.green.shade600],
                                  ),
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isActive ? Icons.stop_circle : Icons.play_circle,
                                      color: Colors.white,
                                      size: 28.sp,
                                    ),
                                    SizedBox(width: 12.w),
                                    Text(
                                      isActive ? "Stop Trip" : "Start Trip",
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      SizedBox(height: 40.h),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28.sp,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(DriverController controller) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Driver Details",
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16.h),
          Obx(() => _buildDetailRow(
                icon: Icons.badge,
                label: "License Number",
                value: controller.driver.value?.licenseNumber ?? 'N/A',
              )),
          SizedBox(height: 12.h),
          Obx(() => _buildDetailRow(
                icon: Icons.route,
                label: "Bus Route",
                value: controller.busDetail.value?.routeName ?? 'N/A',
              )),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: AppColors.lightblue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(
            icon,
            size: 20.sp,
            color: AppColors.lightblue,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
