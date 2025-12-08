import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_management_controller.dart';
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'student_controller.dart';
import 'student_model.dart';

class AddStudentScreenUpgraded extends StatelessWidget {
  late final StudentController studentController;
  late final BusController busController;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController credentialController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final RxBool passwordVisible = false.obs;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController rollNumberController = TextEditingController();
  final TextEditingController classController = TextEditingController();
  final TextEditingController parentContactController = TextEditingController();
  final TextEditingController stoppingController = TextEditingController();

  final RxString selectedBusId = ''.obs;
  final RxInt notificationPreferenceByTime = 10.obs;
  final RxString notificationType = 'Voice Notification'.obs;
  final RxString language = 'English'.obs;
  final RxList<String> locationOptions = <String>[].obs;

  final bool isEdit;
  final Student? student;
  final String schoolId;

  AddStudentScreenUpgraded({super.key})
      : isEdit = Get.arguments?['isEdit'] ?? false,
        student = Get.arguments?['student'],
        schoolId = Get.arguments?['schoolId'] ?? '' {
    // Get or create StudentController
    final effectiveSchoolId = schoolId.isNotEmpty ? schoolId : 'default';
    if (Get.isRegistered<StudentController>(tag: effectiveSchoolId)) {
      studentController = Get.find<StudentController>(tag: effectiveSchoolId);
    } else {
      studentController = Get.put(StudentController(), tag: effectiveSchoolId);
    }
    
    // Get or create BusController
    if (Get.isRegistered<BusController>(tag: effectiveSchoolId)) {
      busController = Get.find<BusController>(tag: effectiveSchoolId);
    } else {
      busController = Get.put(BusController(), tag: effectiveSchoolId);
    }

    // Set schoolId and fetch buses
    if (schoolId.isNotEmpty) {
      studentController.schoolId = schoolId;
      busController.schoolId = schoolId;
      busController.fetchBuses();

      // If editing, initialize stoppings
      if (isEdit && student?.assignedBusId != null) {
        final bus = busController.buses
            .firstWhereOrNull((bus) => bus.id == student!.assignedBusId);
        if (bus != null) {
          selectedBusId.value = bus.id;
          locationOptions.value =
              bus.stoppings.map((stop) => stop['name'] as String).toList();
        }
      }
    }
  }

  Future<void> _saveStudent() async {
    if (_formKey.currentState!.validate()) {
      try {
        if (isEdit && student != null) {
          // Get driver ID from the selected bus if bus has a driver
          String? driverId;
          if (selectedBusId.value.isNotEmpty) {
            final selectedBus = busController.buses
                .firstWhereOrNull((bus) => bus.id == selectedBusId.value);
            if (selectedBus != null && selectedBus.hasDriver) {
              driverId = selectedBus.driverId;
            }
          }
          
          // Check if password was changed
          String finalPassword = student!.password; // Keep old password by default
          if (passwordController.text.isNotEmpty && passwordController.text != student!.password) {
            // Password was changed, hash it locally
            final bytes = utf8.encode(passwordController.text);
            final digest = sha256.convert(bytes);
            finalPassword = digest.toString();
          }
          
          // Update existing student
          final updatedStudent = Student(
            id: student!.id,
            email: credentialController.text.trim(),
            password: finalPassword, // Use hashed password
            name: nameController.text.trim(),
            rollNumber: rollNumberController.text.trim(),
            studentClass: classController.text.trim(),
            parentContact: parentContactController.text.trim(),
            stopping: stoppingController.text.trim(),
            notificationPreferenceByTime: notificationPreferenceByTime.value,
            notificationPreferenceByLocation: '',
            notificationType: notificationType.value,
            languagePreference: language.value,
            assignedBusId:
                selectedBusId.value.isNotEmpty ? selectedBusId.value : null,
            assignedDriverId: driverId, // Automatically assign driver from bus
            schoolId: schoolId,
          );
          await studentController.updateStudent(student!.id, updatedStudent);
          
          // Also update in adminusers collection for mobile app
          await FirebaseFirestore.instance
              .collection('adminusers')
              .doc(student!.id)
              .update({
            'email': credentialController.text.trim(),
            'password': finalPassword,
            'name': nameController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          // Handle bus assignment changes
          final oldBusId = student!.assignedBusId;
          final newBusId = selectedBusId.value.isNotEmpty ? selectedBusId.value : null;
          
          // If bus changed, update the bus student lists
          if (oldBusId != newBusId) {
            // Remove from old bus if there was one
            if (oldBusId != null && oldBusId.isNotEmpty) {
              await busController.removeStudentFromBus(oldBusId, student!.id);
            }
            
            // Add to new bus if there is one
            if (newBusId != null && newBusId.isNotEmpty) {
              await busController.addStudentToBus(newBusId, student!.id);
            }
          }
          
          Get.snackbar(
            'Success',
            'Student updated successfully',
            backgroundColor: Colors.green[100],
            colorText: Colors.green[900],
            snackPosition: SnackPosition.BOTTOM,
          );
        } else {
          // Register new student - NO Firebase Auth, direct Firestore storage
          String credential = credentialController.text.trim();
          String password = passwordController.text;
          
          // Hash the password locally using SHA-256
          final bytes = utf8.encode(password);
          final digest = sha256.convert(bytes);
          String hashedPassword = digest.toString();

          // Generate a unique student ID (Firestore will create it)
          String studentUid = studentController.studentCollection.doc().id;

          // Get driver ID from the selected bus if bus has a driver
          String? driverId;
          if (selectedBusId.value.isNotEmpty) {
            final selectedBus = busController.buses
                .firstWhereOrNull((bus) => bus.id == selectedBusId.value);
            if (selectedBus != null && selectedBus.hasDriver) {
              driverId = selectedBus.driverId;
            }
          }

          final newStudent = Student(
            id: studentUid,
            email: credential, // Store credential (can be anything - roll number, phone, etc.)
            password: hashedPassword, // Store HASHED password, never plain text!
            name: nameController.text.trim(),
            rollNumber: rollNumberController.text.trim(),
            studentClass: classController.text.trim(),
            parentContact: parentContactController.text.trim(),
            stopping: stoppingController.text.trim(),
            notificationPreferenceByTime: notificationPreferenceByTime.value,
            notificationPreferenceByLocation: '',
            notificationType: notificationType.value,
            languagePreference: language.value,
            assignedBusId:
                selectedBusId.value.isNotEmpty ? selectedBusId.value : null,
            assignedDriverId: driverId, // Automatically assign driver from bus
            schoolId: schoolId,
          );

          await studentController.addStudent(newStudent);

          // Also save to adminusers collection for mobile app authentication
          await FirebaseFirestore.instance
              .collection('adminusers')
              .doc(studentUid)
              .set({
            'email': credential,
            'password': hashedPassword,
            'role': 'student',
            'schoolId': schoolId,
            'studentId': studentUid,
            'name': nameController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Add student to bus
          if (selectedBusId.value.isNotEmpty) {
            await busController.addStudentToBus(
                selectedBusId.value, newStudent.id);
          }

          Get.snackbar(
            'Success',
            'Student added successfully',
            backgroundColor: Colors.green[100],
            colorText: Colors.green[900],
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        Get.back();
      } catch (e, stackTrace) {
        // Close loading dialog if it's still open
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }
        
        print('❌ Error saving student: $e');
        print('❌ Stack trace: $stackTrace');
        
        Get.snackbar(
          'Error',
          'Failed to save student: $e',
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5),
        );
      }
    }
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getIconForSection(title),
                    color: Colors.green[700],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  IconData _getIconForSection(String title) {
    switch (title) {
      case 'Login Credentials':
        return Icons.lock;
      case 'Personal Information':
        return Icons.person;
      case 'Academic Details':
        return Icons.school;
      case 'Contact Information':
        return Icons.phone;
      case 'Bus Assignment':
        return Icons.directions_bus;
      case 'Notification Preferences':
        return Icons.notifications;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isEdit && student != null) {
      credentialController.text = student!.email;
      passwordController.text = student!.password;
      nameController.text = student!.name;
      rollNumberController.text = student!.rollNumber;
      classController.text = student!.studentClass;
      parentContactController.text = student!.parentContact;
      stoppingController.text = student!.stopping;

      if (student!.assignedBusId?.isNotEmpty == true) {
        selectedBusId.value = student!.assignedBusId!;
        final bus = busController.buses
            .firstWhereOrNull((bus) => bus.id == student!.assignedBusId);
        if (bus != null) {
          locationOptions.value =
              bus.stoppings.map((stop) => stop['name'] as String).toList();
        }
      }

      final allowedTimes = [20, 15, 10, 5];
      if (allowedTimes.contains(student!.notificationPreferenceByTime)) {
        notificationPreferenceByTime.value =
            student!.notificationPreferenceByTime;
      } else {
        notificationPreferenceByTime.value = 10;
      }
      notificationType.value = student!.notificationType;
      language.value = student!.languagePreference;
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.green[700],
        title: Text(
          isEdit ? 'Edit Student' : 'Add New Student',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Info Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[700]!, Colors.green[500]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_add,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'Update Student Details' : 'Student Registration',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isEdit
                                ? 'Modify student information'
                                : 'Fill in the details to add a new student',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Login Credentials Section
              _buildSectionCard(
                title: 'Login Credentials',
                children: [
                  TextFormField(
                    controller: credentialController,
                    decoration: InputDecoration(
                      labelText: 'Credential (Email/Phone/Roll No/Code)',
                      hintText: 'Enter any unique identifier',
                      prefixIcon: const Icon(Icons.badge),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      helperText: 'Can be email, phone number, roll number, or any unique code',
                      helperMaxLines: 2,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Credential is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Obx(() => TextFormField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              passwordVisible.value
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              passwordVisible.value = !passwordVisible.value;
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          helperText: 'Can be numbers, letters, DOB, or any combination',
                          helperMaxLines: 2,
                        ),
                        obscureText: !passwordVisible.value,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      )),
                ],
              ),

              // Personal Information Section
              _buildSectionCard(
                title: 'Personal Information',
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter student name',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                ],
              ),

              // Academic Details Section
              _buildSectionCard(
                title: 'Academic Details',
                children: [
                  TextFormField(
                    controller: rollNumberController,
                    decoration: InputDecoration(
                      labelText: 'Roll Number',
                      hintText: 'Enter roll number',
                      prefixIcon: const Icon(Icons.numbers),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Roll number is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: classController,
                    decoration: InputDecoration(
                      labelText: 'Class',
                      hintText: 'Enter class (e.g., 10th Grade)',
                      prefixIcon: const Icon(Icons.class_),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Class is required';
                      }
                      return null;
                    },
                  ),
                ],
              ),

              // Contact Information Section
              _buildSectionCard(
                title: 'Contact Information',
                children: [
                  TextFormField(
                    controller: parentContactController,
                    decoration: InputDecoration(
                      labelText: 'Parent Contact',
                      hintText: 'Enter parent phone number',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Parent contact is required';
                      }
                      return null;
                    },
                  ),
                ],
              ),

              // Bus Assignment Section
              _buildSectionCard(
                title: 'Bus Assignment',
                children: [
                  Obx(() {
                    return DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Assign Bus',
                        prefixIcon: const Icon(Icons.directions_bus),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      value: selectedBusId.value.isNotEmpty
                          ? selectedBusId.value
                          : null,
                      items: busController.buses.map((Bus bus) {
                        return DropdownMenuItem(
                          value: bus.id,
                          child: Text('Bus ${bus.busNo} - ${bus.routeName}'),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        if (value != null) {
                          selectedBusId.value = value;
                          stoppingController.text = '';

                          try {
                            final selectedBus = busController.buses
                                .firstWhere((bus) => bus.id == value);
                            locationOptions.value = selectedBus.stoppings
                                .map((stop) => stop['name'] as String)
                                .toList()
                                .cast<String>();
                          } catch (e) {
                            locationOptions.clear();
                            Get.snackbar('Error', 'Failed to fetch stoppings: $e');
                          }
                        } else {
                          selectedBusId.value = '';
                          locationOptions.clear();
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a bus';
                        }
                        return null;
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                  Obx(() {
                    final items = locationOptions.map((location) {
                      return DropdownMenuItem(
                        value: location,
                        child: Text(location),
                      );
                    }).toList();

                    if (items.isEmpty) {
                      return TextFormField(
                        controller: stoppingController,
                        decoration: InputDecoration(
                          labelText: 'Stopping',
                          hintText: 'Select a bus first',
                          prefixIcon: const Icon(Icons.location_on),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          enabled: false,
                        ),
                      );
                    }

                    return DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Stopping',
                        prefixIcon: const Icon(Icons.location_on),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      value: locationOptions.contains(stoppingController.text)
                          ? stoppingController.text
                          : null,
                      items: items,
                      onChanged: (value) {
                        if (value != null) {
                          stoppingController.text = value;
                        }
                      },
                      validator: (value) {
                        if (selectedBusId.value.isNotEmpty &&
                            (value == null || value.isEmpty)) {
                          return 'Please select a stopping point';
                        }
                        return null;
                      },
                    );
                  }),
                ],
              ),

              // Notification Preferences Section
              _buildSectionCard(
                title: 'Notification Preferences',
                children: [
                  Obx(() {
                    return DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Notification Time (Minutes Before)',
                        prefixIcon: const Icon(Icons.access_time),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      value: notificationPreferenceByTime.value,
                      items: const [
                        DropdownMenuItem(value: 20, child: Text('20 Minutes Before')),
                        DropdownMenuItem(value: 15, child: Text('15 Minutes Before')),
                        DropdownMenuItem(value: 10, child: Text('10 Minutes Before')),
                        DropdownMenuItem(value: 5, child: Text('5 Minutes Before')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          notificationPreferenceByTime.value = value;
                        }
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                  Obx(() {
                    return DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Notification Type',
                        prefixIcon: const Icon(Icons.notifications_active),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      value: notificationType.value,
                      items: const [
                        DropdownMenuItem(
                          value: 'Voice Notification',
                          child: Text('Voice Notification'),
                        ),
                        DropdownMenuItem(
                          value: 'Text Notification',
                          child: Text('Text Notification'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          notificationType.value = value;
                        }
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                  Obx(() {
                    return DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Language Preference',
                        prefixIcon: const Icon(Icons.language),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      value: language.value,
                      items: const [
                        DropdownMenuItem(value: 'English', child: Text('English')),
                        DropdownMenuItem(value: 'Tamil', child: Text('Tamil')),
                        DropdownMenuItem(value: 'Kannada', child: Text('Kannada')),
                        DropdownMenuItem(value: 'Telugu', child: Text('Telugu')),
                        DropdownMenuItem(value: 'Malayalam', child: Text('Malayalam')),
                        DropdownMenuItem(value: 'Hindi', child: Text('Hindi')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          language.value = value;
                        }
                      },
                    );
                  }),
                ],
              ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveStudent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isEdit ? Icons.update : Icons.add,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEdit ? 'Update Student' : 'Add Student',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
