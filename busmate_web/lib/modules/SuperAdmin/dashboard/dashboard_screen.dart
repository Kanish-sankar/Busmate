import 'package:busmate_web/modules/Authentication/auth_controller.dart';
import 'package:busmate_web/modules/SchoolAdmin/dashboard/dashboard_controller.dart';
import 'package:busmate_web/modules/SchoolAdmin/route_management/select_bus_screen.dart';
import 'package:busmate_web/modules/SuperAdmin/dashboard/dashboard_controller.dart';
import 'package:busmate_web/modules/SuperAdmin/notification_management/notification_screen.dart';
import 'package:busmate_web/modules/SuperAdmin/payment_management/payment_management_screen.dart';
import 'package:busmate_web/modules/SuperAdmin/school_management/school_management_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_management_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/driver_management/driver_management_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/student_management/student_management_screen.dart';
import 'package:busmate_web/modules/SchoolAdmin/payments/payments_screen.dart';
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
            Navigator.of(Get.context!).pop();
            Get.to(() => BusManagementScreen(),
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
            Navigator.of(Get.context!).pop();
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
            Navigator.of(Get.context!).pop();
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
            Navigator.of(Get.context!).pop();
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
            Navigator.of(Get.context!).pop();
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
            Navigator.of(Get.context!).pop();
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
            Navigator.of(Get.context!).pop();
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
      SuperAdminPaymentScreen(),
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
                  showDialog(
                    context: context,
                    builder: (context) {
                      return Dialog(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          child: Obx(() {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: controller.schools.map((school) {
                                var schoolData =
                                    school.data() as Map<String, dynamic>?;
                                String schoolName =
                                    schoolData?['school_name'] ??
                                        'Unnamed School';
                                return _buildSchoolManagementOptions(
                                    school.id, schoolName);
                              }).toList(),
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
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 180,
        height: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color ?? Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30, color: iconColor ?? Colors.blue[700]),
            const Spacer(),
            Text(label,
                style: const TextStyle(fontSize: 14, color: Colors.black54)),
            Text(
              value.toString(),
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemHealthCard() {
    // Dummy status for now
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.health_and_safety, color: Colors.green[700], size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("System Health",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 6),
                      const Text("Firestore: Connected",
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 6),
                      const Text("FCM: Operational",
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 6),
                      const Text("API: Healthy",
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSchools() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text("Recently Added Schools",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                TextButton(
                  onPressed: () {/* TODO: Implement view all */},
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
                    Text("No recent schools found.",
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ...recentSchools.map((s) => ListTile(
                  leading: const Icon(Icons.school, color: Colors.blue),
                  title: Text(s['name'] ?? ''),
                  subtitle: Text(s['email'] ?? ''),
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text("Recent Payment Requests",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                TextButton(
                  onPressed: () {/* TODO: Implement view all */},
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
                    Text("No recent payments found.",
                        style: TextStyle(color: Colors.grey)),
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
                leading: const Icon(Icons.payment, color: Colors.green),
                title: Text(p['school_name'] ?? ''),
                subtitle:
                    Text("Amount: ₹$amount | Status: ${p['status'] ?? 'N/A'}"),
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Quick Actions",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.school),
                  label: const Text("Add School"),
                  onPressed: () => Get.toNamed('/add-school'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[50],
                      foregroundColor: Colors.blue[900]),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.notifications),
                  label: const Text("Send Notification"),
                  onPressed: () => Get.toNamed('/send-notification'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[50],
                      foregroundColor: Colors.blue[900]),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.monetization_on),
                  label: const Text("Generate Bill"),
                  onPressed: () => Get.toNamed('/payment-management'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[50],
                      foregroundColor: Colors.blue[900]),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting and date
          Row(
            children: [
              const Text(
                "Welcome, Super Admin",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Overview of your bus tracking system at a glance.",
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          // Metrics Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMetricCard(
                    icon: Icons.school, label: "Schools", value: schools),
                const SizedBox(width: 16),
                _buildMetricCard(
                    icon: Icons.directions_bus, label: "Buses", value: buses),
                const SizedBox(width: 16),
                _buildMetricCard(
                    icon: Icons.person, label: "Drivers", value: drivers),
                const SizedBox(width: 16),
                _buildMetricCard(
                    icon: Icons.child_care, label: "Students", value: students),
                const SizedBox(width: 16),
                _buildMetricCard(
                    icon: Icons.directions_bus_filled,
                    label: "Active Buses",
                    value: activeBuses,
                    color: Colors.green[50],
                    iconColor: Colors.green[700]),
              ],
            ),
          ),
          const SizedBox(height: 28),
          // System Health
          _buildSystemHealthCard(),
          const SizedBox(height: 28),
          // Recent Activity and Quick Actions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRecentSchools(),
                const SizedBox(width: 24),
                _buildRecentPayments(),
                const SizedBox(width: 24),
                _buildQuickActions(context),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
