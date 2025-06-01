// notification_model.dart
class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime sentAt;
  final List<String> recipientGroups;
  final String? senderId;
  final Map<String, dynamic>? extraData;
  final String status; // "pending", "sent", "failed"

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.sentAt,
    required this.recipientGroups,
    this.senderId,
    this.extraData,
    this.status = 'pending',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'sentAt': sentAt.toIso8601String(),
      'recipientGroups': recipientGroups,
      'senderId': senderId,
      'extraData': extraData,
      'status': status,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      sentAt: DateTime.parse(json['sentAt']),
      recipientGroups: List<String>.from(json['recipientGroups']),
      senderId: json['senderId'],
      extraData: json['extraData'],
      status: json['status'] ?? 'pending',
    );
  }
}
