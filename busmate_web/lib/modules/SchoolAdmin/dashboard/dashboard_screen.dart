import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:busmate_web/modules/Authentication/auth_controller.dart';
import 'package:busmate_web/modules/SchoolAdmin/dashboard/dashboard_controller.dart';
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_management_screen_upgraded.dart';
import 'package:busmate_web/modules/SchoolAdmin/driver_management/driver_management_screen_upgraded.dart';
import 'package:busmate_web/modules/SchoolAdmin/route_management/routes_list_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/time_control/time_control_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/view_bus_status/view_bus_status_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/view_bus_status/bus_simulator_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/student_management/student_management_screen_upgraded.dart';
import 'package:busmate_web/modules/SchoolAdmin/payments/school_admin_payment_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/notifications/notifications_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/admin_management/admin_management_screen_upgraded.dart';

class SchoolAdminDashboard extends StatefulWidget {
  const SchoolAdminDashboard({super.key});

  @override
  State<SchoolAdminDashboard> createState() => _SchoolAdminDashboardState();
}

class _SchoolAdminDashboardState extends State<SchoolAdminDashboard> {
  late final SchoolAdminDashboardController controller;
  late final AuthController authController;
  late final SidebarXController sidebarController;
  
  // Menu items list - initialized once to prevent GlobalKey conflicts
  late final List<Map<String, dynamic>> menuItems;

  @override
  void initState() {
    super.initState();
    
    // Get the arguments to retrieve schoolId if coming from SuperAdmin
    final arguments = Get.arguments as Map<String, dynamic>?;
    final schoolId = arguments?['schoolId'];
    final fromSuperAdmin = arguments?['fromSuperAdmin'] ?? false;
    
    // Use tag to avoid conflicts when multiple dashboards might exist
    controller = Get.put(
      SchoolAdminDashboardController(), 
      tag: schoolId ?? 'default',
    );
    
    // Set schoolId if provided
    if (schoolId != null) {
      controller.schoolId.value = schoolId;
    }
    
    authController = Get.find<AuthController>();
    sidebarController = SidebarXController(selectedIndex: 0);
    
    // Initialize menuItems once with screen builders instead of screen instances
    menuItems = [
      {
        'icon': Icons.bus_alert,
        'label': 'Bus Management',
        'builder': () => BusManagementScreenUpgraded(
          schoolId: controller.schoolId.value,
          fromSuperAdmin: fromSuperAdmin,
        ),
        'permissionKey': 'busManagement',
      },
      {
        'icon': Icons.person_2_sharp,
        'label': 'Driver Management',
        'builder': () => DriverManagementScreenUpgraded(
          schoolId: controller.schoolId.value,
          fromSuperAdmin: fromSuperAdmin,
        ),
        'permissionKey': 'driverManagement',
      },
      {
        'icon': Icons.route,
        'label': 'Route Management',
        'builder': () => RoutesListScreen(schoolId: controller.schoolId.value),
        'permissionKey': 'routeManagement',
      },
      {
        'icon': Icons.access_time,
        'label': 'Time Control',
        'builder': () => TimeControlScreen(schoolId: controller.schoolId.value),
        'permissionKey': 'routeManagement', // Same permission as route management
      },
      {
        'icon': Icons.lan_rounded,
        'label': 'View Bus Status',
        'builder': () => ViewBusStatusScreen(schoolId: controller.schoolId.value),
        'permissionKey': 'viewingBusStatus',
      },
      {
        'icon': Icons.child_care,
        'label': 'Student Management',
        'builder': () => StudentManagementScreenUpgraded(
          schoolId: controller.schoolId.value,
          fromSuperAdmin: fromSuperAdmin,
        ),
        'permissionKey': 'studentManagement',
      },
      {
        'icon': Icons.payment,
        'label': 'Payment Management',
        'builder': () => SchoolAdminPaymentScreen(controller.schoolId.value),
        'permissionKey': 'paymentManagement',
      },
      {
        'icon': Icons.notifications_active,
        'label': 'Notification Management',
        'builder': () => SchoolNotificationsScreen(controller.schoolId.value),
        'permissionKey': 'notifications',
      },
      {
        'icon': Icons.add_moderator_outlined,
        'label': 'Admin Management',
        'builder': () => SchoolAdminManagementScreenUpgraded(
          schoolId: controller.schoolId.value,
          fromSuperAdmin: fromSuperAdmin,
        ),
        'permissionKey': 'adminManagement',
      },
      {
        'icon': Icons.settings_remote,
        'label': 'Bus Simulator',
        'builder': () => BusSimulatorScreen(schoolId: controller.schoolId.value),
        'permissionKey': 'viewingBusStatus', // Same permission as View Bus Status
      },
    ];
  }

  @override
  void dispose() {
    final arguments = Get.arguments as Map<String, dynamic>?;
    final schoolId = arguments?['schoolId'];
    // Clean up controller when widget is disposed
    Get.delete<SchoolAdminDashboardController>(tag: schoolId ?? 'default');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[50],
        shadowColor: Colors.black,
        elevation: 0.6,
        actionsPadding: const EdgeInsets.only(right: 20),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () => authController.logout(),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.schoolData.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        // Debug: Log permissions to verify the issue
        final permissions = controller.schoolData['permissions'] ?? {};
        
        print('🔑 School Admin Permissions: $permissions');
        
        // Check if Superior Admin is accessing (they should see all menu items)
        final arguments = Get.arguments as Map<String, dynamic>?;
        final fromSuperAdmin = arguments?['fromSuperAdmin'] ?? false;
        final isSuperiorAdmin = authController.isSuperiorAdmin;

        // Filter menu items based on permissions (Superior Admin bypasses permission check)
        final filteredMenuItems = menuItems.where((item) {
          // If Superior Admin, show all items
          if (isSuperiorAdmin || fromSuperAdmin) {
            print('📋 ${item['label']}: SUPERIOR ADMIN - Full Access ✅');
            return true;
          }
          
          // Otherwise, check permissions
          final hasPermission = permissions[item['permissionKey']] ?? false;
          print('📋 ${item['label']}: ${item['permissionKey']} = $hasPermission');

          return hasPermission;
        }).toList();
        
        print('✅ Filtered Menu Items Count: ${filteredMenuItems.length}');

        return Row(
          children: [
            SidebarX(
              controller: sidebarController,
              theme: SidebarXTheme(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(color: Colors.black),
                selectedTextStyle: const TextStyle(color: Colors.blue),
                itemTextPadding: const EdgeInsets.only(left: 20),
                selectedItemDecoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              extendedTheme: SidebarXTheme(
                width: 250,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                ),
              ),
              items: filteredMenuItems.map((item) {
                return SidebarXItem(
                  icon: item['icon'],
                  label: item['label'],
                  onTap: () {
                    sidebarController
                        .selectIndex(filteredMenuItems.indexOf(item));
                    controller.changePage(filteredMenuItems.indexOf(item));
                  },
                );
              }).toList(),
            ),
            Expanded(
              child: Obx(() {
                final currentIndex = controller.currentPageIndex.value;
                if (filteredMenuItems.isEmpty) {
                  return const Center(
                    child: Text("No accessible pages available."),
                  );
                }
                
                if (currentIndex >= filteredMenuItems.length) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                // Call the builder function to create the screen widget fresh
                final builder = filteredMenuItems[currentIndex]['builder'] as Widget Function();
                return builder();
              }),
            ),
          ],
        );
      }),
    );
  }
}
