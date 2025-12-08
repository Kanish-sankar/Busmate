import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Widget driverInfoBox(
  String title, 
  String info, 
  void Function()? onTap, 
  {String? imageUrl, String? phoneNumber}
) {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 10.w),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10.r),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
          ),
        ),

        Row(
          children: [
            CircleAvatar(
              radius: 27.r,
              backgroundColor: Colors.grey,
              backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                  ? NetworkImage(imageUrl) // Fetch image from the provided URL
                  : null,
              child: imageUrl == null || imageUrl.isEmpty
                  ? Icon(
                      Icons.person,
                      size: 27.sp,
                      color: Colors.white,
                    )
                  : null,
            ),
            SizedBox(width: 7.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.darkteal,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (phoneNumber != null && phoneNumber.isNotEmpty)
                    GestureDetector(
                      onTap: onTap,
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 14.sp,
                            color: Colors.blue,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            phoneNumber,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                    color: AppColors.darkteal,
                    borderRadius: BorderRadius.circular(5.r)),
                child: Icon(
                  Icons.call,
                  color: Colors.white,
                  size: 20.sp,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
