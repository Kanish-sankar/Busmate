import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_management_controller.dart';
import 'package:busmate_web/modules/SchoolAdmin/driver_management/driver_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:busmate_web/modules/utils/uniqueness_check_controller.dart';
import 'driver_controller.dart';

class AddDriverScreenUpgraded extends StatefulWidget {
  const AddDriverScreenUpgraded({super.key});

  @override
  State<AddDriverScreenUpgraded> createState() => _AddDriverScreenUpgradedState();
}

class _AddDriverScreenUpgradedState extends State<AddDriverScreenUpgraded> {
  final _formKey = GlobalKey<FormState>();
  
  late final DriverController driverController;
  late final BusController busController;
  late final String schoolId;
  
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController licenseController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController profileImageController = TextEditingController();
  
  final RxBool passwordVisible = false.obs;
  final RxBool available = true.obs;
  late final UniquenessCheckController credentialCheck;
  final RxString selectedBusId = ''.obs;
  final RxString imageUploadStatus = ''.obs;
  final RxString profileImageUrlRx = ''.obs;
  final RxBool isLoading = false.obs;
  final RxString driverType = 'software'.obs; // 'software' or 'hardware'
  
  bool isEdit = false;
  Driver? driver;

  @override
  void initState() {
    super.initState();
    schoolId = Get.arguments?['schoolId'] ?? '';
    isEdit = Get.arguments?['isEdit'] ?? false;
    driver = Get.arguments?['driver'];
    
    driverController = Get.put(DriverController(), tag: schoolId);
    busController = Get.put(BusController(), tag: schoolId);
    
    driverController.schoolId = schoolId;
    busController.schoolId = schoolId;

    final credentialTag = 'driverCredential-$schoolId-${driver?.id ?? 'new'}';
    if (Get.isRegistered<UniquenessCheckController>(tag: credentialTag)) {
      credentialCheck = Get.find<UniquenessCheckController>(tag: credentialTag);
    } else {
      credentialCheck = Get.put(
        UniquenessCheckController(
          UniquenessCheckType.firebaseAuthEmail,
          schoolId: schoolId,
          authTypeGetter: () => 'email',
        ),
        tag: credentialTag,
      );
    }
    
    if (isEdit && driver != null) {
      _populateFields();
    }
    
    busController.fetchBuses();
  }

  void _populateFields() {
    emailController.text = driver!.email;
    passwordController.text = driver!.password;
    nameController.text = driver!.name;
    licenseController.text = driver!.licenseNumber;
    contactController.text = driver!.contactInfo;
    profileImageController.text = driver!.profileImageUrl;
    profileImageUrlRx.value = driver!.profileImageUrl;
    selectedBusId.value = driver!.assignedBusId ?? '';
    available.value = driver!.available;

    if (driver!.email.trim().isNotEmpty) {
      credentialCheck.onValueChanged(
        driver!.email,
        excludeDocId: driver!.id,
        debounce: Duration.zero,
      );
    }
    
    // Determine driver type based on assigned bus (if available)
    if (driver!.assignedBusId != null && driver!.assignedBusId!.isNotEmpty) {
      final assignedList = busController.buses.where((b) => b.id == driver!.assignedBusId).toList();
      if (assignedList.isNotEmpty) {
        final assignedBus = assignedList.first;
        driverType.value = assignedBus.gpsType;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Driver Type Selection
                  _buildDriverTypeSelection(),
                  const SizedBox(height: 24),

                  // Account Information (only for software drivers)
                  Obx(() => driverType.value == 'software'
                      ? _buildSectionCard(
                          title: 'Account Information',
                          icon: Icons.account_circle,
                          color: Colors.blue,
                          children: [
                            Obx(() => _buildTextField(
                              controller: emailController,
                              label: 'Email Address',
                              icon: Icons.email,
                              onChanged: (v) => credentialCheck.onValueChanged(
                                v,
                                excludeDocId: (isEdit && driver != null) ? driver!.id : null,
                              ),
                              errorText: (driverType.value == 'software' && credentialCheck.isTaken.value)
                                  ? 'Email already exists'
                                  : null,
                              suffixIcon: (driverType.value == 'software' && credentialCheck.isChecking.value)
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : (driverType.value == 'software' && credentialCheck.isTaken.value)
                                      ? const Icon(Icons.error_outline, color: Colors.red)
                                      : (driverType.value == 'software' && emailController.text.trim().isNotEmpty)
                                          ? const Icon(Icons.check_circle, color: Colors.green)
                                          : null,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                  return 'Please enter a valid email address';
                                }
                                if (credentialCheck.isTaken.value) {
                                  return 'Email already exists';
                                }
                                return null;
                              },
                            )),
                            const SizedBox(height: 16),
                            Obx(() => _buildTextField(
                                  controller: passwordController,
                                  label: 'Password',
                                  icon: Icons.lock,
                                  obscureText: !passwordVisible.value,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      passwordVisible.value ? Icons.visibility : Icons.visibility_off,
                                    ),
                                    onPressed: () => passwordVisible.value = !passwordVisible.value,
                                  ),
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
                        )
                      : const SizedBox.shrink()),

                  const SizedBox(height: 24),

                  // Personal Information (always visible)
                  _buildSectionCard(
                    title: 'Personal Information',
                    icon: Icons.person,
                    color: Colors.green,
                    children: [
                      _buildTextField(
                        controller: nameController,
                        label: 'Full Name',
                        icon: Icons.badge,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: licenseController,
                        label: 'License Number',
                        icon: Icons.credit_card,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'License Number is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: contactController,
                        label: 'Contact Number',
                        icon: Icons.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Contact number is required';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildSectionCard(
                    title: 'Profile Picture',
                    icon: Icons.photo_camera,
                    color: Colors.purple,
                    children: [
                      Row(
                        children: [
                          Obx(() => Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: profileImageUrlRx.value.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(11),
                                        child: Image.network(
                                          profileImageUrlRx.value,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              Icon(Icons.person, size: 40, color: Colors.grey[400]),
                                        ),
                                      )
                                    : Icon(Icons.person, size: 40, color: Colors.grey[400]),
                              )),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _pickAndUploadImage(),
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Upload Image'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple[600],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Obx(() => Text(
                                      imageUploadStatus.value.isEmpty
                                          ? 'No file selected'
                                          : imageUploadStatus.value,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: imageUploadStatus.value == 'Uploaded!'
                                            ? Colors.green
                                            : Colors.grey[600],
                                      ),
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildSectionCard(
                    title: 'Availability & Bus Assignment',
                    icon: Icons.assignment,
                    color: Colors.orange,
                    children: [
                      Obx(() => SwitchListTile(
                            title: const Text('Driver Available'),
                            subtitle: Text(
                              available.value ? 'Driver is available for assignments' : 'Driver is currently busy',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            value: available.value,
                            onChanged: (value) => available.value = value,
                            activeColor: Colors.green,
                          )),
                      const SizedBox(height: 16),
                      Obx(() {
                        final availableBuses = busController.buses
                            .where((bus) => bus.driverId == null || bus.driverId!.isEmpty || (isEdit && bus.id == selectedBusId.value))
                            .toList();

                        return DropdownButtonFormField<String>(
                          value: selectedBusId.value.isEmpty ? null : selectedBusId.value,
                          decoration: InputDecoration(
                            labelText: 'Assign Bus (Optional)',
                            prefixIcon: const Icon(Icons.directions_bus),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('No Bus Assigned'),
                            ),
                            ...availableBuses.map((bus) => DropdownMenuItem<String>(
                                  value: bus.id,
                                  child: Text('${bus.busNo} - ${bus.busVehicleNo}'),
                                )),
                          ],
                          onChanged: (value) => selectedBusId.value = value ?? '',
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 32),

                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1A1A1A),
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Get.back(),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isEdit ? Icons.edit : Icons.person_add,
              color: Colors.blue[700],
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isEdit ? 'Edit Driver' : 'Add New Driver',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverTypeSelection() {
    return Obx(() => Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.settings_input_component, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Driver Type', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Software (App)'),
                            selected: driverType.value == 'software',
                            onSelected: (s) => driverType.value = 'software',
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Hardware (Device)'),
                            selected: driverType.value == 'hardware',
                            onSelected: (s) => driverType.value = 'hardware',
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        driverType.value == 'software'
                            ? 'Software drivers need app credentials (email & password).'
                            : 'Hardware drivers do not require app login; only basic info will be stored.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        errorText: errorText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator,
    );
  }

  Widget _buildActionButtons() {
    return Obx(() => Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isLoading.value ? null : () => Get.back(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.grey[400]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: (isLoading.value ||
                    (driverType.value == 'software' &&
                        (credentialCheck.isChecking.value || credentialCheck.isTaken.value)))
                ? null
                : () => _handleSubmit(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: isLoading.value
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    isEdit ? 'Update Driver' : 'Add Driver',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    ));
  }

  Future<void> _pickAndUploadImage() async {
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
            .ref()
            .child('driver_images/${DateTime.now().millisecondsSinceEpoch}_$fileName');
        
        await storageRef.putData(fileBytes);
        final downloadUrl = await storageRef.getDownloadURL();
        
        profileImageController.text = downloadUrl;
        profileImageUrlRx.value = downloadUrl;
        imageUploadStatus.value = 'Uploaded!';
      } else {
        imageUploadStatus.value = 'No file selected';
      }
    } catch (e) {
      imageUploadStatus.value = 'Upload failed';
      Get.snackbar(
        'Error',
        'Failed to upload image: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    isLoading.value = true;

    try {
      if (isEdit && driver != null) {
        await _updateDriver();
      } else {
        await _registerDriver();
      }
    } catch (e) {
      // ✅ Handle "email-already-in-use" - check if it's an orphaned account
      if (e.toString().contains('email-already-in-use') || 
          e.toString().contains('email is already registered')) {
        
        // Check if this email exists in OUR Firestore database
        final credential = emailController.text.trim();
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
                        'This email exists in Firebase Authentication but has no associated driver data. '
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
              'This email "$credential" is already registered as a driver in your school. '
              'Please use a different email or edit the existing driver.',
              backgroundColor: Colors.red,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 8),
              maxWidth: 500,
            );
          }
        });
        return;
      }
      
      // ✅ Provide specific error messages based on error type
      String errorTitle = 'Error';
      String errorMessage = 'Failed to ${isEdit ? 'update' : 'add'} driver: $e';
      
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
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 8),
        maxWidth: 500,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _registerDriver() async {
    try {
      String driverUid = '';
      String? email;

      // For software drivers, create Firebase Auth account
      if (driverType.value == 'software') {
        final credential = emailController.text.trim();
        
        // Check if email already exists in Firestore (our source of truth)
        final existingQuery = await FirebaseFirestore.instance
            .collection('adminusers')
            .where('email', isEqualTo: credential)
            .where('schoolId', isEqualTo: schoolId)
            .limit(1)
            .get();
            
        if (existingQuery.docs.isNotEmpty) {
          Get.snackbar(
            'Duplicate Email',
            'This email is already registered in your school records: "$credential"',
            backgroundColor: Colors.red[100],
            colorText: Colors.red[900],
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }
        
        // Create a secondary Firebase app instance for driver creation
        // This prevents logging out the current admin
        FirebaseApp secondaryApp;
        try {
          secondaryApp = Firebase.app('SecondaryApp');
        } catch (e) {
          secondaryApp = await Firebase.initializeApp(
            name: 'SecondaryApp',
            options: Firebase.app().options,
          );
        }

        final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
        
        try {
          final credential = emailController.text.trim();
          final password = passwordController.text.trim();

          if (password.length < 6) {
            throw Exception('Password must be at least 6 characters');
          }

          // Email authentication
          final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
            email: credential,
            password: password,
          );
          email = credential;

          driverUid = userCredential.user!.uid;

          // Set display name
          await userCredential.user!.updateDisplayName(nameController.text.trim());

          // Sign out from secondary app (don't affect current admin session)
          await secondaryAuth.signOut();

          print('DEBUG: Created Firebase Auth account for driver: $driverUid');
        } catch (authError) {
          print('DEBUG: Firebase Auth error: $authError');
          if (authError.toString().contains('email-already-in-use')) {
            throw Exception('This email is already registered');
          } else if (authError.toString().contains('invalid-email')) {
            throw Exception('Invalid email format');
          } else if (authError.toString().contains('weak-password')) {
            throw Exception('Password is too weak. Use at least 6 characters');
          }
          rethrow;
        }
      } else {
        // Hardware drivers don't need Firebase Auth
        final docRef = driverController.driverCollection.doc();
        driverUid = docRef.id;
      }

      final newDriver = Driver(
        id: driverUid,
        email: driverType.value == 'software'
            ? emailController.text.trim() 
            : '',
        password: '', // No password stored in Driver model anymore
        name: nameController.text.trim(),
        licenseNumber: licenseController.text.trim(),
        contactInfo: contactController.text.trim(),
        profileImageUrl: profileImageController.text.trim(),
        gpsType: driverType.value,
        available: available.value,
        assignedBusId: selectedBusId.value.isNotEmpty ? selectedBusId.value : null,
        schoolId: schoolId,
      );

      await driverController.addDriver(newDriver);

      // Create metadata in adminusers collection (no password)
      if (driverType.value == 'software') {
        await FirebaseFirestore.instance.collection('adminusers').doc(driverUid).set({
          'email': email,
          'role': 'driver',
          'name': nameController.text.trim(),
          'schoolId': schoolId,
          'assignedBusId': selectedBusId.value.isNotEmpty ? selectedBusId.value : null,
          'contactInfo': contactController.text.trim(),
          'licenseNumber': licenseController.text.trim(),
          'employeeId': licenseController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('DEBUG: Created adminusers doc for driver: $driverUid');
        
        // Set custom claims via Cloud Function
        try {
          final callable = FirebaseFunctions.instance.httpsCallable('setUserClaims');
          await callable.call({'uid': driverUid});
          print('✅ Custom claims set for driver: $driverUid');
        } catch (claimsError) {
          print('⚠️ Failed to set custom claims (non-critical): $claimsError');
        }
      }

      if (selectedBusId.value.isNotEmpty) {
        await busController.updateBusDriver(
          selectedBusId.value,
          newDriver.id,
          newDriver.name,
        );
      }

      Get.back();
      Get.snackbar(
        'Success',
        'Driver added successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _updateDriver() async {
    try {
      final updatedDriver = Driver(
        id: driver!.id,
        email: emailController.text.trim(),
        password: passwordController.text,
        gpsType: driverType.value,
        name: nameController.text.trim(),
        licenseNumber: licenseController.text.trim(),
        contactInfo: contactController.text.trim(),
        profileImageUrl: profileImageController.text.trim(),
        available: available.value,
        assignedBusId: selectedBusId.value.isNotEmpty ? selectedBusId.value : null,
        schoolId: schoolId,
      );

      // Update driver document in schooldetails/{schoolId}/drivers/{driverId}
      await driverController.updateDriver(driver!.id, updatedDriver);

      // Update adminusers document if this is a software driver
      if (driverType.value == 'software') {
        try {
          await FirebaseFirestore.instance.collection('adminusers').doc(driver!.id).update({
            'email': emailController.text.trim(),
            'name': nameController.text.trim(),
            'contactInfo': contactController.text.trim(),
            'licenseNumber': licenseController.text.trim(),
            'employeeId': licenseController.text.trim(),
            'assignedBusId': selectedBusId.value.isNotEmpty ? selectedBusId.value : null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('✅ Updated adminusers doc for driver: ${driver!.id}');
        } catch (e) {
          print('⚠️ Failed to update adminusers (non-critical): $e');
        }
      }

      // Update bus assignment if changed
      if (driver!.assignedBusId != selectedBusId.value) {
        // Remove from old bus
        if (driver!.assignedBusId != null && driver!.assignedBusId!.isNotEmpty) {
          await busController.updateBusDriver(driver!.assignedBusId!, '', '');
        }
        // Assign to new bus
        if (selectedBusId.value.isNotEmpty) {
          await busController.updateBusDriver(
            selectedBusId.value,
            updatedDriver.id,
            updatedDriver.name,
          );
        }
      }

      Get.back();
      Get.snackbar(
        'Success',
        'Driver updated successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    licenseController.dispose();
    contactController.dispose();
    profileImageController.dispose();
    super.dispose();
  }
}
