import 'package:busmate_web/modules/SuperAdmin/notification_management/notification_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SchoolNotificationsScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String schoolId;

  SchoolNotificationsScreen(this.schoolId, {super.key});

  @override
  Widget build(BuildContext context) {
    // Query notifications for schools
    final Query notificationQuery = _firestore
        .collection('notifications')
        .where('recipientGroups', arrayContains: schoolId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('School Notifications'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: notificationQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No notifications available.'));
          }

          // Map Firestore documents to NotificationModel objects
          final notifications = snapshot.data!.docs.map((doc) {
            return NotificationModel.fromJson(
                doc.data() as Map<String, dynamic>);
          }).toList();

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return NotificationCard(notification: notification);
            },
          );
        },
      ),
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(notification.message),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 4),
                Text(formatter.format(notification.sentAt)),
              ],
            ),
            // const SizedBox(height: 4),
            // Row(
            //   children: [
            //     const Icon(Icons.info_outline, size: 16),
            //     const SizedBox(width: 4),
            //     Text('Status: ${notification.status}'),
            //   ],
            // ),
          ],
        ),
      ),
    );
  }
}
