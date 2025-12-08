import 'package:busmate/meta/model/student_model.dart';
import 'package:busmate/meta/nav/pages.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class StopNotifyController extends GetxController {
  @override
  void onInit() {
    GetStorage gs = GetStorage();
    final studentId = gs.read('studentId');
    final schoolId = gs.read('studentSchoolId'); // Changed from 'schoolId' to 'studentSchoolId'
    
    if (studentId != null && schoolId != null) {
      fetchStudent(studentId, schoolId);
    } else {
      print('❌ Error: Missing studentId or schoolId in storage');
      print('   studentId: $studentId');
      print('   schoolId: $schoolId');
      Get.snackbar("Error", "Student information not found. Please login again.");
    }
    super.onInit();
  }

  var student = Rxn<StudentModel>();
  var isLoading = false.obs;

  Future<void> fetchStudent(String studentId, String schoolId) async {
    isLoading.value = true;

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

    FirebaseFirestore.instance
        .collection(collectionName)
        .doc(schoolId)
        .collection('students')
        .doc(studentId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        student.value = StudentModel.fromMap(doc);
        print('✅ Student loaded: ${student.value!.name}');
        print('   Student ID: ${student.value!.id}');
        
        // Initialize selectedTime with saved preference (default to 10 if not set)
        final savedTime = doc.data()?['notificationPreferenceByTime'] as int?;
        selectedTime?.value = savedTime ?? 10;
        print('   Notification preference: ${selectedTime?.value} minutes');
      } else {
        student.value = null;
        Get.snackbar("Error", "Student not found");
      }
      isLoading.value = false;
    }, onError: (e) {
      Get.snackbar("Error", "Failed to fetch student: $e");
      isLoading.value = false;
    });
  }

  RxInt? selectedTime = RxInt(-1);
  RxInt? selectedStop = RxInt(-1);

  final List<int> timeOptions = [5, 10, 15, 20, 25, 30];

  RxList<String> stopOptions = RxList<String>([
    "Vellanaipatti",
    "Neelambur",
    "Chinniampalayam",
    "Kulathur",
    "Venkitapuram",
    "A.G Pudur",
    "Irugur Santhai",
    "Irugur Post Office",
    "Irugur Bus Stop",
    "Irugur Pirivu",
    "Jay Santhi",
    "Ondipudur",
    "Singanallur",
    "Ramanathapuram",
    "Olympus"
  ]);

  /// **Select Time-Based Notification**
  void selectTime(int time) {
    selectedTime?.value = time;
    selectedStop?.value = -1; // Reset stop selection
  }

  /// **Select Stop-Based Notification**
  void selectStop(int index) {
    selectedStop?.value = index;
    selectedTime?.value = -1; // Reset time selection
  }

  /// **Confirm Selection**
  void selectConfirmButton() async {
    final studentId = GetStorage().read('studentId');
    final schoolId = GetStorage().read('studentSchoolId');
    
    if (studentId == null || schoolId == null) {
      Get.snackbar("Error", "Student information not found");
      return;
    }
    
    if (selectedTime?.value != -1 && selectedTime?.value != null) {
      // Save to Firebase
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
        
        // Save time preference to Firestore
        await FirebaseFirestore.instance
            .collection(collectionName)
            .doc(schoolId)
            .collection('students')
            .doc(studentId)
            .update({
          'notificationPreferenceByTime': selectedTime!.value,
        });
        
        Get.snackbar("Selected",
            "You will be notified ${selectedTime?.value} minutes before your stop.",
            backgroundColor: Colors.white);
        Get.offAllNamed(Routes.dashBoard);
      } catch (e) {
        Get.snackbar("Error", "Failed to save preference: $e");
      }
    } else if (selectedStop?.value != -1) {
      Get.snackbar("Selected",
          "You will be notified at ${stopOptions[selectedStop!.value]}.",
          backgroundColor: Colors.white);
      Get.offAllNamed(Routes.dashBoard);
    } else {
      Get.snackbar("Error", "Please select a notification time or stop.");
    }
  }
}
