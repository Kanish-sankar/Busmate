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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          return StreamBuilder<QuerySnapshot>(
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
                padding: EdgeInsets.all(isMobile ? 8 : 12),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return NotificationCard(notification: notification, isMobile: isMobile);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final bool isMobile;

  const NotificationCard({super.key, required this.notification, this.isMobile = false});

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('MMM dd, yyyy hh:mm a');
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 0 : 12,
        vertical: isMobile ? 6 : 8,
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.title,
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isMobile ? 5 : 6),
            Text(
              notification.message,
              style: TextStyle(fontSize: isMobile ? 13 : 14),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isMobile ? 6 : 8),
            Row(
              children: [
                Icon(Icons.access_time, size: isMobile ? 14 : 16),
                SizedBox(width: isMobile ? 3 : 4),
                Expanded(
                  child: Text(
                    formatter.format(notification.sentAt),
                    style: TextStyle(fontSize: isMobile ? 12 : 13),
                  ),
                ),
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
