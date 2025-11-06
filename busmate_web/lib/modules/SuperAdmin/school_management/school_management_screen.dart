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
    final controller = Get.put(SchoolManagementController());
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Top bar: Search field and Add School button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: controller.searchSchools,
                    decoration: const InputDecoration(
                      labelText: "Search Schools",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Refresh icon button
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: "Refresh Schools",
                  onPressed: controller.fetchSchools,
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => Get.to(() => AddSchoolScreen()),
                  icon: const Icon(Icons.add),
                  label: const Text("Add School"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 20),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Grid view for school cards
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.schools.isEmpty) {
                  return const Center(child: Text("No schools found"));
                }
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // Adjust number of columns for Chrome
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,
                    childAspectRatio: 3 / 2,
                  ),
                  itemCount: controller.schools.length,
                  itemBuilder: (context, index) {
                    final school = controller.schools[index];
                    return InkWell(
                      onTap: () {
                        Get.dialog(
                            SchoolDetailsDialog(school: school) as Widget);
                      },
                      child: Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    school['schoolName'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Text("Email: ${school['email'] ?? ''}"),
                                  Text("Phone: ${school['phone'] ?? ''}"),
                                  Text("Address: ${school['address'] ?? ''}",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  Text("Code: ${school['schoolCode'] ?? ''}"),
                                  Text("ID: ${school['school_id'] ?? ''}"),
                                  Text("Buses: ${school['totalBuses'] ?? 0}"),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
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
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
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