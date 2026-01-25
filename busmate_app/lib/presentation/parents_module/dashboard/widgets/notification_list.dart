import 'package:busmate/meta/model/bus_model.dart';
import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

Widget notificationList(String id, List<Stoppings> data) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
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
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                shrinkWrap: true,
                itemCount: 6,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text("${5 * (index + 1)} Mins", style: TextStyle(
                          fontSize: 12.sp,
                        ),),
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
                        
                        await docRef.update({
                          'notificationPreferenceByTime': 5 * (index + 1),
                        });
                        Get.back();
                        Get.snackbar("Success", "Notification time updated to ${5 * (index + 1)} minutes");
                      } else {
                        Get.snackbar("Error", "School ID not found");
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
