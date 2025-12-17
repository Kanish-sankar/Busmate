import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';
import 'route_schedule_model.dart';
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_model.dart';

class TimeControlScreen extends StatefulWidget {
  final String schoolId;

  const TimeControlScreen({super.key, required this.schoolId});

  @override
  State<TimeControlScreen> createState() => _TimeControlScreenState();
}

class _TimeControlScreenState extends State<TimeControlScreen> {
  bool isLoading = true;
  List<RouteSchedule> schedules = [];
  List<Bus> buses = [];

  Bus? _findBus(String busId) {
    try {
      return buses.firstWhere((b) => b.id == busId);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      // Load buses
      final busSnapshot = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(widget.schoolId)
          .collection('buses')
          .get();
      buses = busSnapshot.docs.map((doc) => Bus.fromDocument(doc)).toList();

      // Load route schedules
      final scheduleSnapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('route_schedules')
          .get();
      schedules = scheduleSnapshot.docs
          .map((doc) => RouteSchedule.fromDocument(doc))
          .toList();

      setState(() => isLoading = false);
    } catch (e) {
      print('Error loading data: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Control - Route Schedules',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle),
            onPressed: () => _showAddScheduleDialog(),
            tooltip: 'Add New Schedule',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : schedules.isEmpty
              ? _buildEmptyState()
              : _buildScheduleList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'No route schedules configured',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 10),
          Text(
            'Create schedules to enable automatic route activation',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => _showAddScheduleDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Create First Schedule'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        final schedule = schedules[index];
        return _buildScheduleCard(schedule);
      },
    );
  }

  Widget _buildScheduleCard(RouteSchedule schedule) {
    final isPickup = schedule.direction == 'pickup';
    final color = isPickup ? Colors.blue : Colors.orange;
    final bus = _findBus(schedule.busId);
    final busLabel = (bus != null)
        ? '${bus.busNo} (${bus.busVehicleNo})'
        : (schedule.busVehicleNo.isNotEmpty
            ? schedule.busVehicleNo
            : schedule.busId);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPickup ? Icons.upload : Icons.download,
                  color: color,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule.routeName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bus: $busLabel',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      if ((schedule.routeRefId != null &&
                              schedule.routeRefId!.isNotEmpty) ||
                          (schedule.routeRefName != null &&
                              schedule.routeRefName!.isNotEmpty))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Route: ${schedule.routeRefName ?? 'Route'} (${schedule.routeRefId ?? 'N/A'})',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: schedule.isActive,
                  onChanged: (value) => _toggleScheduleStatus(schedule, value),
                  activeColor: Colors.green,
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow(
                  Icons.directions,
                  'Direction',
                  schedule.directionDisplayName,
                  color,
                ),
                if ((schedule.routeRefId != null &&
                        schedule.routeRefId!.isNotEmpty) ||
                    (schedule.routeRefName != null &&
                        schedule.routeRefName!.isNotEmpty)) ...[
                  const Divider(),
                  _buildDetailRow(
                    Icons.route,
                    'Assigned Route',
                    schedule.routeRefName ?? schedule.routeRefId ?? 'N/A',
                    Colors.grey[700]!,
                  ),
                ],
                const Divider(),
                _buildDetailRow(
                  Icons.access_time,
                  'Time Window',
                  '${schedule.startTime} - ${schedule.endTime}',
                  Colors.grey[700]!,
                ),
                const Divider(),
                _buildDetailRow(
                  Icons.calendar_today,
                  'Days',
                  schedule.daysOfWeekString,
                  Colors.grey[700]!,
                ),
                const Divider(),
                _buildDetailRow(
                  Icons.location_on,
                  'Stops',
                  '${schedule.stops.length} stops configured',
                  Colors.grey[700]!,
                ),
              ],
            ),
          ),

          // Actions
          OverflowBar(
            children: [
              TextButton.icon(
                onPressed: () => _showEditScheduleDialog(schedule),
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: () => _deleteSchedule(schedule),
                icon: const Icon(Icons.delete, color: Colors.red),
                label:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showAddScheduleDialog() async {
    if (buses.isEmpty) {
      Get.snackbar(
        'No Buses Available',
        'Please add buses first before creating schedules',
        backgroundColor: Colors.orange[100],
        colorText: Colors.orange[900],
      );
      return;
    }

    // Show dialog to create new schedule
    showDialog(
      context: context,
      builder: (context) => _RouteScheduleFormDialog(
        schoolId: widget.schoolId,
        buses: buses,
        onSave: _loadData,
      ),
    );
  }

  Future<void> _showEditScheduleDialog(RouteSchedule schedule) async {
    showDialog(
      context: context,
      builder: (context) => _RouteScheduleFormDialog(
        schoolId: widget.schoolId,
        buses: buses,
        schedule: schedule,
        onSave: _loadData,
      ),
    );
  }

  Future<void> _toggleScheduleStatus(
      RouteSchedule schedule, bool newStatus) async {
    try {
      // Update Firestore (source of truth)
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('route_schedules')
          .doc(schedule.id)
          .update({'isActive': newStatus});

      // Update RTDB cache for fast Cloud Function access
      await FirebaseDatabase.instance
          .ref(
              'route_schedules_cache/${widget.schoolId}/${schedule.busId}/${schedule.id}')
          .update({'isActive': newStatus});

      Get.snackbar(
        'Schedule Updated',
        'Route ${newStatus ? 'activated' : 'deactivated'} successfully',
        backgroundColor: Colors.green[100],
        colorText: Colors.green[900],
      );

      _loadData();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update schedule: $e',
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
    }
  }

  Future<void> _deleteSchedule(RouteSchedule schedule) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete Schedule'),
        content:
            Text('Are you sure you want to delete "${schedule.routeName}"?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete from Firestore
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(widget.schoolId)
            .collection('route_schedules')
            .doc(schedule.id)
            .delete();

        // Delete from RTDB cache
        await FirebaseDatabase.instance
            .ref(
                'route_schedules_cache/${widget.schoolId}/${schedule.busId}/${schedule.id}')
            .remove();

        Get.snackbar(
          'Schedule Deleted',
          'Route schedule deleted successfully',
          backgroundColor: Colors.green[100],
          colorText: Colors.green[900],
        );

        _loadData();
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to delete schedule: $e',
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
        );
      }
    }
  }
}

// Form Dialog for creating/editing schedules
class _RouteScheduleFormDialog extends StatefulWidget {
  final String schoolId;
  final List<Bus> buses;
  final RouteSchedule? schedule;
  final VoidCallback onSave;

  const _RouteScheduleFormDialog({
    required this.schoolId,
    required this.buses,
    this.schedule,
    required this.onSave,
  });

  @override
  State<_RouteScheduleFormDialog> createState() =>
      _RouteScheduleFormDialogState();
}

class _RouteScheduleFormDialogState extends State<_RouteScheduleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String? selectedBusId;
  String? selectedRouteId;
  String? selectedRouteName;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> availableRoutes = [];
  bool isLoadingRoutes = false;
  String routeName = '';
  String direction = 'pickup';
  List<int> selectedDays = [1, 2, 3, 4, 5]; // Mon-Fri default
  TimeOfDay startTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 9, minute: 0);
  bool isActive = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.schedule != null) {
      selectedBusId = widget.schedule!.busId;
      routeName = widget.schedule!.routeName;
      direction = widget.schedule!.direction;
      selectedRouteId = widget.schedule!.routeRefId;
      selectedRouteName = widget.schedule!.routeRefName;
      selectedDays = widget.schedule!.daysOfWeek;

      // Parse time
      final startParts = widget.schedule!.startTime.split(':');
      startTime = TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      );
      final endParts = widget.schedule!.endTime.split(':');
      endTime = TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      );
      isActive = widget.schedule!.isActive;

      // Preload routes for editing
      if (selectedBusId != null) {
        _loadRoutesForBus(selectedBusId!);
      }
    }
  }

  Future<void> _loadRoutesForBus(String busId) async {
    setState(() {
      isLoadingRoutes = true;
      availableRoutes = [];
      // Keep existing selection while loading
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(widget.schoolId)
          .collection('routes')
          .where('assignedBusId', isEqualTo: busId)
          .get();

      setState(() {
        availableRoutes = snapshot.docs;
        isLoadingRoutes = false;

        // Auto-select if exactly one route exists
        if (availableRoutes.length == 1) {
          final doc = availableRoutes.first;
          selectedRouteId = doc.id;
          selectedRouteName =
              (doc.data()['routeName'] as String?) ?? 'Unnamed Route';
        }
      });
    } catch (e) {
      setState(() {
        isLoadingRoutes = false;
      });
    }
  }

  List<Map<String, dynamic>> _extractPickupStopsFromRouteDoc(
      Map<String, dynamic> routeData) {
    // Preferred: upStops (full Stop.toMap format)
    final upStopsRaw = routeData['upStops'] as List<dynamic>?;
    if (upStopsRaw != null && upStopsRaw.isNotEmpty) {
      return upStopsRaw
          .where(
              (s) => (s is Map<String, dynamic>) && (s['isWaypoint'] != true))
          .map((s) {
        final m = s as Map<String, dynamic>;
        final loc = (m['location'] as Map<String, dynamic>?);
        return {
          'name': m['name'] ?? '',
          'latitude': (loc?['latitude'] as num?)?.toDouble() ?? 0.0,
          'longitude': (loc?['longitude'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();
    }

    // Legacy: stops (may be simple or nested)
    final legacyStops = routeData['stops'] as List<dynamic>?;
    if (legacyStops != null && legacyStops.isNotEmpty) {
      return legacyStops.map((s) {
        final m = (s as Map<String, dynamic>);
        final loc = m['location'] as Map<String, dynamic>?;
        return {
          'name': m['name'] ?? '',
          'latitude': (m['latitude'] as num?)?.toDouble() ??
              (loc?['latitude'] as num?)?.toDouble() ??
              0.0,
          'longitude': (m['longitude'] as num?)?.toDouble() ??
              (loc?['longitude'] as num?)?.toDouble() ??
              0.0,
        };
      }).toList();
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.schedule == null
          ? 'Create Route Schedule'
          : 'Edit Route Schedule'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bus Selection
              DropdownButtonFormField<String>(
                value: selectedBusId,
                decoration: const InputDecoration(
                  labelText: 'Select Bus',
                  border: OutlineInputBorder(),
                ),
                items: widget.buses.map((bus) {
                  return DropdownMenuItem(
                    value: bus.id,
                    child: Text('${bus.busNo} (${bus.busVehicleNo})'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedBusId = value;
                    selectedRouteId = null;
                    selectedRouteName = null;
                    availableRoutes = [];
                    if (value != null) {
                      final bus = widget.buses.firstWhere((b) => b.id == value);
                      routeName =
                          '${bus.busNo} - ${direction == 'pickup' ? 'Morning Pickup' : 'Afternoon Drop'}';
                    }
                  });

                  if (value != null) {
                    _loadRoutesForBus(value);
                  }
                },
                validator: (value) =>
                    value == null ? 'Please select a bus' : null,
              ),
              const SizedBox(height: 16),

              // Route Selection (required when multiple routes exist for this bus)
              if (selectedBusId != null) ...[
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Select Route',
                    border: OutlineInputBorder(),
                  ),
                  child: isLoadingRoutes
                      ? const SizedBox(
                          height: 20,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        )
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedRouteId,
                            hint: Text(
                              availableRoutes.length <= 1
                                  ? (availableRoutes.isEmpty
                                      ? 'No routes assigned to this bus'
                                      : 'Route auto-selected')
                                  : 'Choose a route',
                            ),
                            items: availableRoutes.map((doc) {
                              final data = doc.data();
                              final name = (data['routeName'] as String?) ??
                                  'Unnamed Route';
                              return DropdownMenuItem(
                                value: doc.id,
                                child: Text(name),
                              );
                            }).toList(),
                            onChanged: availableRoutes.length <= 1
                                ? null
                                : (value) {
                                    final doc = availableRoutes
                                        .firstWhere((d) => d.id == value);
                                    setState(() {
                                      selectedRouteId = value;
                                      selectedRouteName =
                                          (doc.data()['routeName']
                                                  as String?) ??
                                              'Unnamed Route';
                                    });
                                  },
                          ),
                        ),
                ),
                const SizedBox(height: 16),
              ],

              // Route Name
              TextFormField(
                initialValue: routeName,
                decoration: const InputDecoration(
                  labelText: 'Route Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => routeName = value,
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter route name'
                    : null,
              ),
              const SizedBox(height: 16),

              // Direction
              DropdownButtonFormField<String>(
                value: direction,
                decoration: const InputDecoration(
                  labelText: 'Direction',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'pickup', child: Text('Pickup (Home → School)')),
                  DropdownMenuItem(
                      value: 'drop', child: Text('Drop (School → Home)')),
                ],
                onChanged: (value) {
                  setState(() {
                    direction = value!;
                    if (selectedBusId != null) {
                      final bus =
                          widget.buses.firstWhere((b) => b.id == selectedBusId);
                      routeName =
                          '${bus.busNo} - ${direction == 'pickup' ? 'Morning Pickup' : 'Afternoon Drop'}';
                    }
                  });
                },
              ),
              const SizedBox(height: 16),

              // Days of Week
              const Text('Active Days:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: [
                  _buildDayChip(1, 'Mon'),
                  _buildDayChip(2, 'Tue'),
                  _buildDayChip(3, 'Wed'),
                  _buildDayChip(4, 'Thu'),
                  _buildDayChip(5, 'Fri'),
                  _buildDayChip(6, 'Sat'),
                  _buildDayChip(7, 'Sun'),
                ],
              ),
              const SizedBox(height: 16),

              // Time Window
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Start Time'),
                      subtitle: Text(startTime.format(context)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: startTime,
                        );
                        if (time != null) setState(() => startTime = time);
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('End Time'),
                      subtitle: Text(endTime.format(context)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: endTime,
                        );
                        if (time != null) setState(() => endTime = time);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Active Status
              SwitchListTile(
                title: const Text('Schedule Active'),
                value: isActive,
                onChanged: (value) => setState(() => isActive = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isSaving ? null : _saveSchedule,
          child: isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildDayChip(int day, String label) {
    final isSelected = selectedDays.contains(day);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            selectedDays.add(day);
          } else {
            selectedDays.remove(day);
          }
        });
      },
    );
  }

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedDays.isEmpty) {
      Get.snackbar(
        'Validation Error',
        'Please select at least one active day',
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final bus = widget.buses.firstWhere((b) => b.id == selectedBusId);

      // Enforce route selection when multiple routes exist for this bus
      if (availableRoutes.length > 1 &&
          (selectedRouteId == null || selectedRouteId!.isEmpty)) {
        Get.snackbar(
          'Validation Error',
          'Please select a route for this bus',
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
        );
        return;
      }

      // Get stops from selected route (preferred). Drop is derived by reversing pickup.
      List<Map<String, dynamic>> pickupStops = [];
      if (selectedRouteId != null && selectedRouteId!.isNotEmpty) {
        final routeDoc = await FirebaseFirestore.instance
            .collection('schooldetails')
            .doc(widget.schoolId)
            .collection('routes')
            .doc(selectedRouteId)
            .get();
        final routeData = routeDoc.data();
        if (routeData != null) {
          pickupStops = _extractPickupStopsFromRouteDoc(routeData);
          selectedRouteName ??=
              (routeData['routeName'] as String?) ?? 'Unnamed Route';
        }
      }

      // Backward-compatible fallback: use bus.stoppings if no route stops are available
      if (pickupStops.isEmpty && bus.stoppings.isNotEmpty) {
        pickupStops = bus.stoppings;
      }

      // Store stops in PICKUP order for both directions.
      // The driver app derives DROP at runtime by reversing pickup order when tripDirection == 'drop'.
      final List<Map<String, dynamic>> stops = pickupStops;

      final data = {
        'schoolId': widget.schoolId,
        'busId': bus.id,
        'busVehicleNo': bus.busVehicleNo,
        'routeName': routeName,
        'routeRefId': selectedRouteId,
        'routeRefName': selectedRouteName,
        'direction': direction,
        'daysOfWeek': selectedDays,
        'startTime':
            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
        'endTime':
            '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
        'stops': stops,
        'routePolyline': bus.routePolyline,
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      String? scheduleId;
      if (widget.schedule == null) {
        // Create new schedule in Firestore
        data['createdAt'] = FieldValue.serverTimestamp();
        final docRef = await FirebaseFirestore.instance
            .collection('schools')
            .doc(widget.schoolId)
            .collection('route_schedules')
            .add(data);
        scheduleId = docRef.id;
      } else {
        // Update existing schedule in Firestore
        scheduleId = widget.schedule!.id;
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(widget.schoolId)
            .collection('route_schedules')
            .doc(scheduleId)
            .update(data);
      }

      // Cache in RTDB for fast Cloud Function access (excluding FieldValue)
      final cacheData = {
        'schoolId': widget.schoolId,
        'busId': bus.id,
        'busVehicleNo': bus.busVehicleNo,
        'routeName': routeName,
        'routeRefId': selectedRouteId,
        'routeRefName': selectedRouteName,
        'direction': direction,
        'daysOfWeek': selectedDays,
        'startTime': data['startTime'],
        'endTime': data['endTime'],
        'stops': stops,
        'routePolyline': bus.routePolyline,
        'isActive': isActive,
        'lastUpdated': ServerValue.timestamp,
      };

      await FirebaseDatabase.instance
          .ref('route_schedules_cache/${widget.schoolId}/${bus.id}/$scheduleId')
          .set(cacheData);

      Get.snackbar(
        'Success',
        'Schedule ${widget.schedule == null ? 'created' : 'updated'} successfully',
        backgroundColor: Colors.green[100],
        colorText: Colors.green[900],
      );

      Navigator.pop(context);
      widget.onSave();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save schedule: $e',
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
    } finally {
      setState(() => isSaving = false);
    }
  }
}
