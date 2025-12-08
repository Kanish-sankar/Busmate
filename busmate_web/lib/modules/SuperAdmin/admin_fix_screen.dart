import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

/// Quick fix screen to update admin schoolId
class AdminFixScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AdminFixScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fix Admin - School Mapping'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Admin Configuration',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Show all admins
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('admins').snapshots(),
                builder: (context, adminSnapshot) {
                  if (!adminSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('schooldetails').snapshots(),
                    builder: (context, schoolSnapshot) {
                      if (!schoolSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final admins = adminSnapshot.data!.docs;
                      final schools = schoolSnapshot.data!.docs;

                      return ListView.builder(
                        itemCount: admins.length,
                        itemBuilder: (context, index) {
                          final admin = admins[index];
                          final adminData = admin.data() as Map<String, dynamic>;
                          
                          // Skip super admins
                          if (adminData['role'] == 'superior' || adminData['role'] == 'super_admin') {
                            return const SizedBox.shrink();
                          }

                          final currentSchoolId = adminData['schoolId'] ?? 'NOT SET';
                          
                          // Find if school exists
                          final schoolExists = schools.any((s) => s.id == currentSchoolId);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            color: schoolExists ? Colors.green[50] : Colors.red[50],
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        schoolExists ? Icons.check_circle : Icons.error,
                                        color: schoolExists ? Colors.green : Colors.red,
                                        size: 32,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              adminData['email'] ?? 'No email',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Admin ID: ${admin.id}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(),
                                  const SizedBox(height: 12),
                                  
                                  Row(
                                    children: [
                                      const Text(
                                        'Current School ID: ',
                                        style: TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                      Expanded(
                                        child: Text(
                                          currentSchoolId,
                                          style: TextStyle(
                                            color: schoolExists ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  if (!schoolExists) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.orange),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.warning, color: Colors.orange),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '⚠️ School not found! Select correct school:',
                                              style: TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    // Dropdown to select correct school
                                    DropdownButtonFormField<String>(
                                      decoration: const InputDecoration(
                                        labelText: 'Select Correct School',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.school),
                                      ),
                                      items: schools.map((school) {
                                        final schoolData = school.data() as Map<String, dynamic>;
                                        return DropdownMenuItem(
                                          value: school.id,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                schoolData['schoolName'] ?? 'Unknown',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                'ID: ${school.id}',
                                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (newSchoolId) {
                                        if (newSchoolId != null) {
                                          _updateAdminSchoolId(admin.id, newSchoolId);
                                        }
                                      },
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.green[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check_circle, color: Colors.green),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '✅ School link is valid',
                                              style: TextStyle(
                                                color: Colors.green[900],
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateAdminSchoolId(String adminId, String newSchoolId) async {
    try {
      await _firestore.collection('admins').doc(adminId).update({
        'schoolId': newSchoolId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      Get.snackbar(
        '✅ Success',
        'Admin schoolId updated to $newSchoolId',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        '❌ Error',
        'Failed to update: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
