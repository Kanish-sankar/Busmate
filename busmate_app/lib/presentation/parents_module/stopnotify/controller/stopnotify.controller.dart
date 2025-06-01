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
    fetchStudent(gs.read('studentId'));
    super.onInit();
  }

  var student = Rxn<StudentModel>();
  var isLoading = false.obs;

  Future<void> fetchStudent(String studentId) async {
    isLoading.value = true;

    FirebaseFirestore.instance
        .collection('students')
        .doc(studentId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        student.value = StudentModel.fromMap(doc);
        print(student.value!.name);
        print(student.value!.id);
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
  void selectConfirmButton() {
    if (selectedTime?.value != -1) {
      Get.snackbar("Selected",
          "You will be notified ${selectedTime?.value} minutes before your stop.",
          backgroundColor: Colors.white);
      Get.offAllNamed(Routes.dashBoard);
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
