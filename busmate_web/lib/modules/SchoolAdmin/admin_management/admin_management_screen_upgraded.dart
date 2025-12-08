import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SchoolAdminManagementScreenUpgraded extends StatefulWidget {
  final String schoolId;
  final bool fromSuperAdmin;

  const SchoolAdminManagementScreenUpgraded({
    super.key,
    required this.schoolId,
    this.fromSuperAdmin = false,
  });

  @override
  State<SchoolAdminManagementScreenUpgraded> createState() =>
      _SchoolAdminManagementScreenUpgradedState();
}

class _SchoolAdminManagementScreenUpgradedState
    extends State<SchoolAdminManagementScreenUpgraded> {
  late GlobalKey<FormState> _formKey;
  final TextEditingController _adminNameController = TextEditingController();
  final TextEditingController _adminIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final RxBool passwordVisible = false.obs;
  
  final RxMap<String, bool> _permissions = {
    "busManagement": true,
    "driverManagement": true,
    "routeManagement": true,
    "viewingBusStatus": true,
    "studentManagement": true,
    "paymentManagement": true,
    "notifications": true,
    "adminManagement": false, // Regional admins can't manage other admins by default
  }.obs;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> _verifyAdminPassword(String password) async {
    try {
      final adminEmail = _auth.currentUser!.email!;
      await _auth.signInWithEmailAndPassword(
          email: adminEmail, password: password);
      return true;
    } catch (e) {
      Get.snackbar(
        "Error",
        "Invalid admin password",
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
  }

  Future<void> _registerNewAdmin() async {
    if (_formKey.currentState!.validate()) {
      try {
        String? adminPassword = await _promptForAdminPassword();
        if (adminPassword == null || adminPassword.isEmpty) return;

        if (!await _verifyAdminPassword(adminPassword)) return;

        // Show loading
        Get.dialog(
          const Center(child: CircularProgressIndicator()),
          barrierDismissible: false,
        );

        // Store School Admin credentials BEFORE creating new user
        final schoolAdminEmail = _auth.currentUser!.email!;

        // Create user in Firebase Auth (this will auto-login the new user)
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        // Create regional admin document in 'admins' collection
        await FirebaseFirestore.instance
            .collection("admins")
            .doc(userCredential.user!.uid)
            .set({
              'email': _emailController.text.trim(),
              'role': 'regionalAdmin',
              'schoolId': widget.schoolId,
              'permissions': Map<String, bool>.from(_permissions),
              'adminName': _adminNameController.text.trim(),
              'adminID': _adminIdController.text.trim(),
              'createdAt': FieldValue.serverTimestamp(),
            });

        // Sign back in as School Admin (new user is auto-logged in, we need to restore School Admin)
        await _auth.signInWithEmailAndPassword(
          email: schoolAdminEmail,
          password: adminPassword,
        );

        Get.back(); // Close loading dialog

        Get.snackbar(
          "Success",
          "Admin created successfully!",
          backgroundColor: Colors.green[100],
          colorText: Colors.green[900],
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
        _clearForm();
      } catch (e) {
        Get.back(); // Close loading if still open
        Get.snackbar(
          "Error",
          "Failed to register admin: $e",
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  Future<void> _editAdmin(String docId, Map<String, dynamic> adminData) async {
    _populateForm(adminData);
    // Create a new form key for the edit dialog
    _formKey = GlobalKey<FormState>();
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Edit Regional Admin",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: _buildAdminForm(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        try {
                          String? adminPassword = await _promptForAdminPassword();
                          if (adminPassword == null || adminPassword.isEmpty) {
                            return;
                          }

                          if (!await _verifyAdminPassword(adminPassword)) return;

                          // Update in root admins collection
                          await FirebaseFirestore.instance.collection('admins').doc(docId).update({
                            'adminName': _adminNameController.text.trim(),
                            'adminID': _adminIdController.text.trim(),
                            'email': _emailController.text.trim(),
                            'permissions': Map<String, bool>.from(_permissions),
                          });

                          Get.back(); // Close dialog
                          Get.snackbar(
                            "Success",
                            "Admin updated successfully",
                            backgroundColor: Colors.green[100],
                            colorText: Colors.green[900],
                            snackPosition: SnackPosition.BOTTOM,
                          );
                          _clearForm();
                        } catch (e) {
                          Get.snackbar(
                            "Error",
                            "Failed to update admin: $e",
                            backgroundColor: Colors.red[100],
                            colorText: Colors.red[900],
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      "Save Changes",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAdmin(String docId, String adminName) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Are you sure you want to delete $adminName?"),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete from root admins collection (where Regional Admins are stored)
        await FirebaseFirestore.instance.collection('admins').doc(docId).delete();
        Get.snackbar(
          "Success",
          "Admin deleted successfully",
          backgroundColor: Colors.green[100],
          colorText: Colors.green[900],
          snackPosition: SnackPosition.BOTTOM,
        );
      } catch (e) {
        Get.snackbar(
          "Error",
          "Failed to delete admin: $e",
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  Future<String?> _promptForAdminPassword() async {
    TextEditingController passwordController = TextEditingController();
    String? password;

    await Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.blue[700]),
            const SizedBox(width: 12),
            const Text('Admin Authentication'),
          ],
        ),
        content: TextField(
          controller: passwordController,
          decoration: InputDecoration(
            labelText: 'Enter Your Password',
            prefixIcon: const Icon(Icons.password),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              password = passwordController.text.trim();
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
            ),
            child: const Text('Verify', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    return password;
  }

  void _clearForm() {
    // Create a new form key to prevent duplicate key errors
    _formKey = GlobalKey<FormState>();
    _adminNameController.clear();
    _adminIdController.clear();
    _emailController.clear();
    _passwordController.clear();
    _permissions.value = {
      "busManagement": true,
      "driverManagement": true,
      "routeManagement": true,
      "viewingBusStatus": true,
      "studentManagement": true,
      "paymentManagement": true,
      "notifications": true,
      "adminManagement": false,
    };
  }

  void _populateForm(Map<String, dynamic> adminData) {
    _adminNameController.text = adminData['adminName'] ?? '';
    _adminIdController.text = adminData['adminID'] ?? '';
    _emailController.text = adminData['email'] ?? '';
    
    Map<String, dynamic>? permissions = adminData['permissions'];
    if (permissions != null) {
      _permissions.clear();
      permissions.forEach((key, value) {
        _permissions[key] = value as bool;
      });
    }
  }

  String _getPermissionLabel(String key) {
    switch (key) {
      case 'busManagement':
        return 'Bus Management';
      case 'driverManagement':
        return 'Driver Management';
      case 'routeManagement':
        return 'Route Management';
      case 'viewingBusStatus':
        return 'View Bus Status';
      case 'studentManagement':
        return 'Student Management';
      case 'paymentManagement':
        return 'Payment Management';
      case 'notifications':
        return 'Notifications';
      case 'adminManagement':
        return 'Admin Management';
      default:
        return key;
    }
  }

  IconData _getPermissionIcon(String key) {
    switch (key) {
      case 'busManagement':
        return Icons.directions_bus;
      case 'driverManagement':
        return Icons.person;
      case 'routeManagement':
        return Icons.route;
      case 'viewingBusStatus':
        return Icons.visibility;
      case 'studentManagement':
        return Icons.school;
      case 'paymentManagement':
        return Icons.payment;
      case 'notifications':
        return Icons.notifications;
      case 'adminManagement':
        return Icons.admin_panel_settings;
      default:
        return Icons.check;
    }
  }

  Widget _buildAdminForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Information Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    const Text(
                      "Basic Information",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _adminNameController,
                  decoration: InputDecoration(
                    labelText: "Admin Name",
                    prefixIcon: const Icon(Icons.badge),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) =>
                      value!.isEmpty ? "Enter admin name" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _adminIdController,
                  decoration: InputDecoration(
                    labelText: "Admin ID",
                    prefixIcon: const Icon(Icons.numbers),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) =>
                      value!.isEmpty ? "Enter admin ID" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: "Email",
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value!.isEmpty) return "Enter email";
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return "Enter a valid email";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Obx(() => TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: "Password",
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
                        fillColor: Colors.white,
                      ),
                      obscureText: !passwordVisible.value,
                      validator: (value) {
                        if (value!.isEmpty) return "Enter password";
                        if (value.length < 6) {
                          return "Password must be at least 6 characters";
                        }
                        return null;
                      },
                    )),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Permissions Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    const Text(
                      "Screen Access Permissions",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Select which screens this Regional Admin can access",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                Obx(() => Column(
                      children: _permissions.keys.map((key) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _permissions[key]!
                                  ? Colors.green[300]!
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: SwitchListTile(
                            secondary: Icon(
                              _getPermissionIcon(key),
                              color: _permissions[key]!
                                  ? Colors.green[700]
                                  : Colors.grey,
                            ),
                            title: Text(
                              _getPermissionLabel(key),
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: _permissions[key]!
                                    ? Colors.black87
                                    : Colors.grey,
                              ),
                            ),
                            value: _permissions[key]!,
                            onChanged: (value) {
                              _permissions[key] = value;
                            },
                            activeColor: Colors.green[700],
                          ),
                        );
                      }).toList(),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(DocumentSnapshot doc) {
    var adminData = doc.data() as Map<String, dynamic>;
    var permissions = adminData['permissions'] as Map<String, dynamic>?;
    int accessibleScreens = permissions?.values.where((v) => v == true).length ?? 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  radius: 24,
                  child: Icon(Icons.person, color: Colors.blue[700], size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        adminData['adminName'] ?? 'Unknown Admin',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        adminData['email'] ?? 'No Email',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purple[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield, size: 16, color: Colors.purple[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Regional Admin',
                        style: TextStyle(
                          color: Colors.purple[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.badge, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'ID: ${adminData['adminID'] ?? 'N/A'}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(width: 24),
                Icon(Icons.screen_share, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '$accessibleScreens screens accessible',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _editAdmin(doc.id, adminData),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                    side: BorderSide(color: Colors.blue[300]!),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      _deleteAdmin(doc.id, adminData['adminName'] ?? 'Admin'),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[700],
                    side: BorderSide(color: Colors.red[300]!),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('admins')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('role', isEqualTo: 'regionalAdmin')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                const Text("Error loading admins"),
              ],
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  "No Regional Admins yet",
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  "Create your first Regional Admin using the form",
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) => _buildAdminCard(docs[index]),
        );
      },
    );
  }

  @override
  void dispose() {
    _adminNameController.dispose();
    _adminIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
        children: [
          // Form Section
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.person_add,
                              color: Colors.blue[700], size: 28),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Create Regional Admin",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Add a new Regional Admin with custom permissions",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildAdminForm(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _registerNewAdmin,
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text(
                          "Register Regional Admin",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // List Section
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.people,
                            color: Colors.green[700], size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Regional Admins",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Manage your Regional Admins and their permissions",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildAdminList()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
