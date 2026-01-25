import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

Widget notificationType(String id) => DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.3,
      maxChildSize: 0.6,
      expand: false,
      builder: (context, scrollController) => Container(
        margin: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20.r),
              topRight: Radius.circular(20.r),
            )),
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
            Expanded(
              child: ListView(
                controller: scrollController,
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: Text("Voice Notification",
                        style: TextStyle(
                          fontSize: 14.sp,
                        )),
                    onTap: () async {
                      final schoolId = GetStorage().read('studentSchoolId');
                      if (schoolId != null) {
                        // Try schooldetails first
                        DocumentReference docRef = FirebaseFirestore.instance
                            .collection('schooldetails')
                            .doc(schoolId)
                            .collection('students')
                            .doc(id);
                        
                        DocumentSnapshot doc = await docRef.get();
                        if (!doc.exists) {
                          // Try schools collection
                          docRef = FirebaseFirestore.instance
                              .collection('schools')
                              .doc(schoolId)
                              .collection('students')
                              .doc(id);
                        }
                        
                        await docRef.update({'notificationType': 'Voice Notification'});
                        Get.back();
                        Get.snackbar("Success", "Notification type updated to Voice");
                      } else {
                        Get.snackbar("Error", "School ID not found");
                      }
                    },
                  ),
                  ListTile(
                    title: Text("Text Notification",
                        style: TextStyle(
                          fontSize: 14.sp,
                        )),
                    onTap: () async {
                      final schoolId = GetStorage().read('studentSchoolId');
                      if (schoolId != null) {
                        // Try schooldetails first
                        DocumentReference docRef = FirebaseFirestore.instance
                            .collection('schooldetails')
                            .doc(schoolId)
                            .collection('students')
                            .doc(id);
                        
                        DocumentSnapshot doc = await docRef.get();
                        if (!doc.exists) {
                          // Try schools collection
                          docRef = FirebaseFirestore.instance
                              .collection('schools')
                              .doc(schoolId)
                              .collection('students')
                              .doc(id);
                        }
                        
                        await docRef.update({'notificationType': 'Text Notification'});
                        Get.back();
                        Get.snackbar("Success", "Notification type updated to Text");
                      } else {
                        Get.snackbar("Error", "School ID not found");
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
