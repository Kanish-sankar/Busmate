import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Widget infoCard(String title, String value) {
  return Column(
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
          color: Colors.black54,
        ),
      ),
      SizedBox(height: 4.h),
      Text(
        value,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    ],
  );
}

Widget infoText(String title, String value, {bool bold = false}) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 4.h),
    child: RichText(
      text: TextSpan(
        text: "$title : ",
        style: TextStyle(
          fontSize: 14.sp,
          color: Colors.black,
          fontWeight: FontWeight.w500,
        ),
        children: [
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: bold ? FontWeight.bold : FontWeight.w400,
              color: Colors.black,
            ),
          ),
        ],
      ),
    ),
  );
}