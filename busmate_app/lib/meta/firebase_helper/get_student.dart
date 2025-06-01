import 'dart:developer';

import 'package:busmate/meta/model/student_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class GetStudent extends GetxController {
  RxList<StudentModel> studentList = <StudentModel>[].obs;
  @override
  void onInit() {
    super.onInit();
    fetchStudents(); // Fetch data when the controller is initialized
  }

  // Fetch all student documents from Firestore
  void fetchStudents() async {
    try {
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('students').get();

      List<StudentModel> students = querySnapshot.docs.map((doc) => StudentModel.fromMap(doc)).toList();

      studentList.assignAll(students);
    } catch (e) {
      log("Error fetching students: $e");
    }
  }
}
