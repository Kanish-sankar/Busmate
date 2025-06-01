import 'package:busmate/meta/model/bus_model.dart';
import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

Widget notificationList(String id, List<Stoppings> data) => AnimatedContainer(
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
                  size: 30.sp,
                ),
              ),
              SizedBox(
                width: 27.w,
              ),
              Text(
                'select'.tr,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 15.h,
          ),
          ...List.generate(
            6,
            // data.length + 6,
            (index) {
              return ListTile(
                title: Text((index < 6)
                    ? "${5 * (index + 1)} Mins"
                    : data[index - 6].name, style: TextStyle(
                      fontSize: 12.sp,
                    ),),
                onTap: () {
                  if (index < 6) {
                    FirebaseFirestore.instance
                        .collection('students')
                        .doc(id)
                        .update({
                      'notificationPreferenceByTime': 5 * (index + 1),
                    });
                  } else {
                    // for now not needed
                  }
                  Get.back();
                },
                // textColor: GetStorage().read('selectedLangIndex') == index
                //     ? Colors.blue
                //     : Colors.black,
              );
            },
          ),
        ],
      ),
    );
