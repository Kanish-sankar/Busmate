import 'dart:developer';

import 'package:busmate/meta/model/driver_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class GetDriver extends GetxController {
  RxList<DriverModel> driverList = <DriverModel>[].obs;
  
  @override
  void onInit() {
    super.onInit();
    // REMOVED: Automatic fetching on init to reduce Firebase costs
    // Call fetchDrivers() manually only when needed
  }

  // Fetch all driver documents from Firestore
  Future<void> fetchDrivers() async {
    try {
      print('DEBUG: Attempting to fetch drivers...');
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('drivers').get();
          
      print('DEBUG: Found ${querySnapshot.docs.length} driver documents');

      List<DriverModel> drivers = querySnapshot.docs.map((doc) => DriverModel.fromMap(doc)).toList();

      driverList.assignAll(drivers);
      print('DEBUG: Successfully loaded ${drivers.length} drivers');
    } catch (e) {
      log("Error fetching drivers: $e");
      print('DEBUG: Failed to fetch drivers, continuing with empty list');
      // Don't rethrow the error, just continue with empty list
      driverList.clear();
    }
  }
}
