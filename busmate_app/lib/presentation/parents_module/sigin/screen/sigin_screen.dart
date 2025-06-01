import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:busmate/meta/utils/constant/app_images.dart';
import 'package:busmate/meta/utils/text/text_constants.dart';
import 'package:busmate/meta/utils/text/textstyle_constants.dart';
import 'package:busmate/presentation/parents_module/dashboard/screens/help_support.dart';
import 'package:busmate/presentation/parents_module/sigin/controller/signin_controller.dart';
import 'package:busmate/presentation/parents_module/sigin/widget/input_field.dart';
import 'package:busmate/presentation/parents_module/sigin/widget/rdbottom_clipped.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class SignInScreen extends GetView<SignInScreen> {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightblue,
      resizeToAvoidBottomInset: true,
      body: GetBuilder<SigInController>(
        builder: (controller) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Form(
              key: controller.formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipPath(
                    clipper: CurvedClipper(),
                    child: SizedBox(
                      height: 250.h,
                      width: double.infinity,
                      child: Image.asset(
                        AppImages.loginclipped,
                        fit: BoxFit.fitWidth,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 30.w,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'welcomemsg'.tr,
                          style: TextStyle(
                            fontSize: 28.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 30.h),
                        // Student ID Input
                        inputField(
                          controller: controller.txtId,
                          validator: controller.validateUserId,
                          icon: Icons.person,
                          hintText: 'idmsg'.tr,
                        ),
                        SizedBox(height: 20.h),
          
                        // Password Input
                        Obx(
                          () => inputField(
                            controller: controller.txtPassword,
                            validator: controller.validatePassword,
                            icon: controller.isShowPass.value
                                ? Icons.visibility
                                : Icons.visibility_off,
                            hintText: 'passmsg'.tr,
                            isPassword: !controller.isShowPass.value,
                            onTap: () {
                              controller.isShowPass.value =
                                  !controller.isShowPass.value;
                            },
                          ),
                        ),
                        SizedBox(height: 10.h),
          
                        // Remember Me & Forgot Password
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Obx(
                              () => GestureDetector(
                                onTap: () {
                                  controller.isRemeber.value =
                                      !controller.isRemeber.value;
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                        controller.isRemeber.value
                                            ? Icons.check_circle
                                            : Icons.check_circle_outline,
                                        size: 20.sp),
                                    SizedBox(width: 5.w),
                                    appText(
                                        text: 'remeber'.tr,
                                        textStyle: size12TextStyle()),
                                  ],
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: controller.showEmailDialog,
                              child: appText(
                                text: 'forgotpass'.tr,
                                textStyle: size12TextStyle(
                                  fontWeight: FontWeight.w400,
                                  textDecoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20.h),
          
                        // Login Button
                        Obx(() => SizedBox(
                              width: double.infinity,
                              height: 50.h,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.yellow,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                ),
                                onPressed: controller.isLoading.value
                                    ? null
                                    : controller.submitForm,
                                child: controller.isLoading.value
                                    ? SizedBox(
                                        height: 20.h,
                                        width: 20.h,
                                        child:
                                            const CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.black),
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : appText(
                                        text: 'login'.tr,
                                        textStyle: size18TextStyle(),
                                      ),
                              ),
                            )),
                      ],
                    ),
                  ),
                  //Spacer();
                  SizedBox(
                    height: 50.h,
                  ),
                  // Terms & Support
                  GestureDetector(
                    onTap: () {
                      Get.to(const HelpSupportScreen());
                    },
                    child: Text.rich(
                      TextSpan(
                        text: 'termcondition1'.tr,
                        style: TextStyle(fontSize: 11.sp),
                        children: [
                          TextSpan(
                            text: 'termcondition2'.tr,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 5.h),
                  GestureDetector(
                    onTap: () {
                      Get.to(() => const HelpSupportScreen());
                    },
                    child: appText(
                      text: 'helpsupport'.tr,
                      textStyle: size11TextStyle(
                        textDecoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  // Footer
                  appText(
                    text: 'copyright'.tr,
                    textStyle: size11TextStyle(
                      color: AppColors.shadow,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
