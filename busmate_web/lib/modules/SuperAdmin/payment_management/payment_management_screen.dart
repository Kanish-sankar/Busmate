import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SuperAdminPaymentScreen extends StatelessWidget {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  SuperAdminPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Super Admin - Payment Management"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.collection('schools').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var schools = snapshot.data!.docs;

          return ListView.builder(
            itemCount: schools.length,
            itemBuilder: (context, index) {
              var school = schools[index];
              return ListTile(
                title: Text(school['school_name']),
                subtitle: Text("Email: ${school['email']}"),
                // Removed the trailing "Generate Bill" button.
                onTap: () => Get.to(
                  () => PaymentHistoryScreen(
                    schoolId: school.id,
                    schoolName: school['school_name'],
                    schoolEmail: school['email'],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// GetX Controller for handling payment-related operations.
class PaymentController extends GetxController {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// Sends an email for the given payment. Constructs the email content
  /// using the provided payment details and then updates the payment record.
  Future<void> sendPaymentEmail({
    required String schoolId,
    required String paymentId,
    required Map<String, dynamic> paymentData,
    required String schoolName,
    required String schoolEmail,
  }) async {
    // Retrieve necessary fields from the payment record.
    DateTime createdAt =
        (paymentData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    String invoiceId = paymentId;
    String title = paymentData['title'] ?? "Payment";
    double amount = (paymentData['amount'] is num)
        ? (paymentData['amount'] as num).toDouble()
        : 0.0;
    String dueDate = paymentData['dueDate'] ?? "";
    // For billing period, we assume it starts at the created date and ends at the due date.
    String billingPeriod = "${_formatDate(createdAt)} to $dueDate";
    String monthYear = "${_monthName(createdAt.month)} ${createdAt.year}";

    // Payment Link via WhatsApp
    String paymentLink =
        "https://wa.me/917597181771?text=${Uri.encodeComponent("Hello, I want to pay my pending bill of ₹$amount.")}";

    // Construct email subject and content using the provided format.
    String subject = "$schoolName – BusMate Service Invoice for $monthYear";

    String emailContent = """
Dear $schoolName Team,

We hope you are having a great day! Please find attached the invoice for your BusMate subscription for the month of $monthYear. Kindly review the details below:

Invoice Details:
 Invoice Number: $invoiceId
 Payment Name: $title
 Billing Period: $billingPeriod
 Total Amount: ₹${amount.toStringAsFixed(2)}
 Due Date: $dueDate
 Payment Link: $paymentLink

Please ensure the payment is made before the due date to avoid any service disruptions. If you have already completed the payment, kindly ignore this email.

For any billing-related queries, feel free to reach out to us at jupentabusmate@gmail.com or call 7597181771.

Thank you for being a valued partner with BusMate!

Best Regards,
Kanish SS
Jupenta Technologies
 jupentabusmate@gmail.com | 7597181771 | 
123 Lotus Temple near Gate no. 3
""";

    // Use your deployed Cloud Function endpoint for sending email
    const String cloudFunctionUrl =
        'https://sendcredentialemail-gnxzq4evda-uc.a.run.app';

    try {
      final response = await http.post(
        Uri.parse(cloudFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': schoolEmail,
          'subject': subject,
          'body': emailContent,
        }),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to send payment email');
      }
    } catch (e) {
      if (kDebugMode) print('Error sending payment email: $e');
    }

    // Update Firestore document to mark that the email has been sent.
    await firestore
        .collection('schools')
        .doc(schoolId)
        .collection('payments')
        .doc(paymentId)
        .update({
      'emailSent': true,
      'lastEmailSent': FieldValue.serverTimestamp(),
    });
    Get.snackbar("Email Sent", "Invoice email sent to $schoolEmail");
  }

  String _monthName(int month) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return months[month - 1];
  }

  String _formatDate(DateTime date) {
    return "${date.day}-${date.month}-${date.year}";
  }
}

/// Payment History Screen with GetX state management.
class PaymentHistoryScreen extends StatefulWidget {
  final String schoolId;
  final String schoolName;
  final String schoolEmail; // New field to know where to send the email

  const PaymentHistoryScreen({
    super.key,
    required this.schoolId,
    required this.schoolName,
    required this.schoolEmail,
  });

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final PaymentController _paymentController = Get.put(PaymentController());

  // Controllers for the "Request Payment" dialog form.
  final _titleController = TextEditingController();
  final _typeController = TextEditingController();
  final _amountController = TextEditingController();
  final _dueDateController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _titleController.dispose();
    _typeController.dispose();
    _amountController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  /// Displays the dialog form to request a new payment.
  void _showRequestPaymentDialog() {
    _titleController.clear();
    _typeController.clear();
    _amountController.clear();
    _dueDateController.clear();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Request Payment"),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: "Title of Payment",
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Please enter a title";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _typeController,
                    decoration: const InputDecoration(
                      labelText: "Type of Payment (e.g. hardware, software)",
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Please enter a payment type";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Amount",
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Please enter an amount";
                      }
                      if (double.tryParse(value) == null) {
                        return "Amount must be a valid number";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _dueDateController,
                    decoration: const InputDecoration(
                      labelText: "Due Date (e.g. 2025-12-31)",
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Please enter a due date";
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: _requestPayment,
              child: const Text("Submit"),
            ),
          ],
        );
      },
    );
  }

  /// Creates a new payment request in Firestore from the dialog form.
  Future<void> _requestPayment() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        double amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
        await firestore
            .collection('schools')
            .doc(widget.schoolId)
            .collection('payments')
            .add({
          'schoolId': widget.schoolId,
          'title': _titleController.text.trim(),
          'type': _typeController.text.trim(),
          'amount': amount,
          'dueDate': _dueDateController.text.trim(),
          'status': 'Pending',
          'emailSent': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // ignore: use_build_context_synchronously
        Navigator.of(context).pop();
        Get.snackbar("Success", "Payment request generated");
      } catch (e) {
        Get.snackbar("Error", e.toString());
      }
    }
  }

  /// Marks the payment as paid.
  Future<void> _markAsPaid(String paymentId) async {
    try {
      await firestore
          .collection('schools')
          .doc(widget.schoolId)
          .collection('payments')
          .doc(paymentId)
          .update({'status': 'Paid'});
      Get.snackbar("Updated", "Payment marked as Paid");
    } catch (e) {
      Get.snackbar("Error", e.toString());
    }
  }

  /// Sends (or resends) the payment email using the PaymentController.
  Future<void> _resendRequest(
      String paymentId, Map<String, dynamic> paymentData) async {
    // Only send email if the payment is not already marked as paid.
    if ((paymentData['status'] as String).toLowerCase() == 'paid') return;

    await _paymentController.sendPaymentEmail(
      schoolId: widget.schoolId,
      paymentId: paymentId,
      paymentData: paymentData,
      schoolName: widget.schoolName,
      schoolEmail: widget.schoolEmail,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Customized AppBar.
      appBar: AppBar(
        titleSpacing: 0,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Super Admin",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
            ),
            Text(
              "School: ${widget.schoolName}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title and REQUEST PAYMENT button.
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Payment Management",
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: _showRequestPaymentDialog,
                  child: const Text(
                    "REQUEST PAYMENT",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          // Table header.
          Container(
            color: Colors.grey[300],
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    "DATE & TIME",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "AMOUNT",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "RECEIVED",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "STATUS",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "RESEND REQUEST",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // List of payment records.
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('schools')
                  .doc(widget.schoolId)
                  .collection('payments')
                  .where('schoolId', isEqualTo: widget.schoolId)
                  // .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var payments = snapshot.data!.docs;
                if (payments.isEmpty) {
                  return const Center(
                    child: Text("No payment history found."),
                  );
                }
                return ListView.builder(
                  itemCount: payments.length,
                  itemBuilder: (context, index) {
                    var payment = payments[index];
                    Map<String, dynamic> paymentData =
                        payment.data() as Map<String, dynamic>;
                    Timestamp? createdAt =
                        paymentData['createdAt'] as Timestamp?;
                    DateTime dateTime = createdAt?.toDate() ?? DateTime.now();
                    String date =
                        "${_twoDigits(dateTime.day)} ${_monthName(dateTime.month)} ${dateTime.year}";
                    String time =
                        "${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}:${_twoDigits(dateTime.second)}";
                    String dateTimeDisplay = "$date, $time";

                    String status = paymentData['status'] ?? 'Pending';
                    bool isPaid = status.toLowerCase() == 'paid';
                    double amount = (paymentData['amount'] is num)
                        ? (paymentData['amount'] as num).toDouble()
                        : 0.0;
                    bool emailSent = paymentData['emailSent'] ?? false;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 8),
                      margin: const EdgeInsets.symmetric(
                          vertical: 2, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isPaid ? Colors.grey.shade200 : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // DATE & TIME
                          Expanded(
                            flex: 2,
                            child: Text(
                              dateTimeDisplay,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          // AMOUNT
                          Expanded(
                            flex: 2,
                            child: Text(
                              "₹${amount.toStringAsFixed(2)}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          // RECEIVED (Paid or "Mark as Paid" button)
                          Expanded(
                            flex: 2,
                            child: isPaid
                                ? Text(
                                    "Paid",
                                    style: TextStyle(
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.bold),
                                  )
                                : ElevatedButton(
                                    onPressed: () => _markAsPaid(payment.id),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: const Text("Mark as Paid"),
                                  ),
                          ),
                          // STATUS
                          Expanded(
                            flex: 2,
                            child: Text(
                              status,
                              style: TextStyle(
                                color:
                                    isPaid ? Colors.green : Colors.orange[800],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          // RESEND REQUEST (Send/Resend button or disabled if paid)
                          Expanded(
                            flex: 2,
                            child: isPaid
                                ? ElevatedButton(
                                    onPressed: null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: const Text("Sent"),
                                  )
                                : ElevatedButton(
                                    onPressed: () =>
                                        _resendRequest(payment.id, paymentData),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: Text(emailSent ? "Resend" : "Send"),
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return months[month - 1];
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
}
