import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:busmate_web/modules/Authentication/auth_controller.dart';
import 'student_controller.dart';
import 'student_model.dart';
import 'add_student_screen_upgraded.dart';

class StudentManagementScreen extends StatelessWidget {
  final String? schoolId;
  final bool fromSuperAdmin;
  late final StudentController controller;

  StudentManagementScreen({
    super.key, 
    this.schoolId,
    this.fromSuperAdmin = false,
  }) {
    // Initialize controller with schoolId passed as parameter OR from Get.arguments
    final arguments = Get.arguments as Map<String, dynamic>?;
    final effectiveSchoolId = schoolId ?? arguments?['schoolId'];
    
    print('🔍 StudentManagementScreen - schoolId param: $schoolId');
    print('🔍 StudentManagementScreen - Get.arguments: $arguments');
    print('🔍 StudentManagementScreen - effectiveSchoolId: $effectiveSchoolId');
    
    // Put controller with tag to avoid conflicts between different school instances
    controller = Get.put(
      StudentController(),
      tag: effectiveSchoolId ?? 'default',
    );
    
    // Set the schoolId in controller if provided
    if (effectiveSchoolId != null) {
      controller.schoolId = effectiveSchoolId;
      controller.fetchStudents();
    } else {
      print('❌ StudentManagementScreen - No schoolId provided!');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    
    // Check if we're being accessed by a Superior Admin through school navigation
    // Use widget parameter first, then fallback to Get.arguments
    final arguments = Get.arguments as Map<String, dynamic>?;
    final fromSuperAdminFlag = fromSuperAdmin || (arguments?['fromSuperAdmin'] ?? false);
    
    // Only restrict if user is an actual School Admin (not Superior Admin viewing school)
    final shouldRestrictAccess = authController.isSchoolAdmin && !fromSuperAdminFlag;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              controller.resetFilters();
            },
            tooltip: 'Reset Filters',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search by name or student ID',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          controller.searchText.value = value;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Bus Filter
                    Expanded(
                      child: Obx(() => DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Filter by Bus',
                              border: OutlineInputBorder(),
                            ),
                            value: controller.selectedBusFilter.value.isEmpty
                                ? null
                                : controller.selectedBusFilter.value,
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('All Buses'),
                              ),
                              ...controller.students
                                  .where((s) =>
                                      s.assignedBusId != null &&
                                      s.assignedBusId!.isNotEmpty)
                                  .map((s) => s.assignedBusId!)
                                  .toSet()
                                  .map((busId) => DropdownMenuItem<String>(
                                        value: busId,
                                        child: Text('Bus $busId'),
                                      ))
                                  ,
                            ],
                            onChanged: (value) {
                              controller.selectedBusFilter.value = value ?? '';
                            },
                          )),
                    ),
                    const SizedBox(width: 8),
                    // Class Filter
                    Expanded(
                      child: Obx(() => DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Filter by Class',
                              border: OutlineInputBorder(),
                            ),
                            value: controller.selectedClassFilter.value.isEmpty
                                ? null
                                : controller.selectedClassFilter.value,
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('All Classes'),
                              ),
                              ...controller.uniqueClasses
                                  .map((className) => DropdownMenuItem<String>(
                                        value: className,
                                        child: Text(className),
                                      )),
                            ],
                            onChanged: (value) {
                              controller.selectedClassFilter.value =
                                  value ?? '';
                            },
                          )),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Student List (DataTable)
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.filteredStudents.isEmpty) {
                return Center(
                  child: Text(
                    shouldRestrictAccess
                      ? 'No students found. Contact Superior Admin to add students.'
                      : 'No students found',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Roll No')),
                        DataColumn(label: Text('Class')),
                        DataColumn(label: Text('Parent Contact')),
                        DataColumn(label: Text('Stopping')),
                        DataColumn(label: Text('Notif. PrefByTime')),
                        DataColumn(label: Text('Notif. PrefByLoc')),
                        DataColumn(label: Text('Notif. Type')),
                        DataColumn(label: Text('Language')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: controller.filteredStudents.map((Student student) {
                        return DataRow(cells: [
                          DataCell(Text(student.email)),
                          DataCell(Text(student.name)),
                          DataCell(Text(student.rollNumber)),
                          DataCell(Text(student.studentClass)),
                          DataCell(Text(student.parentContact)),
                          DataCell(Text(student.stopping)),
                          DataCell(Text(student.notificationPreferenceByTime
                              .toString())), // Convert int to String if necessary
                          DataCell(
                              Text(student.notificationPreferenceByLocation)),
                          DataCell(Text(student.notificationType)),
                          DataCell(Text(student.languagePreference)),
                          DataCell(
                            Row(
                              children: [
                                // Edit button - Available to both Superior Admin and School Admin
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {
                                    Get.to(() => AddStudentScreenUpgraded(),
                                        arguments: {
                                          'isEdit': true,
                                          'student': student,
                                          'schoolId': controller.schoolId,
                                        });
                                  },
                                ),
                                // Delete button - Only for Superior Admin (not School Admin)
                                if (!shouldRestrictAccess)
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () {
                                      controller.deleteStudent(student.id);
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ));
            }),
          ),
        ],
      ),
      // Only show Add Student button if not restricted (Superior Admins or accessing from Super Admin)
      floatingActionButton: !shouldRestrictAccess
        ? FloatingActionButton(
            onPressed: () {
              Get.to(AddStudentScreenUpgraded(), arguments: {
                'schoolId': controller.schoolId, // <-- Pass schoolId for add too
              });
            },
            child: const Icon(Icons.add),
          )
        : null,
    );
  }
}
