import 'dart:async';
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
  
  // Stream subscriptions to cancel on logout
  StreamSubscription<QuerySnapshot>? _schoolsSubscription;

  @override
  void onInit() {
    super.onInit();
    fetchSchools();
  }

  Future<void> fetchSchools() async {
    try {
      // Cancel existing listener
      _schoolsSubscription?.cancel();
      
      // Starting to fetch schools from Firestore
      // Try schooldetails collection first (primary collection)
      _schoolsSubscription = _firestore.collection('schooldetails').snapshots().listen((snapshot) {
        schools.value = snapshot.docs;
      }, onError: (error) {
        // If schooldetails fails, try schools collection as fallback
        _schoolsSubscription?.cancel();
        _schoolsSubscription = _firestore.collection('schools').snapshots().listen((snapshot) {
          schools.value = snapshot.docs;
        }, onError: (fallbackError) {
          if (kDebugMode) {
            print("Error fetching schools from both collections: $fallbackError");
          }
        });
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
  
  @override
  void onClose() {
    // Cancel Firestore listener when controller is disposed
    _schoolsSubscription?.cancel();
    pageController.dispose();
    super.onClose();
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
}
