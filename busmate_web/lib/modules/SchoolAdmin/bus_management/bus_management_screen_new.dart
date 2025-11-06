import 'package:busmate_web/modules/SchoolAdmin/bus_management/add_bus.dart';
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_management_controller.dart';
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BusManagementScreenNew extends StatefulWidget {
  final String? schoolId;

  const BusManagementScreenNew({super.key, this.schoolId});

  @override
  State<BusManagementScreenNew> createState() => _BusManagementScreenNewState();
}

class _BusManagementScreenNewState extends State<BusManagementScreenNew> {
  late final BusController controller;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments as Map<String, dynamic>?;
    final effectiveSchoolId = widget.schoolId ?? arguments?['schoolId'];
    
    print('🔍 BusManagementScreen - schoolId param: ${widget.schoolId}');
    print('🔍 BusManagementScreen - Get.arguments: $arguments');
    print('🔍 BusManagementScreen - effectiveSchoolId: $effectiveSchoolId');
    
    controller = Get.put(
      BusController(),
      tag: effectiveSchoolId ?? 'default',
    );
    
    if (effectiveSchoolId != null && effectiveSchoolId.isNotEmpty) {
      controller.schoolId = effectiveSchoolId;
      controller.fetchBuses();
    } else {
      print('❌ BusManagementScreen - No schoolId provided!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[500]!],
            ),
          ),
        ),
        title: const Text(
          'Bus Management',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.fetchBuses(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Section
          _buildStatsSection(),
          
          // Filter Section
          _buildFilterSection(),
          
          // Buses Grid
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final buses = controller.filteredBuses;
              
              if (buses.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_bus, size: 80, color: Colors.grey[400]),
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
                      Text(
                        'Click the + button to add your first bus',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }
              
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: buses.map((bus) => SizedBox(
                      width: (MediaQuery.of(context).size.width - 80) / 3,
                      child: _buildBusCard(bus),
                    )).toList(),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          print('➕ Navigating to AddBusScreen with schoolId: ${controller.schoolId}');
          Get.to(() => AddBusScreen(), arguments: {
            'schoolId': controller.schoolId,
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Bus'),
        backgroundColor: Colors.blue[700],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Obx(() {
      final buses = controller.buses;
      final totalBuses = buses.length;
      final activeBuses = buses.where((b) => b.status == 'active').length;
      final busesWithDriver = buses.where((b) => b.hasDriver).length;
      final busesWithRoute = buses.where((b) => b.hasRoute).length;
      
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Buses',
                totalBuses.toString(),
                Icons.directions_bus,
                Colors.blue,
              ),
            ),
            Expanded(
              child: _buildStatCard(
                'Active',
                activeBuses.toString(),
                Icons.check_circle,
                Colors.green,
              ),
            ),
            Expanded(
              child: _buildStatCard(
                'With Driver',
                busesWithDriver.toString(),
                Icons.person,
                Colors.orange,
              ),
            ),
            Expanded(
              child: _buildStatCard(
                'With Route',
                busesWithRoute.toString(),
                Icons.route,
                Colors.purple,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          const Text(
            'Filter: ',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          _buildFilterChip('All', 'all'),
          _buildFilterChip('Active', 'active'),
          _buildFilterChip('Needs Setup', 'needs_setup'),
          _buildFilterChip('Maintenance', 'maintenance'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Obx(() => FilterChip(
        label: Text(label),
        selected: controller.selectedFilter.value == value,
        onSelected: (selected) {
          controller.selectedFilter.value = value;
        },
        selectedColor: Colors.blue[100],
        checkmarkColor: Colors.blue[700],
      )),
    );
  }

  Widget _buildBusCard(Bus bus) {
    final statusColor = bus.status == 'active'
        ? Colors.green
        : bus.status == 'maintenance'
            ? Colors.orange
            : Colors.grey;
    
    final needsSetup = !bus.hasDriver || !bus.hasRoute;
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showBusDetails(bus),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with bus number and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.directions_bus, color: Colors.blue[700], size: 28),
                      const SizedBox(width: 8),
                      Text(
                        bus.busNo,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      bus.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Vehicle number
              Row(
                children: [
                  Icon(Icons.confirmation_number, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      bus.busVehicleNo,
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Student count
              Row(
                children: [
                  Icon(Icons.people, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${bus.assignedStudents.length} students assigned',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ),
              
              const Divider(height: 20),
              
              // Setup status indicators
              Row(
                children: [
                  _buildStatusIndicator(
                    bus.hasDriver ? 'Driver' : 'No Driver',
                    bus.hasDriver ? Icons.check_circle : Icons.warning,
                    bus.hasDriver ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusIndicator(
                    bus.hasRoute ? 'Route' : 'No Route',
                    bus.hasRoute ? Icons.check_circle : Icons.warning,
                    bus.hasRoute ? Colors.green : Colors.orange,
                  ),
                ],
              ),
              
              if (needsSetup) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Setup incomplete',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBusDetails(Bus bus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.directions_bus, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Text('Bus ${bus.busNo}'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Vehicle Number', bus.busVehicleNo),
              _buildDetailRow('GPS Type', bus.gpsType),
              if (bus.gpsDeviceId != null)
                _buildDetailRow('GPS Device ID', bus.gpsDeviceId!),
              const Divider(height: 24),
              _buildDetailRow('Driver', bus.driverName ?? 'Not Assigned'),
              if (bus.driverPhone != null)
                _buildDetailRow('Driver Phone', bus.driverPhone!),
              const Divider(height: 24),
              _buildDetailRow('Route', bus.routeName ?? 'Not Assigned'),
              _buildDetailRow('Students', '${bus.assignedStudents.length} assigned'),
              const Divider(height: 24),
              _buildDetailRow('Status', bus.status),
              _buildDetailRow('Created', _formatDate(bus.createdAt)),
              if (bus.notes != null && bus.notes!.isNotEmpty)
                _buildDetailRow('Notes', bus.notes!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Get.back();
              // TODO: Navigate to edit screen
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
