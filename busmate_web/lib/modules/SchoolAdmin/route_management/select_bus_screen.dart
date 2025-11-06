import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_management_controller.dart';
import 'package:busmate_web/modules/SchoolAdmin/route_management/route_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../bus_management/bus_model.dart';

class SelectBusScreen extends StatelessWidget {
  final String? schoolId;
  late final BusController controller;

  SelectBusScreen({super.key, this.schoolId}) {
    // Initialize controller with schoolId passed as parameter OR from Get.arguments
    final arguments = Get.arguments as Map<String, dynamic>?;
    final effectiveSchoolId = schoolId ?? arguments?['schoolId'];
    
    // Put controller with tag to avoid conflicts
    controller = Get.put(
      BusController(),
      tag: effectiveSchoolId ?? 'default',
    );
    
    // Set the schoolId in controller if provided
    if (effectiveSchoolId != null && effectiveSchoolId.isNotEmpty) {
      controller.schoolId = effectiveSchoolId;
      controller.fetchBuses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Bus to Manage Route'),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.buses.isEmpty) {
          return const Center(child: Text('No buses available.'));
        }
        return ListView.builder(
          itemCount: controller.buses.length,
          itemBuilder: (context, index) {
            final Bus bus = controller.buses[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                title: Text('Bus No: ${bus.busNo}'),
                subtitle: Text(bus.routeName ?? 'No route assigned'),
                onTap: () {
                  // Pass the schoolId when navigating to RouteManagementScreen.
                  Get.to(
                    () => RouteManagementScreen(selectedBus: bus),
                    arguments: {'schoolId': controller.schoolId},
                  );
                },
              ),
            );
          },
        );
      }),
    );
  }
}
