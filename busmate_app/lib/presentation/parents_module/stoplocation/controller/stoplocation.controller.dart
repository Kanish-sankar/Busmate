import 'dart:developer';

import 'package:busmate/meta/model/bus_model.dart';
import 'package:busmate/meta/model/student_model.dart';
import 'package:busmate/meta/nav/pages.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class StoplocationController extends GetxController {
  var student = Rxn<StudentModel>();
  var busDetail = Rxn<BusModel>();
  var isLoading = false.obs;
  RxInt locationLength = 0.obs;

  @override
  void onInit() {
    super.onInit();
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
  }

  Future<void> fetchStudent(String studentId) async {
    isLoading.value = true;
    
    // Get schoolId from storage to build correct path
    GetStorage gs = GetStorage();
    String? schoolId = gs.read('studentSchoolId');
    
    if (schoolId == null) {
      Get.snackbar("Error", "School information not found. Please login again.");
      isLoading.value = false;
      return;
    }
    
    // Determine which collection has the student
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
        print("DEBUG: Student fetched - ${student.value!.name}");
      } else {
        student.value = null;
        Get.snackbar("Error", "Student not found in either collection");
      }
      isLoading.value = false;
    }, onError: (e) {
      Get.snackbar("Error", "Failed to fetch student: $e");
      isLoading.value = false;
    });
  }

  Future<void> fetchBusDetail(String schoolId, String busId) async {
    isLoading.value = true;
    
    // Determine which collection has the bus
    DocumentSnapshot testDoc = await FirebaseFirestore.instance
        .collection('schooldetails')
        .doc(schoolId)
        .collection('buses')
        .doc(busId)
        .get();
    
    String collectionName = 'schooldetails';
    if (!testDoc.exists) {
      print("DEBUG: Bus not in schooldetails, trying schools...");
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
        log("DEBUG: Bus fetched - ${busDetail.value!.busNo}");
        locationLength = busDetail.value!.stoppings.length.obs;
        update();
      } else {
        busDetail.value = null;
        locationLength.value = 0;
        Get.snackbar("Error", "Bus not found in either collection");
      }
      isLoading.value = false;
    }, onError: (e) {
      Get.snackbar("Error", "Failed to fetch bus: $e");
      isLoading.value = false;
    });
  }

  void selectLoctionButton() {
    Get.toNamed(Routes.stopNotify);
  }
}
