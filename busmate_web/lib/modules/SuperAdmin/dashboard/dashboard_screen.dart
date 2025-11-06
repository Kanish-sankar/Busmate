import 'package:busmate_web/modules/Authentication/auth_controller.dart';
import 'package:busmate_web/modules/SchoolAdmin/dashboard/dashboard_controller.dart';
import 'package:busmate_web/modules/SchoolAdmin/route_management/select_bus_screen.dart';
import 'package:busmate_web/modules/SuperAdmin/dashboard/dashboard_controller.dart';
import 'package:busmate_web/modules/SuperAdmin/notification_management/notification_screen.dart';
import 'package:busmate_web/modules/SuperAdmin/payment_management/super_admin_payment_screen.dart';
import 'package:busmate_web/modules/SuperAdmin/school_management/school_management_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_management_screen_new.dart';
import 'package:busmate_web/modules/SchoolAdmin/driver_management/driver_management_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/student_management/student_management_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/payments/school_admin_payment_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/notifications/notifications_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/view_bus_status/view_bus_status_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SuperAdminDashboard extends StatelessWidget {
  // Controller for Super Admin-specific functions.
  final SuperAdminDashboardController controller =
      Get.put(SuperAdminDashboardController());
  // Controller for School Admin dashboard that holds the selected school ID.
  final SchoolAdminDashboardController scontroller =
      Get.put(SchoolAdminDashboardController());
  final AuthController authController = Get.find<AuthController>();
  final SidebarXController sidebarController =
      SidebarXController(selectedIndex: 0);

  SuperAdminDashboard({super.key});

  /// Builds an expansion tile for managing a specific school.
  /// When expanded, it updates the selected school ID in both controllers.
  Widget _buildSchoolManagementOptions(String schoolId, String schoolName) {
    return ExpansionTile(
      key: UniqueKey(), // Force rebuild every time dialog opens
      leading: const Icon(Icons.account_balance),
      title: Text(schoolName),
      onExpansionChanged: (expanded) {
        controller.updateSelectedSchool(expanded ? schoolId : '');
        if (expanded) {
          // Ensure that the SchoolAdminDashboardController holds the current schoolId.
          scontroller.schoolId.value = schoolId;
        }
      },
      children: [
        ListTile(
          leading: const Icon(Icons.bus_alert),
          title: const Text("Bus Management"),
          onTap: () {
            controller.updateSelectedSchool(schoolId);
            scontroller.schoolId.value = schoolId;
            // Close the dialog before navigating
            Get.back(); // Use Get.back() instead of Navigator.pop
            Get.to(() => const BusManagementScreenNew(),
                arguments: {'schoolId': schoolId});
          },
        ),
        ListTile(
          leading: const Icon(Icons.person_2_sharp),
          title: const Text("Driver Management"),
          onTap: () {
            controller.updateSelectedSchool(schoolId);
            scontroller.schoolId.value = schoolId;
            // Close the dialog before navigating
            Get.back(); // Use Get.back() instead of Navigator.pop
            Get.to(() => DriverManagementScreen(),
                arguments: {'schoolId': schoolId});
          },
        ),
        ListTile(
          leading: const Icon(Icons.route),
          title: const Text("Route Management"),
          onTap: () async {
            controller.updateSelectedSchool(schoolId);
            scontroller.schoolId.value = schoolId;
            // Close the dialog before navigating
            Get.back(); // Use Get.back() instead of Navigator.pop
            await Get.to(() => SelectBusScreen(),
                arguments: {'schoolId': schoolId});
            controller.updateSelectedSchool('');
          },
        ),
        ListTile(
          leading: const Icon(Icons.child_care),
          title: const Text("Student Management"),
          onTap: () {
            controller.updateSelectedSchool(schoolId);
            scontroller.schoolId.value = schoolId;
            // Close the dialog before navigating
            Get.back(); // Use Get.back() instead of Navigator.pop
            Get.to(() => StudentManagementScreen(),
                arguments: {'schoolId': schoolId});
          },
        ),
        ListTile(
          leading: const Icon(Icons.payment),
          title: const Text("Payment Management"),
          onTap: () {
            controller.updateSelectedSchool(schoolId);
            scontroller.schoolId.value = schoolId;
            // Close the dialog before navigating
            Get.back(); // Use Get.back() instead of Navigator.pop
            Get.to(() => SchoolAdminPaymentScreen(schoolId),
                arguments: {'schoolId': schoolId});
          },
        ),
        ListTile(
          leading: const Icon(Icons.notifications_active),
          title: const Text("Notifications"),
          onTap: () {
            controller.updateSelectedSchool(schoolId);
            scontroller.schoolId.value = schoolId;
            // Close the dialog before navigating
            Get.back(); // Use Get.back() instead of Navigator.pop
            Get.to(() => SchoolNotificationsScreen(schoolId),
                arguments: {'schoolId': schoolId});
          },
        ),
        ListTile(
          leading: const Icon(Icons.lan_rounded),
          title: const Text("View Bus Status"),
          onTap: () {
            controller.updateSelectedSchool(schoolId);
            scontroller.schoolId.value = schoolId;
            // Close the dialog before navigating
            Get.back(); // Use Get.back() instead of Navigator.pop
            Get.to(() => ViewBusStatusScreen(),
                arguments: {'schoolId': schoolId});
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Define the main pages for the super admin dashboard.
    final List<Widget> pages = [
      SuperAdminHomeScreen(), // New advanced dashboard home
      const SchoolManagementScreen(),
      SuperAdminPaymentManagementScreen(),
      SendNotificationScreen()
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: Colors.blue[50],
        shadowColor: Colors.black,
        elevation: 0.6,
        actionsPadding: const EdgeInsets.only(right: 20),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout,
              color: Colors.black,
            ),
            onPressed: () => authController.logout(),
          )
        ],
      ),
      body: Row(
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
            items: [
              SidebarXItem(
                icon: Icons.dashboard,
                label: 'Dashboard',
                onTap: () {
                  sidebarController.selectIndex(0);
                  controller.changePage(0);
                },
              ),
              SidebarXItem(
                icon: Icons.school,
                label: 'School Management',
                onTap: () {
                  sidebarController.selectIndex(1);
                  controller.changePage(1);
                },
              ),
              SidebarXItem(
                icon: Icons.monetization_on,
                label: 'Payment Management',
                onTap: () {
                  sidebarController.selectIndex(2);
                  controller.changePage(2);
                },
              ),
              SidebarXItem(
                icon: Icons.edit_notifications,
                label: 'Notify All',
                onTap: () {
                  sidebarController.selectIndex(3);
                  controller.changePage(3);
                },
              ),
              SidebarXItem(
                icon: Icons.account_balance,
                label: 'Manage Schools',
                onTap: () {
                  sidebarController.selectIndex(3);
                  print('🏫 Opening Manage Schools dialog');
                  print('🏫 Schools count: ${controller.schools.length}');
                  showDialog(
                    context: context,
                    builder: (context) {
                      return Dialog(
                        child: Container(
                          width: 500,
                          padding: const EdgeInsets.all(20),
                          child: Obx(() {
                            if (controller.schools.isEmpty) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Manage Schools',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 20),
                                  const Text('Loading schools...'),
                                  const SizedBox(height: 20),
                                  TextButton(
                                    onPressed: () => Get.back(),
                                    child: const Text('Close'),
                                  ),
                                ],
                              );
                            }
                            
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Manage Schools',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () => Get.back(),
                                    ),
                                  ],
                                ),
                                const Divider(),
                                const SizedBox(height: 10),
                                Flexible(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: controller.schools.map((school) {
                                        var schoolData =
                                            school.data() as Map<String, dynamic>?;
                                        // Try both field names (schoolName and school_name)
                                        String schoolName =
                                            schoolData?['schoolName'] ?? 
                                            schoolData?['school_name'] ??
                                            'Unnamed School';
                                        print('🏫 School: $schoolName (${school.id})');
                                        return _buildSchoolManagementOptions(
                                            school.id, schoolName);
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          Expanded(
            child: Obx(() => pages[controller.currentPageIndex.value]),
          ),
        ],
      ),
    );
  }
}

// --- New Advanced Dashboard Home Screen ---
class SuperAdminHomeScreen extends StatefulWidget {
  @override
  State<SuperAdminHomeScreen> createState() => _SuperAdminHomeScreenState();
}

class _SuperAdminHomeScreenState extends State<SuperAdminHomeScreen> {
  int schools = 0, buses = 0, drivers = 0, students = 0, activeBuses = 0;
  bool loading = true;
  List<Map<String, dynamic>> recentSchools = [];
  List<Map<String, dynamic>> recentPayments = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => loading = true);
    final firestore = FirebaseFirestore.instance;

    final schoolsSnap = await firestore.collection('schools').get();
    final busesSnap = await firestore.collectionGroup('buses').get();
    final driversSnap = await firestore.collection('drivers').get();
    final studentsSnap = await firestore.collection('students').get();
    final busStatusSnap = await firestore.collection('bus_status').get();

    final recentSchoolsSnap = await firestore
        .collection('schools')
        .orderBy('created_at', descending: true)
        .limit(5)
        .get();

    final paymentRequests = <Map<String, dynamic>>[];
    for (final doc in schoolsSnap.docs) {
      final paySnap = await firestore
          .collection('schools')
          .doc(doc.id)
          .collection('payments')
          .orderBy('createdAt', descending: true)
          .limit(2)
          .get();
      for (final p in paySnap.docs) {
        final data = p.data();
        paymentRequests.add({
          ...data,
          'school_name': doc['school_name'],
          'school_id': doc.id,
          'createdAt': data['createdAt'], // may be null
        });
      }
    }
    paymentRequests.sort((a, b) {
      final aTime = a['createdAt'] is Timestamp
          ? (a['createdAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b['createdAt'] is Timestamp
          ? (b['createdAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    setState(() {
      schools = schoolsSnap.size;
      buses = busesSnap.size;
      drivers = driversSnap.size;
      students = studentsSnap.size;
      activeBuses = busStatusSnap.docs
          .where((d) => d['currentStatus'] == 'Active')
          .length;
      recentSchools = recentSchoolsSnap.docs
          .map((d) => {
                'name': d['school_name'],
                'email': d['email'],
                'created_at': d['created_at'],
              })
          .toList();
      recentPayments = paymentRequests.take(5).toList();
      loading = false;
    });
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required int value,
    Color? color,
    Color? iconColor,
    int delay = 0,
  }) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 1000 + delay),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double animValue, child) {
        return Transform.translate(
          offset: Offset(-30 * (1 - animValue), 0),
          child: Opacity(
            opacity: animValue,
            child: child,
          ),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: Card(
            elevation: 4,
            shadowColor: (iconColor ?? Colors.blue[700])?.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 160,
                maxWidth: 200,
                minHeight: 110,
              ),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color ?? Colors.white,
                    (color ?? Colors.white).withOpacity(0.8),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (iconColor ?? Colors.blue[700])
                          ?.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 28,
                      color: iconColor ?? Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: iconColor ?? Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSystemHealthCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.green.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.green[50]!,
              Colors.white,
            ],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.health_and_safety,
                color: Colors.green[700],
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "System Health",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildHealthRow("Firestore: Connected"),
                  _buildHealthRow("FCM: Operational"),
                  _buildHealthRow("API: Healthy"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSchools() {
    return Card(
      elevation: 4,
      shadowColor: Colors.blue.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 300,
          maxWidth: 400,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: const Text(
                    "Recently Added Schools",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: const Text("View All"),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (recentSchools.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "No recent schools found.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ...recentSchools.map((s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.school,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    s['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    s['email'] ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    s['created_at'] is Timestamp
                        ? DateFormat('dd MMM')
                            .format((s['created_at'] as Timestamp).toDate())
                        : '',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPayments() {
    return Card(
      elevation: 4,
      shadowColor: Colors.green.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 300,
          maxWidth: 400,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: const Text(
                    "Recent Payment Requests",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: const Text("View All"),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (recentPayments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "No recent payments found.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ...recentPayments.map((p) {
              final createdAt = p['createdAt'] is Timestamp
                  ? (p['createdAt'] as Timestamp).toDate()
                  : null;
              final dateStr = createdAt != null
                  ? DateFormat('dd MMM').format(createdAt)
                  : '';
              final amount = p['amount'] is num
                  ? (p['amount'] as num).toStringAsFixed(2)
                  : (p['amount']?.toString() ?? '');
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.payment,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                title: Text(
                  p['school_name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  "₹$amount | ${p['status'] ?? 'N/A'}",
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  dateStr,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.blue.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 300,
          maxWidth: 400,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Quick Actions",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.school, size: 18),
                  label: const Text("Add School"),
                  onPressed: () => Get.toNamed('/add-school'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[50],
                    foregroundColor: Colors.blue[900],
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.notifications, size: 18),
                  label: const Text("Send Notification"),
                  onPressed: () => Get.toNamed('/send-notification'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[50],
                    foregroundColor: Colors.blue[900],
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.monetization_on, size: 18),
                  label: const Text("Generate Bill"),
                  onPressed: () => Get.toNamed('/payment-management'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[50],
                    foregroundColor: Colors.blue[900],
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM y').format(now);
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Stack(
      children: [
        // Fabric Pattern Background
        CustomPaint(
          size: Size.infinite,
          painter: _FabricBackgroundPainter(),
        ),
        // Floating animated circles
        const _FloatingBackgroundElements(),
        // Main content
        SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth > 1200 ? 32 : 16,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Animated Greeting and date
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 800),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome, Super Admin",
                          style: TextStyle(
                            fontSize: screenWidth > 600 ? 26 : 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Overview of your bus tracking system at a glance.",
                          style: TextStyle(
                            fontSize: screenWidth > 600 ? 15 : 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1565C0).withOpacity(0.1),
                            const Color(0xFF1E88E5).withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF1565C0).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: const Color(0xFF1565C0),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: screenWidth > 600 ? 14 : 12,
                              color: const Color(0xFF1565C0),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Animated Metrics Row
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 1000),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildMetricCard(
                      icon: Icons.school,
                      label: "Schools",
                      value: schools,
                      delay: 0,
                    ),
                    _buildMetricCard(
                      icon: Icons.directions_bus,
                      label: "Buses",
                      value: buses,
                      delay: 100,
                    ),
                    _buildMetricCard(
                      icon: Icons.person,
                      label: "Drivers",
                      value: drivers,
                      delay: 200,
                    ),
                    _buildMetricCard(
                      icon: Icons.child_care,
                      label: "Students",
                      value: students,
                      delay: 300,
                    ),
                    _buildMetricCard(
                      icon: Icons.directions_bus_filled,
                      label: "Active Buses",
                      value: activeBuses,
                      color: Colors.green[50],
                      iconColor: Colors.green[700],
                      delay: 400,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              
              // Animated System Health
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 1200),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: 0.9 + (0.1 * value),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: _buildSystemHealthCard(),
              ),
              const SizedBox(height: 28),
              
              // Animated Recent Activity and Quick Actions
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 1400),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Opacity(
                    opacity: value,
                    child: child,
                  );
                },
                child: Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    _buildRecentSchools(),
                    _buildRecentPayments(),
                    _buildQuickActions(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Fabric pattern background painter
class _FabricBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF5F7FA)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw subtle diagonal lines for fabric texture
    final linePaint = Paint()
      ..color = Colors.blue.withOpacity(0.03)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (double i = -size.height; i < size.width + size.height; i += 40) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        linePaint,
      );
    }

    for (double i = -size.height; i < size.width + size.height; i += 40) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i - size.height, size.height),
        linePaint,
      );
    }

    // Draw subtle dots for texture
    final dotPaint = Paint()
      ..color = Colors.blue.withOpacity(0.02)
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += 20) {
      for (double y = 0; y < size.height; y += 20) {
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Floating animated background elements
class _FloatingBackgroundElements extends StatefulWidget {
  const _FloatingBackgroundElements();

  @override
  State<_FloatingBackgroundElements> createState() =>
      _FloatingBackgroundElementsState();
}

class _FloatingBackgroundElementsState
    extends State<_FloatingBackgroundElements> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<Offset>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      8,
      (index) => AnimationController(
        duration: Duration(milliseconds: 4000 + (index * 600)),
        vsync: this,
      )..repeat(reverse: true),
    );

    _animations = _controllers.asMap().entries.map((entry) {
      return Tween<Offset>(
        begin: Offset(
          (entry.key % 4) * 0.25,
          (entry.key % 3) * 0.33,
        ),
        end: Offset(
          (entry.key % 4) * 0.25 + 0.15,
          (entry.key % 3) * 0.33 + 0.25,
        ),
      ).animate(CurvedAnimation(
        parent: entry.value,
        curve: Curves.easeInOut,
      ));
    }).toList();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: List.generate(8, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Positioned(
              left: size.width * _animations[index].value.dx,
              top: size.height * _animations[index].value.dy,
              child: Container(
                width: 100 + (index * 30).toDouble(),
                height: 100 + (index * 30).toDouble(),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      index % 2 == 0
                          ? const Color(0xFF1565C0).withOpacity(0.05)
                          : const Color(0xFF1E88E5).withOpacity(0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
