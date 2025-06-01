import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class SchoolAdminPaymentScreen extends StatelessWidget {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final String schoolId;

  SchoolAdminPaymentScreen(this.schoolId, {super.key});

  /// Opens WhatsApp with a pre-composed message to pay the bill.
  void payBill(String amount) async {
    String message = "Hello, I want to pay my pending bill of ₹$amount.";
    String whatsappUrlString =
        "https://wa.me/917597181771?text=${Uri.encodeComponent(message)}";
    final Uri whatsappUrl = Uri.parse(whatsappUrlString);

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar("Error", "Could not open WhatsApp");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("School Admin - Payments")),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('schools')
            .doc(schoolId)
            .collection('payments')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var payments = snapshot.data!.docs;
          if (payments.isEmpty) {
            return const Center(child: Text("No payment records found."));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              var payment = payments[index];
              // Retrieve payment fields. These fields can be null if not set.
              double amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
              String status = payment['status'] ?? 'Pending';
              String? title = payment['title']; // Optional payment title
              String? dueDate = payment['dueDate']; // Optional due date

              // Format createdAt date (if available)
              Timestamp? timestamp = payment['createdAt'] as Timestamp?;
              DateTime createdAt = timestamp?.toDate() ?? DateTime.now();
              String formattedDate =
                  "${createdAt.day}-${createdAt.month}-${createdAt.year}";

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Amount: ₹${amount.toStringAsFixed(2)}",
                            style: const TextStyle(fontSize: 15),
                          ),
                          Text(
                            "Date: $formattedDate",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      if (dueDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "Due Date: $dueDate",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Status: $status",
                            style: TextStyle(
                              color: status.toLowerCase() == 'pending'
                                  ? Colors.red
                                  : Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          status.toLowerCase() == 'pending'
                              ? ElevatedButton(
                                  onPressed: () => payBill(amount.toString()),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: const Text("Pay"),
                                )
                              : const Icon(Icons.check_circle,
                                  color: Colors.green),
                        ],
                      ),
                    ],
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
