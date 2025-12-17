import 'dart:async';
import 'dart:convert';
import 'package:busmate/meta/model/bus_model.dart';
import 'package:busmate/meta/model/driver_model.dart';
import 'package:busmate/meta/model/scool_model.dart';
import 'package:busmate/meta/model/student_model.dart';
import 'package:busmate/presentation/parents_module/dashboard/screens/help_support.dart';
import 'package:busmate/presentation/parents_module/dashboard/screens/home_screen.dart';
import 'package:busmate/presentation/parents_module/dashboard/screens/live_tracking_screen.dart';
import 'package:busmate/presentation/parents_module/dashboard/screens/manage_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:crypto/crypto.dart';
import 'package:bcrypt/bcrypt.dart';

class DashboardController extends GetxController {
  late final MapController mapController;
  var lastMapUpdate = DateTime.now().obs;
  static const mapUpdateThreshold = Duration(milliseconds: 100);

  RxList<dynamic> remainingStops = <dynamic>[].obs;

  // Multi-trip display (current schedule route)
  final RxList<Stoppings> currentTripStopsPickupOrder = <Stoppings>[].obs;
  final RxString currentTripRouteName = ''.obs;
  final RxnString currentTripRouteRefId = RxnString();
  @override
  void onInit() async {
    mapController = MapController();
    super.onInit();

    // 🔒 Check if user is actually logged in first
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Not logged in - don't try to fetch any data
      return;
    }

    GetStorage gs = GetStorage();
    String? studentId = gs.read('studentId');
    String? schoolId = gs.read('studentSchoolId');
    String? busId = gs.read('studentBusId');
    String? driverId = gs.read('studentDriverId');

    // Store the primary (logged-in) student ID on first init
    if (gs.read('primaryStudentId') == null && studentId != null) {
      gs.write('primaryStudentId', studentId);
    }

    // 🔒 Ensure custom claims are set for current user (critical for security rules)
    await _ensureUserClaimsAreSet();

    // 🔥 LOAD CACHED DATA IMMEDIATELY (eliminates N/A flashing)
    _loadCachedData(gs);

    // Then fetch fresh data in background
    if (studentId != null && schoolId != null) {
      fetchStudent(studentId, schoolId);
    }
    if (schoolId != null) {
      fetchSchool(schoolId);
    }
    if (schoolId != null && busId != null) {
      fetchBusDetail(schoolId, busId);
      fetchBusStatus(busId);
      fetchStudentsByBusId(schoolId, busId);

      // IMPORTANT: Call the OSRM polyline updater after fetching bus details
      updateRoutePolyline(schoolId, busId);
    }
    if (schoolId != null && driverId != null) {
      fetchDriver(schoolId, driverId);
    }

    // Initialize remaining stops
    if (busDetail.value != null) {
      remainingStops.value = List.from(busDetail.value!.stoppings);
    }

    // Listen to busDetail changes to update remainingStops
    ever(busDetail, (bus) {
      if (bus != null) {
        for (var i = 0; i < bus.stoppings.length; i++) {
        }
        // Only initialize if empty (to avoid resetting during updates)
        if (remainingStops.isEmpty) {
          remainingStops.value = List.from(bus.stoppings);
        }
      }
    });

    // Add a listener to smooth out bus location updates
    ever(busStatus, (status) {
      if (status != null &&
          (status.currentStatus.toLowerCase() == 'moving' ||
              status.currentStatus == 'Active')) {
        final now = DateTime.now();
        if (now.difference(lastMapUpdate.value) > mapUpdateThreshold) {
          try {
            // Auto-follow the bus (only if map is ready)
            mapController.move(
              LatLng(status.latitude, status.longitude),
              mapController.camera.zoom,
            );
            lastMapUpdate.value = now;
          } catch (e) {
            // Map not ready yet, ignore
          }
        }
      }
    });

    // Keep displayed stops in sync with RTDB + schedule cache (fixes "shows first trip" when bus inactive)
    ever(busStatus, (status) {
      final schoolId =
          student.value?.schoolId ?? GetStorage().read('studentSchoolId');
      final busId =
          student.value?.assignedBusId ?? GetStorage().read('studentBusId');
      if (schoolId is String &&
          schoolId.isNotEmpty &&
          busId is String &&
          busId.isNotEmpty) {
        _refreshCurrentTripFromCache(
            schoolId: schoolId, busId: busId, status: status);
      }
    });

    // Also load trip data initially when student loads (even if bus inactive)
    ever(student, (s) {
      if (s != null && currentTripStopsPickupOrder.isEmpty) {
        final schoolId = s.schoolId ?? GetStorage().read('studentSchoolId');
        final busId = s.assignedBusId ?? GetStorage().read('studentBusId');
        if (schoolId is String &&
            schoolId.isNotEmpty &&
            busId is String &&
            busId.isNotEmpty) {
          _refreshCurrentTripFromCache(
              schoolId: schoolId, busId: busId, status: busStatus.value);
        }
      }
    });
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
        } catch (e) {
          // Silently fail - user can retry by logging out and in
        }
      }
    } catch (e) {
      // Silently fail - don't block app startup
    }
  }

  @override
  void onClose() {
    mapController.dispose();
    super.onClose();
  }

  /// Load cached data immediately to prevent N/A flashing
  void _loadCachedData(GetStorage gs) {
    try {
      // Load cached student
      final cachedStudent = gs.read('cached_student');
      if (cachedStudent != null) {
        student.value = StudentModel.fromJson(cachedStudent);
      }

      // Load cached school
      final cachedSchool = gs.read('cached_school');
      if (cachedSchool != null) {
        school.value = SchoolModel.fromJson(cachedSchool);
      }

      // Load cached bus
      final cachedBus = gs.read('cached_bus');
      if (cachedBus != null) {
        busDetail.value = BusModel.fromJson(cachedBus);
      }

      // Load cached driver
      final cachedDriver = gs.read('cached_driver');
      if (cachedDriver != null) {
        driver.value = DriverModel.fromJson(cachedDriver);
      }

      // Load cached siblings
      final cachedSiblings = gs.read('cached_siblings');
      if (cachedSiblings != null && cachedSiblings is List) {
        siblings.value = (cachedSiblings)
            .map((json) => StudentModel.fromJson(json))
            .toList();
      }

      // Load cached other bus students
      final cachedOtherStudents = gs.read('cached_other_students');
      if (cachedOtherStudents != null && cachedOtherStudents is List) {
        otherBusStudents.value = (cachedOtherStudents)
            .map((json) => StudentModel.fromJson(json))
            .toList();
      }
    } catch (e) {
    }
  }

  var student = Rxn<StudentModel>();
  var school = Rxn<SchoolModel>();
  var busDetail = Rxn<BusModel>();
  var driver = Rxn<DriverModel>();
  var otherBusStudents = <StudentModel>[].obs;
  var siblings = <StudentModel>[].obs;
  var isLoading = false.obs;
  var busStatus = Rxn<BusStatusModel>();

  // Navigation and other UI state management
  var selectedIndex = 0.obs;
  final List<Widget> screens = [
    const HomeScreen(),
    const LiveTrackingScreen(),
    const ManageDetailScreen(),
    const HelpSupportScreen(),
  ];
  List<RxBool> isTrue = [true.obs, false.obs, false.obs, false.obs];

  void changeIndex(int index) {
    selectedIndex.value = index;
  }

  void isButtonPress(int index) {
    for (int i = 0; i < isTrue.length; i++) {
      isTrue[i].value = (i == index);
    }
    update();
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "goodmorning".tr;
    } else if (hour < 18) {
      return "goodafternoon".tr;
    } else {
      return "goodevening".tr;
    }
  }

  /// Check if bus is active FOR THIS STUDENT (trip-aware)
  /// Returns true only if bus is Active AND running the student's assigned trip
  bool get isBusActiveForStudent {
    final status = busStatus.value;
    if (status == null || status.currentStatus != 'Active') {
      return false;
    }

    // Check if bus's current trip matches student's assigned route
    final studentRouteId = student.value?.assignedRouteId;
    final busRouteRefId = status.routeRefId;

    if (studentRouteId == null || studentRouteId.isEmpty) {
      return false;
    }

    // Bus is active for this student only if routeRefId matches
    final isMatch = busRouteRefId == studentRouteId;
    return isMatch;
  }

  // Reactive collections for stops and polyline.
  var stops = <Stoppings>[].obs;
  var isAddingStop = false.obs;
  var routePolyline = <LatLng>[].obs;

  /// Fetch the OSRM polyline route based on current bus location and stops.
  DateTime? _lastRouteFetch;
  static const _minFetchInterval = Duration(seconds: 10); // Rate limiting
  static const _maxRetries = 3;

  /// Update the route polyline and store it in BusStatusModel
  Future<void> updateRoutePolyline(String schoolId, String busId) async {
    if (schoolId.isEmpty || busId.isEmpty) {
      return;
    }

    // Listen for changes in Realtime Database (not Firestore!)
    FirebaseDatabase.instance
        .ref('bus_locations/$schoolId/$busId')
        .onValue
        .listen((event) async {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final status = BusStatusModel.fromMap(data, busId);

        // Rate limiting check
        if (_lastRouteFetch != null &&
            DateTime.now().difference(_lastRouteFetch!) < _minFetchInterval) {
          return;
        }
        _lastRouteFetch = DateTime.now();

        // Build route points from current location and bus stops
        List<LatLng> routePoints = [LatLng(status.latitude, status.longitude)];

        // Get remaining stops from RTDB (stops bus hasn't passed yet)
        final remainingStopsFromRTDB = status.remainingStops;

        // Filter to only include stops from student's assigned trip
        final studentStopNames = currentTripStopsPickupOrder
            .map((s) => s.name.toLowerCase().trim())
            .toSet();

        final stopsToUse = remainingStopsFromRTDB.where((stop) {
          return studentStopNames.contains(stop.name.toLowerCase().trim());
        }).toList();
        for (var stop in stopsToUse) {
          routePoints.add(LatLng(stop.latitude, stop.longitude));
        }

        // If we have less than 2 points, we can't create a route
        if (routePoints.length < 2) {
          routePolyline.value = routePoints;
          return;
        }

        // Build OSRM coordinates
        String coords =
            routePoints.map((pt) => '${pt.longitude},${pt.latitude}').join(';');

        // Retry logic for OSRM
        for (int attempt = 0; attempt < _maxRetries; attempt++) {
          try {
            String url =
                'http://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson&steps=true';
            final response = await http.get(
              Uri.parse(url),
              headers: {'User-Agent': 'BusMate-App/1.0'},
            ).timeout(const Duration(seconds: 10));

            if (response.statusCode == 200) {
              Map<String, dynamic> data = json.decode(response.body);
              if (data['routes'] != null && data['routes'].isNotEmpty) {
                List<dynamic> coordinates =
                    data['routes'][0]['geometry']['coordinates'];
                final polyline = coordinates
                    .map((point) =>
                        LatLng(point[1] as double, point[0] as double))
                    .toList();

                // Update local state only (parents don't write to Realtime DB)
                routePolyline.value = polyline;
                // Note: ETA calculations and DB updates handled by Cloud Functions/Driver app

                break;
              } else {
                routePolyline.value = routePoints;
                break;
              }
            } else if (response.statusCode == 429) {
              await Future.delayed(Duration(seconds: (attempt + 1) * 5));
              continue;
            } else {
              if (attempt == _maxRetries - 1) {
                routePolyline.value = routePoints;
                // Parents don't write to DB - only local state
              }
            }
          } catch (e) {
            if (attempt == _maxRetries - 1) {
              routePolyline.value = routePoints;
              // Parents don't write to DB - only local state
            }
            await Future.delayed(Duration(seconds: attempt + 1));
          }
        }
      }
    });
  }

  void addStudent() {
    showListDialog();
  }

  void removeStudent() async {
    String? schoolId = GetStorage().read('studentSchoolId');
    String? primaryStudentId = GetStorage().read('primaryStudentId');

    if (schoolId == null || primaryStudentId == null) {
      Get.snackbar("Error", "School or student information not found");
      return;
    }

    if (siblings.isEmpty) {
      Get.snackbar("Error", "No siblings to remove");
      return;
    }

    StudentModel siblingToRemove = siblings[siblings.length - 1];
    String siblingId = siblingToRemove.id;
    String? siblingBusId = siblingToRemove.assignedBusId;

    // Unsubscribe from FCM topics for this kid's bus
    unsubscribeFromKidBus(siblingId, siblingBusId);

    // Remove from PRIMARY student's sibling list
    DocumentReference docRef = FirebaseFirestore.instance
        .collection('schooldetails')
        .doc(schoolId)
        .collection('students')
        .doc(primaryStudentId);

    DocumentSnapshot doc = await docRef.get();
    if (!doc.exists) {
      docRef = FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .doc(primaryStudentId);
    }

    await docRef.update({
      'sibling': FieldValue.arrayRemove([siblingId])
    });

    Get.snackbar(
        "Removed", "Student ${siblingToRemove.name} removed successfully!",
        snackPosition: SnackPosition.BOTTOM);
  }

  void fetchStudent(String studentId, String schoolId) async {
    // Check if user is authenticated
    if (FirebaseAuth.instance.currentUser == null) {
      return;
    }

    // Don't set loading=true here - cache already loaded
    // ALWAYS fetch siblings from the PRIMARY student, not the current active student
    String? primaryStudentId =
        GetStorage().read('primaryStudentId') ?? studentId;
    
    try {
      // Determine which collection has the student (try schooldetails first)
      DocumentSnapshot testDoc = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(schoolId)
          .collection('students')
          .doc(studentId)
          .get();

    String collectionName = 'schooldetails';
    if (!testDoc.exists) {
      testDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .doc(studentId)
          .get();
      if (testDoc.exists) {
        collectionName = 'schools';
      }
    }
    FirebaseFirestore.instance
        .collection(collectionName)
        .doc(schoolId)
        .collection('students')
        .doc(studentId)
        .snapshots()
        .listen((doc) async {
      if (doc.exists && doc.data() != null) {
        student.value = StudentModel.fromMap(doc);
        // 🔥 CACHE STUDENT DATA
        GetStorage().write('cached_student', student.value!.toJson());

        // Fetch siblings from PRIMARY student, not current active student
        DocumentSnapshot primaryDoc = await FirebaseFirestore.instance
            .collection(collectionName)
            .doc(schoolId)
            .collection('students')
            .doc(primaryStudentId)
            .get();

        if (primaryDoc.exists) {
          final primaryData = primaryDoc.data() as Map<String, dynamic>;
          if (primaryData['sibling'] != null &&
              primaryData['sibling'] is List) {
            List<String> siblingIds = List<String>.from(primaryData['sibling']);
            List<StudentModel> siblingList = [];
            for (String siblingId in siblingIds) {
              DocumentSnapshot siblingDoc = await FirebaseFirestore.instance
                  .collection(collectionName)
                  .doc(schoolId)
                  .collection('students')
                  .doc(siblingId)
                  .get();
              if (siblingDoc.exists && siblingDoc.data() != null) {
                siblingList.add(StudentModel.fromMap(siblingDoc));
              }
            }
            siblings.value = siblingList;

            // 🔥 CACHE SIBLINGS DATA
            GetStorage().write(
                'cached_siblings', siblingList.map((s) => s.toJson()).toList());
          } else {
            siblings.value = [];
            GetStorage().write('cached_siblings', []);
          }
        } else {
          siblings.value = [];
          GetStorage().write('cached_siblings', []);
        }

        // Subscribe to FCM topics for all kids' buses
        subscribeToAllKidsBuses();
      } else {
        student.value = null;
        siblings.value = [];
        Get.snackbar("Error", "Student not found");
      }
      isLoading.value = false;
    }, onError: (e) {
      // Silently fail if permission denied (user not authenticated with claims)
      isLoading.value = false;
    });
    } catch (e) {
      // Silently fail if permission denied
      isLoading.value = false;
    }
  }

  Future<void> fetchSchool(String schoolId) async {
    try {
      // Don't set loading=true here - cache already loaded
      // Try schooldetails first (primary)
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(schoolId)
          .get();

      // If not found, try schools collection (legacy fallback)
      if (!doc.exists) {
        doc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .get();
      }

      if (doc.exists && doc.data() != null) {
        school.value = SchoolModel.fromMap(doc.data() as Map<String, dynamic>);

        // 🔥 CACHE SCHOOL DATA
        GetStorage().write('cached_school', school.value!.toJson());
      } else {
        school.value = null;
        GetStorage().remove('cached_school');
        Get.snackbar("Error", "School not found");
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to fetch school: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchBusDetail(String schoolId, String busId) async {
    // Check if user is authenticated
    if (FirebaseAuth.instance.currentUser == null) {
      return;
    }

    // Don't set loading=true here - cache already loaded
    try {
      // Try schooldetails first
      var busRef = FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(schoolId)
          .collection('buses')
          .doc(busId);

      busRef.snapshots().listen((doc) async {
      // If not found in schooldetails, try schools
      if (!doc.exists) {
        busRef = FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('buses')
            .doc(busId);
        doc = await busRef.get();
      }

      if (doc.exists && doc.data() != null) {
        busDetail.value = BusModel.fromMap(doc.data() as Map<String, dynamic>);

        // 🔥 CACHE BUS DATA
        GetStorage().write('cached_bus', busDetail.value!.toJson());
      } else {
        busDetail.value = null;
        GetStorage().remove('cached_bus');
        Get.snackbar("Error", "Bus not found");
      }
      isLoading.value = false;
    }, onError: (e) {
      // Silently fail if permission denied
      isLoading.value = false;
    });
    } catch (e) {
      // Silently fail if permission denied
      isLoading.value = false;
    }
  }

  Future<void> fetchDriver(String schoolId, String driverId) async {
    try {
      // Don't set loading=true here - cache already loaded
      // Try schooldetails first
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(schoolId)
          .collection('drivers')
          .doc(driverId)
          .get();

      // If not found, try schools
      if (!doc.exists) {
        doc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('drivers')
            .doc(driverId)
            .get();
      }

      if (doc.exists && doc.data() != null) {
        driver.value = DriverModel.fromMap(doc);

        // 🔥 CACHE DRIVER DATA
        GetStorage().write('cached_driver', driver.value!.toJson());
      } else {
        driver.value = null;
        GetStorage().remove('cached_driver');
        Get.snackbar("Error", "Driver not found");
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to fetch driver: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void fetchStudentsByBusId(String schoolId, String busId) async {
    try {
      // Try schooldetails first
      var querySnapshot = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(schoolId)
          .collection('students')
          .where('assignedBusId', isEqualTo: busId)
          .get();

      // If empty, try schools
      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('students')
            .where('assignedBusId', isEqualTo: busId)
            .get();
      }

      otherBusStudents.value =
          querySnapshot.docs.map((doc) => StudentModel.fromMap(doc)).toList();

      // Multi-route: if we know which route is currently relevant, filter to only that route's students.
      final String? routeRefId =
          busStatus.value?.routeRefId ?? currentTripRouteRefId.value;
      if (routeRefId != null && routeRefId.isNotEmpty) {
        otherBusStudents.value = otherBusStudents
            .where((s) => (s.assignedRouteId ?? '') == routeRefId)
            .toList();
      }

      // 🔥 CACHE OTHER BUS STUDENTS DATA
      GetStorage().write('cached_other_students',
          otherBusStudents.map((s) => s.toJson()).toList());
    } catch (e) {
    }
  }

  // ===== Current trip stops helpers =====

  List<Stoppings> getCurrentTripStopsForDisplay() {
    final direction = busStatus.value?.tripDirection ?? 'pickup';
    final stops = List<Stoppings>.from(currentTripStopsPickupOrder);
    if (direction == 'drop') {
      return stops.reversed.toList();
    }
    return stops;
  }

  Future<void> _refreshCurrentTripFromCache({
    required String schoolId,
    required String busId,
    required BusStatusModel? status,
  }) async {
    try {
      final schedulesSnap = await FirebaseDatabase.instance
          .ref('route_schedules_cache/$schoolId/$busId')
          .get();
      if (!schedulesSnap.exists || schedulesSnap.value == null) {
        return;
      }

      final schedules = Map<String, dynamic>.from(schedulesSnap.value as Map);

      // Get student's assigned route to filter stops
      final studentRouteId = student.value?.assignedRouteId;

      if (studentRouteId == null || studentRouteId.isEmpty) {
        return;
      }
      // Find schedule where routeRefId matches student's assignedRouteId
      Map<String, dynamic>? matchingSchedule;
      for (final entry in schedules.entries) {
        final scheduleData = entry.value;
        if (scheduleData is Map) {
          final schedule = Map<String, dynamic>.from(scheduleData);
          final routeRefId = schedule['routeRefId'] as String?;

          if (routeRefId == studentRouteId) {
            matchingSchedule = schedule;
            break;
          }
        }
      }

      if (matchingSchedule == null) {
        return;
      }

      final routeName = (matchingSchedule['routeName'] ?? '') as String;
      if (routeName.isNotEmpty) currentTripRouteName.value = routeName;

      final scheduleRouteRefId = matchingSchedule['routeRefId'];
      if (scheduleRouteRefId is String && scheduleRouteRefId.isNotEmpty) {
        currentTripRouteRefId.value = scheduleRouteRefId;
      }

      final stopsRaw =
          matchingSchedule['stops'] ?? matchingSchedule['stoppings'];
      if (stopsRaw is List) {
        final parsed = stopsRaw
            .where((e) => e != null)
            .map((e) => Stoppings.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (parsed.isNotEmpty) {
          currentTripStopsPickupOrder.assignAll(parsed);
        }
      }

      // Keep old remainingStops list (used by some UI) in sync for display.
      if (remainingStops.isEmpty && currentTripStopsPickupOrder.isNotEmpty) {
        remainingStops.value =
            List<dynamic>.from(getCurrentTripStopsForDisplay());
      }

      // Refresh student list filtering if already loaded
      final busStudentsSchoolId = student.value?.schoolId ?? schoolId;
      final busStudentsBusId = student.value?.assignedBusId ?? busId;
      if (busStudentsSchoolId.isNotEmpty && busStudentsBusId.isNotEmpty) {
        fetchStudentsByBusId(busStudentsSchoolId, busStudentsBusId);
      }
    } catch (e) {
    }
  }

  Map<String, dynamic>? _pickScheduleForNow(Map<String, dynamic> schedules) {
    final now =
        DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final currentDay = now.weekday; // 1..7
    final currentDayName = _dayName(currentDay);
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (final entry in schedules.entries) {
      final raw = entry.value;
      if (raw is! Map) continue;
      final schedule = Map<String, dynamic>.from(raw);
      if (schedule['isActive'] == false) continue;

      final days = schedule['daysOfWeek'];
      if (!_dayMatches(days, currentDay, currentDayName)) continue;

      final startTime = (schedule['startTime'] ?? '') as String;
      final endTime = (schedule['endTime'] ?? '') as String;
      if (startTime.isEmpty || endTime.isEmpty) continue;

      if (_timeWithinWindow(currentTime, startTime, endTime)) {
        return schedule;
      }
    }
    return null;
  }

  bool _dayMatches(dynamic daysOfWeek, int dayNumber, String dayName) {
    if (daysOfWeek == null) return true;
    if (daysOfWeek is List) {
      for (final d in daysOfWeek) {
        if (d is int && d == dayNumber) return true;
        if (d is String) {
          final v = d.toLowerCase().trim();
          if (v == dayName.toLowerCase()) return true;
          if (v.startsWith(dayName.substring(0, 3).toLowerCase())) return true;
        }
      }
    }
    return false;
  }

  bool _timeWithinWindow(String current, String start, String end) {
    // Times are HH:mm; string comparison works if padded.
    if (start.compareTo(end) > 0) {
      // Overnight
      return current.compareTo(start) >= 0 || current.compareTo(end) <= 0;
    }
    return current.compareTo(start) >= 0 && current.compareTo(end) <= 0;
  }

  String _dayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Monday';
    }
  }

  // Additional methods for siblings and dialogs...
  void showListDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text("Select a Student"),
        content: SizedBox(
          width: double.maxFinite,
          height: 300.h,
          child: ListView.builder(
            itemCount: otherBusStudents.length,
            itemBuilder: (context, index) {
              final student = otherBusStudents[index];
              String? primaryStudentId = GetStorage().read('primaryStudentId');

              // Don't show the primary student or already added siblings
              if (student.id == primaryStudentId) {
                return const SizedBox();
              }

              // Check if already added as sibling
              bool isAlreadyAdded = siblings.any((s) => s.id == student.id);

              return ListTile(
                title: Text(student.name),
                subtitle: Text(
                    "Class: ${student.studentClass.isNotEmpty ? student.studentClass : 'N/A'}"),
                trailing: isAlreadyAdded
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: isAlreadyAdded
                    ? null
                    : () {
                        showPasswordDialog(student.id);
                      },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Close"),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  void showPasswordDialog(String selectedStudentId) {
    TextEditingController passwordController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text("Confirm Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: "Enter your password"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              String password = passwordController.text.trim();
              if (password.isEmpty) {
                Get.snackbar("Error", "Password cannot be empty",
                    snackPosition: SnackPosition.BOTTOM);
                return;
              }
              bool isVerified = await verifyPassword(password);
              if (isVerified) {
                Get.back(); // Close password dialog
                Get.back();
                addSibling(selectedStudentId);
              } else {
                Get.snackbar("Error", "Incorrect password",
                    snackPosition: SnackPosition.BOTTOM);
              }
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<bool> verifyPassword(String password) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return false;
      }

      // Get user email from adminusers collection
      String? studentId = GetStorage().read('studentId');
      if (studentId == null) {
        return false;
      }

      DocumentSnapshot adminUserDoc = await FirebaseFirestore.instance
          .collection('adminusers')
          .doc(studentId)
          .get();

      if (!adminUserDoc.exists) {
        return false;
      }

      Map<String, dynamic> userData =
          adminUserDoc.data() as Map<String, dynamic>;
      String email = userData['email'] as String? ?? '';

      if (email.isEmpty) {
        return false;
      }

      // Re-authenticate with Firebase Auth
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await currentUser.reauthenticateWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      return false;
    } catch (e) {
      return false;
    }
  }

  void addSibling(String siblingId) async {
    String? schoolId = GetStorage().read('studentSchoolId');
    String? primaryStudentId = GetStorage().read('primaryStudentId');

    if (schoolId == null || primaryStudentId == null) {
      Get.snackbar("Error", "School or student information not found");
      return;
    }
    // Add sibling to PRIMARY student's sibling list, not current active student
    DocumentReference docRef = FirebaseFirestore.instance
        .collection('schooldetails')
        .doc(schoolId)
        .collection('students')
        .doc(primaryStudentId);

    DocumentSnapshot doc = await docRef.get();
    if (!doc.exists) {
      docRef = FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .doc(primaryStudentId);
      doc = await docRef.get();
    }

    if (!doc.exists) {
      Get.snackbar("Error", "Primary student document not found");
      return;
    }

    await docRef.update({
      'sibling': FieldValue.arrayUnion([siblingId])
    });
    // Fetch the sibling's data to get their bus ID and subscribe to notifications
    DocumentSnapshot siblingDoc = await FirebaseFirestore.instance
        .collection('schooldetails')
        .doc(schoolId)
        .collection('students')
        .doc(siblingId)
        .get();

    if (!siblingDoc.exists) {
      siblingDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .doc(siblingId)
          .get();
    }

    if (siblingDoc.exists) {
      final siblingData = siblingDoc.data() as Map<String, dynamic>;
      final siblingBusId = siblingData['assignedBusId'] as String?;
      final siblingName = siblingData['name'] as String? ?? 'Unknown';
      // Subscribe to the new sibling's bus notifications (skip on web)
      if (!kIsWeb && siblingBusId != null && siblingBusId.isNotEmpty) {
        final fcm = FirebaseMessaging.instance;
        await fcm.subscribeToTopic('bus_$siblingBusId');
        await fcm.subscribeToTopic('student_$siblingId');
      }

      Get.snackbar("Success", "Student $siblingName added successfully!",
          snackPosition: SnackPosition.BOTTOM);
    } else {
      Get.snackbar("Error", "Selected student not found in your school",
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  void switchActiveStudent(String newStudentId) async {
    String? schoolId = GetStorage().read('studentSchoolId');
    if (schoolId == null) {
      Get.snackbar("Error", "School information not found");
      return;
    }

    try {
      // Determine collection
      DocumentSnapshot studentDoc = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(schoolId)
          .collection('students')
          .doc(newStudentId)
          .get();

      if (!studentDoc.exists) {
        studentDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('students')
            .doc(newStudentId)
            .get();
      }

      if (!studentDoc.exists) {
        Get.snackbar("Error", "Student not found");
        return;
      }

      Map<String, dynamic> studentData =
          studentDoc.data() as Map<String, dynamic>;

      // Update GetStorage with new active student
      GetStorage().write('studentId', newStudentId);
      GetStorage().write('studentBusId', studentData['assignedBusId']);
      GetStorage().write('studentDriverId', studentData['assignedDriverId']);

      // Reload all data for the new active student
      fetchStudent(newStudentId, schoolId);
      if (studentData['assignedBusId'] != null) {
        fetchBusDetail(schoolId, studentData['assignedBusId']);
        fetchBusStatus(studentData['assignedBusId']);
        fetchStudentsByBusId(schoolId, studentData['assignedBusId']);
        updateRoutePolyline(schoolId, studentData['assignedBusId']);
      }
      if (studentData['assignedDriverId'] != null) {
        fetchDriver(schoolId, studentData['assignedDriverId']);
      }

      Get.snackbar("Switched", "Now viewing ${studentData['name']}'s details",
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar("Error", "Failed to switch student: $e");
    }
  }

  // Subscribe to FCM topics for all kids' buses to receive notifications
  void subscribeToAllKidsBuses() async {
    // Skip FCM topic subscription on web (not supported)
    if (kIsWeb) {
      return;
    }

    try {
      final fcm = FirebaseMessaging.instance;

      // Get all students (main + siblings)
      List<StudentModel> allKids = [
        if (student.value != null) student.value!,
        ...siblings,
      ];
      for (var kid in allKids) {
        if (kid.assignedBusId.isNotEmpty) {
          // Subscribe to bus-specific topic for notifications
          String topic = 'bus_${kid.assignedBusId}';
          await fcm.subscribeToTopic(topic);
          // Also subscribe to kid-specific topic
          String kidTopic = 'student_${kid.id}';
          await fcm.subscribeToTopic(kidTopic);
        }
      }
    } catch (e) {
    }
  }

  // Unsubscribe from a kid's bus when removed
  void unsubscribeFromKidBus(String kidId, String? busId) async {
    // Skip FCM topic unsubscription on web (not supported)
    if (kIsWeb) {
      return;
    }

    try {
      final fcm = FirebaseMessaging.instance;

      if (busId != null && busId.isNotEmpty) {
        String topic = 'bus_$busId';
        await fcm.unsubscribeFromTopic(topic);
      }

      String kidTopic = 'student_$kidId';
      await fcm.unsubscribeFromTopic(kidTopic);
    } catch (e) {
    }
  }

  // Add method to remove a stop when reached
  void removeStop(dynamic stop) {
    remainingStops.remove(stop);
    update();
  }

  // Add method to reset stops
  void resetStops() {
    if (busDetail.value != null) {
      remainingStops.value = List.from(busDetail.value!.stoppings);
      update();
    }
  }

  // Add method to fetch bus status from Realtime Database
  void fetchBusStatus(String busId) {
    // Get schoolId from student (not activeStudent which doesn't exist)
    final schoolId =
        student.value?.schoolId ?? GetStorage().read('studentSchoolId');

    if (schoolId == null) {
      return;
    }

    // Check if user is authenticated
    if (FirebaseAuth.instance.currentUser == null) {
      return;
    }

    // PATH 1: Listen to /bus_locations for ALL data (ETAs, stops, status, active/inactive, route type, etc.)
    FirebaseDatabase.instance
        .ref('bus_locations/$schoolId/$busId')
        .onValue
        .listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        busStatus.value = BusStatusModel.fromMap(data, busId);
      } else {
      }
    }, onError: (e) {
      // Permission denied or other error - silently fail
    });

    // PATH 2: Listen to /live_bus_locations ONLY for smooth GPS updates (map marker position)
    FirebaseDatabase.instance
        .ref('live_bus_locations/$schoolId/$busId')
        .onValue
        .listen((event) {
      if (event.snapshot.exists &&
          event.snapshot.value != null &&
          busStatus.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        // Update ONLY GPS coordinates for smooth 3-second map tracking
        busStatus.value!.latitude = data['latitude'];
        busStatus.value!.longitude = data['longitude'];
        busStatus.value!.currentSpeed = data['speed'] ?? 0.0;
        busStatus.refresh();
      }
    }, onError: (e) {
      // Permission denied or other error - silently fail
    });
  }

  /// Fallback: Build a polyline using bus location and stops.
  List<LatLng> _buildPolylinePoints() {
    final status = busStatus.value;
    List<LatLng> points = [];
    if (status != null) {
      // Start with the bus's current location.
      points.add(LatLng(status.latitude, status.longitude));
      // Then add remaining stops in order.
      for (var stop in status.remainingStops) {
        points.add(LatLng(stop.latitude, stop.longitude));
      }
    }
    return points;
  }

  // Add this method to update polyline with debouncing
  Timer? _polylineUpdateTimer;
  void updateMapPolyline() {
    if (_polylineUpdateTimer?.isActive ?? false) return;

    _polylineUpdateTimer = Timer(const Duration(milliseconds: 500), () {
      if (busStatus.value != null) {
        final points = _buildPolylinePoints();
        if (!listEquals(routePolyline, points)) {
          routePolyline.value = points;
        }
      }
    });
  }

  // Add this method to recenter the map on the bus position
  void recenterMapOnBus() {
    final status = busStatus.value;
    if (status != null && status.currentStatus == 'Active') {
      mapController.move(
        LatLng(status.latitude, status.longitude),
        mapController.camera.zoom,
      );
    }
  }
}
