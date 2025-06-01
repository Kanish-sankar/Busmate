import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_management_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'bus_model.dart';

// ignore: must_be_immutable
class AddBusScreen extends StatelessWidget {
  final BusController controller = Get.put(BusController());
  final _formKey = GlobalKey<FormState>();
  final TextEditingController busNoController = TextEditingController();
  final TextEditingController busVehicleNoController = TextEditingController();
  final TextEditingController routeNameController = TextEditingController();
  String gpsType = 'Software';
  final bool isEdit;
  final Bus? bus;

  AddBusScreen({super.key})
      : isEdit = Get.arguments?['isEdit'] ?? false,
        bus = Get.arguments?['bus'];

  void _addBus() {
    if (_formKey.currentState!.validate()) {
      // Create a new Bus instance without driver info.
      final newBus = Bus(
        id: '', // Controller will generate a new ID
        busNo: busNoController.text.trim(),
        busVehicleNo: busVehicleNoController.text.trim(),
        // Remove driverName and driverId fields from the creation process.
        driverName: '',
        driverId: '',
        routeName: routeNameController.text.trim(),
        stoppings: [], // You can add stoppings later.
        students: [], // You can assign students later.
        gpsType: gpsType,
      );
      controller.addBus(newBus);
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isEdit && bus != null) {
      busNoController.text = bus!.busNo;
      busVehicleNoController.text = bus!.busVehicleNo;
      routeNameController.text = bus!.routeName;
      gpsType = bus!.gpsType;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Bus' : 'Add Bus'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: busNoController,
                decoration: const InputDecoration(
                  labelText: 'Bus Number',
                  border: OutlineInputBorder(),
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
                decoration: const InputDecoration(
                  labelText: 'Bus Vehicle Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a bus vehicle number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: routeNameController,
                decoration: const InputDecoration(
                  labelText: 'Route Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a route name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: gpsType,
                decoration: const InputDecoration(
                  labelText: 'GPS Type',
                  border: OutlineInputBorder(),
                ),
                items: ['Software', 'Hardware']
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) gpsType = value;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (isEdit && bus != null) {
                    final updatedBus = Bus(
                      id: bus!.id,
                      busNo: busNoController.text.trim(),
                      busVehicleNo: busVehicleNoController.text.trim(),
                      driverName: bus!.driverName,
                      driverId: bus!.driverId,
                      routeName: routeNameController.text.trim(),
                      stoppings: bus!.stoppings,
                      students: bus!.students,
                      gpsType: gpsType,
                    );
                    controller.updateBus(bus!.id, updatedBus);
                  } else {
                    _addBus();
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(isEdit ? 'Update Bus' : 'Add Bus'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
