import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Widget infoText(String title, String value) {
  return Padding(
    padding: EdgeInsets.only(bottom: 8.h),
    child: Text(
      "$title : $value",
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
