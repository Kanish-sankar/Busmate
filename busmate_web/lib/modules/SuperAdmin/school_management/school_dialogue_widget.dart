// import 'package:busmate_web/modules/SuperAdmin/payment_management/payment_management_controller.dart';
import 'package:busmate_web/modules/SuperAdmin/payment_management/payment_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SchoolDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> school;
  const SchoolDetailsDialog({super.key, required this.school});
  // final PaymentController _paymentController = Get.put(PaymentController());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(school['school_name'] ?? 'School Details'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Email: ${school['email'] ?? ''}"),
            Text("Phone: ${school['phone_number'] ?? ''}"),
            Text("Address: ${school['address'] ?? ''}"),
            Text("Package: ${school['package_type'] ?? ''}"),
            Text("Password: ${school['password'] ?? ''}"),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.to(() => PaymentHistoryScreen(
                schoolId: school['school_id'],
                schoolName: school['school_name'],
                schoolEmail: school['email'],
              )),
          // _paymentController.selectedSchoolId.value = value;
          // _paymentController.fetchPaymentRequests(school['school_id']);
          // Open the payment details dialog
          // Get.dialog(PaymentDialog(schoolId: school['school_id']));

          child: const Text("Payment History"),
        ),
        TextButton(
          onPressed: () => Get.back(),
          child: const Text("Close"),
        ),
      ],
    );
  }
}
