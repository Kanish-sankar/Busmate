import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:busmate_web/modules/Authentication/auth_controller.dart';
import 'package:busmate_web/modules/SchoolAdmin/dashboard/dashboard_controller.dart';
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_management_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/driver_management/driver_management_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/route_management/select_bus_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/view_bus_status/view_bus_status_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/student_management/student_management_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/payments/payments_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/notifications/notifications_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/admin_management/admin_management_screen.dart';

class SchoolAdminDashboard extends StatelessWidget {
  final SchoolAdminDashboardController controller =
      Get.put(SchoolAdminDashboardController());
  final AuthController authController = Get.find<AuthController>();
  final SidebarXController sidebarController =
      SidebarXController(selectedIndex: 0);

  SchoolAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> menuItems = [
      {
        'icon': Icons.bus_alert,
        'label': 'Bus Management',
        'screen': BusManagementScreen(),
        'permissionKey': 'busManagement',
      },
      {
        'icon': Icons.person_2_sharp,
        'label': 'Driver Management',
        'screen': DriverManagementScreen(),
        'permissionKey': 'driverManagement',
      },
      {
        'icon': Icons.route,
        'label': 'Route Management',
        'screen': SelectBusScreen(),
        'permissionKey': 'routeManagement',
      },
      {
        'icon': Icons.lan_rounded,
        'label': 'View Bus Status',
        'screen': ViewBusStatusScreen(),
        'permissionKey': 'viewingBusStatus',
      },
      {
        'icon': Icons.child_care,
        'label': 'Student Management',
        'screen': StudentManagementScreen(),
        'permissionKey': 'studentManagement',
      },
      {
        'icon': Icons.payment,
        'label': 'Payment Management',
        'screen': SchoolAdminPaymentScreen(controller.schoolId.value),
        'permissionKey': 'paymentManagement',
      },
      {
        'icon': Icons.notifications_active,
        'label': 'Notification Management',
        'screen': SchoolNotificationsScreen(controller.schoolId.value),
        'permissionKey': 'notifications',
      },
      {
        'icon': Icons.add_moderator_outlined,
        'label': 'Admin Management',
        'screen': SchoolAdminManagementScreen(controller.schoolId.value),
        'permissionKey': 'adminManagement',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(
            "Dashboard - ${controller.schoolData['school_name'] ?? 'School'}")),
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

        // Filter menu items based on permissions
        final filteredMenuItems = menuItems.where((item) {
          final hasPermission = permissions[item['permissionKey']] ?? false;

          return hasPermission;
        }).toList();

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
              child: filteredMenuItems.isNotEmpty
                  ? filteredMenuItems[controller.currentPageIndex.value]
                      ['screen']
                  : const Center(
                      child: Text("No accessible pages available."),
                    ),
            ),
          ],
        );
      }),
    );
  }
}
