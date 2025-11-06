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
      print('🏫 Starting to fetch schools from Firestore...');
      // Try schooldetails collection first (primary collection)
      _firestore.collection('schooldetails').snapshots().listen((snapshot) {
        print('🏫 ✅ Received ${snapshot.docs.length} schools from schooldetails collection');
        schools.value = snapshot.docs;
        for (var doc in snapshot.docs) {
          var data = doc.data();
          print('   - ${data['school_name'] ?? data['schoolName'] ?? 'Unnamed'} (${doc.id})');
        }
      }, onError: (error) {
        print('🏫 ❌ Error fetching schools: $error');
        // If schooldetails fails, try schools collection as fallback
        _firestore.collection('schools').snapshots().listen((snapshot) {
          print('🏫 ✅ Fallback: Received ${snapshot.docs.length} schools from schools collection');
          schools.value = snapshot.docs;
        }, onError: (fallbackError) {
          print('🏫 ❌ Fallback also failed: $fallbackError');
          if (kDebugMode) {
            print("Error fetching schools from both collections: $fallbackError");
          }
        });
      });
    } catch (e) {
      print('🏫 ❌ Error setting up schools listener: $e');
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
