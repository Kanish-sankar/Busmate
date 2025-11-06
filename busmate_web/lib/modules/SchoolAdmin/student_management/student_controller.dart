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
