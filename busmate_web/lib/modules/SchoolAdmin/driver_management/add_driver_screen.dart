// add_driver_screen.dart
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_management_controller.dart';
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_model.dart';
import 'package:busmate_web/modules/SchoolAdmin/driver_management/driver_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'driver_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:busmate_web/modules/utils/uniqueness_check_controller.dart';

// ignore: must_be_immutable
class AddDriverScreen extends StatelessWidget {
  // Use the correct schoolId from arguments for both controllers
  final String schoolId = Get.arguments?['schoolId'] ?? '';
  final DriverController driverController =
      Get.put(DriverController(), tag: null);
  final BusController busController = Get.put(BusController(), tag: null);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController =
      TextEditingController(); // Driver email
  final TextEditingController passwordController = TextEditingController();
  final RxBool passwordVisible = false.obs;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController licenseController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController profileImageController = TextEditingController();
  bool available = true;

  // Reactive variable for selected bus ID.
  final RxString selectedBusId = ''.obs;

  final bool isEdit;
  final Driver? driver;

  late final UniquenessCheckController credentialCheck;

  // Add a reactive variable for image upload state
  final RxString imageUploadStatus = ''.obs;

  // Add a reactive variable for the profile image URL
  final RxString profileImageUrlRx = ''.obs;

  AddDriverScreen({super.key})
      : isEdit = Get.arguments?['isEdit'] ?? false,
        driver = Get.arguments?['driver'] {
    // Set schoolId for controllers after instantiation
    final String schoolId = Get.arguments?['schoolId'] ?? '';
    driverController.schoolId = schoolId;
    busController.schoolId = schoolId;

    final credentialTag = 'driverLegacyCredential-${schoolId.isNotEmpty ? schoolId : 'default'}-${driver?.id ?? 'new'}';
    if (Get.isRegistered<UniquenessCheckController>(tag: credentialTag)) {
      credentialCheck = Get.find<UniquenessCheckController>(tag: credentialTag);
    } else {
      credentialCheck = Get.put(
        UniquenessCheckController(UniquenessCheckType.adminusersCredential),
        tag: credentialTag,
      );
    }

    credentialCheck.onValueChanged(emailController.text, debounce: Duration.zero);
    // Optionally, fetch data again if needed:
    // driverController.fetchDrivers();
    // busController.fetchBuses();
  }

  Future<void> _registerDriver() async {
    if (_formKey.currentState!.validate()) {
      try {
        final credential = emailController.text.trim();

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

        // Save the current admin user's credentials
        // final User? currentUser = FirebaseAuth.instance.currentUser;
        // final String? adminEmail = currentUser?.email;
        // final String? adminPassword = await driverController.getAdminPassword();

        // if (adminEmail == null || adminPassword == null) {
        //   throw Exception("Admin credentials are missing.");
        // }

        // Call the Firebase Function to create the driver user
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
            "role": "driver",
            "schoolId": driverController.schoolId, // Add this line
          }),
        );

        if (response.statusCode != 200) {
          throw Exception("Failed to create driver: ${response.body}");
        }

        // Parse the response to get the UID
        final responseData = jsonDecode(response.body);
        String driverUid = responseData["uid"];

        // Create a new Driver instance
        final newDriver = Driver(
          id: driverUid,
          email: credential,
          password: passwordController.text,
          name: nameController.text.trim(),
          licenseNumber: licenseController.text.trim(),
          contactInfo: contactController.text.trim(),
          profileImageUrl: profileImageController.text.trim(),
          available: available,
          assignedBusId:
              selectedBusId.value.isNotEmpty ? selectedBusId.value : null,
          schoolId: driverController.schoolId,
        );

        // Add the driver document to Firestore
        await driverController.addDriver(newDriver);

        // If a bus is assigned, update that bus document with driver details
        if (selectedBusId.value.isNotEmpty) {
          await busController.updateBusDriver(
              selectedBusId.value, newDriver.id, newDriver.name);
        }

        Get.snackbar('Success', 'Driver added and registered successfully');
        Get.back();
      } catch (e) {
        Get.snackbar('Error', 'Failed to register driver: $e');
      }
    }
  }

  // Method to pick and upload image to Firebase Storage
  Future<void> pickAndUploadImage() async {
    try {
      imageUploadStatus.value = 'Selecting...';
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.bytes != null) {
        imageUploadStatus.value = 'Uploading...';
        final fileBytes = result.files.single.bytes!;
        final fileName = result.files.single.name;
        final storageRef = FirebaseStorage.instance
            .ref() // <-- use default ref, or use .refFromURL('gs://busmate-b80e8.appspot.com')
            .child(
                'driver_images/${DateTime.now().millisecondsSinceEpoch}_$fileName');
        await storageRef.putData(fileBytes);
        final downloadUrl = await storageRef.getDownloadURL();
        print('Download URL: $downloadUrl'); // Debug print
        profileImageController.text = downloadUrl;
        profileImageUrlRx.value = downloadUrl; // update observable
        imageUploadStatus.value = 'Uploaded!';
      } else {
        imageUploadStatus.value = 'No file selected';
      }
    } catch (e) {
      imageUploadStatus.value = 'Upload failed';
      Get.snackbar('Error', 'Failed to upload image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isEdit && driver != null) {
      emailController.text = driver!.email;
      passwordController.text = driver!.password;
      nameController.text = driver!.name;
      licenseController.text = driver!.licenseNumber;
      contactController.text = driver!.contactInfo;
      profileImageController.text = driver!.profileImageUrl;
      profileImageUrlRx.value = driver!.profileImageUrl; // set observable
      selectedBusId.value = driver!.assignedBusId ?? '';
      available = driver!.available;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Driver' : 'Add Driver'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Driver Email Field
              Obx(() => TextFormField(
                    controller: emailController,
                    onChanged: (v) => credentialCheck.onValueChanged(
                      v,
                      excludeDocId: (isEdit && driver != null) ? driver!.id : null,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Driver Email',
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
              // Password Field
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
              // License Number Field
              TextFormField(
                controller: licenseController,
                decoration: const InputDecoration(labelText: 'License Number'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'License Number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              // Contact Information Field
              TextFormField(
                controller: contactController,
                decoration:
                    const InputDecoration(labelText: 'Contact Information'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Contact Information is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              // Profile Image Picker & Preview

              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Choose Image'),
                onPressed: pickAndUploadImage,
              ),
              const SizedBox(width: 8),
              Obx(() => Text(imageUploadStatus.value)),

              const SizedBox(height: 10),
              // Bus Assignment Dropdown for Driver
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
                  onChanged: (value) {
                    if (value != null) {
                      selectedBusId.value = value;
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
              // Available Switch
              SwitchListTile(
                title: const Text('Available'),
                value: available,
                onChanged: (val) {
                  available = val;
                },
              ),
              const SizedBox(height: 20),
              // Submit Button
              ElevatedButton(
                onPressed: () async {
                  if (isEdit && driver != null) {
                    final updatedDriver = Driver(
                      id: driver!.id,
                      email: emailController.text.trim(),
                      password: passwordController.text,
                      name: nameController.text.trim(),
                      licenseNumber: licenseController.text.trim(),
                      contactInfo: contactController.text.trim(),
                      profileImageUrl: profileImageController.text.trim(),
                      available: available,
                      assignedBusId: selectedBusId.value.isNotEmpty
                          ? selectedBusId.value
                          : null,
                      schoolId: driverController.schoolId,
                    );
                    await driverController.updateDriver(
                        driver!.id, updatedDriver);
                  } else {
                    await _registerDriver();
                  }
                },
                child: Text(isEdit ? 'Update Driver' : 'Add Driver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
