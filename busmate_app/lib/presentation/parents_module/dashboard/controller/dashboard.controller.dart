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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

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
    fetchStudent(gs.read('studentId'));
    fetchSchool(gs.read('studentSchoolId'));
    fetchBusDetail(gs.read('studentSchoolId'), gs.read('studentBusId'));
    fetchBusStatus(gs.read('studentBusId'));
    fetchStudentsByBusId(gs.read('studentBusId'));
    fetchDriver(gs.read('studentDriverId'));
    // IMPORTANT:
    // Call the OSRM polyline updater after fetching bus details.
    updateRoutePolyline(gs.read('studentSchoolId'), gs.read('studentBusId'));

    // Initialize remaining stops
    if (busDetail.value != null) {
      remainingStops.value = List.from(busDetail.value!.stoppings);
    }

    // Listen to busDetail changes to update remainingStops
    ever(busDetail, (bus) {
      if (bus != null) {
        // Only initialize if empty (to avoid resetting during updates)
        if (remainingStops.isEmpty) {
          remainingStops.value = List.from(bus.stoppings);
        }
      }
    });

    // Add a listener to smooth out bus location updates
    ever(busStatus, (status) {
      if (status != null && status.currentStatus == 'Active') {
        final now = DateTime.now();
        if (now.difference(lastMapUpdate.value) > mapUpdateThreshold) {
          // Removed automatic map centering
          // mapController.move(
          //   LatLng(status.latitude, status.longitude),
          //   mapController.camera.zoom,
          // );
          lastMapUpdate.value = now;
        }
      }
    });
  }

  @override
  void onClose() {
    mapController.dispose();
    super.onClose();
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
    // Listen for changes in the bus status document
    FirebaseFirestore.instance
        .collection('bus_status')
        .doc(busId)
        .snapshots()
        .listen((doc) async {
      if (doc.exists && doc.data() != null) {
        final status =
            BusStatusModel.fromMap(doc.data() as Map<String, dynamic>, busId);

        // Rate limiting check
        if (_lastRouteFetch != null &&
            DateTime.now().difference(_lastRouteFetch!) < _minFetchInterval) {
          return;
        }
        _lastRouteFetch = DateTime.now();

        // Build route points from current location and remaining stops
        List<LatLng> routePoints = [LatLng(status.latitude, status.longitude)];
        for (var stop in status.remainingStops) {
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

                // Update both local state and Firestore
                routePolyline.value = polyline;

                // Update the polyline in BusStatusModel
                await FirebaseFirestore.instance
                    .collection('bus_status')
                    .doc(busId)
                    .update({
                  'routePolyline': polyline
                      .map((point) => {
                            'latitude': point.latitude,
                            'longitude': point.longitude,
                          })
                      .toList(),
                });

                // Trigger ETA recalculation with new polyline
                status.routePolyline = polyline;
                status.updateETAs();
                await FirebaseFirestore.instance
                    .collection('bus_status')
                    .doc(busId)
                    .update(status.toMap());

                break;
              }
            } else if (response.statusCode == 429) {
              await Future.delayed(Duration(seconds: (attempt + 1) * 5));
              continue;
            } else {
              log('OSRM request failed: Status ${response.statusCode}');
              if (attempt == _maxRetries - 1) {
                routePolyline.value = routePoints;
                // Update fallback polyline in BusStatusModel
                await FirebaseFirestore.instance
                    .collection('bus_status')
                    .doc(busId)
                    .update({
                  'routePolyline': routePoints
                      .map((point) => {
                            'latitude': point.latitude,
                            'longitude': point.longitude,
                          })
                      .toList(),
                });
              }
            }
          } catch (e) {
            log('OSRM request error: $e');
            if (attempt == _maxRetries - 1) {
              routePolyline.value = routePoints;
              // Update fallback polyline in BusStatusModel
              await FirebaseFirestore.instance
                  .collection('bus_status')
                  .doc(busId)
                  .update({
                'routePolyline': routePoints
                    .map((point) => {
                          'latitude': point.latitude,
                          'longitude': point.longitude,
                        })
                    .toList(),
              });
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

  void removeStudent() {
    FirebaseFirestore.instance
        .collection("students")
        .doc(GetStorage().read('studentId'))
        .update({
      'sibling': FieldValue.arrayRemove([siblings[siblings.length - 1].id])
    });
    Get.snackbar("Removed", "Student removed successfully!",
        snackPosition: SnackPosition.BOTTOM);
  }

  void fetchStudent(String studentId) {
    isLoading.value = true;
    FirebaseFirestore.instance
        .collection('students')
        .doc(studentId)
        .snapshots()
        .listen((doc) async {
      if (doc.exists && doc.data() != null) {
        final studentData = doc.data()!;
        student.value = StudentModel.fromMap(doc);
        if (studentData['sibling'] != null && studentData['sibling'] is List) {
          List<String> siblingIds = List<String>.from(studentData['sibling']);
          List<StudentModel> siblingList = [];
          for (String siblingId in siblingIds) {
            DocumentSnapshot siblingDoc = await FirebaseFirestore.instance
                .collection('students')
                .doc(siblingId)
                .get();
            if (siblingDoc.exists && siblingDoc.data() != null) {
              siblingList.add(StudentModel.fromMap(siblingDoc));
            }
          }
          siblings.value = siblingList;
        } else {
          siblings.value = [];
        }
      } else {
        student.value = null;
        siblings.value = [];
        Get.snackbar("Error", "Student not found");
      }
      isLoading.value = false;
    }, onError: (e) {
      Get.snackbar("Error", "Failed to fetch student: $e");
      isLoading.value = false;
    });
  }

  Future<void> fetchSchool(String schoolId) async {
    try {
      isLoading.value = true;
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('schools')
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

  Future<void> fetchBusDetail(String schoolId, String busId) async {
    isLoading.value = true;
    FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection('buses')
        .doc(busId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        busDetail.value = BusModel.fromMap(doc.data() as Map<String, dynamic>);
      } else {
        busDetail.value = null;
        Get.snackbar("Error", "Bus not found");
      }
      isLoading.value = false;
    }, onError: (e) {
      Get.snackbar("Error", "Failed to fetch bus: $e");
      isLoading.value = false;
    });
  }

  Future<void> fetchDriver(String driverId) async {
    try {
      isLoading.value = true;
      DocumentSnapshot doc = await FirebaseFirestore.instance
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
              if (otherBusStudents[index].id ==
                  GetStorage().read('studentId')) {
                return const SizedBox();
              }
              return ListTile(
                title: Text(otherBusStudents[index].name),
                onTap: () {
                  showPasswordDialog(otherBusStudents[index].id);
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
      User? user = FirebaseAuth.instance.currentUser;
      AuthCredential credential =
          EmailAuthProvider.credential(email: user!.email!, password: password);
      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      return false;
    }
  }

  void addSibling(String siblingId) async {
    await FirebaseFirestore.instance
        .collection("students")
        .doc(GetStorage().read('studentId'))
        .update({
      'sibling': FieldValue.arrayUnion([siblingId])
    });
    Get.snackbar("Success", "Student added successfully!",
        snackPosition: SnackPosition.BOTTOM);
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

  // Add method to fetch bus status
  void fetchBusStatus(String busId) {
    FirebaseFirestore.instance
        .collection('bus_status')
        .doc(busId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        busStatus.value =
            BusStatusModel.fromMap(doc.data() as Map<String, dynamic>, busId);

        // Update the map if bus is active
        if (busStatus.value?.currentStatus == 'Active') {
          final lat = busStatus.value?.latitude ?? 0.0;
          final lng = busStatus.value?.longitude ?? 0.0;
          // Removed automatic map centering
          // mapController.move(LatLng(lat, lng), mapController.camera.zoom);
        }
      } else {
        busStatus.value = null;
      }
    }, onError: (e) {
      print('Error fetching bus status: $e');
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
