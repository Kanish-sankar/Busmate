import 'package:busmate/meta/model/bus_model.dart';
import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

Widget locationList(String id, List<Stoppings> data) => AnimatedContainer(
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
          ...List.generate(
            data.length,
            (index) => ListTile(
              title: Text(data[index].name, 
                  style: TextStyle(
                    fontSize: 14.sp,
                  )),
              onTap: () {
                FirebaseFirestore.instance
                    .collection('students')
                    .doc(id)
                    .update({
                  'stopping': data[index].name,
                  'stopLocation': {
                    'latitude': data[index].latitude,
                    'longitude': data[index].longitude,
                  }
                });
                Get.back();
              },
              // textColor: GetStorage().read('selectedLangIndex') == index
              //     ? Colors.blue
              //     : Colors.black,
            ),
          ),
        ],
      ),
    );
