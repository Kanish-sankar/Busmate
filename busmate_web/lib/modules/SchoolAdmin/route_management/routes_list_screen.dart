import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:busmate_web/modules/SchoolAdmin/route_management/route_management_screen_upgraded.dart';

class RoutesListScreen extends StatefulWidget {
  final String schoolId;

  const RoutesListScreen({super.key, required this.schoolId});

  @override
  State<RoutesListScreen> createState() => _RoutesListScreenState();
}

class _RoutesListScreenState extends State<RoutesListScreen> {
  final TextEditingController _routeNameController = TextEditingController();
  
  @override
  void dispose() {
    _routeNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.route, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Route Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Manage all routes',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('schooldetails')
            .doc(widget.schoolId)
            .collection('routes')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final routes = snapshot.data?.docs ?? [];

          if (routes.isEmpty) {
            return _buildEmptyState();
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 400,
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: routes.length,
              itemBuilder: (context, index) {
                final routeDoc = routes[index];
                final routeData = routeDoc.data() as Map<String, dynamic>;
                return _buildRouteCard(routeDoc.id, routeData);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRouteDialog,
        icon: const Icon(Icons.add_road),
        label: const Text('Create New Route'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.route_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No Routes Created',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first route to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateRouteDialog,
            icon: const Icon(Icons.add_road),
            label: const Text('Create Route'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(String routeId, Map<String, dynamic> routeData) {
    final routeName = routeData['routeName'] ?? 'Unnamed Route';
    final assignedBusId = routeData['assignedBusId'] as String?;
    final stopCount = (routeData['stops'] as List?)?.length ?? 0;
    final totalDistance = (routeData['totalDistance'] as num?)?.toDouble() ?? 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openRouteManagement(routeId, routeName),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.route, color: Colors.blue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routeName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (assignedBusId != null)
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('schooldetails')
                                .doc(widget.schoolId)
                                .collection('buses')
                                .doc(assignedBusId)
                                .get(),
                            builder: (context, busSnapshot) {
                              if (busSnapshot.hasData && busSnapshot.data!.exists) {
                                final busData = busSnapshot.data!.data() as Map<String, dynamic>;
                                return Row(
                                  children: [
                                    Icon(Icons.directions_bus, size: 14, color: Colors.green[700]),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Bus ${busData['busNo']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return Text(
                                'No bus assigned',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              );
                            },
                          )
                        else
                          Text(
                            'No bus assigned',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteRoute(routeId, routeName);
                      } else if (value == 'rename') {
                        _renameRoute(routeId, routeName);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Rename'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              // Stats
              Row(
                children: [
                  _buildStatChip(
                    icon: Icons.location_on,
                    value: stopCount.toString(),
                    label: 'Stops',
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    icon: Icons.straighten,
                    value: '${(totalDistance / 1000).toStringAsFixed(1)} km',
                    label: 'Distance',
                    color: Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateRouteDialog() async {
    _routeNameController.clear();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_road, color: Colors.blue),
            SizedBox(width: 12),
            Text('Create New Route'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter a name for the new route:'),
            const SizedBox(height: 16),
            TextField(
              controller: _routeNameController,
              decoration: InputDecoration(
                labelText: 'Route Name',
                hintText: 'e.g., Morning Route A, Route 101',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.route),
              ),
              autofocus: true,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.of(context).pop(value.trim());
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_routeNameController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(_routeNameController.text.trim());
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _createRoute(result);
    }
  }

  Future<void> _createRoute(String routeName) async {
    try {
      // Create route document
      final routeRef = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(widget.schoolId)
          .collection('routes')
          .add({
        'routeName': routeName,
        'assignedBusId': null,
        // Legacy (some screens still read `stops`)
        'stops': [],
        // New schema used by RouteController
        'upStops': [],
        'downStops': [],
        'upDistance': 0,
        'downDistance': 0,
        'totalDistance': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Get.snackbar(
        '✅ Route Created',
        'Route "$routeName" has been created successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.9),
        colorText: Colors.white,
      );

      // Open route management
      _openRouteManagement(routeRef.id, routeName);
    } catch (e) {
      Get.snackbar(
        '❌ Error',
        'Failed to create route: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }

  void _openRouteManagement(String routeId, String routeName) {
    Get.to(
      () => RouteManagementScreenUpgraded(
        routeId: routeId,
        routeName: routeName,
        schoolId: widget.schoolId,
      ),
      arguments: {
        'routeId': routeId,
        'routeName': routeName,
        'schoolId': widget.schoolId,
      },
    );
  }

  Future<void> _renameRoute(String routeId, String currentName) async {
    _routeNameController.text = currentName;
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.blue),
            SizedBox(width: 12),
            Text('Rename Route'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter a new name for the route:'),
            const SizedBox(height: 16),
            TextField(
              controller: _routeNameController,
              decoration: InputDecoration(
                labelText: 'Route Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.route),
              ),
              autofocus: true,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.of(context).pop(value.trim());
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_routeNameController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(_routeNameController.text.trim());
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != currentName) {
      try {
        await FirebaseFirestore.instance
            .collection('schooldetails')
            .doc(widget.schoolId)
            .collection('routes')
            .doc(routeId)
            .update({
          'routeName': result,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        Get.snackbar(
          '✅ Route Renamed',
          'Route renamed to "$result"',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.withOpacity(0.9),
          colorText: Colors.white,
        );
      } catch (e) {
        Get.snackbar(
          '❌ Error',
          'Failed to rename route: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.9),
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _deleteRoute(String routeId, String routeName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 12),
            Text('Delete Route'),
          ],
        ),
        content: Text('Are you sure you want to delete "$routeName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('schooldetails')
            .doc(widget.schoolId)
            .collection('routes')
            .doc(routeId)
            .delete();

        Get.snackbar(
          '✅ Route Deleted',
          '"$routeName" has been deleted',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.withOpacity(0.9),
          colorText: Colors.white,
        );
      } catch (e) {
        Get.snackbar(
          '❌ Error',
          'Failed to delete route: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.9),
          colorText: Colors.white,
        );
      }
    }
  }
}
