import 'dart:developer';

import 'package:busmate/meta/model/bus_model.dart';
import 'package:busmate/meta/model/student_model.dart';
import 'package:busmate/meta/nav/pages.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class StoplocationController extends GetxController {
  @override
  void onInit() {
    GetStorage gs = GetStorage();
    fetchStudent(gs.read('studentId'));
    fetchBusDetail(gs.read('studentSchoolId'), gs.read('studentBusId'));
    super.onInit();
  }

  var student = Rxn<StudentModel>();
  var busDetail = Rxn<BusModel>();
  var isLoading = false.obs;
  RxInt locationLength = 0.obs;

  Future<void> fetchStudent(String studentId) async {
    isLoading.value = true;

    FirebaseFirestore.instance
        .collection('students')
        .doc(studentId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        student.value = StudentModel.fromMap(doc);
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
        log("Bus No: ${busDetail.value!.busNo}");
        locationLength = busDetail.value!.stoppings.length.obs;
        update();
      } else {
        busDetail.value = null;
        locationLength.value = 0;
        Get.snackbar("Error", "Bus not found");
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
