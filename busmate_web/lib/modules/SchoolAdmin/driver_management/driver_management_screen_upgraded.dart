import 'package:busmate_web/modules/SchoolAdmin/driver_management/add_driver_screen_upgraded.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'driver_controller.dart';
import 'driver_model.dart';
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_management_controller.dart';

class DriverManagementScreenUpgraded extends StatefulWidget {
  final String? schoolId;
  final bool fromSuperAdmin;

  const DriverManagementScreenUpgraded({
    super.key,
    this.schoolId,
    this.fromSuperAdmin = false,
  });

  @override
  State<DriverManagementScreenUpgraded> createState() => _DriverManagementScreenUpgradedState();
}

class _DriverManagementScreenUpgradedState extends State<DriverManagementScreenUpgraded> {
  late final DriverController controller;
  late final BusController busController;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments as Map<String, dynamic>?;
    final effectiveSchoolId = widget.schoolId ?? arguments?['schoolId'];

    controller = Get.put(
      DriverController(),
      tag: effectiveSchoolId ?? 'default',
    );
    
    busController = Get.put(
      BusController(),
      tag: effectiveSchoolId ?? 'default',
    );

    if (effectiveSchoolId != null && effectiveSchoolId.isNotEmpty) {
      controller.schoolId = effectiveSchoolId;
      busController.schoolId = effectiveSchoolId;
      controller.fetchDrivers();
      busController.fetchBuses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStatsCards(),
          _buildSearchBar(),
          Expanded(child: _buildDriverList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Get.to(() => const AddDriverScreenUpgraded(), arguments: {
            'schoolId': controller.schoolId,
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Driver'),
        backgroundColor: const Color(0xFF2196F3),
        elevation: 4,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1A1A1A),
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.person_pin, color: Colors.blue[700], size: 24),
          ),
          const SizedBox(width: 12),
          const Text(
            'Driver Management',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => controller.fetchDrivers(),
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildStatsCards() {
    return Obx(() {
      final drivers = controller.drivers;
      final totalDrivers = drivers.length;
      final availableDrivers = drivers.where((d) => d.available).length;
      final assignedDrivers = drivers.where((d) => d.assignedBusId != null && d.assignedBusId!.isNotEmpty).length;

      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Drivers',
                totalDrivers.toString(),
                Icons.group,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Available',
                availableDrivers.toString(),
                Icons.check_circle,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Assigned',
                assignedDrivers.toString(),
                Icons.assignment_ind,
                Colors.orange,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search by driver name or license number...',
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

  Widget _buildDriverList() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      
      if (controller.filteredDrivers.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No drivers found',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: controller.filteredDrivers.length,
        itemBuilder: (context, index) {
          final driver = controller.filteredDrivers[index];
          return _buildDriverCard(driver);
        },
      );
    });
  }

  Widget _buildDriverCard(Driver driver) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Show driver details dialog
          _showDriverDetailsDialog(driver);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Profile Image
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[100]!, width: 2),
                    ),
                    child: driver.profileImageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              driver.profileImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.person, size: 30, color: Colors.blue[700]),
                            ),
                          )
                        : Icon(Icons.person, size: 30, color: Colors.blue[700]),
                  ),
                  const SizedBox(width: 16),
                  
                  // Driver Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          driver.email,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Availability Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: driver.available 
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: driver.available ? Colors.green : Colors.grey,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          driver.available ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: driver.available ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          driver.available ? 'Available' : 'Busy',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: driver.available ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              
              // Driver Details
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      'License',
                      driver.licenseNumber,
                      Icons.badge,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoChip(
                      'Phone',
                      driver.contactInfo,
                      Icons.phone,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              
              if (driver.assignedBusId != null && driver.assignedBusId!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Obx(() {
                  // Find the bus by ID and display bus number
                  final busList = busController.buses.where((b) => b.id == driver.assignedBusId).toList();
                  final bus = busList.isNotEmpty ? busList.first : null;
                  final busDisplayText = bus != null 
                      ? 'Bus ${bus.busNo} - ${bus.busVehicleNo}'
                      : driver.assignedBusId!;
                  
                  return _buildInfoChip(
                    'Assigned Bus',
                    busDisplayText,
                    Icons.directions_bus,
                    Colors.orange,
                    fullWidth: true,
                  );
                }),
              ],
              
              // Action Buttons (available to both Superior and School Admins)
              const SizedBox(height: 16),
              Row(
                children: [
                    Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Get.to(() => const AddDriverScreenUpgraded(), arguments: {
                          'isEdit': true,
                          'driver': driver,
                          'schoolId': controller.schoolId,
                        });
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue[700],
                        side: BorderSide(color: Colors.blue[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmDelete(driver),
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[700],
                          side: BorderSide(color: Colors.red[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon, Color color, {bool fullWidth = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDriverDetailsDialog(Driver driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person, color: Colors.blue[700]),
            const SizedBox(width: 8),
            const Text('Driver Details'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Name', driver.name),
            _buildDetailRow('Email', driver.email),
            _buildDetailRow('License', driver.licenseNumber),
            _buildDetailRow('Phone', driver.contactInfo),
            _buildDetailRow('Status', driver.available ? 'Available' : 'Busy'),
            if (driver.assignedBusId != null && driver.assignedBusId!.isNotEmpty)
              _buildDetailRow('Assigned Bus', driver.assignedBusId!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Driver driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Driver'),
        content: Text('Are you sure you want to delete ${driver.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              controller.deleteDriver(driver.id);
              Navigator.pop(context);
              Get.snackbar(
                'Success',
                'Driver deleted successfully',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
