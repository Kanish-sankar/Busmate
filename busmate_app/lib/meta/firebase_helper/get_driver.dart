import 'dart:developer';

import 'package:busmate/meta/model/driver_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class GetDriver extends GetxController {
  RxList<DriverModel> driverList = <DriverModel>[].obs;
  @override
  void onInit() {
    super.onInit();
    fetchDrivers(); // Fetch data when the controller is initialized
  }

  // Fetch all student documents from Firestore
  void fetchDrivers() async {
    try {
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('drivers').get();

      List<DriverModel> drivers = querySnapshot.docs.map((doc) => DriverModel.fromMap(doc)).toList();

      driverList.assignAll(drivers);
    } catch (e) {
      log("Error fetching students: $e");
    }
  }
}
