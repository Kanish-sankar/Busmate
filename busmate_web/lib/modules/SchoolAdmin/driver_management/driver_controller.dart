// driver_controller.dart
import 'package:busmate_web/modules/Authentication/auth_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'driver_model.dart';

class DriverController extends GetxController {
  var drivers = <Driver>[].obs;
  var isLoading = false.obs;
  var searchText = ''.obs;
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  late String schoolId;

  // Use root-level drivers collection
  CollectionReference get driverCollection => firestore.collection('drivers');

  @override
  void onInit() {
    super.onInit();
    // Get schoolId from arguments
    final arguments = Get.arguments as Map<String, dynamic>?;
    schoolId = arguments?['schoolId'] ?? FirebaseAuth.instance.currentUser!.uid;
    fetchDrivers();
  }

  void fetchDrivers() {
    isLoading.value = true;
    // Query drivers collection filtered by schoolId
    driverCollection
        .where('schoolId', isEqualTo: schoolId)
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      drivers.value =
          snapshot.docs.map((doc) => Driver.fromDocument(doc)).toList();
      isLoading.value = false;
    });
  }

  Future<void> addDriver(Driver driver) async {
    try {
      await driverCollection.doc(driver.id).set(driver.toMap());
      Get.snackbar('Success', 'Driver added successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to add driver: $e');
    }
  }

  Future<void> updateDriver(String id, Driver driver) async {
    try {
      await driverCollection.doc(id).update(driver.toMap());
      Get.snackbar('Success', 'Driver updated successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update driver: $e');
    }
  }

  Future<void> deleteDriver(String id) async {
    try {
      await driverCollection.doc(id).delete();
      Get.snackbar('Success', 'Driver deleted successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete driver: $e');
    }
  }

  // New: Add a student to a driver's assigned students list.
  Future<void> addStudentToDriver(String driverId, String studentId) async {
    try {
      final driverDoc = driverCollection.doc(driverId);
      await driverDoc.update({
        'students': FieldValue.arrayUnion([studentId]),
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to assign student to driver: $e');
    }
  }

  // Method to fetch the admin password securely.
  Future<String?> getAdminPassword() async {
    try {
      final AuthController authController = Get.find<AuthController>();
      return authController
          .getAdminPassword(); // Fetch password from AuthController.
    } catch (e) {
      Get.snackbar('Error', 'Failed to fetch admin password: $e');
      return null;
    }
  }

  List<Driver> get filteredDrivers {
    if (searchText.value.isEmpty) return drivers;
    return drivers
        .where((driver) =>
            driver.name.toLowerCase().contains(searchText.value.toLowerCase()))
        .toList();
  }
}
