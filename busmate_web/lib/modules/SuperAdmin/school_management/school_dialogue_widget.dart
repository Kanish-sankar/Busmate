// import 'package:busmate_web/modules/SuperAdmin/payment_management/payment_management_controller.dart';
import 'package:busmate_web/modules/SuperAdmin/payment_management/super_admin_payment_screen.dart';
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
          onPressed: () {
            Get.back(); // Close dialog first
            Get.to(() => const SuperAdminPaymentManagementScreen());
          },
          child: const Text("View All Payments"),
        ),
        TextButton(
          onPressed: () => Get.back(),
          child: const Text("Close"),
        ),
      ],
    );
  }
}
