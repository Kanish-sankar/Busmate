import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_model.dart';

class StudentController extends GetxController {
  var students = <Student>[].obs;
  var isLoading = false.obs;
  var searchText = ''.obs;
  var selectedBusFilter = ''.obs;
  var selectedClassFilter = ''.obs;
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  late String schoolId;

  // Update to use root-level students collection
  CollectionReference get studentCollection => firestore.collection('students');

  @override
  void onInit() {
    super.onInit();
    // Get schoolId from arguments
    final arguments = Get.arguments as Map<String, dynamic>?;
    schoolId = arguments?['schoolId'] ?? FirebaseAuth.instance.currentUser!.uid;
    if (schoolId.isEmpty) {
      throw Exception(
          'schoolId must not be empty when initializing StudentController');
    }
    fetchStudents();
  }

  void fetchStudents() {
    isLoading.value = true;
    // Query students collection and filter by schoolId
    studentCollection
        .where('schoolId', isEqualTo: schoolId)
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      students.value =
          snapshot.docs.map((doc) => Student.fromDocument(doc)).toList();
      isLoading.value = false;
    });
  }

  Future<void> addStudent(Student student) async {
    try {
      await studentCollection.doc(student.id).set(student.toMap());
      Get.snackbar('Success', 'Student added successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to add student: $e');
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
      await studentCollection.doc(id).delete();
      Get.snackbar('Success', 'Student deleted successfully');
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
