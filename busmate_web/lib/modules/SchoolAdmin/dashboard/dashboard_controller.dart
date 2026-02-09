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
    // Only initialize if we have valid arguments with schoolId
    if (Get.arguments != null && Get.arguments['schoolId'] != null) {
      schoolId.value = Get.arguments['schoolId'];
      role.value = Get.arguments['role'] ?? '';
      fetchSchoolData();
    }
    // If no arguments, this controller is being used for navigation only
    // (tagged as 'forNavigation' in SuperAdminDashboard)
    // Don't show errors - it's expected behavior
  }

  Future<void> fetchSchoolData() async {
    if (schoolId.value.isNotEmpty) {
      try {
        if (kDebugMode) {
          print('🔍 Fetching school data for ID: ${schoolId.value}');
        }
        
        // Try fetching from schooldetails collection first (NEW structure)
        DocumentSnapshot schoolDoc =
            await _firestore.collection('schooldetails').doc(schoolId.value).get();
        
        // If not found, try the old 'schools' collection (LEGACY support)
        if (!schoolDoc.exists) {
          if (kDebugMode) {
            print('⚠️ School not found in schooldetails, trying schools collection...');
          }
          schoolDoc = await _firestore.collection('schools').doc(schoolId.value).get();
        }
        
        if (kDebugMode) {
          print('📄 School document exists: ${schoolDoc.exists}');
          if (!schoolDoc.exists) {
            print('❌ Document not found in schooldetails/${schoolId.value} OR schools/${schoolId.value}');
            print('❌ School data is missing for this admin!');
          }
        }
        
        if (schoolDoc.exists) {
          final data = schoolDoc.data() as Map<String, dynamic>;
          
          // Normalize field names (handle both old and new formats)
          schoolData.value = {
            'schoolId': data['schoolId'] ?? data['school_id'] ?? schoolId.value,
            'schoolName': data['schoolName'] ?? data['school_name'] ?? 'Unknown School',
            'schoolCode': data['schoolCode'] ?? data['school_code'] ?? 'N/A',
            'email': data['email'] ?? '',
            'phone': data['phone'] ?? data['phone_number'] ?? '',
            'address': data['address'] ?? '',
            'totalBuses': data['totalBuses'] ?? data['total_buses'] ?? 0,
            'totalStudents': data['totalStudents'] ?? data['total_students'] ?? 0,
            'totalDrivers': data['totalDrivers'] ?? data['total_drivers'] ?? 0,
            'totalRoutes': data['totalRoutes'] ?? data['total_routes'] ?? 0,
            'status': data['status'] ?? 'active',
          };
          
          if (kDebugMode) {
            print('✅ School data loaded: ${schoolData['schoolName']}');
          }
        } else {
          // School doesn't exist - Show error and logout
          if (kDebugMode) {
            print('❌ School data not found! Admin account is not properly linked to a school.');
          }
          
          Get.snackbar(
            '❌ Error',
            'Your account is not properly linked to a school. Please contact Super Admin.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
          
          // Logout after a delay
          Future.delayed(const Duration(seconds: 3), () {
            authController.logout();
          });
          
          return; // Exit early
        }

          // Fetch permissions from NEW 'admins' collection
          String adminUid = authController.user.value?.uid ?? "";
          if (adminUid.isNotEmpty) {
            DocumentSnapshot adminDoc =
                await _firestore.collection('admins').doc(adminUid).get();
            if (adminDoc.exists && adminDoc.data() != null) {
              Map<String, dynamic> adminData = adminDoc.data() as Map<String, dynamic>;
              
              // Super admins get all permissions
              if (adminData['role'] == 'super_admin' || adminData['role'] == 'superior') {
                schoolData['permissions'] = {
                  'busManagement': true,
                  'driverManagement': true,
                  'routeManagement': true,
                  'timeControl': true,
                  'viewingBusStatus': true,
                  'studentManagement': true,
                  'paymentManagement': true,
                  'adminManagement': true,
                };
              } else {
                // School admins get their assigned permissions (default to all true for now)
                final dbPermissions = adminData['permissions'];
                print('📊 Raw DB Permissions for School Admin: $dbPermissions');
                
                // Get permissions from database or use defaults for School Admins
                final defaultPermissionsForSchoolAdmin = {
                  'busManagement': true,
                  'driverManagement': true,
                  'routeManagement': true,
                  'timeControl': true,
                  'viewingBusStatus': true,
                  'studentManagement': true,
                  'paymentManagement': true,
                  'adminManagement': true,
                };
                
                // Check if this is a Regional Admin (limited permissions)
                final role = adminData['role']?.toString().toLowerCase() ?? '';
                final isRegionalAdmin = role == 'regionaladmin';
                
                if (dbPermissions != null && dbPermissions is Map) {
                  if (isRegionalAdmin) {
                    // Regional Admin: Use ONLY the permissions from database
                    schoolData['permissions'] = Map<String, dynamic>.from(dbPermissions);
                  } else {
                    // School Admin: Use default full permissions (backward compatibility)
                    schoolData['permissions'] = defaultPermissionsForSchoolAdmin;
                  }
                } else {
                  // No permissions in DB: Give full access to School Admin, empty for Regional Admin
                  schoolData['permissions'] = isRegionalAdmin ? {} : defaultPermissionsForSchoolAdmin;
                }
                
                print('✅ Final Permissions Loaded: ${schoolData['permissions']}');
              }
            } else {
              // Set fallback defaults (give all permissions)
              schoolData['permissions'] = {
                'busManagement': true,
                'driverManagement': true,
                'routeManagement': true,
                'timeControl': true,
                'viewingBusStatus': true,
                'studentManagement': true,
                'paymentManagement': true,
                'adminManagement': true,
              };
            }
          } else {
            Get.snackbar(
                'Error', 'Unable to identify the current admin user.');
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
