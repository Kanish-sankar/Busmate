// File: lib/modules/SuperAdmin/school_management/school_management_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class SchoolManagementController extends GetxController {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  var schools = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;
  List<Map<String, dynamic>> allSchools = [];

  @override
  void onInit() {
    super.onInit();
    fetchSchools();
  }

  void fetchSchools() async {
    try {
      isLoading.value = true;
      QuerySnapshot snapshot = await firestore.collection('schools').get();
      allSchools = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['school_id'] = doc.id;
        return data;
      }).toList();
      schools.assignAll(allSchools);
    } catch (e) {
      Get.snackbar("Error", "Failed to fetch schools: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void searchSchools(String query) {
    if (query.isEmpty) {
      schools.assignAll(allSchools);
    } else {
      final filtered = allSchools.where((school) {
        final name = school['school_name']?.toLowerCase() ?? '';
        return name.contains(query.toLowerCase());
      }).toList();
      schools.assignAll(filtered);
    }
  }

  Future<void> deleteSchoolAndAllData(String schoolId) async {
    try {
      isLoading.value = true;
      final firestore = FirebaseFirestore.instance;

      // 1. Delete subcollections under schools/{schoolId}
      final subcollections = [
        'buses',
        'drivers',
        'students',
        'payments',
        'admins'
      ];
      for (final sub in subcollections) {
        final subColRef =
            firestore.collection('schools').doc(schoolId).collection(sub);
        final subDocs = await subColRef.get();
        for (final doc in subDocs.docs) {
          await doc.reference.delete();
        }
      }

      // 2. Delete students in root students collection with schoolId
      final studentsSnap = await firestore
          .collection('students')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      for (final doc in studentsSnap.docs) {
        await doc.reference.delete();
      }

      // 3. Delete drivers in root drivers collection with schoolId
      final driversSnap = await firestore
          .collection('drivers')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      for (final doc in driversSnap.docs) {
        await doc.reference.delete();
      }

      // 4. Delete the school document itself
      await firestore.collection('schools').doc(schoolId).delete();

      // 5. Optionally, remove from local list
      schools.removeWhere((s) => s['school_id'] == schoolId);

      Get.snackbar("Success", "School and all related data deleted.");
      fetchSchools();
    } catch (e) {
      Get.snackbar("Error", "Failed to delete school: $e");
    } finally {
      isLoading.value = false;
    }
  }
}
