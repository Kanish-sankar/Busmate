import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'student_controller.dart';
import 'student_model.dart';
import 'add_student_screen.dart';

class StudentManagementScreen extends StatelessWidget {
  final StudentController controller = Get.put(StudentController());

  StudentManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Ensure controller.schoolId is set from arguments
    final arguments = Get.arguments as Map<String, dynamic>?;
    if (arguments != null && arguments['schoolId'] != null) {
      controller.schoolId = arguments['schoolId'];
      controller.fetchStudents();
    }
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
                                  .toList(),
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
                return const Center(child: Text('No students found'));
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
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {
                                    Get.to(() => AddStudentScreen(),
                                        arguments: {
                                          'isEdit': true,
                                          'student': student,
                                          'schoolId': controller
                                              .schoolId, // <-- Pass schoolId
                                        });
                                  },
                                ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(AddStudentScreen(), arguments: {
            'schoolId': controller.schoolId, // <-- Pass schoolId for add too
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
