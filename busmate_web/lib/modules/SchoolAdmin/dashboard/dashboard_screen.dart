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
import 'package:busmate_web/modules/SchoolAdmin/student_management/student_management_screen_upgraded.dart';
import 'package:busmate_web/modules/SchoolAdmin/payments/school_admin_payment_screen.dart';
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
        'permissionKey': 'timeControl',
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
        'icon': Icons.add_moderator_outlined,
        'label': 'Admin Management',
        'builder': () => SchoolAdminManagementScreenUpgraded(
          schoolId: controller.schoolId.value,
          fromSuperAdmin: fromSuperAdmin,
        ),
        'permissionKey': 'adminManagement',
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

  Widget _buildSidebar(BuildContext context, List<Map<String, dynamic>> filteredMenuItems) {
    final bool isMobile = MediaQuery.of(context).size.width < 1024;
    return SidebarX(
      controller: sidebarController,
      theme: SidebarXTheme(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2196F3),
              const Color(0xFF1976D2),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2196F3).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        textStyle: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        selectedTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        itemTextPadding: const EdgeInsets.only(left: 16),
        selectedItemDecoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        hoverColor: Colors.white.withOpacity(0.1),
        itemMargin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        iconTheme: IconThemeData(
          color: Colors.white.withOpacity(0.8),
          size: 22,
        ),
        selectedIconTheme: const IconThemeData(
          color: Colors.white,
          size: 22,
        ),
      ),
      extendedTheme: SidebarXTheme(
        width: 240,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2196F3),
              const Color(0xFF1976D2),
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      items: filteredMenuItems.map((item) {
        return SidebarXItem(
          icon: item['icon'],
          label: item['label'],
          onTap: () {
            sidebarController.selectIndex(filteredMenuItems.indexOf(item));
            controller.changePage(filteredMenuItems.indexOf(item));
            if (MediaQuery.of(context).size.width < 1024) {
              Navigator.of(context).pop();
            }
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    
    return Scaffold(
      appBar: AppBar(
        leading: isDesktop
            ? null
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Menu',
                ),
              ),
        title: Text(
          "School Admin",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isDesktop ? 20 : 18,
          ),
        ),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: !isDesktop,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => authController.logout(),
            tooltip: 'Logout',
          ),
          SizedBox(width: isDesktop ? 8 : 4),
        ],
      ),
      body: Obx(() {
        if (controller.schoolData.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final permissions = controller.schoolData['permissions'] ?? {};
        final arguments = Get.arguments as Map<String, dynamic>?;
        final fromSuperAdmin = arguments?['fromSuperAdmin'] ?? false;
        final isSuperiorAdmin = authController.isSuperiorAdmin;

        final filteredMenuItems = menuItems.where((item) {
          if (isSuperiorAdmin || fromSuperAdmin) {
            return true;
          }
          return permissions[item['permissionKey']] ?? false;
        }).toList();

        return Row(
          children: [
            if (isDesktop) _buildSidebar(context, filteredMenuItems),
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
                
                final builder = filteredMenuItems[currentIndex]['builder'] as Widget Function();
                return builder();
              }),
            ),
          ],
        );
      }),
      drawer: !isDesktop
          ? Obx(() {
              if (controller.schoolData.isEmpty) {
                return const Drawer(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final permissions = controller.schoolData['permissions'] ?? {};
              final arguments = Get.arguments as Map<String, dynamic>?;
              final fromSuperAdmin = arguments?['fromSuperAdmin'] ?? false;
              final isSuperiorAdmin = authController.isSuperiorAdmin;

              final filteredMenuItems = menuItems.where((item) {
                if (isSuperiorAdmin || fromSuperAdmin) {
                  return true;
                }
                return permissions[item['permissionKey']] ?? false;
              }).toList();

              return Drawer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2196F3),
                        const Color(0xFF1976D2),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      DrawerHeader(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'School Admin',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filteredMenuItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredMenuItems[index];
                            final isSelected = sidebarController.selectedIndex == index;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    sidebarController.selectIndex(index);
                                    controller.changePage(index);
                                    Navigator.of(context).pop();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? Colors.white.withOpacity(0.3) : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          item['icon'],
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            item['label'],
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            })
          : null,
    );
  }
}
