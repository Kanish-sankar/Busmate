// const String _kGoogleApiKey = 'AIzaSyACcNb80veAupNPLmXdEV64i4Hd7rgVLw0';

// route_management_screen.dart
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_model.dart';
import 'package:busmate_web/modules/SchoolAdmin/route_management/route_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

// Import the new location search component
import 'location_search_field.dart';

class RouteManagementScreen extends StatelessWidget {
  final Bus selectedBus;
  final RouteController routeController = Get.put(RouteController());

  RouteManagementScreen({super.key, required this.selectedBus}) {
    // Ensure schoolId is passed in arguments
    final arguments = Get.arguments as Map<String, dynamic>?;
    if (arguments != null && arguments['schoolId'] != null) {
      routeController.init(selectedBus.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    const LatLng defaultCenter = LatLng(11.0168, 76.9558); // Coimbatore, India

    return Scaffold(
      appBar: AppBar(
        title: Text('Route Management for Bus ${selectedBus.busNo}'),
        // actions: [
        // Add save button to confirm route changes
        // IconButton(
        //   icon: const Icon(Icons.save),
        //   onPressed: () {
        //     routeController();
        //     Get.snackbar(
        //       'Success',
        //       'Route saved successfully!',
        //       backgroundColor: Colors.green.withOpacity(0.1),
        //       colorText: Colors.green,
        //     );
        //   },
        // ),
        // ],
      ),
      body: Column(
        children: [
          // Distance indicator
          Obx(() {
            final km = routeController.calculateDistance() / 1000;
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.route, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Total Route Distance: ${km.toStringAsFixed(2)} km',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),

          // Location search field using the new component
          LocationSearchField(
            onLocationSelected: (name, location) {
              routeController.addStop(Stop(name: name, location: location));
              // Update the map view to show the new location
              routeController.updateRoutePolyline();
            },
          ),

          // Map displaying stops and the route
          Expanded(
            flex: 2,
            child: Obx(() {
              // Calculate the center of the map based on stops or use default
              LatLng center = routeController.stops.isNotEmpty
                  ? routeController.stops.first.location
                  : defaultCenter;

              List<Widget> mapChildren = [
                // Base map tiles
                TileLayer(
                  urlTemplate:
                      "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: const ['a', 'b', 'c'],
                  tileProvider: CancellableNetworkTileProvider(),
                ),
              ];

              // Add markers for each stop
              if (routeController.stops.isNotEmpty) {
                mapChildren.add(
                  MarkerLayer(
                    markers: routeController.stops.asMap().entries.map((entry) {
                      int index = entry.key;
                      Stop stop = entry.value;
                      return Marker(
                        width: 80.0,
                        height: 80.0,
                        point: stop.location,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 30,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              }

              // Draw the route polyline
              if (routeController.routePolyline.isNotEmpty) {
                mapChildren.add(
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routeController.routePolyline,
                        strokeWidth: 4.0,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                );
              }

              return FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 13.0,
                  onTap: (tapPosition, point) {
                    // Handle map tap to add new stop
                    if (routeController.isAddingStop.value) {
                      _showAddStopDialog(context, point);
                    }
                  },
                ),
                children: mapChildren,
              );
            }),
          ),

          // List of stops with drag-to-reorder capability
          Expanded(
            flex: 1,
            child: Obx(() {
              return routeController.stops.isEmpty
                  ? const Center(
                      child: Text(
                        'No stops added yet. Search for locations or tap "+" to add stops.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ReorderableListView.builder(
                      itemCount: routeController.stops.length,
                      onReorder: (oldIndex, newIndex) {
                        // Handle reordering
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final Stop item =
                            routeController.stops.removeAt(oldIndex);
                        routeController.stops.insert(newIndex, item);
                        routeController.updateRoutePolyline();
                        routeController.updateFirestore(); // <-- Save new order
                      },
                      itemBuilder: (context, index) {
                        final stop = routeController.stops[index];
                        return Card(
                          key: ValueKey(index),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue,
                              child: Text('${index + 1}'),
                            ),
                            title: Text(stop.name),
                            subtitle: Text(
                              '${stop.location.latitude.toStringAsFixed(5)}, ${stop.location.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () =>
                                      _showEditStopDialog(context, index, stop),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _showDeleteConfirmation(context, index),
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
      // Floating action button to enable "add stop" mode
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          routeController.isAddingStop.value = true;
          Get.snackbar(
            'Add Stop',
            'Tap on the map to add a new stop',
            backgroundColor: Colors.blue.withOpacity(0.1),
            duration: const Duration(seconds: 3),
          );
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add_location),
      ),
    );
  }

  // Show dialog to add a new stop
  void _showAddStopDialog(BuildContext context, LatLng point) {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Stop'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Stop Name',
                  hintText: 'Enter a name for this stop',
                  prefixIcon: Icon(Icons.location_city),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              Text(
                'Coordinates: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                routeController.isAddingStop.value = false;
                Navigator.of(context).pop();
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                String stopName = nameController.text.trim();
                if (stopName.isNotEmpty) {
                  routeController.addStop(
                    Stop(name: stopName, location: point),
                  );
                  Navigator.of(context).pop();
                } else {
                  // Show error if name is empty
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a stop name')),
                  );
                }
                routeController.isAddingStop.value = false;
              },
              child: const Text('ADD'),
            ),
          ],
        );
      },
    );
  }

  // Show dialog to edit an existing stop
  void _showEditStopDialog(BuildContext context, int index, Stop stop) {
    final TextEditingController editController =
        TextEditingController(text: stop.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Stop'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editController,
              decoration: const InputDecoration(
                labelText: 'Stop Name',
                prefixIcon: Icon(Icons.edit_location),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Coordinates: ${stop.location.latitude.toStringAsFixed(5)}, ${stop.location.longitude.toStringAsFixed(5)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              String newName = editController.text.trim();
              if (newName.isNotEmpty) {
                routeController.editStop(
                  index,
                  Stop(name: newName, location: stop.location),
                );
                Navigator.pop(context);
              } else {
                // Show error if name is empty
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a stop name')),
                );
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  // Show confirmation dialog before deleting a stop
  void _showDeleteConfirmation(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Stop'),
        content: const Text('Are you sure you want to remove this stop?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              routeController.removeStop(index);
              Navigator.pop(context);
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
}
