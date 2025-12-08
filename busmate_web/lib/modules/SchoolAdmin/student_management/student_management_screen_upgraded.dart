import 'package:busmate_web/modules/SchoolAdmin/student_management/add_student_screen_upgraded.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'student_controller.dart';
import 'student_model.dart';
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_management_controller.dart';

class StudentManagementScreenUpgraded extends StatefulWidget {
  final String? schoolId;
  final bool fromSuperAdmin;

  const StudentManagementScreenUpgraded({
    super.key,
    this.schoolId,
    this.fromSuperAdmin = false,
  });

  @override
  State<StudentManagementScreenUpgraded> createState() => _StudentManagementScreenUpgradedState();
}

class _StudentManagementScreenUpgradedState extends State<StudentManagementScreenUpgraded> {
  late final StudentController controller;
  late final BusController busController;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments as Map<String, dynamic>?;
    final effectiveSchoolId = widget.schoolId ?? arguments?['schoolId'];

    controller = Get.put(
      StudentController(),
      tag: effectiveSchoolId ?? 'default',
    );
    
    busController = Get.put(
      BusController(),
      tag: effectiveSchoolId ?? 'default',
    );

    if (effectiveSchoolId != null && effectiveSchoolId.isNotEmpty) {
      controller.schoolId = effectiveSchoolId;
      busController.schoolId = effectiveSchoolId;
      controller.fetchStudents();
      busController.fetchBuses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStatsCards(),
          _buildSearchAndFilters(),
          Expanded(child: _buildStudentList()),
        ],
      ),
      // Only show Add button for Super Admin
      floatingActionButton: widget.fromSuperAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                Get.to(() => AddStudentScreenUpgraded(), arguments: {
                  'schoolId': controller.schoolId,
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Student'),
              backgroundColor: const Color(0xFF2196F3),
              elevation: 4,
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1A1A1A),
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.school, color: Colors.green[700], size: 24),
          ),
          const SizedBox(width: 12),
          const Text(
            'Student Management',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => controller.fetchStudents(),
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: const Icon(Icons.filter_list_off),
          onPressed: () => controller.resetFilters(),
          tooltip: 'Reset Filters',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildStatsCards() {
    return Obx(() {
      final students = controller.students;
      final totalStudents = students.length;
      final assignedStudents = students.where((s) => s.assignedBusId != null && s.assignedBusId!.isNotEmpty).length;
      final unassignedStudents = totalStudents - assignedStudents;
      final uniqueClasses = students.map((s) => s.studentClass).toSet().length;

      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatCard(
                'Total Students',
                totalStudents.toString(),
                Icons.groups,
                Colors.blue,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Assigned',
                assignedStudents.toString(),
                Icons.check_circle,
                Colors.green,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Unassigned',
                unassignedStudents.toString(),
                Icons.person_off,
                Colors.orange,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Classes',
                uniqueClasses.toString(),
                Icons.class_,
                Colors.purple,
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by name, roll number, or parent contact...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) => controller.searchText.value = value,
          ),
          const SizedBox(height: 12),
          // Filters Row
          Row(
            children: [
              Expanded(
                child: Obx(() => DropdownButtonFormField<String>(
                  value: controller.selectedClassFilter.value.isEmpty ? null : controller.selectedClassFilter.value,
                  decoration: InputDecoration(
                    labelText: 'Class',
                    prefixIcon: const Icon(Icons.class_, size: 20),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('All Classes')),
                    ...controller.uniqueClasses.map((className) => DropdownMenuItem<String>(
                      value: className,
                      child: Text(className),
                    )),
                  ],
                  onChanged: (value) => controller.selectedClassFilter.value = value ?? '',
                )),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Obx(() => DropdownButtonFormField<String>(
                  value: controller.selectedBusFilter.value.isEmpty ? null : controller.selectedBusFilter.value,
                  decoration: InputDecoration(
                    labelText: 'Bus',
                    prefixIcon: const Icon(Icons.directions_bus, size: 20),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('All Buses')),
                    ...controller.students
                        .where((s) => s.assignedBusId != null && s.assignedBusId!.isNotEmpty)
                        .map((s) => s.assignedBusId!)
                        .toSet()
                        .map((busId) {
                          // Find bus to show bus number
                          final busList = busController.buses.where((b) => b.id == busId).toList();
                          final bus = busList.isNotEmpty ? busList.first : null;
                          final busDisplay = bus != null ? 'Bus ${bus.busNo}' : busId;
                          return DropdownMenuItem<String>(
                            value: busId,
                            child: Text(busDisplay),
                          );
                        }),
                  ],
                  onChanged: (value) => controller.selectedBusFilter.value = value ?? '',
                )),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      
      if (controller.filteredStudents.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No students found',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: controller.filteredStudents.length,
        itemBuilder: (context, index) {
          final student = controller.filteredStudents[index];
          return _buildStudentCard(student);
        },
      );
    });
  }

  Widget _buildStudentCard(Student student) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showStudentDetailsDialog(student),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Student Avatar
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[100]!, width: 2),
                    ),
                    child: Icon(Icons.person, size: 30, color: Colors.green[700]),
                  ),
                  const SizedBox(width: 16),
                  
                  // Student Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.badge, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Roll: ${student.rollNumber}',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.class_, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              student.studentClass,
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Assignment Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (student.assignedBusId != null && student.assignedBusId!.isNotEmpty)
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (student.assignedBusId != null && student.assignedBusId!.isNotEmpty)
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (student.assignedBusId != null && student.assignedBusId!.isNotEmpty)
                              ? Icons.check_circle
                              : Icons.pending,
                          size: 16,
                          color: (student.assignedBusId != null && student.assignedBusId!.isNotEmpty)
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (student.assignedBusId != null && student.assignedBusId!.isNotEmpty)
                              ? 'Assigned'
                              : 'Unassigned',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: (student.assignedBusId != null && student.assignedBusId!.isNotEmpty)
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              
              // Student Details
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      'Parent',
                      student.parentContact,
                      Icons.phone,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoChip(
                      'Stopping',
                      student.stopping.isNotEmpty ? student.stopping : 'Not set',
                      Icons.location_on,
                      Colors.red,
                    ),
                  ),
                ],
              ),
              
              if (student.assignedBusId != null && student.assignedBusId!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Obx(() {
                  final busList = busController.buses.where((b) => b.id == student.assignedBusId).toList();
                  final bus = busList.isNotEmpty ? busList.first : null;
                  final busDisplayText = bus != null 
                      ? 'Bus ${bus.busNo} - ${bus.busVehicleNo}'
                      : student.assignedBusId!;
                  
                  return _buildInfoChip(
                    'Assigned Bus',
                    busDisplayText,
                    Icons.directions_bus,
                    Colors.green,
                    fullWidth: true,
                  );
                }),
              ],
              
              // Action Buttons
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Get.to(() => AddStudentScreenUpgraded(), arguments: {
                          'isEdit': true,
                          'student': student,
                          'schoolId': controller.schoolId,
                        });
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue[700],
                        side: BorderSide(color: Colors.blue[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  // Only show delete button for Super Admin
                  if (widget.fromSuperAdmin) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmDelete(student),
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[700],
                          side: BorderSide(color: Colors.red[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon, Color color, {bool fullWidth = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStudentDetailsDialog(Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person, color: Colors.green[700]),
            const SizedBox(width: 8),
            const Text('Student Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Name', student.name),
              _buildDetailRow('Roll Number', student.rollNumber),
              _buildDetailRow('Class', student.studentClass),
              _buildDetailRow('Email', student.email),
              _buildDetailRow('Parent Contact', student.parentContact),
              _buildDetailRow('Stopping', student.stopping),
              _buildDetailRow('Notification Type', student.notificationType),
              _buildDetailRow('Language', student.languagePreference),
              if (student.assignedBusId != null && student.assignedBusId!.isNotEmpty)
                _buildDetailRow('Assigned Bus', student.assignedBusId!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Not set',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Are you sure you want to delete ${student.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              controller.deleteStudent(student.id);
              Navigator.pop(context);
              Get.snackbar(
                'Success',
                'Student deleted successfully',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
