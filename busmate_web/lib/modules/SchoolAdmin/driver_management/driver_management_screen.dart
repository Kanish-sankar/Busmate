// driver_management_screen.dart
import 'package:busmate_web/modules/SchoolAdmin/driver_management/add_driver_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'driver_controller.dart';
import 'driver_model.dart';

class DriverManagementScreen extends StatelessWidget {
  final String? schoolId;
  late final DriverController controller;

  DriverManagementScreen({super.key, this.schoolId}) {
    // Initialize controller with schoolId passed as parameter OR from Get.arguments
    final arguments = Get.arguments as Map<String, dynamic>?;
    final effectiveSchoolId = schoolId ?? arguments?['schoolId'];
    
    print('🔍 DriverManagementScreen - schoolId param: $schoolId');
    print('🔍 DriverManagementScreen - Get.arguments: $arguments');
    print('🔍 DriverManagementScreen - effectiveSchoolId: $effectiveSchoolId');
    
    // Put controller with tag to avoid conflicts between different school instances
    controller = Get.put(
      DriverController(),
      tag: effectiveSchoolId ?? 'default',
    );
    
    // Set the schoolId in controller if provided
    if (effectiveSchoolId != null) {
      controller.schoolId = effectiveSchoolId;
      controller.fetchDrivers();
    } else {
      print('❌ DriverManagementScreen - No schoolId provided!');
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Management'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search drivers by name',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                controller.searchText.value = value;
              },
            ),
          ),
          // Driver List
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.filteredDrivers.isEmpty) {
                return const Center(child: Text('No drivers found'));
              }
              return ListView.builder(
                itemCount: controller.filteredDrivers.length,
                itemBuilder: (context, index) {
                  final Driver driver = controller.filteredDrivers[index];
                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      leading: driver.profileImageUrl.isNotEmpty
                          ? CircleAvatar(
                              backgroundImage:
                                  NetworkImage(driver.profileImageUrl),
                            )
                          : const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(driver.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('License: ${driver.licenseNumber}'),
                          Text('Contact: ${driver.contactInfo}'),
                          Text('Bus: ${driver.assignedBusId}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              Get.to(() => AddDriverScreen(), arguments: {
                                'isEdit': true,
                                'driver': driver,
                                'schoolId':
                                    controller.schoolId, // pass schoolId
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              controller.deleteDriver(driver.id);
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(() => AddDriverScreen(), arguments: {
            'schoolId': controller.schoolId, // pass schoolId
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
