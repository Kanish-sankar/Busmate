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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

class DriverController extends GetxController {
  // ignore: constant_identifier_names
  static const double STOP_RADIUS = 100.0; // 100 meters radius
  RxList<dynamic> remainingStops = <dynamic>[].obs;
  RxBool isTripActive = false.obs; // <-- Add this observable

  @override
  void onInit() async {
    GetStorage storage = GetStorage();
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

    // Listen to Firestore for trip status changes
    final busId = GetStorage().read('driverBusId');
    if (busId != null) {
      FirebaseFirestore.instance
          .collection('bus_status')
          .doc(busId)
          .snapshots()
          .listen((doc) {
        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>;
          isTripActive.value = (data['currentStatus'] == 'Active');
        } else {
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
  Future<void> fetchSchool(String schoolId) async {
    try {
      isLoading.value = true;
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .get();

      if (doc.exists && doc.data() != null) {
        school.value = SchoolModel.fromMap(doc.data() as Map<String, dynamic>);
        print(school.value!.schoolName);
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
  Future<void> fetchDriver(String driverId) async {
    try {
      isLoading.value = true;
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();

      if (doc.exists && doc.data() != null) {
        driver.value = DriverModel.fromMap(doc);
        print(driver.value!.id);
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
  Future<void> fetchBusDetail(String schoolId, String busId) async {
    try {
      isLoading.value = true;
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('schools')
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
      print('📝 [StartTrip] Updating bus status to Active...');

      String schoolId = GetStorage().read('driverSchoolId');
      String busId = GetStorage().read('driverBusId');
      String routeType = "pickup"; // <-- define routeType with default

      print('🔑 [StartTrip] Using schoolId: $schoolId, busId: $busId');

      // Initialize remainingStops with all stops when starting trip
      final stoppings = busDetail.value!.stoppings;
      final remainingStopsWithETA = stoppings
          .map((stop) => StopWithETA(
                name: stop.name,
                latitude: stop.latitude,
                longitude: stop.longitude,
              ))
          .toList();

      // Create initial bus status document
      final busStatus = BusStatusModel(
        busId: busId,
        schoolId: schoolId,
        currentLocation: {},
        latitude: 0.0,
        longitude: 0.0,
        currentSpeed: 0.0,
        currentStatus: 'Active',
        remainingStops: remainingStopsWithETA,
        lastUpdated: DateTime.now(),
      );

      // Create or update the bus status document
      await FirebaseFirestore.instance
          .collection('bus_status')
          .doc(busId)
          .set(busStatus.toMap());

      print('✅ [StartTrip] Bus status document created');

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
        // Update the bus status with initial position
        final initialStatus = BusStatusModel(
          busId: busId,
          schoolId: schoolId,
          currentLocation: {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'timestamp': FieldValue.serverTimestamp(),
            'source': 'initial_position'
          },
          latitude: position.latitude,
          longitude: position.longitude,
          currentSpeed: 0.0,
          currentStatus: 'Active',
          remainingStops: remainingStopsWithETA,
          lastUpdated: DateTime.now(),
          busRouteType: routeType, // <-- set route type
        );

        // Calculate initial ETAs
        initialStatus.updateETAs();

        // Update Firestore with initial status
        await FirebaseFirestore.instance
            .collection('bus_status')
            .doc(busId)
            .update(initialStatus.toMap());

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

      // Update bus status to Active in Firestore
      await FirebaseFirestore.instance
          .collection('bus_status')
          .doc(busId)
          .update({'currentStatus': 'Active'});
      // Refresh bus details to reflect the updated status
      await fetchBusDetail(schoolId, busId);

      isTripActive.value = true; // <-- Set immediately
      Get.snackbar("Success", "Trip started successfully");
    } catch (e, st) {
      print('❌ [StartTrip] Error: $e');
      print('📜 [StartTrip] Stack trace: $st');
      isTripActive.value = false; // <-- Reset on error
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
    _foregroundTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      print('⏰ [ForegroundFallback] Triggered');

      try {
        // Check if the trip is still active
        DocumentSnapshot busDoc = await FirebaseFirestore.instance
            .collection('bus_status')
            .doc(busId)
            .get();

        if (busDoc.exists && busDoc.data() != null) {
          Map<String, dynamic> data = busDoc.data() as Map<String, dynamic>;
          if (data['currentStatus'] != 'Active') {
            print(
                '🛑 [ForegroundFallback] Bus no longer active, stopping fallback');
            _foregroundTimer?.cancel();
            _foregroundTimer = null;
            return;
          }
        }

        // Get current position
        geolocator.Position position =
            await geolocator.Geolocator.getCurrentPosition(
          desiredAccuracy: geolocator.LocationAccuracy.high,
        );

        print(
            '📍 [ForegroundFallback] Position: ${position.latitude}, ${position.longitude}');

        // Get current bus status
        DocumentSnapshot statusDoc = await FirebaseFirestore.instance
            .collection('bus_status')
            .doc(busId)
            .get();

        if (statusDoc.exists && statusDoc.data() != null) {
          Map<String, dynamic> data = statusDoc.data() as Map<String, dynamic>;
          BusStatusModel status = BusStatusModel.fromMap(data, busId);

          // Current bus location
          final busLocation = LatLng(position.latitude, position.longitude);

          // Check proximity to remaining stops and remove those within threshold
          // Variables for future implementation:
          // bool stopsRemoved = false;
          // List<StopWithETA> stopsToRemove = [];

          // Only remove stops in the correct order based on route type
          String routeType = status.busRouteType ?? "pickup";
          if (status.remainingStops.isNotEmpty) {
            if (routeType == "pickup") {
              // Remove from the front if reached
              final stop = status.remainingStops.first;
              final stopLocation = LatLng(stop.latitude, stop.longitude);
              final distanceToStop = calculateDistance(
                  busLocation.latitude,
                  busLocation.longitude,
                  stopLocation.latitude,
                  stopLocation.longitude);
              if (distanceToStop <= STOP_PROXIMITY_THRESHOLD) {
                print(
                    '🚏 [ForegroundFallback] Bus reached stop: ${stop.name} (distance: ${distanceToStop.toStringAsFixed(2)}m)');
                status.remainingStops.removeAt(0);
                print(
                    '✂️ [ForegroundFallback] Removed stop: ${stop.name} from remaining stops');
              }
            } else {
              // "drop" route: remove from the end if reached
              final stop = status.remainingStops.last;
              final stopLocation = LatLng(stop.latitude, stop.longitude);
              final distanceToStop = calculateDistance(
                  busLocation.latitude,
                  busLocation.longitude,
                  stopLocation.latitude,
                  stopLocation.longitude);
              if (distanceToStop <= STOP_PROXIMITY_THRESHOLD) {
                print(
                    '🚏 [ForegroundFallback] Bus reached stop: ${stop.name} (distance: ${distanceToStop.toStringAsFixed(2)}m)');
                status.remainingStops.removeLast();
                print(
                    '✂️ [ForegroundFallback] Removed stop: ${stop.name} from remaining stops');
              }
            }
            print(
                '📊 [ForegroundFallback] Remaining stops count: ${status.remainingStops.length}');
          }

          // Update location and speed
          status.latitude = position.latitude;
          status.longitude = position.longitude;
          status.currentSpeed = position.speed;
          status.currentLocation = {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'timestamp': FieldValue.serverTimestamp(),
            'source': 'foreground_fallback'
          };

          // Add speed sample for average calculation
          status.addSpeedSample(position.speed);

          // Update ETAs
          status.updateETAs();

          // Update in Firestore
          await FirebaseFirestore.instance
              .collection('bus_status')
              .doc(busId)
              .update(status.toMap());
        }

        print('✅ [ForegroundFallback] Location and ETAs updated');
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
          interval: 1, // Changed from 2000 to 1000 for more frequent updates
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
      rethrow;
    }
  }

  Future<void> stopTrip() async {
    try {
      print('🛑 [StopTrip] Stopping trip...');

      if (busDetail.value == null) {
        Get.snackbar("Error", "Bus details not available");
        return;
      }

      isLoading.value = true;
      String schoolId = GetStorage().read('driverSchoolId');
      String busId = GetStorage().read('driverBusId');

      // Update bus status document
      await FirebaseFirestore.instance
          .collection('bus_status')
          .doc(busId)
          .update({
        'currentStatus': 'InActive',
        'remainingStops': [], // Clear remaining stops when trip ends
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('✅ [StopTrip] Bus status updated to InActive');

      // Cancel foreground timer if running
      if (_foregroundTimer != null) {
        print('⏱️ [StopTrip] Cancelling foreground timer');
        _foregroundTimer?.cancel();
        _foregroundTimer = null;
      }

      // Unregister background location updates
      print('🛑 [StopTrip] Unregistering background location updates');
      final isRunning = await BackgroundLocator.isServiceRunning();
      if (isRunning) {
        await BackgroundLocator.unRegisterLocationUpdate();
        print('✅ [StopTrip] Background location updates stopped');
      } else {
        print('⚠️ [StopTrip] Background locator was not running');
      }

      // Update bus status to InActive in Firestore
      await FirebaseFirestore.instance
          .collection('bus_status')
          .doc(busId)
          .update({'currentStatus': 'InActive'});
      // Refresh bus details to reflect the updated status
      await fetchBusDetail(schoolId, busId);

      isTripActive.value = false; // <-- Set immediately
      Get.snackbar("Success", "Trip stopped successfully");
    } catch (e, st) {
      print('❌ [StopTrip] Error: $e');
      print('📜 [StopTrip] Stack trace: $st');
      isTripActive.value = true; // <-- Reset on error
      Get.snackbar("Error", "Failed to stop trip: $e");
    } finally {
      isLoading.value = false;
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
      GetStorage().read('driverSchoolId');
      String busId = GetStorage().read('driverBusId');

      // Get current bus status
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('bus_status')
          .doc(busId)
          .get();

      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        BusStatusModel status = BusStatusModel.fromMap(data, busId);

        // Remove the reached stop
        status.remainingStops.removeWhere((s) =>
            s.name == stop.name &&
            s.latitude == stop.latitude &&
            s.longitude == stop.longitude);

        // Update ETAs for remaining stops
        status.updateETAs();

        // Update Firestore with new status
        await FirebaseFirestore.instance
            .collection('bus_status')
            .doc(busId)
            .update(status.toMap());
      }
    } catch (e) {
      print('❌ [RemoveStop] Error: $e');
      Get.snackbar("Error", "Failed to update stop: $e");
    }
  }
}
