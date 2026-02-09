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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return AlertDialog(
      title: Text(
        school['school_name'] ?? 'School Details',
        style: TextStyle(fontSize: isMobile ? 18 : 20),
      ),
      contentPadding: EdgeInsets.all(isMobile ? 16 : 24),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? screenWidth * 0.9 : 500,
          maxHeight: isMobile ? 400 : 500,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow(Icons.email, "Email", school['email'] ?? '', isMobile),
              SizedBox(height: isMobile ? 10 : 12),
              _buildInfoRow(Icons.phone, "Phone", school['phone_number'] ?? '', isMobile),
              SizedBox(height: isMobile ? 10 : 12),
              _buildInfoRow(Icons.location_on, "Address", school['address'] ?? '', isMobile),
              SizedBox(height: isMobile ? 10 : 12),
              _buildInfoRow(Icons.credit_card, "Package", school['package_type'] ?? '', isMobile),
              SizedBox(height: isMobile ? 10 : 12),
              _buildInfoRow(Icons.lock, "Password", school['password'] ?? '', isMobile),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Get.back(); // Close dialog first
            Get.to(() => const SuperAdminPaymentManagementScreen());
          },
          child: Text(
            "View All Payments",
            style: TextStyle(fontSize: isMobile ? 13 : 14),
          ),
        ),
        TextButton(
          onPressed: () => Get.back(),
          child: Text(
            "Close",
            style: TextStyle(fontSize: isMobile ? 13 : 14),
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value, bool isMobile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: isMobile ? 18 : 20, color: Colors.grey[600]),
        SizedBox(width: isMobile ? 8 : 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
