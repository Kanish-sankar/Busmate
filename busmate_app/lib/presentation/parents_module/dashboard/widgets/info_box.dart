import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Widget infoBox(String title1, String content1, String title2, String content2) {
  return Container(
    padding: EdgeInsets.all(15.w),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10.r),
      border: Border.all(color: Colors.grey.shade300, width: 1),
      boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title1,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
        SizedBox(height: 5.h),
        Text(content1, style: TextStyle(fontSize: 12.sp)),
        SizedBox(height: 5.h),
        Text(title2,
            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)),
        SizedBox(height: 5.h),
        Text(content2, style: TextStyle(fontSize: 12.sp)),
      ],
    ),
  );
}
