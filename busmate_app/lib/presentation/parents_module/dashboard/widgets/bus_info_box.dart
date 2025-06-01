import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Widget busInfoBox(String title, String info) {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 10.w),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10.r),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
          ),
        ),
        Container(
          margin: EdgeInsets.only(left: 40.w),
          child: Text(info,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.darkteal,
              )),
        ),
      ],
    ),
  );
}
