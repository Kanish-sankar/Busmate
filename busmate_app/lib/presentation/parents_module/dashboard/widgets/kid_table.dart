import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Widget tableHeader(String title) {
  return Expanded(
    child: Text(
      title,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
    ),
  );
}

Widget tableStudentData(String name, String id, String cls, String school) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      tableData(name),
      tableData(id),
      tableData("${cls}th \"A\""),
      tableData(school),
    ],
  );
}

Widget tableData(String data) {
  return Expanded(
    child: Text(
      data,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 14.sp),
    ),
  );
}
