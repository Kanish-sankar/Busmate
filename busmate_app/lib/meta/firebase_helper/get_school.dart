import 'dart:developer';

import 'package:busmate/meta/model/scool_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class GetSchools extends GetxController {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  RxList<SchoolModel> schoolList = <SchoolModel>[].obs;
  var isLoading = true.obs;

  @override
  void onInit() {
    fetchSchools();
    super.onInit();
  }

  // Fetch all school documents from Firestore
  void fetchSchools() async {
    try {
      isLoading(true);
      QuerySnapshot querySnapshot = await firestore.collection('schools').get();

      List<SchoolModel> schools = querySnapshot.docs.map((doc) {
        return SchoolModel.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();

      // schoolList.assignAll(schools);

      // Print all school data in logs
      for (var school in schools) {
        schoolList.add(school);
        log(
            "School Name: ${school.schoolName}, Email: ${school.email}, Phone: ${school.phoneNumber}");
      }
    } catch (e) {
      log("Error fetching schools: $e");
    } finally {
      isLoading(false);
    }
  }
}

