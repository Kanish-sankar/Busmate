import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_management_controller.dart';
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_model.dart';
import 'package:busmate_web/modules/SchoolAdmin/driver_management/driver_controller.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'student_controller.dart';
import 'student_model.dart';

class AddStudentScreen extends StatelessWidget {
  final StudentController studentController = Get.put(StudentController());
  final BusController busController = Get.put(BusController());
  final DriverController driverController = Get.put(DriverController());

  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController =
      TextEditingController(); // Student Email
  final TextEditingController passwordController = TextEditingController();
  // Add this RxBool for password visibility
  final RxBool passwordVisible = false.obs;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController rollNumberController = TextEditingController();
  final TextEditingController classController = TextEditingController();
  final TextEditingController parentContactController = TextEditingController();
  final TextEditingController stoppingController = TextEditingController();

  // Reactive variables for dropdown selections
  final RxString selectedBusId = ''.obs;
  final RxString selectedDriverId = ''.obs; // For driver selection

  // New reactive variables for notification preferences
  final RxInt notificationPreferenceByTime = 10.obs; // Changed to RxInt
  final RxString notificationPreferenceByLocation =
      'Goa'.obs; // Example default

  final RxString notificationType =
      'Text Notification'.obs; // Updated default value
  final RxString language = 'English'.obs;

  // Reactive variable for notification preference type (time or location)
  final RxString notificationPreferenceType = 'Time'.obs;

  // Reactive list for location options fetched from the assigned bus's stops
  final RxList<String> locationOptions = <String>[].obs;

  final bool isEdit;
  final Student? student;
  final String schoolId; // <-- Add this

  AddStudentScreen({super.key})
      : isEdit = Get.arguments?['isEdit'] ?? false,
        student = Get.arguments?['student'],
        schoolId = Get.arguments?['schoolId'] ?? '' // <-- Read from arguments
  {
    // Ensure the controllers' schoolId is set
    if (schoolId.isNotEmpty) {
      studentController.schoolId = schoolId;
      busController.schoolId = schoolId; // Set schoolId for bus controller
      busController.fetchBuses(); // Fetch buses

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

  // Method to register student and add details to Firestore.
  Future<void> _registerStudent() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Prompt the admin for their password
        // String? adminPassword = await _promptForAdminPassword();
        // if (adminPassword == null || adminPassword.isEmpty) {
        //   Get.snackbar('Error', 'Admin password is required to proceed');
        //   return;
        // }

        // // Store the admin's email
        // final adminEmail = FirebaseAuth.instance.currentUser!.email!;

        // Call the Firebase Function to create the student user
        final response = await http.post(
          Uri.parse("https://createschooluser-gnxzq4evda-uc.a.run.app"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "email": emailController.text.trim(),
            "password": passwordController.text,
            "role": "student",
          }),
        );

        if (response.statusCode != 200) {
          throw Exception("Failed to create student: ${response.body}");
        }

        // Parse the response to get the UID
        final responseData = jsonDecode(response.body);
        String studentUid = responseData["uid"];

        // Create a new Student instance
        final newStudent = Student(
          id: studentUid,
          email: emailController.text.trim(),
          password: passwordController.text,
          name: nameController.text.trim(),
          rollNumber: rollNumberController.text.trim(),
          studentClass: classController.text.trim(),
          parentContact: parentContactController.text.trim(),
          stopping: stoppingController.text.trim(),
          notificationPreferenceByTime:
              notificationPreferenceType.value == 'Time'
                  ? notificationPreferenceByTime.value
                  : 0,
          notificationPreferenceByLocation:
              notificationPreferenceType.value == 'Location'
                  ? notificationPreferenceByLocation.value
                  : '',
          notificationType: notificationType.value,
          languagePreference: language.value,
          assignedBusId:
              selectedBusId.value.isNotEmpty ? selectedBusId.value : null,
          assignedDriverId:
              selectedDriverId.value.isNotEmpty ? selectedDriverId.value : null,
          schoolId: schoolId, // <-- Use the correct schoolId
        );

        // Add the student to Firestore
        await studentController.addStudent(newStudent);

        // Update the students list in the assigned bus
        if (selectedBusId.value.isNotEmpty) {
          await busController.addStudentToBus(
              selectedBusId.value, newStudent.id);
        }

        // Update the driver's document (if a driver was selected)
        if (selectedDriverId.value.isNotEmpty) {
          await driverController.addStudentToDriver(
              selectedDriverId.value, newStudent.id);
        }

        // Re-authenticate the admin
        // await FirebaseAuth.instance.signInWithEmailAndPassword(
        //   email: adminEmail,
        //   password: adminPassword,
        // );

        Get.snackbar('Success', 'Student added and registered successfully');
        Get.back();
      } catch (e) {
        Get.snackbar('Error', 'Failed to register student: $e');
      }
    }
  }

  // Helper method to prompt the admin for their password
  // Future<String?> _promptForAdminPassword() async {
  //   TextEditingController passwordController = TextEditingController();
  //   String? password;

  //   await Get.dialog(
  //     AlertDialog(
  //       title: const Text('Admin Authentication'),
  //       content: TextField(
  //         controller: passwordController,
  //         decoration: const InputDecoration(
  //           labelText: 'Enter Admin Password',
  //           border: OutlineInputBorder(),
  //         ),
  //         obscureText: true,
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () {
  //             Get.back(); // Close the dialog without setting the password
  //           },
  //           child: const Text('Cancel'),
  //         ),
  //         ElevatedButton(
  //           onPressed: () {
  //             password = passwordController.text.trim();
  //             Get.back(); // Close the dialog and set the password
  //           },
  //           child: const Text('Submit'),
  //         ),
  //       ],
  //     ),
  //   );

  //   return password;
  // }

  @override
  Widget build(BuildContext context) {
    if (isEdit && student != null) {
      emailController.text = student!.email;
      passwordController.text = student!.password;
      nameController.text = student!.name;
      rollNumberController.text = student!.rollNumber;
      classController.text = student!.studentClass;
      parentContactController.text = student!.parentContact;
      stoppingController.text = student!.stopping;

      // Set bus and fetch stoppings
      if (student!.assignedBusId?.isNotEmpty == true) {
        selectedBusId.value = student!.assignedBusId!;
        // Fetch stops for the assigned bus
        final bus = busController.buses
            .firstWhereOrNull((bus) => bus.id == student!.assignedBusId);
        if (bus != null) {
          locationOptions.value =
              bus.stoppings.map((stop) => stop['name'] as String).toList();
        }
      }

      selectedDriverId.value = student!.assignedDriverId ?? '';
      // Ensure notificationPreferenceByTime is one of the allowed values
      final allowedTimes = [20, 15, 10, 5];
      if (allowedTimes.contains(student!.notificationPreferenceByTime)) {
        notificationPreferenceByTime.value =
            student!.notificationPreferenceByTime;
      } else {
        notificationPreferenceByTime.value = 10; // default
      }
      notificationPreferenceByLocation.value =
          student!.notificationPreferenceByLocation;
      notificationType.value = student!.notificationType;
      language.value = student!.languagePreference;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Student' : 'Add Student'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Bus Assignment Dropdown
              Obx(() {
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Assign Bus'),
                  value: selectedBusId.value.isNotEmpty
                      ? selectedBusId.value
                      : null,
                  items: busController.buses.map((Bus bus) {
                    return DropdownMenuItem(
                      value: bus.id,
                      child: Text('Bus No: ${bus.busNo} (${bus.routeName})'),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    if (value != null) {
                      selectedBusId.value = value;
                      // Clear previous stoppings
                      stoppingController.text = '';

                      // Fetch stops from the selected bus and update location options
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
              const SizedBox(height: 10),
              // Driver Assignment Dropdown
              Obx(() {
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Assign Driver'),
                  value: selectedDriverId.value.isNotEmpty
                      ? selectedDriverId.value
                      : null,
                  items: driverController.drivers.map((driver) {
                    return DropdownMenuItem(
                      value: driver.id,
                      child: Text(driver.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      selectedDriverId.value = value;
                    }
                  },
                );
              }),
              const SizedBox(height: 10),
              // Student Email Field
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Student Email'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              // Password Field with visibility toggle
              Obx(() => TextFormField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
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
              const SizedBox(height: 10),
              // Name Field
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              // Roll Number Field
              TextFormField(
                controller: rollNumberController,
                decoration: const InputDecoration(labelText: 'Roll Number'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Roll number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              // Class Field
              TextFormField(
                controller: classController,
                decoration: const InputDecoration(labelText: 'Class'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Class is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              // Parent Contact Field
              TextFormField(
                controller: parentContactController,
                decoration: const InputDecoration(labelText: 'Parent Contact'),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Parent contact is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              // Stopping Field
              Obx(() {
                final items = locationOptions.map((location) {
                  return DropdownMenuItem(
                    value: location,
                    child: Text(location),
                  );
                }).toList();

                // If we have no items, show a disabled field
                if (items.isEmpty) {
                  return TextFormField(
                    controller: stoppingController,
                    decoration: const InputDecoration(
                      labelText: 'Stopping (Select a bus first)',
                      enabled: false,
                    ),
                  );
                }

                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Stopping'),
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
              const SizedBox(height: 10),
              // Notification Preference Type Dropdown
              Obx(() {
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                      labelText: 'Notification Preference Type'),
                  value: notificationPreferenceType.value,
                  items: const [
                    DropdownMenuItem(
                      value: 'Time',
                      child: Text('By Time'),
                    ),
                    DropdownMenuItem(
                      value: 'Location',
                      child: Text('By Location'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      notificationPreferenceType.value = value;
                    }
                  },
                );
              }),
              const SizedBox(height: 10),
              // Notification Preference By Time Dropdown (conditionally shown)
              Obx(() {
                if (notificationPreferenceType.value == 'Time') {
                  return DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                        labelText: 'Notification Preference (Time)'),
                    value: notificationPreferenceByTime.value,
                    items: const [
                      DropdownMenuItem(
                        value: 20,
                        child: Text('Before 20 Minutes'),
                      ),
                      DropdownMenuItem(
                        value: 15,
                        child: Text('Before 15 Minutes'),
                      ),
                      DropdownMenuItem(
                        value: 10,
                        child: Text('Before 10 Minutes'),
                      ),
                      DropdownMenuItem(
                        value: 5,
                        child: Text('Before 5 Minutes'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        notificationPreferenceByTime.value = value;
                      }
                    },
                  );
                } else {
                  return const SizedBox.shrink();
                }
              }),
              const SizedBox(height: 10),
              // Notification Preference By Location Dropdown (conditionally shown)
              Obx(() {
                if (notificationPreferenceType.value == 'Location') {
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                        labelText: 'Notification Preference (Location)'),
                    value: locationOptions
                            .contains(notificationPreferenceByLocation.value)
                        ? notificationPreferenceByLocation.value
                        : null, // Ensure value is valid
                    items: locationOptions.map((location) {
                      return DropdownMenuItem(
                        value: location,
                        child: Text(location),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        notificationPreferenceByLocation.value = value;
                      }
                    },
                  );
                } else {
                  return const SizedBox.shrink();
                }
              }),
              const SizedBox(height: 10),
              // Notification Type Dropdown
              Obx(() {
                return DropdownButtonFormField<String>(
                  decoration:
                      const InputDecoration(labelText: 'Notification Type'),
                  value: notificationType.value,
                  items: const [
                    DropdownMenuItem(
                      value: 'Text Notification',
                      child: Text('Text Notification'),
                    ),
                    DropdownMenuItem(
                      value: 'Voice Notification',
                      child: Text('Voice Notification'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      notificationType.value = value;
                    }
                  },
                );
              }),
              const SizedBox(height: 10),
              // Language Preference Dropdown
              Obx(() {
                return DropdownButtonFormField<String>(
                  decoration:
                      const InputDecoration(labelText: 'Language Preference'),
                  value: language.value,
                  items: const [
                    DropdownMenuItem(
                      value: 'English',
                      child: Text('English'),
                    ),
                    DropdownMenuItem(
                      value: 'Tamil',
                      child: Text('Tamil'),
                    ),
                    DropdownMenuItem(
                      value: 'Kannada',
                      child: Text('Kannada'),
                    ),
                    DropdownMenuItem(
                      value: 'Telugu',
                      child: Text('Telugu'),
                    ),
                    DropdownMenuItem(
                      value: 'Malayalam',
                      child: Text('Malayalam'),
                    ),
                    DropdownMenuItem(
                      value: 'Hindi',
                      child: Text('Hindi'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      language.value = value;
                    }
                  },
                );
              }),
              const SizedBox(height: 20),
              // Submit Button
              ElevatedButton(
                onPressed: () async {
                  if (isEdit && student != null) {
                    final updatedStudent = Student(
                      id: student!.id,
                      email: emailController.text.trim(),
                      password: passwordController.text,
                      name: nameController.text.trim(),
                      rollNumber: rollNumberController.text.trim(),
                      studentClass: classController.text.trim(),
                      parentContact: parentContactController.text.trim(),
                      stopping: stoppingController.text.trim(),
                      notificationPreferenceByTime:
                          notificationPreferenceType.value == 'Time'
                              ? notificationPreferenceByTime.value
                              : 0,
                      notificationPreferenceByLocation:
                          notificationPreferenceType.value == 'Location'
                              ? notificationPreferenceByLocation.value
                              : '',
                      notificationType: notificationType.value,
                      languagePreference: language.value,
                      assignedBusId: selectedBusId.value.isNotEmpty
                          ? selectedBusId.value
                          : null,
                      assignedDriverId: selectedDriverId.value.isNotEmpty
                          ? selectedDriverId.value
                          : null,
                      schoolId: schoolId, // <-- Use the correct schoolId
                    );
                    await studentController.updateStudent(
                        student!.id, updatedStudent);
                  } else {
                    await _registerStudent();
                  }
                },
                child: Text(isEdit ? 'Update Student' : 'Add Student'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
