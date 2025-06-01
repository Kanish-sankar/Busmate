import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SuperAdminDashboardController extends GetxController {
  final RxInt currentPageIndex = 0.obs;
  final PageController pageController = PageController();
  final RxString selectedSchoolId = "".obs;
  final RxList<DocumentSnapshot> schools = RxList<DocumentSnapshot>([]);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void onInit() {
    super.onInit();
    fetchSchools();
  }

  Future<void> fetchSchools() async {
    try {
      // Set up a real-time listener for schools
      _firestore.collection('schools').snapshots().listen((snapshot) {
        schools.value = snapshot.docs;
      }, onError: (error) {
        if (kDebugMode) {
          print("Error fetching schools: $error");
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error setting up schools listener: $e");
      }
    }
  }

  void updateSelectedSchool(String id) {
    selectedSchoolId.value = id;
    // Store the selected school ID in GetStorage for persistence
    Get.put(id, tag: 'selectedSchoolId', permanent: true);
  }

  String getSelectedSchoolId() {
    return selectedSchoolId.value;
  }

  Map<String, dynamic>? getSelectedSchoolData() {
    if (selectedSchoolId.value.isEmpty) return null;
    final school =
        schools.firstWhereOrNull((doc) => doc.id == selectedSchoolId.value);
    return school?.data() as Map<String, dynamic>?;
  }

  void changePage(int index) {
    currentPageIndex.value = index;
    if (pageController.hasClients) {
      pageController.jumpToPage(index);
    }
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
