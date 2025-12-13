import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:busmate/meta/model/bus_model.dart';
import 'package:busmate/meta/model/driver_model.dart';
import 'package:busmate/meta/model/scool_model.dart';
import 'package:busmate/meta/model/student_model.dart';
import 'package:busmate/presentation/parents_module/dashboard/screens/help_support.dart';
import 'package:busmate/presentation/parents_module/dashboard/screens/home_screen.dart';
import 'package:busmate/presentation/parents_module/dashboard/screens/live_tracking_screen.dart';
import 'package:busmate/presentation/parents_module/dashboard/screens/manage_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  @override
  void onInit() async {
    mapController = MapController();
    super.onInit();

    GetStorage gs = GetStorage();
    String? studentId = gs.read('studentId');
    String? schoolId = gs.read('studentSchoolId');
    String? busId = gs.read('studentBusId');
    String? driverId = gs.read('studentDriverId');
    
    // Store the primary (logged-in) student ID on first init
    if (gs.read('primaryStudentId') == null && studentId != null) {
      gs.write('primaryStudentId', studentId);
      print("DEBUG: Set primary student ID: $studentId");
    }
    
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
        print('🚦 Bus detail loaded: ${bus.busVehicleNo}, Stops: ${bus.stoppings.length}');
        for (var i = 0; i < bus.stoppings.length; i++) {
          print('   Stop ${i + 1}: ${bus.stoppings[i].name} (${bus.stoppings[i].latitude}, ${bus.stoppings[i].longitude})');
        }
        // Only initialize if empty (to avoid resetting during updates)
        if (remainingStops.isEmpty) {
          remainingStops.value = List.from(bus.stoppings);
        }
      }
    });

    // Add a listener to smooth out bus location updates
    ever(busStatus, (status) {
      if (status != null && (status.currentStatus.toLowerCase() == 'moving' || status.currentStatus == 'Active')) {
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
            print('⚠️ Map controller not ready: $e');
          }
        }
      }
    });
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
        print('📦 Loaded cached student: ${student.value?.name}');
      }

      // Load cached school
      final cachedSchool = gs.read('cached_school');
      if (cachedSchool != null) {
        school.value = SchoolModel.fromJson(cachedSchool);
        print('📦 Loaded cached school: ${school.value?.schoolName}');
      }

      // Load cached bus
      final cachedBus = gs.read('cached_bus');
      if (cachedBus != null) {
        busDetail.value = BusModel.fromJson(cachedBus);
        print('📦 Loaded cached bus: ${busDetail.value?.busNo}');
      }

      // Load cached driver
      final cachedDriver = gs.read('cached_driver');
      if (cachedDriver != null) {
        driver.value = DriverModel.fromJson(cachedDriver);
        print('📦 Loaded cached driver: ${driver.value?.name}');
      }

      // Load cached siblings
      final cachedSiblings = gs.read('cached_siblings');
      if (cachedSiblings != null && cachedSiblings is List) {
        siblings.value = (cachedSiblings)
            .map((json) => StudentModel.fromJson(json))
            .toList();
        print('📦 Loaded cached siblings: ${siblings.length} kids');
      }

      // Load cached other bus students
      final cachedOtherStudents = gs.read('cached_other_students');
      if (cachedOtherStudents != null && cachedOtherStudents is List) {
        otherBusStudents.value = (cachedOtherStudents)
            .map((json) => StudentModel.fromJson(json))
            .toList();
        print('📦 Loaded cached other students: ${otherBusStudents.length} students');
      }
    } catch (e) {
      print('⚠️ Error loading cached data: $e');
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
      print('Error: Invalid schoolId or busId for updateRoutePolyline');
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
        
        // Use remainingStops if available, otherwise use all busDetail stops
        final stopsToUse = status.remainingStops.isNotEmpty 
            ? status.remainingStops 
            : busDetail.value?.stoppings ?? [];
        
        for (var stop in stopsToUse) {
          routePoints.add(LatLng(stop.latitude, stop.longitude));
        }

        // If we have less than 2 points, we can't create a route
        if (routePoints.length < 2) {
          routePolyline.value = routePoints;
          print('⚠️ Not enough points for OSRM route: ${routePoints.length}');
          print('   Bus location: (${status.latitude}, ${status.longitude})');
          print('   Stops available: ${stopsToUse.length}');
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

            print('🗺️ Fetching OSRM route (attempt ${attempt + 1}/$_maxRetries)...');
            
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
                print('✅ OSRM route updated: ${polyline.length} points');

                // Note: ETA calculations and DB updates handled by Cloud Functions/Driver app

                break;
              } else {
                print('❌ OSRM returned no routes');
                routePolyline.value = routePoints;
                break;
              }
            } else if (response.statusCode == 429) {
              print('⏳ OSRM rate limit hit, retrying in ${(attempt + 1) * 5}s...');
              await Future.delayed(Duration(seconds: (attempt + 1) * 5));
              continue;
            } else {
              log('OSRM request failed: Status ${response.statusCode}');
              if (attempt == _maxRetries - 1) {
                routePolyline.value = routePoints;
                print('⚠️ Using fallback straight-line polyline');
                // Parents don't write to DB - only local state
              }
            }
          } catch (e) {
            log('OSRM request error: $e');
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
    
    Get.snackbar("Removed", "Student ${siblingToRemove.name} removed successfully!",
        snackPosition: SnackPosition.BOTTOM);
  }

  void fetchStudent(String studentId, String schoolId) async {
    // Don't set loading=true here - cache already loaded
    print("DEBUG: Fetching student - studentId: $studentId, schoolId: $schoolId");
    
    // ALWAYS fetch siblings from the PRIMARY student, not the current active student
    String? primaryStudentId = GetStorage().read('primaryStudentId') ?? studentId;
    print("DEBUG: Primary student ID: $primaryStudentId");
    
    // Determine which collection has the student (try schooldetails first)
    DocumentSnapshot testDoc = await FirebaseFirestore.instance
        .collection('schooldetails')
        .doc(schoolId)
        .collection('students')
        .doc(studentId)
        .get();
    
    String collectionName = 'schooldetails';
    if (!testDoc.exists) {
      print("DEBUG: Student not in schooldetails, trying schools...");
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
    
    print("DEBUG: Using collection: $collectionName");
    
    FirebaseFirestore.instance
        .collection(collectionName)
        .doc(schoolId)
        .collection('students')
        .doc(studentId)
        .snapshots()
        .listen((doc) async {
      if (doc.exists && doc.data() != null) {
        student.value = StudentModel.fromMap(doc);
        print("DEBUG: Student fetched - ${student.value?.name}");
        
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
          if (primaryData['sibling'] != null && primaryData['sibling'] is List) {
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
          GetStorage().write('cached_siblings', siblingList.map((s) => s.toJson()).toList());
          
          print("DEBUG: Siblings fetched from PRIMARY student - ${siblings.length} siblings");
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
        print("ERROR: Student not found in either collection - $schoolId/students/$studentId");
        Get.snackbar("Error", "Student not found");
      }
      isLoading.value = false;
    }, onError: (e) {
      print("ERROR: Failed to fetch student: $e");
      Get.snackbar("Error", "Failed to fetch student: $e");
      isLoading.value = false;
    });
  }

  Future<void> fetchSchool(String schoolId) async {
    try {
      // Don't set loading=true here - cache already loaded
      print("DEBUG: Fetching school - schoolId: $schoolId");
      
      // Try schooldetails first (primary)
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(schoolId)
          .get();
      
      // If not found, try schools collection (legacy fallback)
      if (!doc.exists) {
        print("DEBUG: Not found in schooldetails, trying schools collection...");
        doc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .get();
      }
      
      if (doc.exists && doc.data() != null) {
        school.value = SchoolModel.fromMap(doc.data() as Map<String, dynamic>);
        
        // 🔥 CACHE SCHOOL DATA
        GetStorage().write('cached_school', school.value!.toJson());
        
        print("DEBUG: School fetched - ${school.value?.schoolName}");
      } else {
        school.value = null;
        GetStorage().remove('cached_school');
        print("ERROR: School not found in either schooldetails/$schoolId OR schools/$schoolId");
        Get.snackbar("Error", "School not found");
      }
    } catch (e) {
      print("ERROR: Failed to fetch school: $e");
      Get.snackbar("Error", "Failed to fetch school: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchBusDetail(String schoolId, String busId) async {
    // Don't set loading=true here - cache already loaded
    print("DEBUG: Fetching bus - schoolId: $schoolId, busId: $busId");
    
    // Try schooldetails first
    var busRef = FirebaseFirestore.instance
        .collection('schooldetails')
        .doc(schoolId)
        .collection('buses')
        .doc(busId);
    
    busRef.snapshots().listen((doc) async {
      // If not found in schooldetails, try schools
      if (!doc.exists) {
        print("DEBUG: Bus not in schooldetails, trying schools...");
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
        
        print("DEBUG: Bus fetched - busNo: ${busDetail.value?.busNo}");
      } else {
        busDetail.value = null;
        GetStorage().remove('cached_bus');
        print("ERROR: Bus not found in either collection - $schoolId/buses/$busId");
        Get.snackbar("Error", "Bus not found");
      }
      isLoading.value = false;
    }, onError: (e) {
      print("ERROR: Failed to fetch bus: $e");
      Get.snackbar("Error", "Failed to fetch bus: $e");
      isLoading.value = false;
    });
  }

  Future<void> fetchDriver(String schoolId, String driverId) async {
    try {
      // Don't set loading=true here - cache already loaded
      print("DEBUG: Fetching driver - schoolId: $schoolId, driverId: $driverId");
      
      // Try schooldetails first
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(schoolId)
          .collection('drivers')
          .doc(driverId)
          .get();
      
      // If not found, try schools
      if (!doc.exists) {
        print("DEBUG: Driver not in schooldetails, trying schools...");
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
        
        print("DEBUG: Driver fetched - ${driver.value?.name}");
      } else {
        driver.value = null;
        GetStorage().remove('cached_driver');
        print("ERROR: Driver not found in either collection - $schoolId/drivers/$driverId");
        Get.snackbar("Error", "Driver not found");
      }
    } catch (e) {
      print("ERROR: Failed to fetch driver: $e");
      Get.snackbar("Error", "Failed to fetch driver: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void fetchStudentsByBusId(String schoolId, String busId) async {
    try {
      print("DEBUG: Fetching students by bus - schoolId: $schoolId, busId: $busId");
      
      // Try schooldetails first
      var querySnapshot = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(schoolId)
          .collection('students')
          .where('assignedBusId', isEqualTo: busId)
          .get();
      
      // If empty, try schools
      if (querySnapshot.docs.isEmpty) {
        print("DEBUG: No students in schooldetails, trying schools...");
        querySnapshot = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('students')
            .where('assignedBusId', isEqualTo: busId)
            .get();
      }
      
      otherBusStudents.value =
          querySnapshot.docs.map((doc) => StudentModel.fromMap(doc)).toList();
      
      // 🔥 CACHE OTHER BUS STUDENTS DATA
      GetStorage().write('cached_other_students', 
          otherBusStudents.map((s) => s.toJson()).toList());
      
      print("DEBUG: Fetched ${otherBusStudents.length} students for bus");
    } catch (e) {
      print("ERROR: Error fetching students: $e");
      log("Error fetching students: $e");
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
                subtitle: Text("Class: ${student.studentClass.isNotEmpty ? student.studentClass : 'N/A'}"),
                trailing: isAlreadyAdded 
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: isAlreadyAdded 
                    ? null
                    : () {
                        print("DEBUG: Selected student - ID: ${student.id}, Name: ${student.name}");
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
      String? studentId = GetStorage().read('studentId');
      if (studentId == null) {
        print("DEBUG: No studentId found in GetStorage");
        return false;
      }
      
      // Fetch the student's password from adminusers collection
      DocumentSnapshot adminUserDoc = await FirebaseFirestore.instance
          .collection('adminusers')
          .doc(studentId)
          .get();
      
      
      if (!adminUserDoc.exists) {
        print("DEBUG: Admin user document not found for ID: $studentId");
        return false;
      }
      
      Map<String, dynamic> userData = adminUserDoc.data() as Map<String, dynamic>;
      String storedPassword = userData['password'] as String? ?? '';
      
      if (storedPassword.isEmpty) {
        print("DEBUG: No password stored for user");
        return false;
      }
      
      // Hash the entered password using SHA-256
      String hashedPassword = hashPassword(password);
      
      // Check if stored password is bcrypt (starts with $2a$, $2b$, or $2y$)
      if (storedPassword.startsWith(RegExp(r'\$2[aby]\$'))) {
        print("DEBUG: Verifying bcrypt password");
        // Verify using bcrypt
        try {
          return BCrypt.checkpw(password, storedPassword);
        } catch (e) {
          print("DEBUG: Bcrypt verification error: $e");
          return false;
        }
      } else {
        print("DEBUG: Verifying SHA-256 password");
        // Compare SHA-256 hashes
        return storedPassword == hashedPassword;
      }
    } catch (e) {
      print("DEBUG: Password verification error: $e");
      return false;
    }
  }
  
  // Hash password using SHA-256 (same as AuthLogin)
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  void addSibling(String siblingId) async {
    String? schoolId = GetStorage().read('studentSchoolId');
    String? primaryStudentId = GetStorage().read('primaryStudentId');
    
    if (schoolId == null || primaryStudentId == null) {
      Get.snackbar("Error", "School or student information not found");
      return;
    }
    
    print("DEBUG: Adding sibling - siblingId: $siblingId, primaryStudentId: $primaryStudentId, schoolId: $schoolId");
    
    // Add sibling to PRIMARY student's sibling list, not current active student
    DocumentReference docRef = FirebaseFirestore.instance
        .collection('schooldetails')
        .doc(schoolId)
        .collection('students')
        .doc(primaryStudentId);
    
    DocumentSnapshot doc = await docRef.get();
    if (!doc.exists) {
      print("DEBUG: Primary student not in schooldetails, trying schools...");
      docRef = FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .doc(primaryStudentId);
      doc = await docRef.get();
    }
    
    if (!doc.exists) {
      Get.snackbar("Error", "Primary student document not found");
      print("ERROR: Primary student not found: $primaryStudentId in school: $schoolId");
      return;
    }
    
    await docRef.update({
      'sibling': FieldValue.arrayUnion([siblingId])
    });
    
    print("DEBUG: Sibling ID added to primary student's sibling array");
    
    // Fetch the sibling's data to get their bus ID and subscribe to notifications
    DocumentSnapshot siblingDoc = await FirebaseFirestore.instance
        .collection('schooldetails')
        .doc(schoolId)
        .collection('students')
        .doc(siblingId)
        .get();
    
    if (!siblingDoc.exists) {
      print("DEBUG: Sibling not in schooldetails, trying schools...");
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
      
      print("DEBUG: Sibling found - Name: $siblingName, BusId: $siblingBusId");
      
      // Subscribe to the new sibling's bus notifications (skip on web)
      if (!kIsWeb && siblingBusId != null && siblingBusId.isNotEmpty) {
        final fcm = FirebaseMessaging.instance;
        await fcm.subscribeToTopic('bus_$siblingBusId');
        await fcm.subscribeToTopic('student_$siblingId');
        print("✅ Subscribed to notifications for new sibling: $siblingName");
      }
      
      Get.snackbar("Success", "Student $siblingName added successfully!",
          snackPosition: SnackPosition.BOTTOM);
    } else {
      print("ERROR: Sibling document not found: $siblingId in school: $schoolId");
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
      
      Map<String, dynamic> studentData = studentDoc.data() as Map<String, dynamic>;
      
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
      print("ERROR: Failed to switch student: $e");
      Get.snackbar("Error", "Failed to switch student: $e");
    }
  }
  
  // Subscribe to FCM topics for all kids' buses to receive notifications
  void subscribeToAllKidsBuses() async {
    // Skip FCM topic subscription on web (not supported)
    if (kIsWeb) {
      print("INFO: FCM topic subscription skipped on web platform");
      return;
    }
    
    try {
      final fcm = FirebaseMessaging.instance;
      
      // Get all students (main + siblings)
      List<StudentModel> allKids = [
        if (student.value != null) student.value!,
        ...siblings,
      ];
      
      print("DEBUG: Subscribing to FCM topics for ${allKids.length} kids");
      
      for (var kid in allKids) {
        if (kid.assignedBusId.isNotEmpty) {
          // Subscribe to bus-specific topic for notifications
          String topic = 'bus_${kid.assignedBusId}';
          await fcm.subscribeToTopic(topic);
          print("✅ Subscribed to topic: $topic for kid: ${kid.name}");
          
          // Also subscribe to kid-specific topic
          String kidTopic = 'student_${kid.id}';
          await fcm.subscribeToTopic(kidTopic);
          print("✅ Subscribed to topic: $kidTopic");
        }
      }
    } catch (e) {
      print("ERROR: Failed to subscribe to FCM topics: $e");
    }
  }
  
  // Unsubscribe from a kid's bus when removed
  void unsubscribeFromKidBus(String kidId, String? busId) async {
    // Skip FCM topic unsubscription on web (not supported)
    if (kIsWeb) {
      print("INFO: FCM topic unsubscription skipped on web platform");
      return;
    }
    
    try {
      final fcm = FirebaseMessaging.instance;
      
      if (busId != null && busId.isNotEmpty) {
        String topic = 'bus_$busId';
        await fcm.unsubscribeFromTopic(topic);
        print("✅ Unsubscribed from topic: $topic");
      }
      
      String kidTopic = 'student_$kidId';
      await fcm.unsubscribeFromTopic(kidTopic);
      print("✅ Unsubscribed from topic: $kidTopic");
    } catch (e) {
      print("ERROR: Failed to unsubscribe from FCM topics: $e");
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
    final schoolId = student.value?.schoolId ?? GetStorage().read('studentSchoolId');
    
    if (schoolId == null) {
      print('❌ Error: School ID not found');
      return;
    }
    
    print('📡 [BusStatus] Setting up dual-path listeners:');
    print('   🔵 Live: live_bus_locations/$schoolId/$busId (3s GPS updates for map)');
    print('   🟢 Full: bus_locations/$schoolId/$busId (ETAs, stops, status, route type)');
    
    // PATH 1: Listen to /bus_locations for ALL data (ETAs, stops, status, active/inactive, route type, etc.)
    FirebaseDatabase.instance
        .ref('bus_locations/$schoolId/$busId')
        .onValue
        .listen((event) {
      print('📨 [BusStatus] Received FULL data event - exists: ${event.snapshot.exists}');
      
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        busStatus.value = BusStatusModel.fromMap(data, busId);
        print('✅ [BusStatus] Full status updated: ${busStatus.value?.currentStatus}, isActive: ${busStatus.value?.isActive}, ETAs: ${busStatus.value?.remainingStops.length} stops');
        print('   📊 Route: ${data['routeName'] ?? 'N/A'}, Direction: ${data['tripDirection'] ?? 'N/A'}');
      } else {
        print('⚠️ [BusStatus] No bus location data - driver may not have started trip');
      }
    }, onError: (e) {
      print('❌ [BusStatus] Error fetching full bus data: $e');
    });
    
    // PATH 2: Listen to /live_bus_locations ONLY for smooth GPS updates (map marker position)
    FirebaseDatabase.instance
        .ref('live_bus_locations/$schoolId/$busId')
        .onValue
        .listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null && busStatus.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        // Update ONLY GPS coordinates for smooth 3-second map tracking
        busStatus.value!.latitude = data['latitude'];
        busStatus.value!.longitude = data['longitude'];
        busStatus.value!.currentSpeed = data['speed'] ?? 0.0;
        busStatus.refresh();
        print('🗺️ [BusStatus] Map marker updated (lat: ${data['latitude']}, lng: ${data['longitude']})');
      }
    }, onError: (e) {
      print('❌ [BusStatus] Error fetching live GPS: $e');
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
