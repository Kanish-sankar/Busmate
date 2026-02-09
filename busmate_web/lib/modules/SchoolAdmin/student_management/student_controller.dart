import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'student_model.dart';

class StudentController extends GetxController {
  var students = <Student>[].obs;
  var isLoading = false.obs;
  var searchText = ''.obs;
  var selectedBusFilter = ''.obs;
  var selectedClassFilter = ''.obs;
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  late String schoolId;

  // Use subcollection under schooldetails
  CollectionReference get studentCollection => 
      firestore.collection('schooldetails').doc(schoolId).collection('students');

  @override
  void onInit() {
    super.onInit();
    // Get schoolId from arguments (set by screen constructor)
    final arguments = Get.arguments as Map<String, dynamic>?;
    if (arguments != null && arguments.containsKey('schoolId')) {
      schoolId = arguments['schoolId'];
    }
    // schoolId should be set by the screen before calling onInit
    // If not set, throw an error to catch configuration issues
    if (schoolId.isEmpty) {
      throw Exception('StudentController initialized without schoolId. Please pass schoolId to StudentManagementScreen.');
    }
    fetchStudents();
  }

  void fetchStudents() async {
    print('👨‍🎓 Fetching students for schoolId: $schoolId');
    isLoading.value = true;
    try {
      // ONE-TIME READ instead of real-time listener
      final snapshot = await studentCollection.get();
      print('✅ Received ${snapshot.docs.length} students');
      students.value =
          snapshot.docs.map((doc) => Student.fromDocument(doc)).toList();
      isLoading.value = false;
    } catch (error) {
      print('❌ Error fetching students: $error');
      isLoading.value = false;
      Get.snackbar(
        '❌ Error',
        'Failed to load students: $error',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
    }
  }

  Future<void> addStudent(Student student) async {
    try {
      await studentCollection.doc(student.id).set(student.toMap());
      Get.snackbar('Success', 'Student added successfully');
    } catch (e) {
      print('❌ Error saving student: $e');
      
      // Handle specific Firebase Auth errors with helpful messages
      String errorMessage = 'Failed to add student';
      
      if (e.toString().contains('email-already-in-use')) {
        errorMessage = 'This email is already registered in Firebase Authentication. '
            'Please use a different email or contact support if this is unexpected.';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Invalid email format. Please check the email address.';
      } else if (e.toString().contains('weak-password')) {
        errorMessage = 'Password is too weak. Please use a stronger password.';
      } else {
        errorMessage = 'Failed to add student: ${e.toString()}';
      }
      
      Get.snackbar(
        'Error', 
        errorMessage,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

  Future<void> updateStudent(String id, Student student) async {
    try {
      await studentCollection.doc(id).update(student.toMap());
      Get.snackbar('Success', 'Student updated successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update student: $e');
    }
  }

  Future<void> deleteStudent(String id) async {
    try {
      // First, find the student to get their assigned bus
      DocumentSnapshot studentDoc = await studentCollection.doc(id).get();
      
      if (studentDoc.exists) {
        Map<String, dynamic> studentData = studentDoc.data() as Map<String, dynamic>;
        String? assignedBusId = studentData['assignedBusId'] as String?;
        
        // If student is assigned to a bus, remove them from the bus
        if (assignedBusId != null && assignedBusId.isNotEmpty) {
          DocumentReference busRef = firestore
              .collection('schooldetails')
              .doc(schoolId)
              .collection('buses')
              .doc(assignedBusId);
          
          // Remove student from bus's assignedStudents array
          await busRef.update({
            'assignedStudents': FieldValue.arrayRemove([id]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      
      // Delete from students collection (web)
      await studentCollection.doc(id).delete();
      
      // Also delete from adminusers collection (mobile app)
      try {
        await firestore.collection('adminusers').doc(id).delete();
      } catch (e) {
        print('Student not found in adminusers: $e');
      }
      
      Get.snackbar(
        'Success', 
        'Student deleted and removed from bus',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete student: $e');
    }
  }

  // Get unique class list
  List<String> get uniqueClasses {
    return students
        .map((student) => student.studentClass)
        .where((studentClass) => studentClass.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  // Updated filteredStudents getter to include bus and class filters
  List<Student> get filteredStudents {
    return students.where((student) {
      // Apply text search filter
      bool matchesSearch = searchText.value.isEmpty ||
          student.name.toLowerCase().contains(searchText.value.toLowerCase()) ||
          student.id.contains(searchText.value);

      // Apply bus filter
      bool matchesBus = selectedBusFilter.value.isEmpty ||
          student.assignedBusId == selectedBusFilter.value;

      // Apply class filter
      bool matchesClass = selectedClassFilter.value.isEmpty ||
          student.studentClass == selectedClassFilter.value;

      return matchesSearch && matchesBus && matchesClass;
    }).toList();
  }

  // Reset all filters
  void resetFilters() {
    searchText.value = '';
    selectedBusFilter.value = '';
    selectedClassFilter.value = '';
  }
}
