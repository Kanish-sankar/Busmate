import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_management_controller.dart';
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:busmate_web/modules/utils/uniqueness_check_controller.dart';
import 'student_controller.dart';
import 'student_model.dart';

class AddStudentScreenUpgraded extends StatelessWidget {
  late final StudentController studentController;
  late final BusController busController;
  late final UniquenessCheckController credentialCheck;

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
  final RxString selectedRouteId = ''.obs;
  final RxString selectedRouteName = ''.obs;
  final RxInt notificationPreferenceByTime = 10.obs;
  final RxString notificationType = 'Voice Notification'.obs;
  final RxString language = 'English'.obs;
  final RxList<String> locationOptions = <String>[].obs;
  final RxList<Map<String, dynamic>> routeOptions = <Map<String, dynamic>>[].obs; // [{id,name}]

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

    final credentialTag = 'studentCredential-$effectiveSchoolId-${student?.id ?? 'new'}';
    if (Get.isRegistered<UniquenessCheckController>(tag: credentialTag)) {
      credentialCheck = Get.find<UniquenessCheckController>(tag: credentialTag);
    } else {
      credentialCheck = Get.put(
        UniquenessCheckController(
          UniquenessCheckType.firebaseAuthEmail,
          schoolId: effectiveSchoolId,
          authTypeGetter: () => 'email',
        ),
        tag: credentialTag,
      );
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
          // Initialize selected route if present
          selectedRouteId.value = (student!.assignedRouteId ?? '');
          selectedRouteName.value = (student!.assignedRouteName ?? '');
          _loadRoutesAndStopsForBus(bus.id);
        }
      }
    }
  }

  Future<void> _loadRoutesAndStopsForBus(String busId) async {
    try {
      // Load routes assigned to this bus
      final snapshot = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(schoolId)
          .collection('routes')
          .where('assignedBusId', isEqualTo: busId)
          .get();

      final routes = snapshot.docs
          .map((d) => {
                'id': d.id,
                'name': (d.data()['routeName'] as String?) ?? 'Unnamed Route',
                'data': d.data(),
              })
          .toList();

      routeOptions.value = routes;

      // Auto-select if exactly one route and none selected
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

    if (selectedRouteId.value.isEmpty) {
      return;
    }

    try {
      final routeDoc = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(schoolId)
          .collection('routes')
          .doc(selectedRouteId.value)
          .get();

      final data = routeDoc.data();
      if (data == null) {
        return;
      }

      selectedRouteName.value = (data['routeName'] as String?) ?? selectedRouteName.value;
      locationOptions.value = _extractStopNamesFromRoute(data);
    } catch (e) {
      locationOptions.clear();
    }
  }

  Future<void> _saveStudent() async {
    if (_formKey.currentState!.validate()) {
      try {
        final String credential = credentialController.text.trim();
        final String password = passwordController.text.trim();

        if (isEdit && student != null) {
          // EDITING EXISTING STUDENT
          // Get driver ID from the selected bus if bus has a driver
          String? driverId;
          if (selectedBusId.value.isNotEmpty) {
            final selectedBus = busController.buses
                .firstWhereOrNull((bus) => bus.id == selectedBusId.value);
            if (selectedBus != null && selectedBus.hasDriver) {
              driverId = selectedBus.driverId;
            }
          }
          
          // Update existing student (no password in Student model anymore)
          final updatedStudent = Student(
            id: student!.id,
            email: credential,
            password: '', // Password no longer stored
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
            assignedRouteId:
              selectedRouteId.value.isNotEmpty ? selectedRouteId.value : null,
            assignedRouteName:
              selectedRouteName.value.isNotEmpty ? selectedRouteName.value : null,
            assignedDriverId: driverId,
            schoolId: schoolId,
          );
          await studentController.updateStudent(student!.id, updatedStudent);
          
          // Update metadata in adminusers (no password)
          final adminUpdate = <String, dynamic>{
            'email': credential,
            'name': nameController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          await FirebaseFirestore.instance
              .collection('adminusers')
              .doc(student!.id)
              .update(adminUpdate);
          
          // Handle bus assignment changes
          final oldBusId = student!.assignedBusId;
          final newBusId = selectedBusId.value.isNotEmpty ? selectedBusId.value : null;
          
          if (oldBusId != newBusId) {
            if (oldBusId != null && oldBusId.isNotEmpty) {
              await busController.removeStudentFromBus(oldBusId, student!.id);
            }
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
          // CREATING NEW STUDENT with Firebase Authentication
          
          // Check if email already exists in Firestore (our source of truth)
          final credential = credentialController.text.trim();
          final existingQuery = FirebaseFirestore.instance
              .collection('adminusers')
              .where('email', isEqualTo: credential)
              .where('schoolId', isEqualTo: schoolId)
              .limit(1);

          final existingDocs = await existingQuery.get();
          if (existingDocs.docs.isNotEmpty) {
            Get.snackbar(
              'Duplicate Email',
              'This email is already registered in your school records: "$credential"',
              backgroundColor: Colors.red[100],
              colorText: Colors.red[900],
              snackPosition: SnackPosition.BOTTOM,
            );
            return;
          }

          // Show loading
          Get.dialog(
            const Center(child: CircularProgressIndicator()),
            barrierDismissible: false,
          );

          // Create Firebase Auth account using secondary app
          final secondaryApp = await Firebase.initializeApp(
            name: 'SecondaryApp-${DateTime.now().millisecondsSinceEpoch}',
            options: Firebase.app().options,
          );

          late final String studentUid;
          try {
            final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
            
            // Create with email/password
            final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
              email: credential,
              password: password,
            );
            
            studentUid = userCredential.user!.uid;
            await secondaryAuth.signOut();
          } finally {
            await secondaryApp.delete();
          }

          // Get driver ID from the selected bus
          String? driverId;
          if (selectedBusId.value.isNotEmpty) {
            final selectedBus = busController.buses
                .firstWhereOrNull((bus) => bus.id == selectedBusId.value);
            if (selectedBus != null && selectedBus.hasDriver) {
              driverId = selectedBus.driverId;
            }
          }

          // Create student metadata doc (no password)
          final newStudent = Student(
            id: studentUid,
            email: credential,
            password: '', // No password stored
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
            assignedRouteId:
              selectedRouteId.value.isNotEmpty ? selectedRouteId.value : null,
            assignedRouteName:
              selectedRouteName.value.isNotEmpty ? selectedRouteName.value : null,
            assignedDriverId: driverId,
            schoolId: schoolId,
          );

          await studentController.addStudent(newStudent);

          // Create adminusers doc for custom claims (NO PASSWORD)
          final adminUserData = <String, dynamic>{
            'role': 'student',
            'schoolId': schoolId,
            'studentId': studentUid,
            'name': nameController.text.trim(),
            'email': credential,
            'createdAt': FieldValue.serverTimestamp(),
          };

          await FirebaseFirestore.instance
              .collection('adminusers')
              .doc(studentUid)
              .set(adminUserData);

          // Set custom claims via Cloud Function
          try {
            final callable = FirebaseFunctions.instance.httpsCallable('setUserClaims');
            await callable.call({'uid': studentUid});
            print('✅ Custom claims set for student: $studentUid');
          } catch (claimsError) {
            print('⚠️ Failed to set custom claims (non-critical): $claimsError');
            // Continue - user can still login, claims will be set on first login
          }

          // Add student to bus
          if (selectedBusId.value.isNotEmpty) {
            await busController.addStudentToBus(
                selectedBusId.value, newStudent.id);
          }

          Get.back(); // Close loading dialog
          Get.back(); // Close form

          Get.snackbar(
            'Success',
            'Student created successfully. Email: $credential',
            backgroundColor: Colors.green[100],
            colorText: Colors.green[900],
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      } catch (e, stackTrace) {
        // Close loading dialog if it's still open
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }
        
        print('❌ Error saving student: $e');
        print('❌ Stack trace: $stackTrace');
        
        // ✅ Handle "email-already-in-use" - check if it's an orphaned account
        if (e.toString().contains('email-already-in-use')) {
          // Check if this email exists in OUR Firestore database
          final credential = credentialController.text.trim();
          FirebaseFirestore.instance
              .collection('adminusers')
              .where('email', isEqualTo: credential)
              .limit(1)
              .get()
              .then((snapshot) {
            if (snapshot.docs.isEmpty) {
              // ORPHANED ACCOUNT: Exists in Firebase Auth but NOT in Firestore
              Get.dialog(
                AlertDialog(
                  title: const Text('⚠️ Orphaned Account Detected'),
                  content: SizedBox(
                    width: 500,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'This email exists in Firebase Authentication but has no associated student data. '
                          'This usually happens when a previous registration attempt failed halfway.',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Email:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(credential),
                        const SizedBox(height: 16),
                        const Text(
                          'To fix this, please:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Text('1. Contact your system administrator'),
                        const Text('2. Ask them to delete this orphaned account from Firebase Authentication Console'),
                        const Text('3. Or try using a different email address'),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
                barrierDismissible: true,
              );
            } else {
              // Account exists in BOTH Auth and Firestore - legitimate duplicate
              Get.snackbar(
                'Email Already Exists',
                'This email "$credential" is already registered as a student in your school. '
                'Please use a different email or edit the existing student.',
                backgroundColor: Colors.red[100],
                colorText: Colors.red[900],
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 8),
                maxWidth: 500,
              );
            }
          });
          return;
        }
        
        // ✅ Other error types with specific messages
        String errorTitle = 'Error';
        String errorMessage = 'Failed to save student: ${e.toString()}';
        
        if (e.toString().contains('invalid-email')) {
          errorTitle = 'Invalid Email';
          errorMessage = 'The email address format is invalid. Please check and try again.';
        } else if (e.toString().contains('weak-password')) {
          errorTitle = 'Weak Password';
          errorMessage = 'The password is too weak. Please use a stronger password (at least 6 characters).';
        } else if (e.toString().contains('network')) {
          errorTitle = 'Network Error';
          errorMessage = 'Network connection issue. Please check your internet connection and try again.';
        }
        
        Get.snackbar(
          errorTitle,
          errorMessage,
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 8),
          maxWidth: 500,
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
        selectedRouteId.value = student!.assignedRouteId ?? '';
        selectedRouteName.value = student!.assignedRouteName ?? '';

        // Load routes/stops (best-effort; avoid blocking build)
        if (routeOptions.isEmpty) {
          Future.microtask(() => _loadRoutesAndStopsForBus(selectedBusId.value));
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
                  Obx(() => TextFormField(
                        controller: credentialController,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (v) => credentialCheck.onValueChanged(
                          v,
                          excludeDocId: (isEdit && student != null) ? student!.id : null,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'Enter email address',
                          prefixIcon: const Icon(Icons.email),
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
                                  : (credentialController.text.trim().isNotEmpty
                                      ? const Icon(Icons.check_circle, color: Colors.green)
                                      : null)),
                          errorText: credentialCheck.isTaken.value
                              ? 'This email is already registered'
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          helperText: 'Student will login using this email',
                          helperMaxLines: 2,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (credentialCheck.isTaken.value) {
                            return 'This email is already registered';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      )),
                  const SizedBox(height: 16),
                  Obx(() => TextFormField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter password (min 6 characters)',
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
                          helperText: 'Student will login using this password.',
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
                  const SizedBox(height: 16),

                  // Route selection (required when multiple routes exist)
                  Obx(() {
                    if (selectedBusId.value.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    if (routeOptions.isEmpty) {
                      return TextFormField(
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Route',
                          hintText: 'No routes assigned to this bus',
                          prefixIcon: const Icon(Icons.route),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      );
                    }

                    return DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Route',
                        prefixIcon: const Icon(Icons.route),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      value: selectedRouteId.value.isNotEmpty ? selectedRouteId.value : null,
                      items: routeOptions.map((r) {
                        return DropdownMenuItem<String>(
                          value: r['id'] as String,
                          child: Text(r['name'] as String),
                        );
                      }).toList(),
                      onChanged: routeOptions.length <= 1
                          ? null
                          : (value) async {
                              if (value == null) return;
                              selectedRouteId.value = value;
                              final selected = routeOptions.firstWhere((r) => r['id'] == value);
                              selectedRouteName.value = selected['name'] as String;
                              stoppingController.text = '';
                              await _loadStopsForSelectedRoute();
                            },
                      validator: (value) {
                        if (routeOptions.length > 1 && (value == null || value.isEmpty)) {
                          return 'Please select a route';
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
                          hintText: selectedBusId.value.isEmpty
                              ? 'Select a bus first'
                              : (routeOptions.length > 1 && selectedRouteId.value.isEmpty)
                                  ? 'Select a route first'
                                  : 'No stops available',
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
                child: Obx(() => ElevatedButton(
                      onPressed: (credentialCheck.isChecking.value || credentialCheck.isTaken.value)
                          ? null
                          : _saveStudent,
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
                    )),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
