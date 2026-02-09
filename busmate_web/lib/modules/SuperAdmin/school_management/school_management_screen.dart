// File: lib/modules/SuperAdmin/school_management/school_management_screen.dart
import 'package:busmate_web/modules/SuperAdmin/school_management/add_school_screen.dart';
import 'package:busmate_web/modules/SuperAdmin/school_management/school_dialogue_widget.dart';
import 'package:busmate_web/modules/SuperAdmin/school_management/school_management_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SchoolManagementScreen extends StatelessWidget {
  const SchoolManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use Get.find if already exists, otherwise create new
    final controller = Get.isRegistered<SchoolManagementController>()
        ? Get.find<SchoolManagementController>()
        : Get.put(SchoolManagementController());
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    // Determine grid columns based on screen size
    int crossAxisCount;
    double childAspectRatio;
    if (isMobile) {
      crossAxisCount = 1;
      childAspectRatio = 1.4;
    } else if (isTablet) {
      crossAxisCount = 2;
      childAspectRatio = 1.3;
    } else {
      crossAxisCount = 3;
      childAspectRatio = 1.5;
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFF0F9FF),
              Colors.white,
              const Color(0xFFFAF5FF),
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
          child: Column(
            children: [
              // Header section with title
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667EEA).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
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
                        Icons.school_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'School Management',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 18 : 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Obx(() => Text(
                                '${controller.schools.length} Schools',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: isMobile ? 12 : 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isMobile ? 12 : 20),
              // Top bar: Search field and buttons
              isMobile
                  ? Column(
                      children: [
                        TextField(
                          onChanged: controller.searchSchools,
                          decoration: InputDecoration(
                            labelText: "Search Schools",
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => Get.to(() => const AddSchoolScreen()),
                                icon: const Icon(Icons.add),
                                label: const Text("Add School"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF667EEA),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF667EEA).withOpacity(0.3),
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.refresh),
                                tooltip: "Refresh",
                                color: const Color(0xFF667EEA),
                                onPressed: controller.fetchSchools,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: controller.searchSchools,
                            decoration: InputDecoration(
                              labelText: "Search Schools",
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF667EEA).withOpacity(0.3),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: "Refresh Schools",
                            color: const Color(0xFF667EEA),
                            onPressed: controller.fetchSchools,
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () => Get.to(() => const AddSchoolScreen()),
                          icon: const Icon(Icons.add),
                          label: const Text("Add School"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667EEA),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: isTablet ? 16 : 20,
                            ),
                            textStyle: TextStyle(
                              fontSize: isTablet ? 14 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
              SizedBox(height: isMobile ? 12 : 20),
              // Grid view for school cards
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
                      ),
                    );
                  }
                  if (controller.schools.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No schools found",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification scrollInfo) {
                      if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent * 0.9) {
                        // Load more when 90% scrolled
                        if (controller.hasMoreData.value && !controller.isLoadingMore.value) {
                          controller.loadMoreSchools();
                        }
                      }
                      return false;
                    },
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: isMobile ? 12 : 15,
                        crossAxisSpacing: isMobile ? 12 : 15,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemCount: controller.schools.length + (controller.hasMoreData.value ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Show loading indicator at the end
                        if (index == controller.schools.length) {
                          return Center(
                            child: Obx(() => controller.isLoadingMore.value
                                ? const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(),
                                  )
                                : const SizedBox()),
                          );
                        }
                        
                        final school = controller.schools[index];
                        return InkWell(
                        onTap: () {
                          Get.dialog(
                              SchoolDetailsDialog(school: school) as Widget);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Card(
                          elevation: 4,
                          shadowColor: const Color(0xFF667EEA).withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: const Color(0xFF667EEA).withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white,
                                      const Color(0xFF667EEA).withOpacity(0.02),
                                    ],
                                  ),
                                ),
                                padding: EdgeInsets.all(isMobile ? 16 : 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF667EEA),
                                                Color(0xFF764BA2)
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.school,
                                            color: Colors.white,
                                            size: isMobile ? 18 : 20,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            school['schoolName'] ?? '',
                                            style: TextStyle(
                                              fontSize: isMobile ? 16 : 18,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF1F2937),
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _buildInfoRow(
                                              Icons.email_outlined,
                                              "Email",
                                              school['email'] ?? '',
                                              isMobile,
                                            ),
                                            const SizedBox(height: 6),
                                            _buildInfoRow(
                                              Icons.phone_outlined,
                                              "Phone",
                                              school['phone'] ?? '',
                                              isMobile,
                                            ),
                                            const SizedBox(height: 6),
                                            _buildInfoRow(
                                              Icons.location_on_outlined,
                                              "Address",
                                              school['address'] ?? '',
                                              isMobile,
                                            ),
                                            const SizedBox(height: 6),
                                            _buildInfoRow(
                                              Icons.code_outlined,
                                              "Code",
                                              school['schoolCode'] ?? '',
                                              isMobile,
                                            ),
                                            const SizedBox(height: 6),
                                            _buildInfoRow(
                                              Icons.directions_bus_outlined,
                                              "Buses",
                                              '${school['totalBuses'] ?? 0}',
                                              isMobile,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    iconSize: isMobile ? 20 : 24,
                                    tooltip: "Delete School",
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text("Delete School"),
                                          content: const Text(
                                              "Are you sure you want to delete this school and all its data? This action cannot be undone."),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text("Cancel"),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red),
                                              child: const Text("Delete"),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await controller.deleteSchoolAndAllData(
                                            school['school_id']);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isMobile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: isMobile ? 14 : 16,
          color: const Color(0xFF667EEA),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
              color: const Color(0xFF4B5563),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}







// MOVE SCHOOL TO INACTIVE SCHOOLS

//  Future<void> moveSchoolToInactive(Map<String, dynamic> school) async {
//     final FirebaseFirestore firestore = FirebaseFirestore.instance;
//     final String schoolId = school['school_id'] as String;

//     try {
//       // 1. Copy the main school document to "inactiveschools"
//       await firestore.collection('inactiveschools').doc(schoolId).set(school);

//       // 2. List the subcollections you want to move.
//       // For example, here we move the "payments" subcollection.
//       List<String> subCollectionsToMove = ["payments"];
//       for (String subCollectionName in subCollectionsToMove) {
//         final activeSubColRef = firestore
//             .collection('schools')
//             .doc(schoolId)
//             .collection(subCollectionName);
//         final inactiveSubColRef = firestore
//             .collection('inactiveschools')
//             .doc(schoolId)
//             .collection(subCollectionName);

//         // Fetch all documents in the subcollection
//         QuerySnapshot subCollectionSnapshot = await activeSubColRef.get();
//         for (var doc in subCollectionSnapshot.docs) {
//           // Copy each subcollection document to the inactive school doc
//           await inactiveSubColRef
//               .doc(doc.id)
//               .set(doc.data() as Map<String, dynamic>);
//           // Optionally, delete the document from the active subcollection
//           await activeSubColRef.doc(doc.id).delete();
//         }
//       }

//       // 3. Finally, delete the school document from the active "schools" collection.
//       await firestore.collection('schools').doc(schoolId).delete();

//       Get.snackbar(
//           "Success", "School and its subcollections moved to inactive");
//     } catch (e) {
//       Get.snackbar("Error", "Failed to move school: $e");
//     }
//   }