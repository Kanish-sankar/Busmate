// send_notification_screen.dart
import 'package:busmate_web/modules/SuperAdmin/school_management/school_management_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'notification_controller.dart';
import 'notification_model.dart';
import 'package:intl/intl.dart';

class SendNotificationScreen extends StatelessWidget {
  final NotificationController notificationController =
      Get.put(NotificationController());
  final SchoolManagementController controller =
      Get.put(SchoolManagementController());

  final TextEditingController titleController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  // List of selected school IDs for which at least one recipient group is chosen.
  final RxList<String> selectedSchoolIds = <String>[].obs;
  // Mapping schoolId to a Map of selected recipient groups:
  // { 'schools': true/false, 'parents': true/false, 'drivers': true/false }
  final RxMap<String, Map<String, bool>> selectedSchoolRecipients =
      <String, Map<String, bool>>{}.obs;

  SendNotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Notification'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Notification Sending Form
              _buildNotificationForm(),
              const SizedBox(height: 32),
              // Notification Logs Section
              _buildNotificationLogs(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Notification Title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: messageController,
          decoration: const InputDecoration(
            labelText: 'Notification Message',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
        ),
        const SizedBox(height: 16),
        const Text(
          'Select Schools:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.schools.isEmpty) {
            return const Center(child: Text('No schools found'));
          }

          return Column(
            children: controller.schools.map((school) {
              final String schoolName =
                  school['school_name'] ?? 'Unnamed School';
              final String schoolId = school['school_id'] ?? '';

              return ExpansionTile(
                title: Text(schoolName),
                children: [
                  CheckboxListTile(
                    title: const Text("School Admins"),
                    value:
                        selectedSchoolRecipients[schoolId]?['schools'] ?? false,
                    onChanged: (bool? value) {
                      selectedSchoolRecipients[schoolId] ??= {};
                      selectedSchoolRecipients[schoolId]!['schools'] =
                          value ?? false;
                      _updateSelectedSchoolIds(schoolId);
                      selectedSchoolRecipients.refresh();
                    },
                  ),
                  CheckboxListTile(
                    title: const Text("Students"),
                    value: selectedSchoolRecipients[schoolId]?['students'] ??
                        false,
                    onChanged: (bool? value) {
                      selectedSchoolRecipients[schoolId] ??= {};
                      selectedSchoolRecipients[schoolId]!['students'] =
                          value ?? false;
                      _updateSelectedSchoolIds(schoolId);
                      selectedSchoolRecipients.refresh();
                    },
                  ),
                  CheckboxListTile(
                    title: const Text("Drivers"),
                    value:
                        selectedSchoolRecipients[schoolId]?['drivers'] ?? false,
                    onChanged: (bool? value) {
                      selectedSchoolRecipients[schoolId] ??= {};
                      selectedSchoolRecipients[schoolId]!['drivers'] =
                          value ?? false;
                      _updateSelectedSchoolIds(schoolId);
                      selectedSchoolRecipients.refresh();
                    },
                  ),
                ],
              );
            }).toList(),
          );
        }),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty ||
                  messageController.text.trim().isEmpty ||
                  selectedSchoolIds.isEmpty) {
                Get.snackbar('Error',
                    'Please fill all fields and select at least one school with recipients');
                return;
              }

              // Convert RxMap to plain Map for serialization
              final Map<String, Map<String, bool>> selectedRecipientsPlain = {};
              selectedSchoolRecipients.forEach((key, value) {
                selectedRecipientsPlain[key] = Map<String, bool>.from(value);
              });

              await notificationController.sendNotification(
                title: titleController.text.trim(),
                message: messageController.text.trim(),
                recipientGroups: selectedSchoolIds.toList(),
                extraData: {
                  'selectedSchoolRecipients': selectedRecipientsPlain,
                },
              );

              // Clear the form fields
              titleController.clear();
              messageController.clear();
              selectedSchoolIds.clear();
              selectedSchoolRecipients.clear();
            },
            child: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('Send Notification'),
            ),
          ),
        ),
      ],
    );
  }

  // Helper function: Check if any recipient is selected for a given school.
  // If yes, ensure its schoolId is in selectedSchoolIds; otherwise, remove it.
  void _updateSelectedSchoolIds(String schoolId) {
    final recipients = selectedSchoolRecipients[schoolId] ?? {};
    bool isAnySelected = (recipients['schools'] ?? false) ||
        (recipients['students'] ?? false) ||
        (recipients['drivers'] ?? false);
    if (isAnySelected) {
      if (!selectedSchoolIds.contains(schoolId)) {
        selectedSchoolIds.add(schoolId);
      }
    } else {
      selectedSchoolIds.remove(schoolId);
    }
  }

  Widget _buildNotificationLogs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notification Logs:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Obx(() {
          if (notificationController.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (notificationController.notifications.isEmpty) {
            return const Center(child: Text('No notifications sent yet'));
          }
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: notificationController.notifications.length,
            itemBuilder: (context, index) {
              final notification = notificationController.notifications[index];
              return NotificationCard(notification: notification);
            },
          );
        }),
      ],
    );
  }
}

class NotificationCard extends StatelessWidget {
  final NotificationModel notification;

  const NotificationCard({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('MMM dd, yyyy hh:mm a');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(notification.message),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16),
                const SizedBox(width: 4),
                Text('Recipients: ${notification.recipientGroups.join(", ")}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 4),
                Text('Sent: ${formatter.format(notification.sentAt)}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 4),
                Text('Status: ${notification.status}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
