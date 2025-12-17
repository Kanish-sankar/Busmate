import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_management_controller.dart';
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_model.dart';
import 'package:busmate_web/modules/SchoolAdmin/driver_management/driver_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:busmate_web/modules/utils/uniqueness_check_controller.dart';
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
  final RxString selectedRouteId = ''.obs;
  final RxString selectedRouteName = ''.obs;
  final RxList<Map<String, dynamic>> routeOptions = <Map<String, dynamic>>[].obs; // [{id,name}]

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

  late final UniquenessCheckController credentialCheck;

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
          selectedRouteId.value = student!.assignedRouteId ?? '';
          selectedRouteName.value = student!.assignedRouteName ?? '';
          Future.microtask(() => _loadRoutesAndStopsForBus(bus.id));
        }
      }
    }

    final credentialTag = 'studentLegacyCredential-${schoolId.isNotEmpty ? schoolId : 'default'}-${student?.id ?? 'new'}';
    if (Get.isRegistered<UniquenessCheckController>(tag: credentialTag)) {
      credentialCheck = Get.find<UniquenessCheckController>(tag: credentialTag);
    } else {
      credentialCheck = Get.put(
        UniquenessCheckController(UniquenessCheckType.adminusersCredential),
        tag: credentialTag,
      );
    }

    credentialCheck.onValueChanged(emailController.text, debounce: Duration.zero);
  }

  Future<void> _loadRoutesAndStopsForBus(String busId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(schoolId)
          .collection('routes')
          .where('assignedBusId', isEqualTo: busId)
          .get();

      routeOptions.value = snapshot.docs
          .map((d) => {
                'id': d.id,
                'name': (d.data()['routeName'] as String?) ?? 'Unnamed Route',
              })
          .toList();

      if (routeOptions.length == 1 && selectedRouteId.value.isEmpty) {
        selectedRouteId.value = routeOptions.first['id'] as String;
        selectedRouteName.value = routeOptions.first['name'] as String;
      }

      await _loadStopsForSelectedRoute();
    } catch (e) {
      routeOptions.clear();
      locationOptions.clear();
    }
  }

  List<String> _extractStopNamesFromRoute(Map<String, dynamic> routeData) {
    final upStopsRaw = routeData['upStops'] as List<dynamic>?;
    if (upStopsRaw != null && upStopsRaw.isNotEmpty) {
      return upStopsRaw
          .where((s) => (s is Map<String, dynamic>) && (s['isWaypoint'] != true))
          .map((s) => (s as Map<String, dynamic>)['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
    }

    final legacyStops = routeData['stops'] as List<dynamic>?;
    if (legacyStops != null && legacyStops.isNotEmpty) {
      return legacyStops
          .map((s) => (s as Map<String, dynamic>)['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
    }

    return [];
  }

  Future<void> _loadStopsForSelectedRoute() async {
    locationOptions.clear();
    if (selectedRouteId.value.isEmpty) return;

    try {
      final routeDoc = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(schoolId)
          .collection('routes')
          .doc(selectedRouteId.value)
          .get();

      final data = routeDoc.data();
      if (data == null) return;

      selectedRouteName.value = (data['routeName'] as String?) ?? selectedRouteName.value;
      locationOptions.value = _extractStopNamesFromRoute(data);
    } catch (e) {
      locationOptions.clear();
    }
  }

  // Method to register student and add details to Firestore.
  Future<void> _registerStudent() async {
    if (_formKey.currentState!.validate()) {
      try {
        final credential = emailController.text.trim();

        // Enforce UNIQUE credential across adminusers (login identifier)
        final existingCredential = await FirebaseFirestore.instance
            .collection('adminusers')
            .where('email', isEqualTo: credential)
            .limit(1)
            .get();

        if (existingCredential.docs.isNotEmpty) {
          Get.snackbar(
            'Duplicate Credential',
            'This credential is already used: "$credential"',
          );
          return;
        }

        // Prompt the admin for their password
        // String? adminPassword = await _promptForAdminPassword();
        // if (adminPassword == null || adminPassword.isEmpty) {
        //   Get.snackbar('Error', 'Admin password is required to proceed');
        //   return;
        // }

        // // Store the admin's email
        // final adminEmail = FirebaseAuth.instance.currentUser!.email!;

        // Call the Firebase Function to create the student user
        final currentUser = FirebaseAuth.instance.currentUser;
        final idToken = await currentUser?.getIdToken();
        if (idToken == null || idToken.isEmpty) {
          throw Exception("Not authenticated");
        }

        final response = await http.post(
          Uri.parse("https://createschooluser-gnxzq4evda-uc.a.run.app"),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $idToken",
          },
          body: jsonEncode({
            "email": credential,
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
          email: credential,
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
            assignedRouteId:
              selectedRouteId.value.isNotEmpty ? selectedRouteId.value : null,
            assignedRouteName:
              selectedRouteName.value.isNotEmpty ? selectedRouteName.value : null,
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
        selectedRouteId.value = student!.assignedRouteId ?? '';
        selectedRouteName.value = student!.assignedRouteName ?? '';
        Future.microtask(() => _loadRoutesAndStopsForBus(selectedBusId.value));
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
                      // Clear previous selections
                      stoppingController.text = '';
                      selectedRouteId.value = '';
                      selectedRouteName.value = '';
                      routeOptions.clear();

                      locationOptions.clear();
                      await _loadRoutesAndStopsForBus(value);
                    } else {
                      selectedBusId.value = '';
                      selectedRouteId.value = '';
                      selectedRouteName.value = '';
                      routeOptions.clear();
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

              // Route Selection Dropdown
              Obx(() {
                if (selectedBusId.value.isEmpty) {
                  return const SizedBox.shrink();
                }

                if (routeOptions.isEmpty) {
                  return const Text('No routes assigned to this bus');
                }

                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Select Route'),
                  value: selectedRouteId.value.isNotEmpty ? selectedRouteId.value : null,
                  items: routeOptions.map((r) {
                    return DropdownMenuItem(
                      value: r['id'] as String,
                      child: Text(r['name'] as String),
                    );
                  }).toList(),
                  onChanged: routeOptions.length <= 1
                      ? null
                      : (value) {
                          if (value == null) return;
                          selectedRouteId.value = value;
                          final selected = routeOptions.firstWhere((r) => r['id'] == value);
                          selectedRouteName.value = selected['name'] as String;
                          stoppingController.text = '';
                          _loadStopsForSelectedRoute();
                        },
                  validator: (value) {
                    if (routeOptions.length > 1 && (value == null || value.isEmpty)) {
                      return 'Please select a route';
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
              Obx(() => TextFormField(
                    controller: emailController,
                    onChanged: (v) => credentialCheck.onValueChanged(
                      v,
                      excludeDocId: (isEdit && student != null) ? student!.id : null,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Student Email',
                      suffixIcon: credentialCheck.isChecking.value
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : (credentialCheck.isTaken.value
                              ? const Icon(Icons.error_outline, color: Colors.red)
                              : null),
                      errorText: credentialCheck.isTaken.value
                          ? 'Credential already exists'
                          : null,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
                        return 'Enter a valid email';
                      }
                      if (credentialCheck.isTaken.value) {
                        return 'Credential already exists';
                      }
                      return null;
                    },
                  )),
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
                  if (credentialCheck.isChecking.value || credentialCheck.isTaken.value) {
                    Get.snackbar('Duplicate Credential', 'This credential already exists');
                    return;
                  }
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
                        assignedRouteId: selectedRouteId.value.isNotEmpty
                          ? selectedRouteId.value
                          : null,
                        assignedRouteName: selectedRouteName.value.isNotEmpty
                          ? selectedRouteName.value
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
