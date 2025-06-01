import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:busmate_web/modules/Authentication/auth_controller.dart';

class SchoolAdminDashboardController extends GetxController {
  final RxInt currentPageIndex = 0.obs;
  final PageController pageController = PageController();
  final RxString schoolId = "".obs;
  final RxString role = "".obs;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RxMap<String, dynamic> schoolData = RxMap<String, dynamic>();

  /// Retrieve the AuthController to get the currently logged in admin UID.
  final AuthController authController = Get.find<AuthController>();

  @override
  void onInit() {
    super.onInit();
    initializeData();
  }

  void initializeData() {
    if (Get.arguments != null && Get.arguments['schoolId'] != null) {
      schoolId.value = Get.arguments['schoolId'];
      role.value = Get.arguments['role'] ?? '';
      fetchSchoolData();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Get.snackbar(
        //   'Error',
        //   'School ID is missing. Unable to fetch school data.',
        // );
      });
    }
  }

  Future<void> fetchSchoolData() async {
    if (schoolId.value.isNotEmpty) {
      try {
        // Fetch basic school data from the schools collection.
        DocumentSnapshot schoolDoc =
            await _firestore.collection('schools').doc(schoolId.value).get();
        if (schoolDoc.exists) {
          schoolData.value = schoolDoc.data() as Map<String, dynamic>;

          // For manager roles (regionalAdmin or schoolSuperAdmin),
          // fetch permissions from the adminusers collection.
          if (role.value == 'regionalAdmin' ||
              role.value == 'schoolSuperAdmin') {
            String adminUid = authController.user.value?.uid ?? "";
            if (adminUid.isNotEmpty) {
              DocumentSnapshot adminDoc =
                  await _firestore.collection('adminusers').doc(adminUid).get();
              if (adminDoc.exists && adminDoc.data() != null) {
                schoolData['permissions'] = adminDoc.get('permissions') ??
                    {
                      'busManagement': false,
                      'driverManagement': false,
                      'routeManagement': false,
                      'viewingBusStatus': false, // Ensure this key exists
                      'studentManagement': false,
                      'paymentManagement': false,
                      'notifications': true,
                      'adminManagement': false,
                    };
              } else {
                // Set fallback defaults for manager roles.
                schoolData['permissions'] = {
                  'busManagement': false,
                  'driverManagement': false,
                  'routeManagement': false,
                  'viewingBusStatus': false, // Ensure this key exists
                  'studentManagement': false,
                  'paymentManagement': false,
                  'notifications': true,
                  'adminManagement': false,
                };
              }
            } else {
              Get.snackbar(
                  'Error', 'Unable to identify the current admin user.');
            }
          } else {
            // For non-manager roles, assume full access.
            schoolData['permissions'] = {
              'busManagement': true,
              'driverManagement': true,
              'routeManagement': true,
              'viewingBusStatus': true, // Ensure this key exists
              'studentManagement': true,
              'paymentManagement': true,
              'notifications': true,
              'adminManagement': true,
            };
          }
        } else {
          Get.snackbar('Error', 'School data not found for the given ID.');
        }
      } catch (e) {
        if (kDebugMode) print("Error fetching school data: $e");
        Get.snackbar('Error', 'Failed to fetch school data: $e');
      }
    }
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
