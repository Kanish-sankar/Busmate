import 'package:busmate/presentation/parents_module/dashboard/widgets/info_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

Widget studentDetails({
  required String studentName,
  required String studentClass,
  required String schoolName,
  required String busNumber,
  required String location,
}) =>
    Padding(
      padding: EdgeInsets.only(left: 25.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          infoText("stdname".tr, studentName),
          infoText("stdclass".tr, studentClass),
          infoText("schname".tr, schoolName),
          infoText("busno".tr, busNumber),
          infoText("stdloc".tr, location),
        ],
      ),
    );
