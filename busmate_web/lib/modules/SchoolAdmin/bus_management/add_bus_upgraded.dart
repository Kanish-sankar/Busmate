import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_management_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'bus_model.dart';

class AddBusScreenUpgraded extends StatefulWidget {
  const AddBusScreenUpgraded({super.key});

  @override
  State<AddBusScreenUpgraded> createState() => _AddBusScreenUpgradedState();
}

class _AddBusScreenUpgradedState extends State<AddBusScreenUpgraded> {
  late final BusController controller;
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController busNoController = TextEditingController();
  final TextEditingController busVehicleNoController = TextEditingController();
  final TextEditingController gpsDeviceIdController = TextEditingController();
  
  String gpsType = 'software';
  
  late final bool isEdit;
  late final Bus? bus;

  @override
  void initState() {
    super.initState();
    // Get schoolId from arguments to find the tagged controller
    final schoolId = Get.arguments?['schoolId'];
    controller = Get.find<BusController>(tag: schoolId ?? 'default');
    isEdit = Get.arguments?['isEdit'] ?? false;
    bus = Get.arguments?['bus'];
    
    if (isEdit && bus != null) {
      busNoController.text = bus!.busNo;
      busVehicleNoController.text = bus!.busVehicleNo;
      gpsDeviceIdController.text = bus!.gpsDeviceId ?? '';
      gpsType = bus!.gpsType;
    }
  }

  @override
  void dispose() {
    busNoController.dispose();
    busVehicleNoController.dispose();
    gpsDeviceIdController.dispose();
    super.dispose();
  }

  void _saveBus() {
    if (_formKey.currentState!.validate()) {
      if (isEdit && bus != null) {
        final updatedBus = bus!.copyWith(
          busNo: busNoController.text.trim(),
          busVehicleNo: busVehicleNoController.text.trim(),
          gpsType: gpsType,
          gpsDeviceId: gpsType == 'hardware' ? gpsDeviceIdController.text.trim() : null,
          updatedAt: DateTime.now(),
        );
        controller.updateBus(bus!.id, updatedBus);
      } else {
        final newBus = Bus(
          id: '',
          schoolId: controller.schoolId,
          busNo: busNoController.text.trim(),
          busVehicleNo: busVehicleNoController.text.trim(),
          gpsType: gpsType,
          gpsDeviceId: gpsType == 'hardware' ? gpsDeviceIdController.text.trim() : null,
          createdAt: DateTime.now(),
        );
        controller.addBus(newBus);
      }
      Get.back();
      Get.snackbar(
        'Success',
        isEdit ? 'Bus updated successfully' : 'Bus added successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        automaticallyImplyLeading: false, // Remove back button
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isEdit ? Icons.edit : Icons.add,
                color: Colors.blue[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isEdit ? 'Edit Bus' : 'Add New Bus',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _saveBus,
            icon: const Icon(Icons.check),
            label: Text(isEdit ? 'Update' : 'Save'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue[700],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // GPS Type Selection Card
            _buildGPSTypeCard(),
            const SizedBox(height: 24),
            
            // Basic Information Card
            _buildBasicInfoCard(),
            const SizedBox(height: 24),
            
            // GPS Configuration Card (conditional)
            if (gpsType == 'hardware') _buildHardwareGPSCard(),
            if (gpsType == 'hardware') const SizedBox(height: 24),
            
            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildGPSTypeCard() {
    return Container(
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gps_fixed, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Text(
                'GPS Tracking Type',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildGPSTypeOption(
                  'software',
                  'Software GPS',
                  'Driver App Tracking',
                  Icons.phone_android,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildGPSTypeOption(
                  'hardware',
                  'Hardware GPS',
                  'SIM-based Tracking',
                  Icons.gps_fixed,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGPSTypeOption(String value, String title, String subtitle, IconData icon, Color color) {
    final isSelected = gpsType == value;
    return InkWell(
      onTap: () => setState(() => gpsType = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey[400],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? color : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return Container(
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Text(
                'Basic Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: busNoController,
            decoration: InputDecoration(
              labelText: 'Bus Number *',
              hintText: 'e.g., BUS-001',
              prefixIcon: const Icon(Icons.directions_bus),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a bus number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: busVehicleNoController,
            decoration: InputDecoration(
              labelText: 'Vehicle Registration Number *',
              hintText: 'e.g., TN-01-AB-1234',
              prefixIcon: const Icon(Icons.confirmation_number),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter vehicle registration number';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareGPSCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sim_card, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hardware GPS Configuration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'SIM-based GPS tracking device details',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: gpsDeviceIdController,
            decoration: InputDecoration(
              labelText: 'GPS Device ID / SIM Number *',
              hintText: 'Enter GPS device identifier or SIM number',
              prefixIcon: const Icon(Icons.sim_card_outlined),
              filled: true,
              fillColor: Colors.orange.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.orange.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.orange, width: 2),
              ),
            ),
            validator: (value) {
              if (gpsType == 'hardware' && (value == null || value.trim().isEmpty)) {
                return 'GPS Device ID is required for hardware GPS';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'This bus will use an integrated GPS device with SIM card for real-time tracking.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Get.back(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.grey[400]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _saveBus,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue[700],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 20),
                const SizedBox(width: 8),
                Text(
                  isEdit ? 'Update Bus' : 'Add Bus',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
