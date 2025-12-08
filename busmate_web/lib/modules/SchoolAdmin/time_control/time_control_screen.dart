import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
                        'Bus: ${schedule.busVehicleNo}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
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
                label: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
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
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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

  Future<void> _toggleScheduleStatus(RouteSchedule schedule, bool newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('route_schedules')
          .doc(schedule.id)
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
        content: Text('Are you sure you want to delete "${schedule.routeName}"?'),
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
        await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('route_schedules')
          .doc(schedule.id)
          .delete();        Get.snackbar(
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
  State<_RouteScheduleFormDialog> createState() => _RouteScheduleFormDialogState();
}

class _RouteScheduleFormDialogState extends State<_RouteScheduleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String? selectedBusId;
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.schedule == null ? 'Create Route Schedule' : 'Edit Route Schedule'),
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
                    if (value != null) {
                      final bus = widget.buses.firstWhere((b) => b.id == value);
                      routeName = '${bus.busNo} - ${direction == 'pickup' ? 'Morning Pickup' : 'Afternoon Drop'}';
                    }
                  });
                },
                validator: (value) => value == null ? 'Please select a bus' : null,
              ),
              const SizedBox(height: 16),

              // Route Name
              TextFormField(
                initialValue: routeName,
                decoration: const InputDecoration(
                  labelText: 'Route Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => routeName = value,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Please enter route name' : null,
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
                  DropdownMenuItem(value: 'pickup', child: Text('Pickup (Home → School)')),
                  DropdownMenuItem(value: 'drop', child: Text('Drop (School → Home)')),
                ],
                onChanged: (value) {
                  setState(() {
                    direction = value!;
                    if (selectedBusId != null) {
                      final bus = widget.buses.firstWhere((b) => b.id == selectedBusId);
                      routeName = '${bus.busNo} - ${direction == 'pickup' ? 'Morning Pickup' : 'Afternoon Drop'}';
                    }
                  });
                },
              ),
              const SizedBox(height: 16),

              // Days of Week
              const Text('Active Days:', style: TextStyle(fontWeight: FontWeight.bold)),
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
      
      // Get stops from bus
      List<Map<String, dynamic>> stops;
      if (direction == 'pickup' && bus.stoppings.isNotEmpty) {
        stops = bus.stoppings;
      } else if (direction == 'drop' && bus.stoppings.isNotEmpty) {
        stops = bus.stoppings.reversed.toList(); // Reverse for drop route
      } else {
        stops = [];
      }

      final data = {
        'schoolId': widget.schoolId,
        'busId': bus.id,
        'busVehicleNo': bus.busVehicleNo,
        'routeName': routeName,
        'direction': direction,
        'daysOfWeek': selectedDays,
        'startTime': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
        'endTime': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
        'stops': stops,
        'routePolyline': bus.routePolyline,
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.schedule == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(widget.schoolId)
            .collection('route_schedules')
            .add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(widget.schoolId)
            .collection('route_schedules')
            .doc(widget.schedule!.id)
            .update(data);
      }

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
