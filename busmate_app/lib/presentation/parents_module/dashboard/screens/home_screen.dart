import 'package:busmate/meta/nav/pages.dart';
import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:busmate/meta/utils/constant/app_images.dart';
import 'package:busmate/presentation/parents_module/dashboard/controller/dashboard.controller.dart';
import 'package:busmate/presentation/parents_module/dashboard/widgets/student_details.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

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
                          onPressed: () async {
                            // Direct logout without using Get.find
                            await FirebaseAuth.instance.signOut();
                            GetStorage().erase();
                            Get.offAllNamed(Routes.sigIn);
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(17.r),
                          child: Image.asset(
                            AppImages.jupentaLogoFront,
                            width: constraints.maxWidth * 0.9,
                            height: MediaQuery.of(context).size.height * 0.25,
                            fit: BoxFit.contain,
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 10.h),
                  
                  // Kid Switcher Dropdown
                  Obx(() {
                    if (controller.siblings.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    
                    // Get PRIMARY student ID (the logged-in account holder)
                    String? primaryStudentId = GetStorage().read('primaryStudentId');
                    String? primaryStudentName = 'Primary Student';
                    
                    // Find primary student name
                    if (primaryStudentId == controller.student.value?.id) {
                      primaryStudentName = controller.student.value?.name ?? 'N/A';
                    } else {
                      // Check if primary is in siblings
                      var primarySibling = controller.siblings.where((s) => s.id == primaryStudentId).firstOrNull;
                      if (primarySibling != null) {
                        primaryStudentName = primarySibling.name;
                      }
                    }
                    
                    // Build list: PRIMARY student + all siblings
                    List<Map<String, String>> allKids = [
                      {
                        'id': primaryStudentId ?? '',
                        'name': primaryStudentName,
                      },
                      ...controller.siblings.map((sib) => {
                        'id': sib.id,
                        'name': sib.name,
                      }),
                    ];
                    
                    String currentKidId = GetStorage().read('studentId') ?? '';
                    
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: AppColors.lightblue,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.people, size: 20.sp),
                          SizedBox(width: 10.w),
                          Text(
                            'Viewing: ',
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            child: DropdownButton<String>(
                              value: currentKidId,
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: allKids.map((kid) {
                                return DropdownMenuItem<String>(
                                  value: kid['id'],
                                  child: Text(
                                    kid['name']!,
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newKidId) {
                                if (newKidId != null && newKidId != currentKidId) {
                                  controller.switchActiveStudent(newKidId);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  SizedBox(height: 15.h),
                  
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
