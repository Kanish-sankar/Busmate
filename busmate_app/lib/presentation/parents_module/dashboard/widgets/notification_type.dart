import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

Widget notificationType(String id) => AnimatedContainer(
      margin: EdgeInsets.all(10.w),
      duration: const Duration(
        seconds: 10,
      ),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.r),
            topRight: Radius.circular(20.r),
          )),
      curve: Curves.fastOutSlowIn,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  Get.back();
                },
                icon: Icon(
                  Icons.clear_sharp,
                  size: 24.sp,
                ),
              ),
              SizedBox(
                width: 27.w,
              ),
              Text(
                'select'.tr,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 15.h,
          ),
          ListTile(
            title: Text("Voice Notification",
                style: TextStyle(
                  fontSize: 14.sp,
                )),
            onTap: () {
              FirebaseFirestore.instance
                  .collection('students')
                  .doc(id)
                  .update({'notificationType': 'Voice Notification'});
              Get.back();
            },
          ),
          ListTile(
            title: Text("Text Notification",
                style: TextStyle(
                  fontSize: 14.sp,
                )),
            onTap: () {
              FirebaseFirestore.instance
                  .collection('students')
                  .doc(id)
                  .update({'notificationType': 'Text Notification'});
              Get.back();
            },
          ),
        ],
      ),
    );
