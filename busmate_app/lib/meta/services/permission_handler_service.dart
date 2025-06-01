import 'dart:io';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PermissionHandlerService {
  static Future<void> handleAllPermissions() async {
    try {
      // Check location services
      bool serviceEnabled =
          await geolocator.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        bool openedSettings =
            await geolocator.Geolocator.openLocationSettings();
        if (!openedSettings) {
          Get.snackbar(
            "Location Services Required",
            "Please enable location services to use this app",
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
          return;
        }
      }

      // Request permissions based on platform
      if (Platform.isAndroid) {
        await _handleAndroidPermissions();
      } else if (Platform.isIOS) {
        await _handleIOSPermissions();
      }
    } catch (e) {
      Get.snackbar(
        "Permission Error",
        "Error requesting permissions: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  static Future<void> _handleAndroidPermissions() async {
    // Request notification permission
    final notificationStatus = await Permission.notification.request();
    if (!notificationStatus.isGranted) {
      Get.snackbar(
        "Notification Permission",
        "Please enable notifications to receive important updates",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }

    // Request location permissions
    final locationStatus = await Permission.location.request();
    if (locationStatus.isGranted) {
      final backgroundStatus = await Permission.locationAlways.request();
      if (!backgroundStatus.isGranted) {
        Get.snackbar(
          "Background Location",
          "Please allow background location for bus tracking",
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } else {
      Get.snackbar(
        "Location Permission",
        "Location permission is required for bus tracking",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }

    // Request battery optimization exemption
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  static Future<void> _handleIOSPermissions() async {
    // Request notification permission
    final notificationStatus = await Permission.notification.request();
    if (!notificationStatus.isGranted) {
      Get.snackbar(
        "Notification Permission",
        "Please enable notifications to receive important updates",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }

    // Request locationWhenInUse first
    var whenInUse = await Permission.locationWhenInUse.status;
    if (whenInUse.isDenied) {
      whenInUse = await Permission.locationWhenInUse.request();
    }
    if (whenInUse.isPermanentlyDenied) {
      Get.snackbar(
        "Location Permission",
        "Please enable location permissions in Settings → Privacy → Location Services → BusMate.",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      await openAppSettings();
      return;
    }
    if (!whenInUse.isGranted) {
      Get.snackbar(
        "Location Permission",
        "Location permission is required for bus tracking",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Request locationAlways only if whenInUse is granted
    var always = await Permission.locationAlways.status;
    if (!always.isGranted) {
      always = await Permission.locationAlways.request();
    }
    if (always.isPermanentlyDenied) {
      Get.snackbar(
        "Background Location",
        "Please allow background location in Settings for bus tracking",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      await openAppSettings();
      return;
    }
    if (!always.isGranted) {
      Get.snackbar(
        "Background Location",
        "Please allow background location for bus tracking",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }
  }
}
