import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String paymentId;
  final String schoolId;
  final String schoolName;
  final String schoolEmail;
  final String title;
  final String type; // 'hardware', 'software', 'subscription', 'other'
  final double amount;
  final String dueDate;
  final String status; // 'pending', 'paid', 'overdue', 'cancelled'
  final bool emailSent;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? paidAt;
  final DateTime? lastEmailSent;
  final String? notes;
  final String? invoiceNumber;

  PaymentModel({
    required this.paymentId,
    required this.schoolId,
    required this.schoolName,
    required this.schoolEmail,
    required this.title,
    required this.type,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.emailSent = false,
    required this.createdAt,
    this.updatedAt,
    this.paidAt,
    this.lastEmailSent,
    this.notes,
    this.invoiceNumber,
  });

  // Convert Firestore document to PaymentModel
  factory PaymentModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      paymentId: doc.id,
      schoolId: data['schoolId'] ?? '',
      schoolName: data['schoolName'] ?? '',
      schoolEmail: data['schoolEmail'] ?? '',
      title: data['title'] ?? '',
      type: data['type'] ?? 'other',
      amount: (data['amount'] is num) ? (data['amount'] as num).toDouble() : 0.0,
      dueDate: data['dueDate'] ?? '',
      status: data['status'] ?? 'pending',
      emailSent: data['emailSent'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
      lastEmailSent: (data['lastEmailSent'] as Timestamp?)?.toDate(),
      notes: data['notes'],
      invoiceNumber: data['invoiceNumber'],
    );
  }

  // Convert PaymentModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'schoolName': schoolName,
      'schoolEmail': schoolEmail,
      'title': title,
      'type': type,
      'amount': amount,
      'dueDate': dueDate,
      'status': status,
      'emailSent': emailSent,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'lastEmailSent': lastEmailSent != null ? Timestamp.fromDate(lastEmailSent!) : null,
      'notes': notes,
      'invoiceNumber': invoiceNumber,
    };
  }

  // Copy with method for easy updates
  PaymentModel copyWith({
    String? paymentId,
    String? schoolId,
    String? schoolName,
    String? schoolEmail,
    String? title,
    String? type,
    double? amount,
    String? dueDate,
    String? status,
    bool? emailSent,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? paidAt,
    DateTime? lastEmailSent,
    String? notes,
    String? invoiceNumber,
  }) {
    return PaymentModel(
      paymentId: paymentId ?? this.paymentId,
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName ?? this.schoolName,
      schoolEmail: schoolEmail ?? this.schoolEmail,
      title: title ?? this.title,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      emailSent: emailSent ?? this.emailSent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paidAt: paidAt ?? this.paidAt,
      lastEmailSent: lastEmailSent ?? this.lastEmailSent,
      notes: notes ?? this.notes,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
    );
  }

  // Check if payment is overdue
  bool get isOverdue {
    if (status.toLowerCase() == 'paid') return false;
    try {
      final due = DateTime.parse(dueDate);
      return DateTime.now().isAfter(due);
    } catch (e) {
      return false;
    }
  }

  // Get status color
  String get statusColor {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'green';
      case 'pending':
        return isOverdue ? 'red' : 'orange';
      case 'overdue':
        return 'red';
      case 'cancelled':
        return 'grey';
      default:
        return 'blue';
    }
  }
}