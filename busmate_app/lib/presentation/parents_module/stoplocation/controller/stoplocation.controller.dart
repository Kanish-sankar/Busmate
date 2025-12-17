import 'dart:developer';

import 'package:busmate/meta/model/bus_model.dart';
import 'package:busmate/meta/model/student_model.dart';
import 'package:busmate/meta/nav/pages.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class StoplocationController extends GetxController {
  var student = Rxn<StudentModel>();
  var busDetail = Rxn<BusModel>();
  var isLoading = false.obs;
  RxInt locationLength = 0.obs;

  /// Stops for the currently relevant trip (prevents showing "first trip" stops after login).
  final RxList<Stoppings> availableStops = <Stoppings>[].obs;

  @override
  void onInit() {
    super.onInit();
    
    // Check if user is authenticated
    if (FirebaseAuth.instance.currentUser == null) {
      isLoading.value = false;
      return;
    }
    
    GetStorage gs = GetStorage();
    String? studentId = gs.read('studentId');
    String? schoolId = gs.read('studentSchoolId');
    String? busId = gs.read('studentBusId');
    if (studentId != null) {
      fetchStudent(studentId);
    }

    if (schoolId != null && busId != null) {
      fetchBusDetail(schoolId, busId);
    }

    // Load trip stops after student data is available
    ever(student, (s) {
      if (s != null && schoolId != null && busId != null) {
        _loadStopsForCurrentTripFromCache(schoolId: schoolId, busId: busId);
      } else {
      }
    });
  }

  Future<void> fetchStudent(String studentId) async {
    // Check authentication
    if (FirebaseAuth.instance.currentUser == null) {
      isLoading.value = false;
      return;
    }

    isLoading.value = true;

    // Get schoolId from storage to build correct path
    GetStorage gs = GetStorage();
    String? schoolId = gs.read('studentSchoolId');

    if (schoolId == null) {
      Get.snackbar(
          "Error", "School information not found. Please login again.");
      isLoading.value = false;
      return;
    }

    try {
      // Determine which collection has the student
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

      // Correct path: schooldetails/{schoolId}/students/{studentId}
      FirebaseFirestore.instance
          .collection(collectionName)
          .doc(schoolId)
          .collection('students')
          .doc(studentId)
          .snapshots()
          .listen((doc) {
        if (doc.exists && doc.data() != null) {
          student.value = StudentModel.fromMap(doc);
        } else {
          student.value = null;
          Get.snackbar("Error", "Student not found in either collection");
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

  Future<void> fetchBusDetail(String schoolId, String busId) async {
    // Check authentication
    if (FirebaseAuth.instance.currentUser == null) {
      isLoading.value = false;
      return;
    }

    isLoading.value = true;

    try {
      // Determine which collection has the bus
      DocumentSnapshot testDoc = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(schoolId)
          .collection('buses')
          .doc(busId)
          .get();

      String collectionName = 'schooldetails';
      if (!testDoc.exists) {
        testDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('buses')
            .doc(busId)
            .get();
        if (testDoc.exists) {
          collectionName = 'schools';
        }
      }

      // Correct path: schooldetails/{schoolId}/buses/{busId}
      FirebaseFirestore.instance
          .collection(collectionName)
          .doc(schoolId)
          .collection('buses')
          .doc(busId)
          .snapshots()
          .listen((doc) {
        if (doc.exists && doc.data() != null) {
          busDetail.value = BusModel.fromMap(doc.data() as Map<String, dynamic>);
          // DO NOT populate availableStops from bus master - let trip-specific load handle it
          update();
        } else {
          busDetail.value = null;
          locationLength.value = 0;
          Get.snackbar("Error", "Bus not found in either collection");
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

  void selectLoctionButton() {
    Get.toNamed(Routes.stopNotify);
  }

  Future<void> _loadStopsForCurrentTripFromCache({
    required String schoolId,
    required String busId,
  }) async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref('route_schedules_cache/$schoolId/$busId')
          .get();

      if (!snap.exists || snap.value == null) {
        return;
      }

      final schedules = Map<String, dynamic>.from(snap.value as Map);
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

      final stopsRaw =
          matchingSchedule['stops'] ?? matchingSchedule['stoppings'];
      if (stopsRaw is! List) {
        return;
      }

      final parsed = stopsRaw
          .where((e) => e != null)
          .map((e) => Stoppings.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (parsed.isEmpty) {
        return;
      }

      availableStops.assignAll(parsed);
      locationLength.value = parsed.length;
      update();
    } catch (e) {
    }
  }

  Map<String, dynamic>? _pickScheduleForNow(Map<String, dynamic> schedules) {
    // Match the app's timezone behavior (IST).
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
        }
      }
    }
    return false;
  }

  String _dayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'monday';
      case DateTime.tuesday:
        return 'tuesday';
      case DateTime.wednesday:
        return 'wednesday';
      case DateTime.thursday:
        return 'thursday';
      case DateTime.friday:
        return 'friday';
      case DateTime.saturday:
        return 'saturday';
      case DateTime.sunday:
        return 'sunday';
      default:
        return '';
    }
  }

  int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  bool _timeWithinWindow(String current, String start, String end) {
    final c = _toMinutes(current);
    final s = _toMinutes(start);
    final e = _toMinutes(end);
    if (s <= e) {
      return c >= s && c <= e;
    }
    // Overnight window (e.g., 22:00 to 01:00)
    return c >= s || c <= e;
  }
}
