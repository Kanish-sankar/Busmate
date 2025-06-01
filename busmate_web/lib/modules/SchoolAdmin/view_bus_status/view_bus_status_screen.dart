import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_management_controller.dart';
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ViewBusStatusScreen extends StatelessWidget {
  final BusController controller = Get.put(BusController());

  ViewBusStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Bus Status'),
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
            controller
                .fetchBusStatus(bus.id); // Start listening to real-time updates
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                title: Text('Bus No: ${bus.busNo}'),
                subtitle: Obx(() {
                  final status = controller.busStatuses[bus.id];
                  if (status != null && status.currentStatus == 'Active') {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status: ${status.currentStatus}'),
                        Text(
                            'Speed: ${status.currentSpeed?.toStringAsFixed(2) ?? "0"} km/h'),
                        Text(
                            'Estimated Arrival: ${status.estimatedArrival?.toStringAsFixed(2) ?? "N/A"} minutes'),
                        Text(
                            'Location: Lat ${status.latitude}, Lon ${status.longitude}'),
                      ],
                    );
                  } else if (status != null) {
                    return Text(
                        'Status: ${status.currentStatus ?? "Inactive"}');
                  } else {
                    return const Text('Bus status not available.');
                  }
                }),
              ),
            );
          },
        );
      }),
    );
  }
}
