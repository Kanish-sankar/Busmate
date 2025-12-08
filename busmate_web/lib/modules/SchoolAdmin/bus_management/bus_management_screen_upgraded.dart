import 'package:busmate_web/modules/SchoolAdmin/bus_management/add_bus_upgraded.dart';
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_management_controller.dart';
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_model.dart';
import 'package:busmate_web/modules/Authentication/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BusManagementScreenUpgraded extends StatefulWidget {
  final String? schoolId;
  final bool fromSuperAdmin;

  const BusManagementScreenUpgraded({
    super.key,
    this.schoolId,
    this.fromSuperAdmin = false,
  });

  @override
  State<BusManagementScreenUpgraded> createState() => _BusManagementScreenUpgradedState();
}

class _BusManagementScreenUpgradedState extends State<BusManagementScreenUpgraded> with SingleTickerProviderStateMixin {
  late final BusController controller;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments as Map<String, dynamic>?;
    final effectiveSchoolId = widget.schoolId ?? arguments?['schoolId'];

    controller = Get.put(
      BusController(),
      tag: effectiveSchoolId ?? 'default',
    );

    if (effectiveSchoolId != null && effectiveSchoolId.isNotEmpty) {
      controller.schoolId = effectiveSchoolId;
      controller.fetchBuses();
    }

    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final arguments = Get.arguments as Map<String, dynamic>?;
    final fromSuperAdmin = widget.fromSuperAdmin || (arguments?['fromSuperAdmin'] ?? false);
    final shouldRestrictAccess = authController.isSchoolAdmin && !fromSuperAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(shouldRestrictAccess),
      body: Column(
        children: [
          _buildStatsCards(),
          _buildSearchAndFilter(),
          _buildTabBar(),
          Expanded(child: _buildTabContent()),
        ],
      ),
      floatingActionButton: !shouldRestrictAccess
          ? FloatingActionButton.extended(
              onPressed: () {
                Get.to(() => const AddBusScreenUpgraded(), arguments: {
                  'schoolId': controller.schoolId,
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Bus'),
              backgroundColor: const Color(0xFF2196F3),
              elevation: 4,
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(bool shouldRestrictAccess) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1A1A1A),
      automaticallyImplyLeading: false, // Remove back arrow
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.directions_bus, color: Colors.blue[700], size: 24),
          ),
          const SizedBox(width: 12),
          const Text(
            'Bus Fleet Management',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => controller.fetchBuses(),
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildStatsCards() {
    return Obx(() {
      final buses = controller.buses;
      final totalBuses = buses.length;
      final softwareBuses = buses.where((b) => b.gpsType == 'software').length;
      final hardwareBuses = buses.where((b) => b.gpsType == 'hardware').length;

      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatCard(
                'Total Buses',
                totalBuses.toString(),
                Icons.directions_bus,
                Colors.blue,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Software GPS',
                softwareBuses.toString(),
                Icons.phone_android,
                Colors.green,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Hardware GPS',
                hardwareBuses.toString(),
                Icons.gps_fixed,
                Colors.orange,
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search by bus number or vehicle number...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) => controller.searchText.value = value,
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.blue[700],
        unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.blue[700],
        indicatorWeight: 3,
        isScrollable: true,
        tabs: [
          Obx(() {
            final count = controller.buses.length;
            return Tab(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.view_list, size: 20),
                    const SizedBox(width: 8),
                    Text('All ($count)'),
                  ],
                ),
              ),
            );
          }),
          Obx(() {
            final count = controller.buses.where((b) => b.gpsType == 'software').length;
            return Tab(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone_android, size: 20),
                    const SizedBox(width: 8),
                    Text('Software ($count)'),
                  ],
                ),
              ),
            );
          }),
          Obx(() {
            final count = controller.buses.where((b) => b.gpsType == 'hardware').length;
            return Tab(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gps_fixed, size: 20),
                    const SizedBox(width: 8),
                    Text('Hardware ($count)'),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildBusList(null), // All buses
        _buildBusList('software'), // Software GPS buses
        _buildBusList('hardware'), // Hardware GPS buses
      ],
    );
  }

  Widget _buildBusList(String? gpsFilter) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      var buses = controller.filteredBuses;
      if (gpsFilter != null) {
        buses = buses.where((b) => b.gpsType == gpsFilter).toList();
      }

      if (buses.isEmpty) {
        return _buildEmptyState(gpsFilter);
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: buses.length,
        itemBuilder: (context, index) => _buildModernBusCard(buses[index]),
      );
    });
  }

  Widget _buildEmptyState(String? gpsFilter) {
    final authController = Get.find<AuthController>();
    final arguments = Get.arguments as Map<String, dynamic>?;
    final fromSuperAdmin = widget.fromSuperAdmin || (arguments?['fromSuperAdmin'] ?? false);
    final shouldRestrictAccess = authController.isSchoolAdmin && !fromSuperAdmin;

    String message = shouldRestrictAccess
        ? 'No buses available yet. Contact Superior Admin to add buses.'
        : 'Click the + button to add your first bus';

    if (gpsFilter == 'software') {
      message = shouldRestrictAccess
          ? 'No software GPS buses available yet.'
          : 'Add buses with software GPS (driver app tracking)';
    } else if (gpsFilter == 'hardware') {
      message = shouldRestrictAccess
          ? 'No hardware GPS buses available yet.'
          : 'Add buses with hardware GPS (SIM-based tracking)';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            gpsFilter == 'software' ? Icons.phone_android : 
            gpsFilter == 'hardware' ? Icons.gps_fixed : Icons.directions_bus,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No Buses Found',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernBusCard(Bus bus) {
    final authController = Get.find<AuthController>();
    final arguments = Get.arguments as Map<String, dynamic>?;
    final fromSuperAdmin = widget.fromSuperAdmin || (arguments?['fromSuperAdmin'] ?? false);
    final shouldRestrictAccess = authController.isSchoolAdmin && !fromSuperAdmin;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with bus number and type
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bus.gpsType == 'software' 
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bus.gpsType == 'software' ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    bus.gpsType == 'software' ? Icons.phone_android : Icons.gps_fixed,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bus ${bus.busNo}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        bus.busVehicleNo,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Bus details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // GPS Type badge
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        bus.gpsType == 'software' ? 'Software GPS' : 'Hardware GPS',
                        bus.gpsType == 'software' ? Icons.phone_android : Icons.gps_fixed,
                        bus.gpsType == 'software' ? Colors.green : Colors.orange,
                        subtitle: bus.gpsType == 'software' 
                            ? 'Driver App Tracking' 
                            : 'SIM-based Tracking',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Driver info
                if (bus.hasDriver)
                  _buildInfoRow(
                    Icons.person,
                    'Driver',
                    '${bus.driverName ?? 'N/A'}\n${bus.driverPhone ?? ''}',
                    Colors.blue,
                  )
                else
                  _buildInfoRow(
                    Icons.person_off,
                    'Driver',
                    'Not Assigned',
                    Colors.red,
                  ),
                
                const Divider(),
                
                // Route info
                if (bus.hasRoute)
                  _buildInfoRow(
                    Icons.route,
                    'Route',
                    '${bus.routeName}\n${bus.stoppings.length} stops',
                    Colors.purple,
                  )
                else
                  _buildInfoRow(
                    Icons.route,
                    'Route',
                    'Not Assigned',
                    Colors.red,
                  ),
                
                const Divider(),
                
                // Students info
                _buildInfoRow(
                  Icons.groups,
                  'Students',
                  '${bus.assignedStudents.length} assigned',
                  Colors.teal,
                ),
                
                if (bus.gpsDeviceId != null) ...[
                  const Divider(),
                  _buildInfoRow(
                    Icons.sim_card,
                    'GPS Device ID',
                    bus.gpsDeviceId!,
                    Colors.indigo,
                  ),
                ],
              ],
            ),
          ),
          
          // Action buttons
          if (!shouldRestrictAccess)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Get.to(() => const AddBusScreenUpgraded(), arguments: {
                        'isEdit': true,
                        'bus': bus,
                        'schoolId': controller.schoolId,
                      });
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _confirmDelete(bus),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red[700],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color color, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Bus bus) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Bus'),
        content: Text('Are you sure you want to delete Bus ${bus.busNo}?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              controller.deleteBus(bus.id);
              Get.back();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
