import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Widget inputField({
  required TextEditingController controller,
  required IconData icon,
  required String hintText,

  bool isPassword = false,
  String? Function(String?)? validator,
  void Function()? onTap,
}) =>
    TextFormField(
      controller: controller,
      style: TextStyle(
        fontSize: 14.sp,
      ),
      validator: validator,
      obscureText: isPassword,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.white,
        prefixIcon: Container(
          padding: EdgeInsets.all(10.w),
          margin: EdgeInsets.only(right: 10.w),
          decoration: BoxDecoration(
            color: AppColors.yellow,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: GestureDetector(
            onTap: onTap,
            child: Icon(
              icon,
              size: 20.sp,
              color: Colors.black,
            ),
          ),
        ),
        hintText: hintText,
        hintStyle: TextStyle(
          fontSize: 12.sp,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide.none,
        ),
      ),
    );
