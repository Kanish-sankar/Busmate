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
    GetStorage storage = GetStorage();
    if (storage.read(_trackingEnabledKey) == null) {
      storage.write(_trackingEnabledKey, false);
    }
    
    // Debug prints
    print('🔍 [Driver] GetStorage values:');
    print('   driverId: ${storage.read('driverId')}');
    print('   driverSchoolId: ${storage.read('driverSchoolId')}');
    print('   driverBusId: ${storage.read('driverBusId')}');
    
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
      print('❌ [Driver] Cannot proceed - busId or schoolId is null');
      isTripActive.value = false;
    } else {
      // Check initial state from database once on startup
      print('🔍 [Driver] Checking initial trip state from DB: bus_locations/$schoolId/$busId');
      FirebaseDatabase.instance
          .ref('bus_locations/$schoolId/$busId/isActive')
          .once()
          .then((snapshot) {
        if (snapshot.snapshot.exists && snapshot.snapshot.value != null) {
          final isActive = snapshot.snapshot.value == true;
          print('📊 [Driver] Initial DB state - isActive: $isActive');
          isTripActive.value = isActive;
        } else {
          print('⚠️ [Driver] No initial state in DB - defaulting to inactive');
          isTripActive.value = false;
        }
      });
    }

    super.onInit();
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
    print('📡 [Driver] Setting up background listener');

    final ReceivePort port = ReceivePort();
    if (IsolateNameServer.lookupPortByName(isolateName) != null) {
      IsolateNameServer.removePortNameMapping(isolateName);
    }
    IsolateNameServer.registerPortWithName(port.sendPort, isolateName);

    port.listen((dynamic data) {
      print('📥 [Driver] Received from background: $data');

      if (data is LocationDto) {
        print(
            '📍 [Driver] Location from background: ${data.latitude}, ${data.longitude}');
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
      print('🏫 [Driver] Fetching school: $schoolId');
      if (schoolId == null || schoolId.isEmpty) {
        print('❌ [Driver] schoolId is null or empty');
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
        print('✅ [Driver] School loaded: ${school.value!.schoolName}');
      } else {
        school.value = null;
        print('❌ [Driver] School not found in Firestore');
        Get.snackbar("Error", "School not found");
      }
    } catch (e) {
      print('❌ [Driver] Error fetching school: $e');
      Get.snackbar("Error", "Failed to fetch school: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Fetch Driver by ID
  Future<void> fetchDriver(String? driverId) async {
    try {
      print('🚗 [Driver] Fetching driver: $driverId');
      if (driverId == null || driverId.isEmpty) {
        print('❌ [Driver] driverId is null or empty');
        driver.value = null;
        return;
      }
      
      final schoolId = GetStorage().read('driverSchoolId');
      if (schoolId == null || schoolId.isEmpty) {
        print('❌ [Driver] schoolId is null, cannot fetch driver');
        driver.value = null;
        return;
      }
      
      isLoading.value = true;
      print('🔍 [Driver] Fetching from: schooldetails/$schoolId/drivers/$driverId');
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(schoolId)
          .collection('drivers')
          .doc(driverId)
          .get();

      if (doc.exists && doc.data() != null) {
        driver.value = DriverModel.fromMap(doc);
        print('✅ [Driver] Driver loaded: ${driver.value!.id}');
      } else {
        driver.value = null;
        print('❌ [Driver] Driver not found in Firestore');
        Get.snackbar("Error", "Driver not found");
      }
    } catch (e) {
      print('❌ [Driver] Error fetching driver: $e');
      Get.snackbar("Error", "Failed to fetch driver: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Fetch Bus by ID
  Future<void> fetchBusDetail(String? schoolId, String? busId) async {
    try {
      print('🚌 [Driver] Fetching bus: $busId from school: $schoolId');
      if (schoolId == null || schoolId.isEmpty || busId == null || busId.isEmpty) {
        print('❌ [Driver] schoolId or busId is null/empty');
        busDetail.value = null;
        return;
      }
      
      isLoading.value = true;
      print('🔍 [Driver] Fetching from: schooldetails/$schoolId/buses/$busId');
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(schoolId)
          .collection('buses')
          .doc(busId)
          .get();

      if (doc.exists && doc.data() != null) {
        busDetail.value = BusModel.fromMap(doc.data() as Map<String, dynamic>);
        print(GetStorage().read('driverBusId'));
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
      var querySnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('assignedBusId', isEqualTo: busId)
          .get();
      otherBusStudents.value =
          querySnapshot.docs.map((doc) => StudentModel.fromMap(doc)).toList();
    } catch (e) {
      log("Error fetching students: $e");
    }
  }

// Timer for fallback foreground updates
  Timer? _foregroundTimer;

  Future<void> startTrip() async {
    try {
      final url =
          Uri.parse("https://sendbusstartnotification-gnxzq4evda-uc.a.run.app");

      final response = await http.get(url);

      if (response.statusCode == 200) {
        print("✅ [Notification] Sent to all students successfully");
      } else {
        print("❌ [Notification] Failed: ${response.body}");
      }
    } catch (e) {
      print("❌ [Notification] Error sending notification: $e");
    }

    print('🚗 [StartTrip] Starting trip...');

    bool permissionGranted = await _checkAndRequestLocationPermissions();
    if (!permissionGranted) {
      print('⛔ [StartTrip] Permissions not granted, aborting');
      Get.snackbar("Permission Required",
          "Location permissions are needed to track bus location");
      return;
    }

    try {
      if (busDetail.value == null) {
        print('⚠️ [StartTrip] Bus details not available');
        Get.snackbar("Error", "Bus details not available");
        return;
      }

      isLoading.value = true;
      
      // **BUTTON CONTROLS STATE** - Update immediately for instant UI feedback
      isTripActive.value = true;
      print('🔴 [Driver] Button state set to ACTIVE (red) - USER CLICKED START');

      final storage = GetStorage();
      storage.write(_trackingEnabledKey, true);

      String schoolId = storage.read('driverSchoolId');
      String busId = storage.read('driverBusId');
      String routeType = "pickup"; // <-- define routeType with default

      print('🔑 [StartTrip] Using schoolId: $schoolId, busId: $busId');

      // Query ALL active route schedules (may have both pickup and drop)
      print('🔍 [StartTrip] Querying active route schedules...');
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
      final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      print('🕐 [StartTrip] Current time: $currentTime');

      // Find schedule that matches current time window
      DocumentSnapshot<Map<String, dynamic>>? selectedDoc;
      bool foundMatchingSchedule = false;
      
      if (routeQuery.docs.length > 1) {
        print('📋 [StartTrip] Found ${routeQuery.docs.length} active schedules - checking time windows:');
        
        for (var doc in routeQuery.docs) {
          final data = doc.data();
          final startTime = data['startTime'] as String? ?? '';
          final endTime = data['endTime'] as String? ?? '23:59';
          final direction = data['direction'] as String? ?? 'unknown';
          
          print('   - ${data['routeName']}: $direction ($startTime - $endTime)');
          
          // Check if current time is within this schedule's window
          if (_isTimeWithinSchedule(currentTime, startTime, endTime)) {
            selectedDoc = doc;
            foundMatchingSchedule = true;
            print('   ✅ Selected this schedule (matches current time)');
            break;
          }
        }
      } else {
        // Only one schedule - check if current time is within its window
        final data = routeQuery.docs.first.data();
        final startTime = data['startTime'] as String? ?? '';
        final endTime = data['endTime'] as String? ?? '23:59';
        
        if (_isTimeWithinSchedule(currentTime, startTime, endTime)) {
          selectedDoc = routeQuery.docs.first;
          foundMatchingSchedule = true;
          print('   ✅ Current time is within schedule window ($startTime - $endTime)');
        }
      }
      
      // CRITICAL VALIDATION: If no schedule matches current time, prevent trip start
      if (!foundMatchingSchedule || selectedDoc == null) {
        print('❌ [StartTrip] VALIDATION FAILED: No trips scheduled at current time');
        print('⏰ [StartTrip] Current time ($currentTime) is outside all schedule windows');
        
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
      final routeData = routeDoc.data()!; // Safe to use ! here because we validated selectedDoc is not null above
      final stoppings = routeData['stops'] as List<dynamic>? ?? routeData['stoppings'] as List<dynamic>? ?? [];
      final routeName = routeData['routeName'] as String? ?? 'Unknown Route';
      routeType = routeData['direction'] as String? ?? 'pickup';
      
      print('🎯 [StartTrip] Selected schedule: $routeName (${routeType.toUpperCase()})');
      
      // Get schedule times (CRITICAL: Must match Cloud Function's tripId generation)
      final scheduleStartTime = routeData['startTime'] as String? ?? '';
      final scheduleEndTime = routeData['endTime'] as String? ?? '23:59';

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
        print('🔄 [StartTrip] Reversed stops for DROP direction');
      }

      print('✅ [StartTrip] Found route: $routeName ($routeType) with ${stops.length} stops');

      // Generate currentTripId using SCHEDULE START TIME (not current time)
      // CRITICAL: Must match Cloud Function's tripId format for student queries to work
      final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final currentTripId = '${routeId}_${dateKey}_${scheduleStartTime.replaceAll(':', '')}';
      print('🎫 [StartTrip] Generated tripId using schedule time: $currentTripId (schedule: $scheduleStartTime)');

      // Calculate if current time is within schedule window
      final currentTimeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final isWithinWindow = _isTimeWithinSchedule(currentTimeStr, scheduleStartTime, scheduleEndTime);
      print('⏰ [StartTrip] Time check: Current=$currentTimeStr, Start=$scheduleStartTime, End=$scheduleEndTime, Within=$isWithinWindow');
      
      if (!isWithinWindow) {
        print('⚠️ [StartTrip] WARNING: Current time is OUTSIDE schedule window!');
        print('⚠️ [StartTrip] Notifications may not work because Cloud Function checks isWithinTripWindow');
        print('⚠️ [StartTrip] Consider updating schedule times to include current time, or wait until schedule time');
      }

      // Get driver's ACTUAL current location (not first stop location)
      print('📍 [StartTrip] Getting driver\'s current GPS location...');
      geolocator.Position currentPosition;
      try {
        currentPosition = await geolocator.Geolocator.getCurrentPosition(
          desiredAccuracy: geolocator.LocationAccuracy.high,
        );
        print('📍 [StartTrip] Current location: ${currentPosition.latitude}, ${currentPosition.longitude}');
      } catch (e) {
        print('⚠️ [StartTrip] Could not get current position, using first stop as fallback: $e');
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
      print('📝 [StartTrip] Creating bus status in Realtime DB with driver\'s actual location...');
      await FirebaseDatabase.instance
          .ref('bus_locations/$schoolId/$busId')
          .set({
        'isActive': true,
        'activeRouteId': routeId, // Real route ID from route_schedules
        'currentTripId': currentTripId, // CRITICAL: Required for notifications
        'tripDirection': routeType,
        'routeName': routeName,
        'currentStatus': 'Active',
        'latitude': currentPosition.latitude,  // DRIVER'S ACTUAL CURRENT LOCATION
        'longitude': currentPosition.longitude, // DRIVER'S ACTUAL CURRENT LOCATION
        'speed': currentPosition.speed,
        'accuracy': currentPosition.accuracy,
        'heading': currentPosition.heading,
        'source': 'phone',
        'remainingStops': stops, // ALL stops including Stop 1 (driver needs to reach it first)
        'stopsPassedCount': 0,   // No stops passed yet
        'totalStops': stops.length,
        'lastETACalculation': 0, // Force initial ETA calculation
        'lastRecalculationAt': 0,
        'scheduleStartTime': scheduleStartTime, // Use schedule's start time, not current time
        'scheduleEndTime': scheduleEndTime, // Store end time for reference
        'tripStartedAt': now.millisecondsSinceEpoch,
        'isWithinTripWindow': isWithinWindow, // Calculate based on schedule times
        'allStudentsNotified': false, // CRITICAL: Reset notification flags for new trip
        'noPendingStudents': false, // CRITICAL: Reset to allow notification processing
        'timestamp': ServerValue.timestamp,
      });

      print('✅ [StartTrip] Bus status created in Realtime DB with driver\'s actual location');
      print('📍 [StartTrip] Driver location: ${currentPosition.latitude}, ${currentPosition.longitude}');
      print('🎯 [StartTrip] All ${stops.length} stops in remainingStops (driver will reach Stop 1 first)');

      // Start background location updates IMMEDIATELY (non-blocking)
      print('🚀 [StartTrip] Starting background location updates...');
      _startBackgroundLocator(schoolId, busId, routeType);
      print('✅ [StartTrip] Background location updates started');

      // Start fallback foreground timer for location updates
      _startForegroundFallback(schoolId, busId);

      // CRITICAL: Reset students in BACKGROUND (non-blocking) to avoid delay
      // This ensures student.currentTripId matches bus.currentTripId for notification query
      print('👥 [StartTrip] Resetting students in background (non-blocking)...');
      _resetStudentsForTrip(schoolId, busId, currentTripId, routeId).then((_) {
        print('✅ [StartTrip] Student reset completed in background');
      }).catchError((e) {
        print('❌ [StartTrip] Failed to reset students: $e');
        print('⚠️ [StartTrip] NOTIFICATIONS WILL NOT WORK - student tripId won\'t match bus tripId!');
      });

      // Bus status is now tracked in Realtime Database only
      // Refresh bus details to reflect the updated status
      await fetchBusDetail(schoolId, busId);

      // Note: isTripActive will be updated automatically by the Realtime DB listener
      Get.snackbar("Success", "Trip started successfully");
    } catch (e, st) {
      print('❌ [StartTrip] Error: $e');
      print('📜 [StartTrip] Stack trace: $st');
      isTripActive.value = false;
      GetStorage().write(_trackingEnabledKey, false);
      Get.snackbar("Error", "Failed to start trip: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Background method to reset students without blocking trip start
  Future<void> _resetStudentsForTrip(String schoolId, String busId, String currentTripId, String routeId) async {
    try {
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('schooldetails/$schoolId/students')
          .where('assignedBusId', isEqualTo: busId)
          .get();

      if (studentsSnapshot.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in studentsSnapshot.docs) {
          batch.update(doc.reference, {
            'notified': false,
            'currentTripId': currentTripId, // MUST MATCH bus.currentTripId for query to work!
            'tripStartedAt': FieldValue.serverTimestamp(),
            'lastNotifiedRoute': routeId,
            'lastNotifiedAt': null,
          });
        }
        await batch.commit();
        print('✅ Background: Reset ${studentsSnapshot.docs.length} students with matching tripId');
      } else {
        print('⚠️ Background: No students assigned to bus $busId');
      }
    } catch (e) {
      throw Exception('Failed to reset students: $e');
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
      print('⏰ [ForegroundFallback] Triggered (30s interval - cost optimized)');

      try {
        final storage = GetStorage();
        final trackingEnabled = storage.read(_trackingEnabledKey) == true;
        if (!trackingEnabled) {
          print('⏹️ [ForegroundFallback] Tracking disabled flag detected. Stopping timer.');
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

        print(
            '📍 [ForegroundFallback] Position: ${position.latitude}, ${position.longitude}');

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

        print('✅ [ForegroundFallback] GPS data written to Realtime DB');
      } catch (e) {
        print('❌ [ForegroundFallback] Error: $e');
      }
    });
  }

  Future<void> _startBackgroundLocator(
      String schoolId, String busId, String routeType) async {
    try {
      print('🚀 [StartTrip] Starting background locator...');

      // For Android: Explicitly request exemption from battery optimization
      if (Platform.isAndroid) {
        try {
          if (await Permission.ignoreBatteryOptimizations.isGranted == false) {
            print('🔋 [StartTrip] Requesting battery optimization exemption');
            await Permission.ignoreBatteryOptimizations.request();
          }

          // Also request notification permission for the foreground service
          final notificationStatus = await Permission.notification.request();
          print(
              '🔔 [StartTrip] Notification permission status: $notificationStatus');
        } catch (e) {
          print('⚠️ [StartTrip] Permission error: $e');
        }
      }

      // Check if already running and stop it
      final isRunning = await BackgroundLocator.isServiceRunning();
      if (isRunning) {
        print(
            '⚠️ [StartTrip] Background locator already running, stopping it first');
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
      print('📦 [StartTrip] Init data: $initData');

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
          interval: 3, // 3 seconds - for smooth live tracking (dual-path system controls actual writes)
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
      print('✅ [StartTrip] Background locator registered successfully');

      // Verify the service is running
      final checkRunning = await BackgroundLocator.isServiceRunning();
      print('🔍 [StartTrip] Background locator running check: $checkRunning');
    } catch (e, st) {
      print('❌ [StartTrip] Error starting background locator: $e');
      print('📜 [StartTrip] Stack trace: $st');
      
      // Rollback button state on error
      isTripActive.value = false;
      print('⬅️ [Driver] Rolled back button state to INACTIVE (green) due to error');
      
      rethrow;
    }
  }

  Future<void> stopTrip() async {
    try {
      print('🛑 [StopTrip] Stopping trip...');
      isLoading.value = true;

      final storage = GetStorage();
      final String? schoolId = storage.read('driverSchoolId');
      final String? busId = storage.read('driverBusId');

      // **BUTTON CONTROLS STATE** - Update immediately for instant UI feedback
      isTripActive.value = false;
      print('🟢 [Driver] Button state set to INACTIVE (green) - USER CLICKED STOP');

      if (schoolId != null && busId != null) {
        print('📝 [StopTrip] Updating Realtime DB: bus_locations/$schoolId/$busId');
        await FirebaseDatabase.instance
            .ref('bus_locations/$schoolId/$busId')
            .update({
          'isActive': false,
          'isWithinTripWindow': false,
          'currentStatus': 'InActive',
          'tripEndedAt': ServerValue.timestamp,
          'timestamp': ServerValue.timestamp,
        });
        print('✅ [StopTrip] Bus status updated to InActive in Realtime DB');
      }

      await _stopTrackingServices(updateRealtimeStatus: false);

      if (schoolId != null && busId != null) {
        await fetchBusDetail(schoolId, busId);
      }

      Get.snackbar("Success", "Trip stopped successfully");
    } catch (e, st) {
      print('❌ [StopTrip] Error: $e');
      print('📜 [StopTrip] Stack trace: $st');
      
      // Rollback button state on error
      isTripActive.value = true;
      GetStorage().write(_trackingEnabledKey, true);
      print('⬅️ [Driver] Rolled back button state to ACTIVE (red) due to error');
      
      Get.snackbar("Error", "Failed to stop trip: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> handleDriverLogout() async {
    print('🚪 [Driver] Logging out driver...');
    try {
      await _stopTrackingServices(updateRealtimeStatus: true);
    } catch (e) {
      print('⚠️ [Driver] Error while stopping services during logout: $e');
    }

    try {
      await _firebaseAuth.signOut();
      print('✅ [Driver] Firebase signOut complete');
    } catch (e) {
      print('⚠️ [Driver] Firebase signOut failed: $e');
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

    if (_foregroundTimer != null) {
      print('⏱️ [Driver] Cancelling foreground timer (force stop)');
      _foregroundTimer?.cancel();
      _foregroundTimer = null;
    }

    try {
      final isRunning = await BackgroundLocator.isServiceRunning();
      if (isRunning) {
        await BackgroundLocator.unRegisterLocationUpdate();
        print('✅ [Driver] Background location updates stopped (force)');
      }
    } catch (e) {
      print('⚠️ [Driver] Error stopping background locator: $e');
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
        print('📝 [Driver] Realtime DB updated to inactive (force stop)');
      } catch (e) {
        print('⚠️ [Driver] Failed to update Realtime DB while stopping: $e');
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
      print('⚠️ [RemoveStop] Manual stop removal deprecated - handled by backend');
    } catch (e) {
      print('❌ [RemoveStop] Error: $e');
      Get.snackbar("Error", "Failed to update stop: $e");
    }
  }

  /// Check if current time is within schedule window (startTime <= current <= endTime)
  bool _isTimeWithinSchedule(String currentTime, String startTime, String endTime) {
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
      print('⚠️ [TimeCheck] Error parsing schedule times: $e');
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
