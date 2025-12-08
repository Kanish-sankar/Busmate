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
import 'package:latlong2/latlong.dart';
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

      // Query active route schedule to get route ID and stops
      print('🔍 [StartTrip] Querying active route schedule...');
      final routeQuery = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('route_schedules')
          .where('busId', isEqualTo: busId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (routeQuery.docs.isEmpty) {
        Get.snackbar("Error", "No active route schedule found for this bus");
        isLoading.value = false;
        isTripActive.value = false;
        return;
      }

      final routeDoc = routeQuery.docs.first;
      final routeId = routeDoc.id;
      final routeData = routeDoc.data();
      final stoppings = routeData['stops'] as List<dynamic>? ?? routeData['stoppings'] as List<dynamic>? ?? [];
      final routeName = routeData['routeName'] as String? ?? 'Unknown Route';
      routeType = routeData['direction'] as String? ?? 'pickup';

      if (stoppings.isEmpty) {
        Get.snackbar("Error", "Route has no stops defined");
        isLoading.value = false;
        isTripActive.value = false;
        return;
      }

      // Convert stops to proper format
      final stops = stoppings.map((stop) {
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

      print('✅ [StartTrip] Found route: $routeName ($routeType) with ${stops.length} stops');

      // Initialize bus status in Realtime Database with isActive: true
      print('📝 [StartTrip] Creating bus status in Realtime DB...');
      await FirebaseDatabase.instance
          .ref('bus_locations/$schoolId/$busId')
          .set({
        'isActive': true,
        'activeRouteId': routeId, // Real route ID from route_schedules
        'tripDirection': routeType,
        'routeName': routeName,
        'currentStatus': 'Active',
        'latitude': stops[0]['latitude'],
        'longitude': stops[0]['longitude'],
        'speed': 0.0,
        'source': 'phone',
        'remainingStops': stops,
        'stopsPassedCount': 0,
        'totalStops': stops.length,
        'lastETACalculation': 0, // Force initial ETA calculation
        'lastRecalculationAt': 0,
        'timestamp': ServerValue.timestamp,
      });

      print('✅ [StartTrip] Bus status created in Realtime DB with route: $routeName');

      // Get initial position and update Firestore
      print('📍 [StartTrip] Getting initial position...');
      try {
        geolocator.Position position =
            await geolocator.Geolocator.getCurrentPosition(
          desiredAccuracy: geolocator.LocationAccuracy.high,
        );

        print(
            '📍 [StartTrip] Initial position received: ${position.latitude}, ${position.longitude}');
        // Determine route type (pickup/drop) based on initial position
        routeType = determineRouteType(
          busDetail.value!.stoppings,
          LatLng(position.latitude, position.longitude),
        );
        print('🛣️ [StartTrip] Route type determined: $routeType');

        // Set 'notified' to false for all students assigned to this bus
        try {
          final studentsQuery = await FirebaseFirestore.instance
              .collection('students')
              .where('assignedBusId', isEqualTo: busId)
              .get();
          for (var doc in studentsQuery.docs) {
            await doc.reference.update({'notified': false});
          }
          print(
              "✅ [StartTrip] Reset 'notified' for all students on bus $busId");
        } catch (e) {
          print("❌ [StartTrip] Failed to reset 'notified' for students: $e");
        }
        // Initial position will be written to Realtime Database only
        // (Firestore writes removed to reduce costs)
        print('✅ [StartTrip] Initial position captured, will be sent to Realtime DB');

        print('✅ [StartTrip] Initial location and ETAs updated in Firestore');
      } catch (e) {
        print('⚠️ [StartTrip] Could not get initial position: $e');
      }

      // Start background location updates
      print('🚀 [StartTrip] Starting background location updates...');
      // Pass routeType to background locator
      await _startBackgroundLocator(schoolId, busId, routeType);
      print('✅ [StartTrip] Background location updates started');

      // Start fallback foreground timer for location updates
      _startForegroundFallback(schoolId, busId);

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

// Add this constant to the DriverController class
  static const double STOP_PROXIMITY_THRESHOLD = 200.0; // 200 meters

// Update the _startForegroundFallback method in driver.controller.dart

  void _startForegroundFallback(String schoolId, String busId) {
    // Cancel existing timer if any
    _foregroundTimer?.cancel();

    // Start a new timer for foreground location updates as fallback
    // Changed from 1 second to 30 seconds to reduce Firebase Function calls
    // 1s = 86,400 calls/day per bus | 30s = 2,880 calls/day per bus (97% reduction)
    _foregroundTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      print('⏰ [ForegroundFallback] Triggered');

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
          interval: 30, // 30 seconds - optimal for battery and cost efficiency
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
          'currentStatus': 'InActive',
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
          'currentStatus': 'InActive',
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
}
