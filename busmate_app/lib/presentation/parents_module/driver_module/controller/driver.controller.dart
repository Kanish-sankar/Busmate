import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui';

import 'package:background_locator_2/background_locator.dart';
import 'package:background_locator_2/location_dto.dart';
import 'package:background_locator_2/settings/android_settings.dart';
import 'package:background_locator_2/settings/ios_settings.dart';
import 'package:background_locator_2/settings/locator_settings.dart';
import 'package:busmate/location_callback_handler.dart';
import 'package:busmate/meta/model/bus_model.dart';
import 'package:busmate/meta/model/driver_model.dart';
import 'package:busmate/meta/model/scool_model.dart';
import 'package:busmate/meta/model/student_model.dart';
import 'package:busmate/meta/nav/pages.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class DriverController extends GetxController {
  // ignore: constant_identifier_names
  static const double STOP_RADIUS = 100.0; // 100 meters radius
  static const String _trackingEnabledKey = 'driverTrackingEnabled';

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  RxList<dynamic> remainingStops = <dynamic>[].obs;
  RxBool isTripActive = false.obs; // <-- Add this observable

  @override
  void onInit() async {
    // 🔒 Check if user is actually logged in first
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Not logged in - don't try to fetch any data
      super.onInit();
      return;
    }

    GetStorage storage = GetStorage();
    if (storage.read(_trackingEnabledKey) == null) {
      storage.write(_trackingEnabledKey, false);
    }

    // 🔒 Ensure custom claims are set for current user (critical for security rules)
    await _ensureUserClaimsAreSet();

    // Debug prints
    await fetchSchool(storage.read('driverSchoolId'));
    await fetchDriver(storage.read('driverId'));
    await fetchBusDetail(
        storage.read('driverSchoolId'), storage.read('driverBusId'));
    await fetchBusDetail(
        storage.read('driverSchoolId'), storage.read('driverBusId'));

    // Initialize remaining stops
    if (busDetail.value != null) {
      remainingStops.value = List.from(busDetail.value!.stoppings);
    }

    // Set up a port to receive updates from the background isolate
    _setupBackgroundListener();

    // Listen to Realtime Database for trip status changes
    final busId = GetStorage().read('driverBusId');
    final schoolId = GetStorage().read('driverSchoolId');

    // Note: Button state is now LOCAL and controls the database
    // We don't listen to database for button state anymore
    // Database listener removed to prevent conflicts

    if (busId == null || schoolId == null) {
      isTripActive.value = false;
    } else {
      // Check initial state from database once on startup
      try {
        final snapshot = await FirebaseDatabase.instance
            .ref('bus_locations/$schoolId/$busId/isActive')
            .once();

        if (snapshot.snapshot.exists && snapshot.snapshot.value != null) {
          final isActive = snapshot.snapshot.value == true;
          isTripActive.value = isActive;
        } else {
          isTripActive.value = false;
        }
      } catch (e) {
        isTripActive.value = false;
      }
    }

    super.onInit();
  }

  // Helper method to ensure custom claims are set on app start
  Future<void> _ensureUserClaimsAreSet() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get current claims
      final idTokenResult = await user.getIdTokenResult();
      final claims = idTokenResult.claims;

      final String? role = claims?['role'] as String?;
      final String? schoolId = claims?['schoolId'] as String?;

      // If claims are missing, set them
      if (role == null || role.isEmpty || schoolId == null || schoolId.isEmpty) {
        try {
          // Call setUserClaims cloud function
          final callable = FirebaseFunctions.instance.httpsCallable('setUserClaims');
          await callable.call({'uid': user.uid});

          // Force refresh the token
          await user.getIdToken(true);

          // Re-check claims after refresh
          final refreshed = await user.getIdTokenResult(true);
          final refreshedClaims = refreshed.claims;
          final refreshedRole = refreshedClaims?['role'] as String?;
          final refreshedSchoolId = refreshedClaims?['schoolId'] as String?;
          if (refreshedRole == null || refreshedRole.isEmpty || refreshedSchoolId == null || refreshedSchoolId.isEmpty) {
            throw Exception('Claims still missing after refresh');
          }
        } catch (e) {
          // Do not continue: RTDB reads will fail with permission-denied.
          await FirebaseAuth.instance.signOut();
          GetStorage().erase();
          Get.snackbar(
            'Login required',
            'Permissions were not ready. Please log in again.',
            snackPosition: SnackPosition.BOTTOM,
          );
          Get.offAllNamed(Routes.sigIn);
        }
      }
    } catch (e) {
      // Silently fail - don't block app startup
    }
  }

  @override
  void onClose() {
    _tripEndTimer?.cancel();
    _tripEndTimer = null;
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    super.onClose();
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final double dLat = (lat2 - lat1) * (math.pi / 180);
    final double dLon = (lon2 - lon1) * (math.pi / 180);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) *
            math.cos(lat2 * (math.pi / 180)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  void _setupBackgroundListener() {
    final ReceivePort port = ReceivePort();
    if (IsolateNameServer.lookupPortByName(isolateName) != null) {
      IsolateNameServer.removePortNameMapping(isolateName);
    }
    IsolateNameServer.registerPortWithName(port.sendPort, isolateName);

    port.listen((dynamic data) {
      if (data is LocationDto) {
      }
    });
  }

  var school = Rxn<SchoolModel>();
  var driver = Rxn<DriverModel>();
  var busDetail = Rxn<BusModel>();
  var otherBusStudents = <StudentModel>[].obs;
  var isLoading = false.obs;

  // Fetch School by ID
  Future<void> fetchSchool(String? schoolId) async {
    try {
      if (schoolId == null || schoolId.isEmpty) {
        school.value = null;
        return;
      }

      isLoading.value = true;
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(schoolId)
          .get();

      if (doc.exists && doc.data() != null) {
        school.value = SchoolModel.fromMap(doc.data() as Map<String, dynamic>);
      } else {
        school.value = null;
        Get.snackbar("Error", "School not found");
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to fetch school: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Fetch Driver by ID
  Future<void> fetchDriver(String? driverId) async {
    try {
      if (driverId == null || driverId.isEmpty) {
        driver.value = null;
        return;
      }

      final schoolId = GetStorage().read('driverSchoolId');
      if (schoolId == null || schoolId.isEmpty) {
        driver.value = null;
        return;
      }

      isLoading.value = true;
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(schoolId)
          .collection('drivers')
          .doc(driverId)
          .get();

      if (doc.exists && doc.data() != null) {
        driver.value = DriverModel.fromMap(doc);
      } else {
        driver.value = null;
        Get.snackbar("Error", "Driver not found");
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to fetch driver: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Fetch Bus by ID
  Future<void> fetchBusDetail(String? schoolId, String? busId) async {
    try {
      if (schoolId == null ||
          schoolId.isEmpty ||
          busId == null ||
          busId.isEmpty) {
        busDetail.value = null;
        return;
      }

      isLoading.value = true;
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(schoolId)
          .collection('buses')
          .doc(busId)
          .get();

      if (doc.exists && doc.data() != null) {
        busDetail.value = BusModel.fromMap(doc.data() as Map<String, dynamic>);
      } else {
        busDetail.value = null;
        Get.snackbar("Error", "Bus not found");
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to fetch driver: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void fetchStudentsByBusId(String busId) async {
    try {
      final schoolId = GetStorage().read('driverSchoolId') as String?;
      if (schoolId == null || schoolId.isEmpty) {
        otherBusStudents.clear();
        return;
      }

      // Prefer schooldetails, fallback to schools (legacy)
      QuerySnapshot querySnapshot;
      try {
        querySnapshot = await FirebaseFirestore.instance
            .collection('schooldetails')
            .doc(schoolId)
            .collection('students')
            .where('assignedBusId', isEqualTo: busId)
            .get();
      } catch (_) {
        querySnapshot = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('students')
            .where('assignedBusId', isEqualTo: busId)
            .get();
      }

      otherBusStudents.value = querySnapshot.docs
          .map((doc) => StudentModel.fromMap(doc))
          .toList();
    } catch (e) {
    }
  }

// Timer for fallback foreground updates
  Timer? _foregroundTimer;

  // Trip timing helpers
  Timer? _tripEndTimer;

  Future<void> _sendBusStartNotification() async {
    try {
      final url =
          Uri.parse("https://sendbusstartnotification-gnxzq4evda-uc.a.run.app");

      final response = await http.get(url);

      if (response.statusCode == 200) {
      } else {
      }
    } catch (e) {
    }
  }

  Future<void> startTrip({String? forcedScheduleStartTime}) async {
    bool permissionGranted = await _checkAndRequestLocationPermissions();
    if (!permissionGranted) {
      Get.snackbar("Permission Required",
          "Location permissions are needed to track bus location");
      return;
    }

    try {
      if (busDetail.value == null) {
        Get.snackbar("Error", "Bus details not available");
        return;
      }

      isLoading.value = true;

      // **BUTTON CONTROLS STATE** - Update immediately for instant UI feedback
      isTripActive.value = true;
      final storage = GetStorage();
      storage.write(_trackingEnabledKey, true);

      String schoolId = storage.read('driverSchoolId');
      String busId = storage.read('driverBusId');
      String routeType = "pickup"; // <-- define routeType with default
      // Query ALL active route schedules (may have both pickup and drop)
      final routeQuery = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('route_schedules')
          .where('busId', isEqualTo: busId)
          .where('isActive', isEqualTo: true)
          .get(); // Get ALL active schedules

      if (routeQuery.docs.isEmpty) {
        Get.snackbar("Error", "No active route schedule found for this bus");
        isLoading.value = false;
        isTripActive.value = false;
        return;
      }

      // Get current time to match with schedule
      final now = DateTime.now();
      final currentTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        // Auto-switch can fire a few seconds late; allow forcing the schedule-start
        // time so we still select the correct next schedule and keep isWithinTripWindow true.
        final selectionTime = forcedScheduleStartTime ?? currentTime;

      // Find schedule that matches current time window
      DocumentSnapshot<Map<String, dynamic>>? selectedDoc;
      bool foundMatchingSchedule = false;

      if (routeQuery.docs.length > 1) {
        // IMPORTANT: If current time equals a schedule's start time, prefer that schedule.
        for (var doc in routeQuery.docs) {
          final data = doc.data();
          final startTime = data['startTime'] as String? ?? '';
          final endTime = data['endTime'] as String? ?? '23:59';
          final direction = data['direction'] as String? ?? 'unknown';
          if (startTime == selectionTime &&
              _isTimeWithinSchedule(selectionTime, startTime, endTime)) {
            selectedDoc = doc;
            foundMatchingSchedule = true;
            break;
          }
        }

        if (!foundMatchingSchedule) {
          for (var doc in routeQuery.docs) {
            final data = doc.data();
            final startTime = data['startTime'] as String? ?? '';
            final endTime = data['endTime'] as String? ?? '23:59';

            // Check if current time is within this schedule's window
            if (_isTimeWithinSchedule(selectionTime, startTime, endTime)) {
              selectedDoc = doc;
              foundMatchingSchedule = true;
              break;
            }
          }
        }
      } else {
        // Only one schedule - check if current time is within its window
        final data = routeQuery.docs.first.data();
        final startTime = data['startTime'] as String? ?? '';
        final endTime = data['endTime'] as String? ?? '23:59';

        if (_isTimeWithinSchedule(selectionTime, startTime, endTime)) {
          selectedDoc = routeQuery.docs.first;
          foundMatchingSchedule = true;
        }
      }

      // CRITICAL VALIDATION: If no schedule matches current time, prevent trip start
      if (!foundMatchingSchedule || selectedDoc == null) {
        // Show available schedules to driver
        String scheduleInfo = 'Available schedules:\n';
        for (var doc in routeQuery.docs) {
          final data = doc.data();
          final startTime = data['startTime'] as String? ?? '';
          final endTime = data['endTime'] as String? ?? '23:59';
          final routeName = data['routeName'] as String? ?? 'Unknown';
          scheduleInfo += '• $routeName: $startTime - $endTime\n';
        }

        Get.snackbar(
          "No Active Trips",
          "Current time ($currentTime) is outside scheduled trip times.\n\n$scheduleInfo",
          duration: Duration(seconds: 5),
          snackPosition: SnackPosition.BOTTOM,
        );

        isLoading.value = false;
        isTripActive.value = false;
        GetStorage().write(_trackingEnabledKey, false);
        return;
      }

      final routeDoc = selectedDoc;
      final routeId = routeDoc.id;
      final routeData = routeDoc
          .data()!; // Safe to use ! here because we validated selectedDoc is not null above
      final stoppings = routeData['stops'] as List<dynamic>? ??
          routeData['stoppings'] as List<dynamic>? ??
          [];
      final routeName = routeData['routeName'] as String? ?? 'Unknown Route';
      routeType = routeData['direction'] as String? ?? 'pickup';
      // Get schedule times (CRITICAL: Must match Cloud Function's tripId generation)
      final scheduleStartTime = routeData['startTime'] as String? ?? '';
      final scheduleEndTime = routeData['endTime'] as String? ?? '23:59';
      final routeRefId = routeData['routeRefId'] as String?;
      if (routeRefId != null && routeRefId.isNotEmpty) {
      }

      if (stoppings.isEmpty) {
        Get.snackbar("Error", "Route has no stops defined");
        isLoading.value = false;
        isTripActive.value = false;
        return;
      }

      // Convert stops to proper format
      var stops = stoppings.map((stop) {
        final location = stop['location'];
        double lat, lng;

        if (location != null && location is Map) {
          lat = ((location['latitude'] ?? 0.0) as num).toDouble();
          lng = ((location['longitude'] ?? 0.0) as num).toDouble();
        } else {
          lat = ((stop['latitude'] ?? 0.0) as num).toDouble();
          lng = ((stop['longitude'] ?? 0.0) as num).toDouble();
        }

        return {
          'name': stop['name'] ?? 'Unknown Stop',
          'latitude': lat,
          'longitude': lng,
          'estimatedMinutesOfArrival': null,
          'distanceMeters': null,
          'eta': null,
        };
      }).toList();

      // CRITICAL: Reverse stops for drop direction (Firestore stores them in pickup order)
      if (routeType.toLowerCase() == 'drop') {
        stops = stops.reversed.toList();
      }
      // Generate currentTripId using SCHEDULE START TIME (not current time)
      // CRITICAL: Must match Cloud Function's tripId format for student queries to work
      final dateKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final currentTripId =
          '${routeId}_${dateKey}_${scheduleStartTime.replaceAll(':', '')}';
      // Calculate if current time is within schedule window
      final currentTimeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        final windowTime = forcedScheduleStartTime ?? currentTimeStr;
        final isWithinWindow =
          _isTimeWithinSchedule(windowTime, scheduleStartTime, scheduleEndTime);
      if (!isWithinWindow) {
      }

      // Get driver's ACTUAL current location (not first stop location)
      geolocator.Position currentPosition;
      try {
        currentPosition = await geolocator.Geolocator.getCurrentPosition(
          desiredAccuracy: geolocator.LocationAccuracy.high,
        );
      } catch (e) {
        // Fallback to first stop if GPS fails
        currentPosition = geolocator.Position(
          latitude: stops[0]['latitude'],
          longitude: stops[0]['longitude'],
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }

      // Initialize bus status in Realtime Database with ACTUAL driver location
      await FirebaseDatabase.instance
          .ref('bus_locations/$schoolId/$busId')
          .set({
        'isActive': true,
        'activeRouteId': routeId, // Real route ID from route_schedules
        'routeRefId':
            routeRefId, // Optional: route doc id from Route Management (multi-route buses)
        'currentTripId': currentTripId, // CRITICAL: Required for notifications
        'tripDirection': routeType,
        'routeName': routeName,
        'currentStatus': 'Active',
        'latitude':
            currentPosition.latitude, // DRIVER'S ACTUAL CURRENT LOCATION
        'longitude':
            currentPosition.longitude, // DRIVER'S ACTUAL CURRENT LOCATION
        'speed': currentPosition.speed,
        'accuracy': currentPosition.accuracy,
        'heading': currentPosition.heading,
        'source': 'phone',
        'remainingStops':
            stops, // ALL stops including Stop 1 (driver needs to reach it first)
        'stopsPassedCount': 0, // No stops passed yet
        'totalStops': stops.length,
        'lastETACalculation': 0, // Force initial ETA calculation
        'lastRecalculationAt': 0,
        'scheduleStartTime':
            scheduleStartTime, // Use schedule's start time, not current time
        'scheduleEndTime': scheduleEndTime, // Store end time for reference
        'tripStartedAt': now.millisecondsSinceEpoch,
        'isWithinTripWindow':
            isWithinWindow, // Calculate based on schedule times
        'allStudentsNotified':
            false, // CRITICAL: Reset notification flags for new trip
        'noPendingStudents':
            false, // CRITICAL: Reset to allow notification processing
        'timestamp': ServerValue.timestamp,
      });
      // ✅ UX: Consider trip "started" as soon as the RTDB write succeeds.
      // Anything after this (background locator, student reset, etc.) should not block the success message.
      Get.snackbar("Success", "Trip started successfully");

      // Start background location updates IMMEDIATELY (non-blocking)
      _startBackgroundLocator(schoolId, busId, routeType);
      // Start fallback foreground timer for location updates
      _startForegroundFallback(schoolId, busId);

      // Auto-stop at schedule end, and if the next schedule starts exactly at
      // the same time, immediately handoff to the next trip.
      _scheduleTripEndTimer(schoolId, busId, scheduleEndTime);

      // Fire-and-forget: send the "bus start" notification without delaying trip start UX.
      // This is best-effort and should not block the driver.
      _sendBusStartNotification();
    } catch (e, st) {
      isTripActive.value = false;
      GetStorage().write(_trackingEnabledKey, false);
      Get.snackbar("Error", "Failed to start trip: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void _scheduleTripEndTimer(
      String schoolId, String busId, String scheduleEndTime) {
    _tripEndTimer?.cancel();

    final endDateTime = _timeToday(scheduleEndTime);
    if (endDateTime == null) return;

    final now = DateTime.now();
    // Handle overnight schedules safely.
    // If the computed end time for "today" is already in the past (e.g., start=23:00 end=01:00
    // and now=23:30), the real end is on the next day.
    DateTime effectiveEnd = endDateTime;
    if (effectiveEnd.isBefore(now)) {
      effectiveEnd = effectiveEnd.add(const Duration(days: 1));
    }

    final delay = effectiveEnd.difference(now);
    if (delay.isNegative) {
      _tripEndTimer = Timer(const Duration(seconds: 1),
          () => _handleScheduleBoundary(schoolId, busId, scheduleEndTime));
      return;
    }

    _tripEndTimer = Timer(
        delay, () => _handleScheduleBoundary(schoolId, busId, scheduleEndTime));
  }

  DateTime? _timeToday(String hhmm) {
    try {
      final parts = hhmm.split(':');
      if (parts.length != 2) return null;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

    Future<void> _handleScheduleBoundary(
      String schoolId, String busId, String previousScheduleEndTime) async {
    try {
      final storage = GetStorage();
      final trackingEnabled = storage.read(_trackingEnabledKey) == true;
      if (!trackingEnabled || isTripActive.value != true) {
        return;
      }

      final now = DateTime.now();
      final currentTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      // Always stop the current trip at its scheduled end.
      await _stopTrackingServices(updateRealtimeStatus: true);

      // If the next trip starts exactly at the previous end time, start it immediately.
      final routeQuery = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('route_schedules')
          .where('busId', isEqualTo: busId)
          .where('isActive', isEqualTo: true)
          .get();

      DocumentSnapshot<Map<String, dynamic>>? nextSchedule;
      for (final doc in routeQuery.docs) {
        final data = doc.data();
        final startTime = data['startTime'] as String? ?? '';
        final endTime = data['endTime'] as String? ?? '23:59';
        if (startTime == previousScheduleEndTime &&
            _isTimeWithinSchedule(currentTime, startTime, endTime)) {
          nextSchedule = doc;
          break;
        }
      }

      if (nextSchedule != null) {
        Get.snackbar('Trip Update', 'Starting next trip automatically');
        await startTrip(forcedScheduleStartTime: previousScheduleEndTime);
      } else {
      }
    } catch (e) {
    }
  }



// Add this constant to the DriverController class
  static const double STOP_PROXIMITY_THRESHOLD = 200.0; // 200 meters

// Update the _startForegroundFallback method in driver.controller.dart

  void _startForegroundFallback(String schoolId, String busId) {
    // Cancel existing timer if any
    _foregroundTimer?.cancel();

    // Start a new timer for foreground location updates as fallback
    // 30 seconds interval - optimal balance of precision, battery, and cost
    // 30s = 2,880 calls/day per bus (cost-effective while maintaining good responsiveness)
    _foregroundTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        final storage = GetStorage();
        final trackingEnabled = storage.read(_trackingEnabledKey) == true;
        if (!trackingEnabled) {
          _foregroundTimer?.cancel();
          _foregroundTimer = null;
          return;
        }

        // Note: Trip status is now monitored via Realtime DB listener
        // No need to check Firestore here

        // Get current position
        geolocator.Position position =
            await geolocator.Geolocator.getCurrentPosition(
          desiredAccuracy: geolocator.LocationAccuracy.high,
        );
        // Note: Foreground fallback simplified - just write GPS data to Realtime DB
        // All ETA calculations and stop management handled by Cloud Functions
        final schoolIdFromStorage = storage.read('driverSchoolId') ?? schoolId;
        await FirebaseDatabase.instance
            .ref('bus_locations/$schoolIdFromStorage/$busId')
            .update({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'speed': position.speed,
          'timestamp': ServerValue.timestamp,
          'source': 'foreground_fallback',
        });
      } catch (e) {
      }
    });
  }

  Future<void> _startBackgroundLocator(
      String schoolId, String busId, String routeType) async {
    try {
      // For Android: Explicitly request exemption from battery optimization
      if (Platform.isAndroid) {
        try {
          if (await Permission.ignoreBatteryOptimizations.isGranted == false) {
            await Permission.ignoreBatteryOptimizations.request();
          }

          // Also request notification permission for the foreground service
          final notificationStatus = await Permission.notification.request();
        } catch (e) {
        }
      }

      // Check if already running and stop it
      final isRunning = await BackgroundLocator.isServiceRunning();
      if (isRunning) {
        await BackgroundLocator.unRegisterLocationUpdate();
        // Add a small delay to ensure cleanup
        await Future.delayed(const Duration(seconds: 3));
      }

      // Create a map of initialization data
      final Map<String, dynamic> initData = {
        'schoolId': schoolId,
        'busId': busId,
        'busRouteType': routeType, // <-- pass route type
        'timestamp': DateTime.now().millisecondsSinceEpoch
      };
      // Register location update with better settings
      await BackgroundLocator.registerLocationUpdate(
        backgroundLocationCallback,
        initCallback: initBackgroundCallback,
        initDataCallback: initData,
        disposeCallback: disposeBackgroundCallback,
        autoStop: false,
        iosSettings: const IOSSettings(
          accuracy: LocationAccuracy.NAVIGATION,
          // distanceFilter: 10,
          stopWithTerminate: false,
          showsBackgroundLocationIndicator: true,
          // activityType: ActivityType
          //     .AUTOMOTIVE_NAVIGATION, // Specific for vehicle tracking
          // pauseLocationUpdatesAutomatically: false,
          // // These are critical for iOS background operation
          // allowsBackgroundLocationUpdates: true,
        ),
        androidSettings: const AndroidSettings(
          accuracy: LocationAccuracy.NAVIGATION,
          interval:
              3, // 3 seconds - for smooth live tracking (dual-path system controls actual writes)
          // distanceFilter: 10, // 10 meters minimum movement
          client: LocationClient.google,
          androidNotificationSettings: AndroidNotificationSettings(
            notificationTitle: "Bus Location Tracking Active",
            notificationMsg: "Your bus location is being tracked",
            notificationIcon: '@mipmap/ic_launcher',
            notificationIconColor: Color(0xFF000000),
            notificationChannelName: 'Location tracking',
            // notificationImportance: NotificationImportance.HIGH,
            // enableVibration: false,
            // // These settings help maintain the foreground service
            // serviceTitle: "Bus Tracker Running",
            // serviceContent: "Tracking bus location in background",
          ),
          // Critical for maintaining background operation
          wakeLockTime: 180, // 3 hours wake lock
          // startMockProvider: false,
          // forceLocationManager: false,
        ),
      );
      // Verify the service is running
      final checkRunning = await BackgroundLocator.isServiceRunning();
    } catch (e, st) {
      // Rollback button state on error
      isTripActive.value = false;
      rethrow;
    }
  }

  Future<void> stopTrip() async {
    try {
      isLoading.value = true;

      _tripEndTimer?.cancel();
      _tripEndTimer = null;

      final storage = GetStorage();
      final String? schoolId = storage.read('driverSchoolId');
      final String? busId = storage.read('driverBusId');

      // **BUTTON CONTROLS STATE** - Update immediately for instant UI feedback
      isTripActive.value = false;
      if (schoolId != null && busId != null) {
        await FirebaseDatabase.instance
            .ref('bus_locations/$schoolId/$busId')
            .update({
          'isActive': false,
          'isWithinTripWindow': false,
          'currentStatus': 'InActive',
          'tripEndedAt': ServerValue.timestamp,
          'timestamp': ServerValue.timestamp,
        });
      }

      await _stopTrackingServices(updateRealtimeStatus: false);

      if (schoolId != null && busId != null) {
        await fetchBusDetail(schoolId, busId);
      }

      Get.snackbar("Success", "Trip stopped successfully");
    } catch (e, st) {
      // Rollback button state on error
      isTripActive.value = true;
      GetStorage().write(_trackingEnabledKey, true);
      Get.snackbar("Error", "Failed to stop trip: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> handleDriverLogout() async {
    try {
      await _stopTrackingServices(updateRealtimeStatus: true);
    } catch (e) {
    }

    try {
      await _firebaseAuth.signOut();
    } catch (e) {
    }

    await GetStorage().erase();
    Get.offAllNamed(Routes.sigIn);
  }

  Future<void> _stopTrackingServices({bool updateRealtimeStatus = true}) async {
    final storage = GetStorage();
    final String? schoolId = storage.read('driverSchoolId');
    final String? busId = storage.read('driverBusId');

    storage.write(_trackingEnabledKey, false);
    isTripActive.value = false;

    _tripEndTimer?.cancel();
    _tripEndTimer = null;

    if (_foregroundTimer != null) {
      _foregroundTimer?.cancel();
      _foregroundTimer = null;
    }

    try {
      final isRunning = await BackgroundLocator.isServiceRunning();
      if (isRunning) {
        await BackgroundLocator.unRegisterLocationUpdate();
      }
    } catch (e) {
    }

    if (updateRealtimeStatus && schoolId != null && busId != null) {
      try {
        await FirebaseDatabase.instance
            .ref('bus_locations/$schoolId/$busId')
            .update({
          'isActive': false,
          'isWithinTripWindow': false,
          'currentStatus': 'InActive',
          'tripEndedAt': ServerValue.timestamp,
          'timestamp': ServerValue.timestamp,
        });
      } catch (e) {
      }
    }
  }

  Future<void> _showPermissionDialog() async {
    Get.defaultDialog(
      title: 'Location Permission Required',
      middleText:
          'Please enable location permissions in Settings → Privacy → Location Services → BusMate.',
      textConfirm: 'Open Settings',
      textCancel: 'Cancel',
      onConfirm: () {
        openAppSettings(); // from permission_handler
        Get.back();
      },
    );
  }

  Future<bool> _checkAndRequestLocationPermissions() async {
    // 1️⃣ WHEN IN USE
    var whenInUse = await Permission.locationWhenInUse.status;
    if (whenInUse.isDenied) {
      whenInUse = await Permission.locationWhenInUse.request();
    }
    if (whenInUse.isPermanentlyDenied) {
      await _showPermissionDialog();
      return false;
    }

    // 2) Then ask "Always"
    if (whenInUse.isGranted) {
      await Permission.locationAlways.request();
    }

    // 2️⃣ ALWAYS (background)
    var always = await Permission.locationAlways.status;
    if (always.isDenied) {
      always = await Permission.locationAlways.request();
    }
    if (always.isPermanentlyDenied) {
      await _showPermissionDialog();
      return false;
    }
    if (!always.isGranted) return false;

    return true;
  }

  // Add method to remove a stop when reached
  Future<void> removeStop(StopWithETA stop) async {
    try {
      // Note: removeStop method deprecated - stops are now managed
      // automatically in Realtime Database by Cloud Functions
    } catch (e) {
      Get.snackbar("Error", "Failed to update stop: $e");
    }
  }

  /// Check if current time is within schedule window (startTime <= current <= endTime)
  bool _isTimeWithinSchedule(
      String currentTime, String startTime, String endTime) {
    try {
      // Parse times as HH:mm format
      final current = _parseTimeToMinutes(currentTime);
      final start = _parseTimeToMinutes(startTime);
      final end = _parseTimeToMinutes(endTime);

      // Handle overnight schedules (e.g., 23:00 to 01:00)
      if (end < start) {
        // Overnight: current >= start OR current <= end
        return current >= start || current <= end;
      } else {
        // Same day: start <= current <= end
        return current >= start && current <= end;
      }
    } catch (e) {
      return true; // Default to true if parsing fails (allow trip to start)
    }
  }

  /// Convert HH:mm time string to minutes since midnight for easy comparison
  int _parseTimeToMinutes(String time) {
    final parts = time.split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    return hours * 60 + minutes;
  }
}
