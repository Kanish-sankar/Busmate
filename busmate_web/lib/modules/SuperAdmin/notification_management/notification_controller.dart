// notification_controller.dart
import 'package:busmate_web/modules/Authentication/auth_controller.dart';
import 'package:busmate_web/modules/SuperAdmin/notification_management/notification_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RxList<NotificationModel> notifications = <NotificationModel>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    isLoading.value = true;
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('notifications')
          .orderBy('sentAt', descending: true)
          .get();

      notifications.value = snapshot.docs
          .map((doc) =>
              NotificationModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Get.snackbar('Error', 'Failed to fetch notifications: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendNotification({
    required String title,
    required String message,
    required List<String> recipientGroups,
    Map<String, dynamic>? extraData,
  }) async {
    final String id = _firestore.collection('notifications').doc().id;
    NotificationModel notification = NotificationModel(
      id: id,
      title: title,
      message: message,
      sentAt: DateTime.now(),
      recipientGroups: recipientGroups,
      senderId: Get.find<AuthController>().user.value!.uid,
      extraData: extraData,
      status: 'pending',
    );

    try {
      await _firestore
          .collection('notifications')
          .doc(id)
          .set(notification.toJson());
      notifications.insert(0, notification);

      // --- Custom logic for students/drivers ---
      if (extraData != null && extraData['selectedSchoolRecipients'] != null) {
        final Map<String, Map<String, bool>> selectedSchoolRecipients =
            Map<String, Map<String, bool>>.from(
                extraData['selectedSchoolRecipients']);

        for (final entry in selectedSchoolRecipients.entries) {
          final schoolId = entry.key;
          final groups = entry.value;

          if (groups['students'] == true) {
            await notifyAllStudentsOfSchool(schoolId, title, message);
          }
          if (groups['drivers'] == true) {
            await notifyAllDriversOfSchool(schoolId, title, message);
          }
          // School admins are handled by your existing logic (Firestore doc, Cloud Function, etc.)
        }
      }

      await _sendPushNotifications(notification);
    } catch (e) {
      Get.snackbar('Error', 'Failed to send notification: $e');
    }
  }

  Future<void> notifyAllStudentsOfSchool(
      String schoolId, String title, String body) async {
    final url = Uri.parse('https://notifyallstudents-gnxzq4evda-uc.a.run.app');
    try {
      final requestBody = {
        "schoolId": schoolId,
        "title": title,
        "body": body,
      };
      print('Sending to notifyAllStudents: $requestBody');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );
      print(
          'notifyAllStudents response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        if (Get.isSnackbarOpen) Get.closeAllSnackbars();
        print('✅ Student notification sent for $schoolId');
      } else {
        print('❌ Failed to notify students: ${response.body}');
      }
    } catch (e) {
      print('❌ Error notifying students: $e');
    }
  }

  Future<void> notifyAllDriversOfSchool(
      String schoolId, String title, String body) async {
    final url = Uri.parse('https://notifyalldrivers-gnxzq4evda-uc.a.run.app');
    try {
      final requestBody = {
        "schoolId": schoolId,
        "title": title,
        "body": body,
      };
      print('Sending to notifyAllDrivers: $requestBody');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );
      print(
          'notifyAllDrivers response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        if (Get.isSnackbarOpen) Get.closeAllSnackbars();
        print('✅ Driver notification sent for $schoolId');
      } else {
        print('❌ Failed to notify drivers: ${response.body}');
      }
    } catch (e) {
      print('❌ Error notifying drivers: $e');
    }
  }

  Future<void> _sendPushNotifications(NotificationModel notification) async {
    // In production, this would be handled automatically by a Firebase Cloud Function.
    // For demonstration, we simulate a delay and then update the status.
    await Future.delayed(const Duration(seconds: 2)); // Simulate network delay

    try {
      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .update({'status': 'sent'});

      // Update local notification list
      int index = notifications.indexWhere((n) => n.id == notification.id);
      if (index != -1) {
        notifications[index] = NotificationModel(
          id: notification.id,
          title: notification.title,
          message: notification.message,
          sentAt: notification.sentAt,
          recipientGroups: notification.recipientGroups,
          senderId: notification.senderId,
          extraData: notification.extraData,
          status: 'sent',
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to update notification status: $e');
    }
  }
}
