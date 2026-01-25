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
                                    () {
                                      final busStatus =
                                          controller.busStatus.value;
                                      final status = busStatus?.currentStatus ??
                                          "InActive";

                                      // Check if bus is truly online (not stale data > 5 minutes)
                                      bool isActuallyOnline = false;
                                      if (busStatus != null) {
                                        final now = DateTime.now();
                                        final difference = now
                                            .difference(busStatus.lastUpdated);
                                        isActuallyOnline =
                                            difference.inMinutes < 5;
                                      }

                                      // Use trip-aware active check: bus is active only if running student's trip
                                      final isActive = isActuallyOnline &&
                                          controller.isBusActiveForStudent;
                                      return Container(
                                        width: 60.w,
                                        height: 30.h,
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? Colors.white
                                              : Colors.grey,
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(20.r),
                                            bottomLeft: Radius.circular(20.r),
                                          ),
                                          border: Border.all(
                                            color: isActive
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
                                                style:
                                                    TextStyle(fontSize: 12.sp),
                                              )
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  Obx(
                                    () {
                                      final busStatus =
                                          controller.busStatus.value;
                                      final status = busStatus?.currentStatus ??
                                          "InActive";

                                      // Check if bus is truly online (not stale data > 5 minutes)
                                      bool isActuallyOnline = false;
                                      if (busStatus != null) {
                                        final now = DateTime.now();
                                        final difference = now
                                            .difference(busStatus.lastUpdated);
                                        isActuallyOnline =
                                            difference.inMinutes < 5;
                                      }

                                      // Use trip-aware active check: bus is active only if running student's trip
                                      final isActive = isActuallyOnline &&
                                          controller.isBusActiveForStudent;
                                      return Container(
                                        width: 64.w,
                                        height: 30.h,
                                        decoration: BoxDecoration(
                                          color: !isActive
                                              ? Colors.white
                                              : Colors.grey,
                                          borderRadius: BorderRadius.only(
                                            topRight: Radius.circular(20.r),
                                            bottomRight: Radius.circular(20.r),
                                          ),
                                          border: Border.all(
                                            color: !isActive
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
                                                style:
                                                    TextStyle(fontSize: 12.sp),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Optimized map container - responsive height
                    Container(
                      height: MediaQuery.of(context).size.height * 0.4,
                      margin: EdgeInsets.symmetric(vertical: 10.h),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(13.r),
                        border: Border.all(
                          color: AppColors.lightblue,
                          width: 2,
                        ),
                      ),
                      child: Obx(() {
                        final status = controller.busStatus.value;
                        final busDetail = controller.busDetail.value;
                        final currentStops =
                            controller.getCurrentTripStopsForDisplay();

                        // Show map with bus details even if no active trip
                        if (status == null &&
                            ((currentStops.isNotEmpty) ||
                                (busDetail != null &&
                                    busDetail.stoppings.isNotEmpty))) {
                          // Show map with bus route but no live tracking
                          final stopsToShow = currentStops.isNotEmpty
                              ? currentStops
                              : busDetail!.stoppings;
                          final firstStop = stopsToShow.first;
                          return Column(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8.w),
                                color: Colors.orange.withOpacity(0.8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Colors.white, size: 20.sp),
                                    SizedBox(width: 8.w),
                                    Text(
                                      "No Active Trip - Showing Route",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: FlutterMap(
                                  mapController: controller.mapController,
                                  options: MapOptions(
                                    initialZoom: 13,
                                    initialCenter: LatLng(firstStop.latitude,
                                        firstStop.longitude),
                                    keepAlive: true,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:
                                          'com.jupenta.busmate',
                                      maxNativeZoom: 19,
                                      maxZoom: 19,
                                    ),
                                    // Show stop markers
                                    MarkerLayer(
                                      markers: stopsToShow
                                          .map((stop) => Marker(
                                                width: 100.sp,
                                                height: 70.sp,
                                                point: LatLng(stop.latitude,
                                                    stop.longitude),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                        horizontal: 8.w,
                                                        vertical: 4.h,
                                                      ),
                                                      constraints:
                                                          BoxConstraints(
                                                        maxWidth: 100.sp,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8.r),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    0.3),
                                                            blurRadius: 6,
                                                            offset:
                                                                const Offset(
                                                                    0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Text(
                                                        stop.name,
                                                        style: TextStyle(
                                                          fontSize: 9.sp,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: AppColors
                                                              .darkteal,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    SizedBox(height: 2.h),
                                                    Icon(
                                                      Icons.location_on,
                                                      size: 30.sp,
                                                      color: AppColors.red,
                                                    ),
                                                  ],
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                    // Show route polyline
                                    Obx(() {
                                      final routePoints =
                                          controller.routePolyline;
                                      if (routePoints.isEmpty) {
                                        // Generate simple polyline from stops if not available
                                        final polylinePoints = stopsToShow
                                            .map((stop) => LatLng(
                                                stop.latitude, stop.longitude))
                                            .toList();
                                        return PolylineLayer(
                                          polylines: [
                                            Polyline(
                                              points: polylinePoints,
                                              strokeWidth: 4.0,
                                              color:
                                                  Colors.blue.withOpacity(0.7),
                                              borderStrokeWidth: 2.0,
                                              borderColor:
                                                  Colors.white.withOpacity(0.5),
                                            ),
                                          ],
                                        );
                                      }

                                      return PolylineLayer(
                                        polylines: [
                                          Polyline(
                                            
                                            points: routePoints,
                                            strokeWidth: 4.0,
                                            color: Colors.blue.withOpacity(0.7),
                                            borderStrokeWidth: 2.0,
                                            borderColor:
                                                Colors.white.withOpacity(0.5),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        // Show "no active trip" message if no bus status and no bus details
                        if (status == null) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.directions_bus_outlined,
                                  size: 80.sp,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 20.h),
                                Text(
                                  "No Route Information",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Text(
                                  "Bus route not configured yet.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Show current segment and delay status above the map
                        return Column(
                          children: [
                            if (status.currentSegment != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 8.0, bottom: 4.0),
                                child: Text(
                                  "Segment: ${status.currentSegment}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.green,
                                  ),
                                ),
                              ),
                            if (status.isDelayed)
                              const Padding(
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
                                  initialZoom: 17,
                                  initialCenter:
                                      LatLng(status.latitude, status.longitude),
                                  keepAlive: true,
                                  onMapReady: () {
                                    // Center on bus if it has a valid location
                                    if (status.latitude != 0.0 &&
                                        status.longitude != 0.0) {
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
                                    userAgentPackageName: 'com.jupenta.busmate',
                                    maxNativeZoom: 19,
                                    maxZoom: 19,
                                  ),

                                  // Optimized marker layer
                                  MarkerLayer(
                                    markers: () {
                                      final List<Marker> markers = [];

                                      // 1. Add bus marker
                                      markers.add(
                                        Marker(
                                          point: LatLng(status.latitude,
                                              status.longitude),
                                          width: 70.sp,
                                          height: 70.sp,
                                          child: RepaintBoundary(
                                            child: Transform.rotate(
                                              angle: (status.currentLocation[
                                                          'heading'] ??
                                                      0.0) *
                                                  (3.14159 / 180),
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  // Drop shadow
                                                  Container(
                                                    width: 50.sp,
                                                    height: 50.sp,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(0.4),
                                                          blurRadius: 8,
                                                          spreadRadius: 2,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  // Main marker circle
                                                  Container(
                                                    width: 50.sp,
                                                    height: 50.sp,
                                                    decoration: BoxDecoration(
                                                      color: (status.currentStatus
                                                                      .toLowerCase() ==
                                                                  'moving' ||
                                                              status.currentStatus ==
                                                                  'Active')
                                                          ? Colors.green
                                                          : Colors.orange,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: Colors.white,
                                                        width: 3,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(0.2),
                                                          blurRadius: 6,
                                                          offset: const Offset(
                                                              0, 3),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Center(
                                                      child: Icon(
                                                        Icons
                                                            .directions_bus_rounded,
                                                        color: Colors.white,
                                                        size: 28.sp,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );

                                      // 2. Add stop markers for the CURRENT trip (schedule cache)
                                      // Fallback to busDetail only if schedule stops are unavailable.
                                      final stops = controller
                                          .getCurrentTripStopsForDisplay()
                                          .cast<dynamic>();
                                      final fallbackStops = controller
                                              .busDetail.value?.stoppings ??
                                          [];
                                      final stopsToShow = stops.isNotEmpty
                                          ? stops
                                          : fallbackStops;
                                      for (var i = 0;
                                          i < stopsToShow.length;
                                          i++) {
                                        final stop = stopsToShow[i];
                                        final lat = stop.latitude;
                                        final lng = stop.longitude;
                                        // Skip stops with invalid coordinates
                                        if (lat == 0.0 && lng == 0.0) {
                                          continue;
                                        }

                                        markers.add(
                                          Marker(
                                            width: 100.sp,
                                            height: 70.sp,
                                            point: LatLng(lat, lng),
                                            child: RepaintBoundary(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                      horizontal: 8.w,
                                                      vertical: 4.h,
                                                    ),
                                                    constraints: BoxConstraints(
                                                      maxWidth: 100.sp,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.r),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(0.3),
                                                          blurRadius: 6,
                                                          offset: const Offset(
                                                              0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Text(
                                                      stop.name,
                                                      style: TextStyle(
                                                        fontSize: 9.sp,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            AppColors.darkteal,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  SizedBox(height: 2.h),
                                                  Icon(
                                                    Icons.location_on,
                                                    size: 32.sp,
                                                    color: AppColors.red,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      return markers;
                                    }(),
                                  ),

                                  // Polyline layer showing route
                                  Obx(() {
                                    final routePoints =
                                        controller.routePolyline;
                                    if (routePoints.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: routePoints,
                                          strokeWidth: 4.0,
                                          color: Colors.blue.withOpacity(0.7),
                                          borderStrokeWidth: 2.0,
                                          borderColor:
                                              Colors.white.withOpacity(0.5),
                                        ),
                                      ],
                                    );
                                  }),
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
                        "${'number'.tr}: ${controller.busDetail.value?.busVehicleNo ?? 'N/A'}\n${'route'.tr}: ${controller.currentTripRouteName.value.isNotEmpty ? controller.currentTripRouteName.value : (controller.busStatus.value?.routeName ?? controller.busDetail.value?.routeName ?? 'N/A')}",
                      ),
                    ),
                    const DottedLine(
                      alignment: WrapAlignment.center,
                      dashLength: 16,
                      lineThickness: 1.7,
                    ),
                    Obx(() => driverInfoBox(
                      "driverinfo".tr,
                      "${'name'.tr}: ${controller.driver.value?.name ?? controller.busStatus.value?.driverName ?? 'N/A'}",
                      () async => await EasyLauncher.call(
                        number: controller.driver.value?.contactInfo ?? 'N/A',
                      ),
                      imageUrl: controller.driver.value?.profileImageUrl,
                      phoneNumber: controller.driver.value?.contactInfo,
                    )),
                    // Add a progress indicator showing completed stops vs total stops
                    Obx(() {
                      final totalStops = controller
                              .currentTripStopsPickupOrder.isNotEmpty
                          ? controller.currentTripStopsPickupOrder.length
                          : (controller.busDetail.value?.stoppings.length ?? 0);
                      final remainingStops =
                          controller.busStatus.value?.remainingStops.length ??
                              0;
                      final busStatus = controller.busStatus.value;
                      final busDetail = controller.busDetail.value;
                      final speed = busStatus?.currentSpeed ?? 0.0;

                      // Check if bus is truly online (not stale data > 5 minutes)
                      bool isActuallyOnline = false;
                      if (busStatus != null) {
                        final now = DateTime.now();
                        final difference =
                            now.difference(busStatus.lastUpdated);
                        isActuallyOnline = difference.inMinutes < 5;
                      }

                      final isMoving = isActuallyOnline && (speed > 2.0);

                      // Get trip direction from RTDB (tripDirection is the actual current trip)
                      final tripDirection =
                          busStatus?.tripDirection ?? "pickup";

                      // Get student's assigned route to show only relevant stops
                      final studentRouteId =
                          controller.student.value?.assignedRouteId;

                      // Prefer current trip stops from schedule cache (always in pickup order)
                      // Filter to student's route if multi-route bus
                      List<Stoppings> allStopsPickupOrder;
                      if (controller.currentTripStopsPickupOrder.isNotEmpty) {
                        allStopsPickupOrder =
                            controller.currentTripStopsPickupOrder;
                      } else if (busDetail?.stoppings != null) {
                        allStopsPickupOrder = busDetail!.stoppings;
                      } else {
                        allStopsPickupOrder = [];
                      }

                      // Reverse stops if this is a drop route
                      final allStops = tripDirection == "drop"
                          ? allStopsPickupOrder.reversed.toList()
                          : allStopsPickupOrder;

                      final remainingStopsList =
                          busStatus?.remainingStops ?? [];
                      final routeType =
                          tripDirection; // Use tripDirection instead of busRouteType

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
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: allStops.length,
                                itemBuilder: (context, idx) {
                                  final stop = allStops[idx];
                                  // Since we've already reversed allStops for drop routes,
                                  // completed stops are always the first N items in the displayed list
                                  bool isCompleted = idx < completedStops;

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
                                                      null)
                                                Text(
                                                  "ETA: ${formatETA(remainingStop.estimatedTimeOfArrival!)}",
                                                  style: TextStyle(
                                                      fontSize: 12.sp),
                                                ),
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
