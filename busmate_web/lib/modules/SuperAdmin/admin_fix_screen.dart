import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

/// Quick fix screen to update admin schoolId
class AdminFixScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AdminFixScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Fix Admin - School Mapping',
          style: TextStyle(fontSize: isMobile ? 16 : 18),
        ),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Admin Configuration',
              style: TextStyle(
                fontSize: isMobile ? 18 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isMobile ? 12 : 20),
            
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
                        padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 0),
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
                            margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
                            color: schoolExists ? Colors.green[50] : Colors.red[50],
                            child: Padding(
                              padding: EdgeInsets.all(isMobile ? 12 : 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        schoolExists ? Icons.check_circle : Icons.error,
                                        color: schoolExists ? Colors.green : Colors.red,
                                        size: isMobile ? 24 : 32,
                                      ),
                                      SizedBox(width: isMobile ? 8 : 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              adminData['email'] ?? 'No email',
                                              style: TextStyle(
                                                fontSize: isMobile ? 14 : 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: isMobile ? 2 : 4),
                                            Text(
                                              'Admin ID: ${admin.id}',
                                              style: TextStyle(
                                                fontSize: isMobile ? 10 : 12,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: isMobile ? 8 : 12),
                                  Divider(),
                                  SizedBox(height: isMobile ? 8 : 12),
                                  
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Current School ID: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: isMobile ? 12 : 14,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          currentSchoolId,
                                          style: TextStyle(
                                            color: schoolExists ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.bold,
                                            fontSize: isMobile ? 12 : 14,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  if (!schoolExists) ...[
                                    SizedBox(height: isMobile ? 8 : 12),
                                    Container(
                                      padding: EdgeInsets.all(isMobile ? 8 : 12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.orange),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.warning,
                                            color: Colors.orange,
                                            size: isMobile ? 18 : 20,
                                          ),
                                          SizedBox(width: isMobile ? 6 : 8),
                                          Expanded(
                                            child: Text(
                                              '⚠️ School not found! Select correct school:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: isMobile ? 12 : 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: isMobile ? 8 : 12),
                                    
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
