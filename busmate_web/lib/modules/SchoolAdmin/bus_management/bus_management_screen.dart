import 'package:busmate_web/modules/SchoolAdmin/bus_management/add_bus.dart';
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_management_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'bus_model.dart';

class BusManagementScreen extends StatelessWidget {
  final String? schoolId;
  late final BusController controller;

  BusManagementScreen({super.key, this.schoolId}) {
    // Initialize controller with schoolId passed as parameter OR from Get.arguments
    final arguments = Get.arguments as Map<String, dynamic>?;
    final effectiveSchoolId = schoolId ?? arguments?['schoolId'];
    
    print('🔍 BusManagementScreen - schoolId param: $schoolId');
    print('🔍 BusManagementScreen - Get.arguments: $arguments');
    print('🔍 BusManagementScreen - effectiveSchoolId: $effectiveSchoolId');
    
    // Put controller with tag to avoid conflicts
    controller = Get.put(
      BusController(),
      tag: effectiveSchoolId ?? 'default',
    );
    
    // Set the schoolId in controller if provided
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
      appBar: AppBar(
        title: const Text('Bus Management'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by Bus Number',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                controller.searchText.value = value;
              },
            ),
          ),
          // List of Buses
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView.builder(
                itemCount: controller.filteredBuses.length,
                itemBuilder: (context, index) {
                  final Bus bus = controller.filteredBuses[index];
                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      title: Text('Bus No: ${bus.busNo} - ${bus.routeName}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bus ID: ${bus.id}'),
                          Text('Driver: ${bus.driverName} (${bus.driverId})'),
                          Text('GPS Type: ${bus.gpsType}'),
                          Row(
                            children: [
                              // View stoppings
                              TextButton(
                                onPressed: () {
                                  showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                            title: const Text('Stoppings'),
                                            content: SizedBox(
                                              width: double.maxFinite,
                                              child: ListView(
                                                children: bus.stoppings
                                                    .map((stop) => ListTile(
                                                          title: Text(
                                                              stop['name']),
                                                        ))
                                                    .toList(),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Close'),
                                              ),
                                            ],
                                          ));
                                },
                                child: Text(
                                    'Stoppings (${bus.stoppings.length}) View'),
                              ),
                              // View students
                              TextButton(
                                onPressed: () {
                                  showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                            title: const Text('Students'),
                                            content: SizedBox(
                                              width: double.maxFinite,
                                              child: ListView(
                                                children: bus.assignedStudents
                                                    .map((student) => ListTile(
                                                          title: Text(student),
                                                        ))
                                                    .toList(),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Close'),
                                              ),
                                            ],
                                          ));
                                },
                                child: Text(
                                    'Students (${bus.assignedStudents.length}) View'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              Get.to(() => AddBusScreen(), arguments: {
                                'isEdit': true,
                                'bus': bus,
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              controller.deleteBus(bus.id);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
      // Add Bus Floating Button
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          print('➕ Navigating to AddBusScreen with schoolId: ${controller.schoolId}');
          Get.to(() => AddBusScreen(), arguments: {
            'schoolId': controller.schoolId,
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
