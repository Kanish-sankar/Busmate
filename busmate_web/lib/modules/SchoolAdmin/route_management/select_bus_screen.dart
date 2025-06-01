import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_management_controller.dart';
import 'package:busmate_web/modules/SchoolAdmin/route_management/route_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../bus_management/bus_model.dart';

class SelectBusScreen extends StatelessWidget {
  final BusController controller = Get.put(
    BusController(),
    tag: null,
  );

  SelectBusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Ensure controller.schoolId is set from arguments
    final arguments = Get.arguments as Map<String, dynamic>?;
    if (arguments != null && arguments['schoolId'] != null) {
      controller.schoolId = arguments['schoolId'];
      controller.fetchBuses();
    }
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
                subtitle: Text(bus.routeName),
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
