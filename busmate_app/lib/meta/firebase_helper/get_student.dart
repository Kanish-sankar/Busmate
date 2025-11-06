import 'dart:developer';

import 'package:busmate/meta/model/student_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class GetStudent extends GetxController {
  RxList<StudentModel> studentList = <StudentModel>[].obs;
  
  @override
  void onInit() {
    super.onInit();
    // REMOVED: Automatic fetching on init to reduce Firebase costs
    // Call fetchStudents() manually only when needed
  }

  Future<void> fetchStudents() async {
    try {
      print('DEBUG: Attempting to fetch students...');
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('students').get();
          
      print('DEBUG: Found ${querySnapshot.docs.length} student documents');

      List<StudentModel> students = querySnapshot.docs.map((doc) => StudentModel.fromMap(doc)).toList();

      studentList.assignAll(students);
      print('DEBUG: Successfully loaded ${students.length} students');
    } catch (e) {
      log("Error fetching students: $e");
      print('DEBUG: Failed to fetch students, continuing with empty list');
      // Don't rethrow the error, just continue with empty list
      studentList.clear();
    }
  }
}


