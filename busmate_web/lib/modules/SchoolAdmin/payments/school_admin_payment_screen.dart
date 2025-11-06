import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:busmate_web/controllers/payment_controller.dart';
import 'package:busmate_web/models/payment_model.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class SchoolAdminPaymentScreen extends StatefulWidget {
  final String schoolId;

  const SchoolAdminPaymentScreen(this.schoolId, {super.key});

  @override
  State<SchoolAdminPaymentScreen> createState() =>
      _SchoolAdminPaymentScreenState();
}

class _SchoolAdminPaymentScreenState extends State<SchoolAdminPaymentScreen> {
  late final PaymentController controller;

  @override
  void initState() {
    super.initState();
    // Initialize controller once with unique tag based on schoolId
    controller = Get.put(
      PaymentController(),
      tag: 'school_admin_payment_${widget.schoolId}',
    );
    controller.fetchSchoolPayments(widget.schoolId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[500]!],
            ),
          ),
        ),
        title: const Text(
          'My Payments',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.fetchSchoolPayments(widget.schoolId),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Section
          _buildStatsSection(),
          
          // Filter Section
          _buildFilterSection(),
          
          // Payments List
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final filteredPayments = controller.filteredPayments;
              
              if (filteredPayments.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wallet, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No payments found',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All your payment invoices will appear here',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredPayments.length,
                itemBuilder: (context, index) {
                  return _buildPaymentCard(filteredPayments[index]);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Obx(() {
      final stats = controller.getStats(widget.schoolId);
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[700]!, Colors.blue[500]!],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildStatCard(
                  'Pending',
                  '₹${stats['totalPending'].toStringAsFixed(0)}',
                  '${stats['countPending']} invoices',
                  Colors.orange[300]!,
                  Icons.pending_actions,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Paid',
                  '₹${stats['totalPaid'].toStringAsFixed(0)}',
                  '${stats['countPaid']} invoices',
                  Colors.green[300]!,
                  Icons.check_circle_outline,
                ),
              ],
            ),
            if (stats['countOverdue'] > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[300]!, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${stats['countOverdue']} Overdue Payment${stats['countOverdue'] > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[900],
                            ),
                          ),
                          Text(
                            'Please pay immediately to avoid service disruption',
                            style: TextStyle(fontSize: 13, color: Colors.red[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildStatCard(String title, String value, String subtitle, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Obx(() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', 'all'),
            _buildFilterChip('Pending', 'pending'),
            _buildFilterChip('Paid', 'paid'),
            _buildFilterChip('Overdue', 'overdue'),
          ],
        ),
      )),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = controller.selectedFilter.value == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          controller.selectedFilter.value = value;
        },
        selectedColor: Colors.blue[100],
        checkmarkColor: Colors.blue[700],
        labelStyle: TextStyle(
          color: isSelected ? Colors.blue[700] : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildPaymentCard(PaymentModel payment) {
    final isOverdue = payment.isOverdue;
    final isPaid = payment.status.toLowerCase() == 'paid';
    
    Color statusColor = isPaid
        ? Colors.green
        : isOverdue
            ? Colors.red
            : Colors.orange;
    
    Color? cardColor = isPaid
        ? Colors.green[50]
        : isOverdue
            ? Colors.red[50]
            : Colors.white;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOverdue ? Colors.red[300]! : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Invoice Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPaid ? Icons.check_circle : Icons.receipt_long,
                    color: statusColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Title & Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isPaid
                              ? 'PAID'
                              : isOverdue
                                  ? 'OVERDUE'
                                  : 'PENDING',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${payment.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            
            // Details Grid
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    Icons.calendar_month,
                    'Created',
                    DateFormat('MMM dd, yyyy').format(payment.createdAt),
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    Icons.event_available,
                    'Due Date',
                    payment.dueDate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    Icons.category,
                    'Type',
                    payment.type.toUpperCase(),
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    Icons.receipt,
                    'Invoice',
                    payment.invoiceNumber ?? payment.paymentId.substring(0, 10),
                  ),
                ),
              ],
            ),
            
            if (payment.notes != null && payment.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        payment.notes!,
                        style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Action Button
            if (!isPaid) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showPaymentDialog(payment),
                  icon: const Icon(Icons.payment),
                  label: const Text(
                    'PAY NOW VIA WHATSAPP',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Paid on ${DateFormat('MMM dd, yyyy').format(payment.paidAt!)}',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showPaymentDialog(PaymentModel payment) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.payment, size: 48, color: Colors.green[600]),
              ),
              const SizedBox(height: 20),
              const Text(
                'Pay via WhatsApp',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Amount: ₹${payment.amount.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 18, color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              Text(
                'Click below to open WhatsApp and send your payment confirmation to our team.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _payViaWhatsApp(payment),
                  icon: const Icon(Icons.chat, size: 24),
                  label: const Text(
                    'Open WhatsApp',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _payViaWhatsApp(PaymentModel payment) async {
    String message = """
Hello Jupenta Technologies,

I would like to make a payment for:
📋 Invoice: ${payment.invoiceNumber ?? payment.paymentId}
🏫 School: ${payment.schoolName}
💳 Amount: ₹${payment.amount.toStringAsFixed(2)}
📝 Payment: ${payment.title}

Please confirm the payment details.

Thank you!
""";

    String whatsappUrl = "https://wa.me/917597181771?text=${Uri.encodeComponent(message)}";
    final Uri url = Uri.parse(whatsappUrl);

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        Get.back(); // Close dialog
        Get.snackbar(
          '✅ Success',
          'WhatsApp opened! Please send the message to complete payment.',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        throw Exception('Could not launch WhatsApp');
      }
    } catch (e) {
      Get.snackbar(
        '❌ Error',
        'Could not open WhatsApp. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
