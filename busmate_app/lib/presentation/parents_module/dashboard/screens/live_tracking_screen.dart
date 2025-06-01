import 'dart:developer';

import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:busmate/meta/model/bus_model.dart';
import 'package:busmate/presentation/parents_module/dashboard/controller/dashboard.controller.dart';
import 'package:busmate/presentation/parents_module/dashboard/widgets/bus_info_box.dart';
import 'package:busmate/presentation/parents_module/dashboard/widgets/driver_info_box.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:easy_url_launcher/easy_url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

// Move this function to top-level (outside the class) so it can be used anywhere in this file.
String formatETA(DateTime eta) {
  final now = DateTime.now();
  final difference = eta.difference(now);

  if (difference.inMinutes < 1) {
    return 'Arriving';
  } else if (difference.inHours < 1) {
    return '${difference.inMinutes}min';
  } else {
    return '${difference.inHours}h ${difference.inMinutes % 60}m';
  }
}

class LiveTrackingScreen extends GetView<DashboardController> {
  const LiveTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DashboardController>(
      builder: (controller) {
        log("Remaining stops: ${controller.busStatus.value?.remainingStops.length.toString() ?? "0"}");
        return SafeArea(
          child: Scaffold(
            backgroundColor:
                Colors.transparent, // Set to transparent to show the map behind
            body: Padding(
              padding: EdgeInsets.all(20.w),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Header with title and status toggle buttons.
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: AppColors.lightblue,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("livetrack".tr,
                                style: TextStyle(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(width: 20.w),
                            Container(
                              width: 124.w,
                              height: 30.h,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Obx(
                                    () => Container(
                                      width: 60.w,
                                      height: 30.h,
                                      decoration: BoxDecoration(
                                        color: ((controller.busStatus.value
                                                        ?.currentStatus ??
                                                    "InActive") ==
                                                'Active')
                                            ? Colors.white
                                            : Colors.grey,
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(20.r),
                                          bottomLeft: Radius.circular(20.r),
                                        ),
                                        border: Border.all(
                                          color: ((controller.busStatus.value
                                                          ?.currentStatus ??
                                                      "InActive") ==
                                                  'Active')
                                              ? AppColors.yellow
                                              : AppColors.shadow,
                                          width: 2,
                                        ),
                                      ),
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              color: Colors
                                                  .green, // Fixed green color for active
                                              size: 10.sp,
                                            ),
                                            SizedBox(width: 2.w),
                                            Text(
                                              "active".tr,
                                              style: TextStyle(fontSize: 12.sp),
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Obx(
                                    () => Container(
                                      width: 64.w,
                                      height: 30.h,
                                      decoration: BoxDecoration(
                                        color: ((controller.busStatus.value
                                                        ?.currentStatus ??
                                                    "InActive") !=
                                                'Active')
                                            ? Colors.white
                                            : Colors.grey,
                                        borderRadius: BorderRadius.only(
                                          topRight: Radius.circular(20.r),
                                          bottomRight: Radius.circular(20.r),
                                        ),
                                        border: Border.all(
                                          color: ((controller.busStatus.value
                                                          ?.currentStatus ??
                                                      "InActive") !=
                                                  'Active')
                                              ? AppColors.yellow
                                              : AppColors.shadow,
                                          width: 2,
                                        ),
                                      ),
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              color: Colors
                                                  .red, // Fixed red color for inactive
                                              size: 10.sp,
                                            ),
                                            SizedBox(width: 2.w),
                                            Text(
                                              "inactive".tr,
                                              style: TextStyle(fontSize: 12.sp),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Optimized map container
                    Container(
                      height: 369.h,
                      margin: EdgeInsets.symmetric(vertical: 10.h),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(13.r),
                        border: Border.all(
                          color: AppColors.lightblue,
                          width: 2,
                        ),
                      ),
                      // Use Obx only for the map content
                      // Use Obx only for the map content
                      child: Obx(() {
                        final status = controller.busStatus.value;
                        if (status == null) return const SizedBox();

                        // Show current segment and delay status above the map
                        return Column(
                          children: [
                            if (status.currentSegment != null)
                              Padding(
                                padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
                                child: Text(
                                  "Segment: ${status.currentSegment}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.green,
                                  ),
                                ),
                              ),
                            if (status.isDelayed)
                              Padding(
                                padding: EdgeInsets.only(bottom: 4.0),
                                child: Text(
                                  "Delay detected: Bus is stationary or slow",
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: FlutterMap(
                                mapController: controller.mapController,
                                options: MapOptions(
                                  initialZoom: 15,
                                  initialCenter:
                                      LatLng(status.latitude, status.longitude),
                                  keepAlive: true,
                                  onMapReady: () {
                                    if (status.currentStatus == 'Active') {
                                      controller.mapController.move(
                                        LatLng(
                                            status.latitude, status.longitude),
                                        controller.mapController.camera.zoom,
                                      );
                                    }
                                  },
                                ),
                                children: [
                                  // Base map layer
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.busmate.app',
                                  ),

                                  // Optimized polyline layer
                                  if (controller.routePolyline.isNotEmpty)
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: controller.routePolyline,
                                          strokeWidth: 4.0,
                                          color:
                                              AppColors.green.withOpacity(0.8),
                                          borderColor:
                                              AppColors.green.withOpacity(0.4),
                                          borderStrokeWidth: 6.0,
                                        ),
                                      ],
                                    ),

                                  // Optimized marker layer
                                  MarkerLayer(
                                    markers: [
                                      // Bus marker
                                      Marker(
                                        point: LatLng(
                                            status.latitude, status.longitude),
                                        width: 50.sp,
                                        height: 50.sp,
                                        child: RepaintBoundary(
                                          child: Transform.rotate(
                                            angle: (status.currentLocation[
                                                        'heading'] ??
                                                    0.0) *
                                                (3.14159 / 180),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.2),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.directions_bus,
                                                size: 30.sp,
                                                color: status.currentStatus ==
                                                        'Active'
                                                    ? AppColors.darkteal
                                                    : Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Stop markers with optimization
                                      ...status.remainingStops.map(
                                        (stop) => Marker(
                                          width: 40.sp,
                                          height: 55.sp,
                                          point: LatLng(
                                              stop.latitude, stop.longitude),
                                          child: RepaintBoundary(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (stop.estimatedTimeOfArrival !=
                                                    null)
                                                  Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                      horizontal: 4.w,
                                                      vertical: 2.h,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4.r),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(0.1),
                                                          blurRadius: 4,
                                                          offset: const Offset(
                                                              0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Text(
                                                      formatETA(stop
                                                          .estimatedTimeOfArrival!),
                                                      style: TextStyle(
                                                        fontSize: 7.sp,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                SizedBox(height: 2.h),
                                                Icon(
                                                  Icons.location_on,
                                                  size: 25.sp,
                                                  color: AppColors.red,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                    SizedBox(height: 20.h),
                    Obx(
                      () => busInfoBox(
                        "businfo".tr,
                        "${'number'.tr}: ${controller.busDetail.value?.busVehicleNo ?? 'N/A'}\n${'route'.tr}: ${controller.busDetail.value?.routeName ?? 'N/A'}",
                      ),
                    ),
                    const DottedLine(
                      alignment: WrapAlignment.center,
                      dashLength: 16,
                      lineThickness: 1.7,
                    ),
                    driverInfoBox(
                      "driverinfo".tr,
                      "${'name'.tr}: ${controller.driver.value?.name ?? 'N/A'}",
                      () async => await EasyLauncher.call(
                        number: controller.driver.value?.contactInfo ?? 'N/A',
                      ),
                      imageUrl: controller
                          .driver.value?.profileImageUrl, // Pass the image URL
                    ),
                    // Add a progress indicator showing completed stops vs total stops
                    Obx(() {
                      final totalStops =
                          controller.busDetail.value?.stoppings.length ?? 0;
                      final remainingStops =
                          controller.busStatus.value?.remainingStops.length ??
                              0;
                      final busStatus = controller.busStatus.value;
                      final busDetail = controller.busDetail.value;
                      final speed = busStatus?.currentSpeed ?? 0.0;
                      final isMoving = (speed > 2.0);
                      final allStops = busDetail?.stoppings ?? [];
                      final remainingStopsList =
                          busStatus?.remainingStops ?? [];
                      final routeType = busStatus?.busRouteType ?? "pickup";

                      // Calculate completed stops based on route type
                      int completedStops = 0;
                      if (totalStops > 0 && remainingStops >= 0) {
                        completedStops = totalStops - remainingStops;
                      }

                      return Padding(
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "stopprogress".tr,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 5.h),
                              LinearProgressIndicator(
                                value: totalStops > 0
                                    ? completedStops / totalStops
                                    : 0,
                                backgroundColor: AppColors.lightblue,
                                color: AppColors.green,
                                minHeight: 10.h,
                              ),
                              SizedBox(height: 5.h),
                              Text(
                                "$completedStops/$totalStops ${'stopscompleted'.tr}",
                                style: TextStyle(fontSize: 14.sp),
                              ),
                              SizedBox(height: 10.h),
                              // Bus status details
                              Container(
                                padding: EdgeInsets.all(10.w),
                                decoration: BoxDecoration(
                                  color: AppColors.lightblue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Bus Speed: ${speed.toStringAsFixed(1)} km/h",
                                      style: TextStyle(fontSize: 13.sp),
                                    ),
                                    Text(
                                      "Current Segment: ${busStatus?.currentSegment ?? 'N/A'}",
                                      style: TextStyle(fontSize: 13.sp),
                                    ),
                                    Text(
                                      "Status: ${isMoving ? "Moving" : "Not Moving"}",
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        color: isMoving
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                    if (busStatus?.isDelayed == true)
                                      Text(
                                        "Delay detected",
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          color: AppColors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    Text(
                                      "Route Type: ${routeType == "pickup" ? "Pickup" : "Drop"}",
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        color: AppColors.darkteal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 10.h),
                              // List all stops with ETA from BusStatusModel
                              ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: allStops.length,
                                itemBuilder: (context, idx) {
                                  final stop = allStops[idx];
                                  // For pickup: completed stops are from the start
                                  // For drop: completed stops are from the end
                                  bool isCompleted = false;
                                  if (routeType == "pickup") {
                                    isCompleted = idx < completedStops;
                                  } else {
                                    isCompleted =
                                        idx >= (totalStops - completedStops);
                                  }

                                  // Find matching stop in remainingStops to get ETA
                                  final remainingStop =
                                      remainingStopsList.firstWhere(
                                    (s) =>
                                        s.name == stop.name &&
                                        s.latitude == stop.latitude &&
                                        s.longitude == stop.longitude,
                                    orElse: () => StopWithETA(
                                      name: stop.name,
                                      latitude: stop.latitude,
                                      longitude: stop.longitude,
                                    ),
                                  );

                                  return Container(
                                    margin: EdgeInsets.symmetric(vertical: 4.h),
                                    padding: EdgeInsets.all(8.w),
                                    decoration: BoxDecoration(
                                      color: isCompleted
                                          ? AppColors.green.withOpacity(0.1)
                                          : AppColors.lightblue
                                              .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6.r),
                                      border: Border.all(
                                        color: isCompleted
                                            ? AppColors.green
                                            : AppColors.lightblue,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isCompleted
                                              ? Icons.check_circle
                                              : Icons.location_on,
                                          color: isCompleted
                                              ? AppColors.green
                                              : AppColors.red,
                                          size: 20.sp,
                                        ),
                                        SizedBox(width: 8.w),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                stop.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.sp,
                                                ),
                                              ),
                                              SizedBox(height: 2.h),
                                              if (!isCompleted &&
                                                  remainingStop
                                                          .estimatedTimeOfArrival !=
                                                      null) ...[
                                                Text(
                                                  "ETA: ${formatETA(remainingStop.estimatedTimeOfArrival!)}",
                                                  style: TextStyle(
                                                      fontSize: 12.sp),
                                                ),
                                                if (remainingStop
                                                        .distanceToStop !=
                                                    null)
                                                  Text(
                                                    "Distance: ${(remainingStop.distanceToStop! / 1000).toStringAsFixed(1)} km",
                                                    style: TextStyle(
                                                        fontSize: 12.sp,
                                                        color: Colors.blue),
                                                  ),
                                              ],
                                              Text(
                                                "Lat: ${stop.latitude.toStringAsFixed(6)}, Lng: ${stop.longitude.toStringAsFixed(6)}",
                                                style: TextStyle(
                                                    fontSize: 11.sp,
                                                    color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ));
                    }),
                  ],
                ),
              ),
            ),
            // Add the FloatingActionButton for recentering
            floatingActionButton: Obx(() {
              final busStatus = controller.busStatus.value;
              // Only show the button if the bus is active
              if (busStatus != null && busStatus.currentStatus == 'Active') {
                return FloatingActionButton(
                  onPressed: () {
                    controller.recenterMapOnBus(); // Call the new method
                  },
                  backgroundColor:
                      AppColors.darkteal, // Choose a suitable color
                  child: const Icon(Icons.my_location, color: Colors.white),
                );
              } else {
                return const SizedBox
                    .shrink(); // Hide button if bus is not active
              }
            }),
          ),
        );
      },
    );
  }
}
