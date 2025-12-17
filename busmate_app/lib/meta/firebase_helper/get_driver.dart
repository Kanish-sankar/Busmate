import 'package:busmate/meta/model/driver_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class GetDriver extends GetxController {
  RxList<DriverModel> driverList = <DriverModel>[].obs;
  

  // Fetch all driver documents from Firestore
  Future<void> fetchDrivers() async {
    try {
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('drivers').get();
      List<DriverModel> drivers = querySnapshot.docs.map((doc) => DriverModel.fromMap(doc)).toList();

      driverList.assignAll(drivers);
    } catch (e) {
      // Don't rethrow the error, just continue with empty list
      driverList.clear();
    }
  }
}
