// school_admin_management_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

class SchoolAdminManagementScreen extends StatefulWidget {
  final String schoolId;
  const SchoolAdminManagementScreen(this.schoolId, {super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SchoolAdminManagementScreenState createState() =>
      _SchoolAdminManagementScreenState();
}

class _SchoolAdminManagementScreenState
    extends State<SchoolAdminManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _adminNameController = TextEditingController();
  final TextEditingController _adminIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final RxString _selectedRole = "schoolSuperAdmin".obs;
  final RxMap<String, bool> _permissions = {
    "busManagement": true,
    "driverManagement": true,
    "routeManagement": true,
    "viewingBusStatus": true,
    "studentManagement": true,
    "paymentManagement": true,
    "notifications": true,
    "adminManagement": true,
  }.obs;

  final RxMap<String, bool> _allpermissions = {
    "busManagement": true,
    "driverManagement": true,
    "routeManagement": true,
    "viewingBusStatus": true,
    "studentManagement": true,
    "paymentManagement": true,
    "notifications": true,
    "adminManagement": true,
  }.obs;

  CollectionReference get _schoolAdminsCollection => FirebaseFirestore.instance
      .collection("schools")
      .doc(widget.schoolId)
      .collection("admins");

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> _verifyAdminPassword(String password) async {
    try {
      final adminEmail = _auth.currentUser!.email!;
      await _auth.signInWithEmailAndPassword(
          email: adminEmail, password: password);
      return true;
    } catch (e) {
      Get.snackbar("Error", "Invalid admin password");
      return false;
    }
  }

  Future<void> _registerNewAdmin() async {
    if (_formKey.currentState!.validate()) {
      try {
        String? adminPassword = await _promptForAdminPassword();
        if (adminPassword == null || adminPassword.isEmpty) return;

        if (!await _verifyAdminPassword(adminPassword)) return;

        final response = await http.post(
          Uri.parse("https://createschooluser-gnxzq4evda-uc.a.run.app"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "email": _emailController.text,
            "password": _passwordController.text,
            "role": _selectedRole.value,
            "schoolId": widget.schoolId,
            "permissions": _selectedRole.value == "regionalAdmin"
                // ignore: invalid_use_of_protected_member
                ? _permissions.value
                : _allpermissions,
          }),
        );
        if (response.statusCode != 200) {
          throw Exception("Failed to create admin: ${response.body}");
        }

        final responseData = jsonDecode(response.body);
        final String newAdminUid = responseData['uid'];

        await _schoolAdminsCollection.doc(newAdminUid).set({
          'adminName': _adminNameController.text,
          'adminID': _adminIdController.text,
          'email': _emailController.text,
          'role': _selectedRole.value,
          'schoolId': widget.schoolId,
          'permissions': _selectedRole.value == "regionalAdmin"
              // ignore: invalid_use_of_protected_member
              ? _permissions.value
              : _allpermissions,
          'createdAt': FieldValue.serverTimestamp(),
        });

        Get.snackbar("Success", "Admin registered successfully");
        _clearForm();
      } catch (e) {
        Get.snackbar("Error", "Failed to register admin: $e");
      }
    }
  }

  Future<void> _editAdmin(String docId, Map<String, dynamic> adminData) async {
    _populateForm(adminData);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Admin"),
          content: _buildAdminForm(),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  try {
                    String? adminPassword = await _promptForAdminPassword();
                    if (adminPassword == null || adminPassword.isEmpty) return;

                    if (!await _verifyAdminPassword(adminPassword)) return;

                    await _schoolAdminsCollection.doc(docId).update({
                      'adminName': _adminNameController.text,
                      'adminID': _adminIdController.text,
                      'email': _emailController.text,
                      'role': _selectedRole.value,
                      'permissions': _selectedRole.value == "regionalAdmin"
                          // ignore: invalid_use_of_protected_member
                          ? _permissions.value
                          : null,
                    });

                    Get.snackbar("Success", "Admin updated successfully");
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).pop();
                  } catch (e) {
                    Get.snackbar("Error", "Failed to update admin: $e");
                  }
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAdmin(String docId) async {
    try {
      await _schoolAdminsCollection.doc(docId).delete();
      Get.snackbar("Success", "Admin deleted successfully");
    } catch (e) {
      Get.snackbar("Error", "Failed to delete admin: $e");
    }
  }

  Future<String?> _promptForAdminPassword() async {
    TextEditingController passwordController = TextEditingController();
    String? password;

    await Get.dialog(
      AlertDialog(
        title: const Text('Admin Authentication'),
        content: TextField(
          controller: passwordController,
          decoration: const InputDecoration(
            labelText: 'Enter Admin Password',
            border: OutlineInputBorder(),
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
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    return password;
  }

  void _clearForm() {
    _adminNameController.clear();
    _adminIdController.clear();
    _emailController.clear();
    _passwordController.clear();
    _selectedRole.value = "schoolSuperAdmin";
    _permissions.value = {
      "busManagement": true,
      "driverManagement": true,
      "routeManagement": true,
      "viewingBusStatus": true,
      "studentManagement": true,
      "paymentManagement": true,
      "notifications": true,
      "adminManagement": true,
    };
  }

  void _populateForm(Map<String, dynamic> adminData) {
    _adminNameController.text = adminData['adminName'] ?? '';
    _adminIdController.text = adminData['adminID'] ?? '';
    _emailController.text = adminData['email'] ?? '';
    _selectedRole.value = adminData['role'] ?? 'schoolSuperAdmin';
    _permissions.value = Map<String, bool>.from(
      adminData['permissions'] ??
          {
            "busManagement": true,
            "driverManagement": true,
            "routeManagement": true,
            "viewingBusStatus": true,
            "studentManagement": true,
            "paymentManagement": true,
            "notifications": true,
            "adminManagement": true,
          },
    );
  }

  Widget _buildAdminForm() {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _adminNameController,
              decoration: const InputDecoration(labelText: "Admin Name"),
              validator: (value) => value!.isEmpty ? "Enter admin name" : null,
            ),
            TextFormField(
              controller: _adminIdController,
              decoration: const InputDecoration(labelText: "Admin ID"),
              validator: (value) => value!.isEmpty ? "Enter admin ID" : null,
            ),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
              validator: (value) => value!.isEmpty ? "Enter email" : null,
            ),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
              validator: (value) => value!.isEmpty ? "Enter password" : null,
            ),
            Obx(() => DropdownButtonFormField<String>(
                  value: _selectedRole.value,
                  items: const [
                    DropdownMenuItem(
                      value: "schoolSuperAdmin",
                      child: Text("School Super Admin"),
                    ),
                    DropdownMenuItem(
                      value: "regionalAdmin",
                      child: Text("Regional Admin"),
                    ),
                  ],
                  onChanged: (value) {
                    _selectedRole.value = value!;
                  },
                  decoration: const InputDecoration(labelText: "Role"),
                )),
            Obx(() => Column(
                  children: [
                    if (_selectedRole.value == "regionalAdmin") ...[
                      const SizedBox(height: 10),
                      const Text("Set Permissions",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      ..._permissions.keys.map((key) {
                        return SwitchListTile(
                          title:
                              Text(key.replaceAll("Management", " Management")),
                          value: _permissions[key]!,
                          onChanged: (value) {
                            _permissions[key] = value;
                          },
                        );
                      }),
                    ],
                  ],
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _schoolAdminsCollection.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading admins."));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var adminData = docs[index].data() as Map<String, dynamic>;
            return ListTile(
              title: Text(adminData['adminName'] ?? 'Unknown Admin'),
              subtitle: Text(
                  "${adminData['email'] ?? 'No Email'} - ${adminData['role'] ?? 'No Role'}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editAdmin(docs[index].id, adminData),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteAdmin(docs[index].id),
                  ),
                ],
              ),
            );
          },
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
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    "Add New Admin",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  _buildAdminForm(),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _registerNewAdmin,
                    child: const Text("Register Admin"),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: _buildAdminList(),
        ),
      ],
    );
  }
}
