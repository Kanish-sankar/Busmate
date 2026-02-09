import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:busmate_web/controllers/payment_controller.dart';
import 'package:busmate_web/models/payment_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SuperAdminPaymentManagementScreen extends StatefulWidget {
  const SuperAdminPaymentManagementScreen({super.key});

  @override
  State<SuperAdminPaymentManagementScreen> createState() =>
      _SuperAdminPaymentManagementScreenState();
}

class _SuperAdminPaymentManagementScreenState
    extends State<SuperAdminPaymentManagementScreen> {
  late final PaymentController controller;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // Initialize controller once with a unique tag using Get.isRegistered to prevent duplicates
    controller = Get.isRegistered<PaymentController>(tag: 'super_admin_payment')
        ? Get.find<PaymentController>(tag: 'super_admin_payment')
        : Get.put(PaymentController(), tag: 'super_admin_payment');
    controller.fetchAllPayments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.indigo[700],
        title: const Text(
          'Payment Management',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.fetchAllPayments(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Cards
          _buildStatsSection(),
          
          // Filter Chips
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
                      Icon(Icons.payment_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No payments found',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePaymentDialog(context),
        backgroundColor: Colors.indigo[700],
        icon: const Icon(Icons.add),
        label: const Text('Create Payment'),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Obx(() {
      final stats = controller.getStats(null);
      return LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          return Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo[700]!, Colors.indigo[500]!],
              ),
            ),
            child: isMobile
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatCard(
                        'Total Pending',
                        '₹${stats['totalPending'].toStringAsFixed(0)}',
                        '${stats['countPending']} payments',
                        Colors.orange,
                        Icons.hourglass_empty,
                        isMobile,
                        useExpanded: false,
                      ),
                      const SizedBox(height: 12),
                      _buildStatCard(
                        'Total Paid',
                        '₹${stats['totalPaid'].toStringAsFixed(0)}',
                        '${stats['countPaid']} payments',
                        Colors.green,
                        Icons.check_circle,
                        isMobile,
                        useExpanded: false,
                      ),
                      const SizedBox(height: 12),
                      _buildStatCard(
                        'Overdue',
                        '${stats['countOverdue']}',
                        'Need attention',
                        Colors.red,
                        Icons.warning_amber,
                        isMobile,
                        useExpanded: false,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      _buildStatCard(
                        'Total Pending',
                        '₹${stats['totalPending'].toStringAsFixed(0)}',
                        '${stats['countPending']} payments',
                        Colors.orange,
                        Icons.hourglass_empty,
                        isMobile,
                        useExpanded: true,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'Total Paid',
                        '₹${stats['totalPaid'].toStringAsFixed(0)}',
                        '${stats['countPaid']} payments',
                        Colors.green,
                        Icons.check_circle,
                        isMobile,
                        useExpanded: true,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'Overdue',
                        '${stats['countOverdue']}',
                        'Need attention',
                        Colors.red,
                        Icons.warning_amber,
                        isMobile,
                        useExpanded: true,
                      ),
                    ],
                  ),
          );
        },
      );
    });
  }

  Widget _buildStatCard(String title, String value, String subtitle, Color color, IconData icon, bool isMobile, {bool useExpanded = true}) {
    final cardWidget = Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Row(
            children: [
              Icon(icon, color: color, size: isMobile ? 20 : 24),
              SizedBox(width: isMobile ? 6 : 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: isMobile ? 11 : 12, color: Colors.grey[500]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    
    return useExpanded ? Expanded(child: cardWidget) : cardWidget;
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
        selectedColor: Colors.indigo[100],
        checkmarkColor: Colors.indigo[700],
        labelStyle: TextStyle(
          color: isSelected ? Colors.indigo[700] : Colors.grey[700],
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
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Card(
          margin: EdgeInsets.only(bottom: isMobile ? 10 : 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => _showPaymentDetailsDialog(payment),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // School Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              payment.schoolName,
                              style: TextStyle(
                                fontSize: isMobile ? 16 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: isMobile ? 3 : 4),
                            Text(
                              payment.title,
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 14,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(width: isMobile ? 8 : 12),
                      
                      // Amount
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${payment.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 8 : 12,
                              vertical: isMobile ? 3 : 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              payment.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: isMobile ? 10 : 12,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  SizedBox(height: isMobile ? 12 : 16),
                  Divider(height: 1),
                  SizedBox(height: isMobile ? 10 : 12),
                  
                  // Details Row - Make scrollable on mobile if needed
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildDetailChip(Icons.calendar_today, 'Due: ${payment.dueDate}', isMobile),
                        SizedBox(width: isMobile ? 8 : 12),
                        _buildDetailChip(Icons.category, payment.type.toUpperCase(), isMobile),
                        SizedBox(width: isMobile ? 8 : 12),
                        _buildDetailChip(
                          Icons.receipt,
                          payment.invoiceNumber ?? payment.paymentId.substring(0, 8),
                          isMobile,
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: isMobile ? 10 : 12),
                  
                  // Action Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isPaid) ...[
                        ElevatedButton.icon(
                          onPressed: () => _confirmMarkAsPaid(payment),
                          icon: Icon(Icons.check, size: isMobile ? 16 : 18),
                          label: Text(isMobile ? 'Mark Paid' : 'Mark Paid', style: TextStyle(fontSize: isMobile ? 13 : 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 12 : 16,
                              vertical: isMobile ? 8 : 12,
                            ),
                          ),
                        ),
                      ] else ...[
                        Icon(Icons.check_circle, color: Colors.green[600], size: isMobile ? 20 : 24),
                        SizedBox(width: isMobile ? 6 : 8),
                        Flexible(
                          child: Text(
                            payment.paidAt != null 
                              ? 'Paid on ${DateFormat('MMM dd, yyyy').format(payment.paidAt!)}'
                              : 'Paid',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                              fontSize: isMobile ? 12 : 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailChip(IconData icon, String label, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 10,
        vertical: isMobile ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isMobile ? 12 : 14, color: Colors.grey[600]),
          SizedBox(width: isMobile ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePaymentDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final typeController = TextEditingController(text: 'subscription');
    final amountController = TextEditingController();
    final dueDateController = TextEditingController();
    final notesController = TextEditingController();
    String? selectedSchoolId;
    String? selectedSchoolName;
    String? selectedSchoolEmail;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.payment, color: Colors.indigo[700], size: 28),
                      const SizedBox(width: 12),
                      const Text(
                        'Create Payment Request',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // School Selection
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('schooldetails').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }
                      
                      final schools = snapshot.data!.docs;
                      
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Select School *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.school),
                        ),
                        items: schools.map((school) {
                          final data = school.data() as Map<String, dynamic>;
                          return DropdownMenuItem(
                            value: school.id,
                            child: Text(data['schoolName'] ?? 'Unknown'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          selectedSchoolId = value;
                          final schoolData = schools.firstWhere((s) => s.id == value).data() as Map<String, dynamic>;
                          selectedSchoolName = schoolData['schoolName'];
                          selectedSchoolEmail = schoolData['email'];
                        },
                        validator: (value) => value == null ? 'Please select a school' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Payment Title *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                      hintText: 'e.g., Monthly Subscription',
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Type
                  DropdownButtonFormField<String>(
                    value: 'subscription',
                    decoration: const InputDecoration(
                      labelText: 'Payment Type *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'subscription', child: Text('Subscription')),
                      DropdownMenuItem(value: 'hardware', child: Text('Hardware')),
                      DropdownMenuItem(value: 'software', child: Text('Software')),
                      DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (value) => typeController.text = value!,
                  ),
                  const SizedBox(height: 16),
                  
                  // Amount
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_rupee),
                      hintText: '0.00',
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      if (double.tryParse(value!) == null) return 'Invalid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Due Date
                  TextFormField(
                    controller: dueDateController,
                    decoration: const InputDecoration(
                      labelText: 'Due Date *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                      hintText: 'YYYY-MM-DD',
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        dueDateController.text = DateFormat('yyyy-MM-dd').format(date);
                      }
                    },
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Notes
                  TextFormField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note),
                      hintText: 'Additional details...',
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            await controller.createPayment(
                              schoolId: selectedSchoolId!,
                              schoolName: selectedSchoolName!,
                              schoolEmail: selectedSchoolEmail!,
                              title: titleController.text.trim(),
                              type: typeController.text.trim(),
                              amount: double.parse(amountController.text.trim()),
                              dueDate: dueDateController.text.trim(),
                              notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                            );
                            // ignore: use_build_context_synchronously
                            Navigator.pop(ctx);
                          }
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Create Payment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo[700],
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPaymentDetailsDialog(PaymentModel payment) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long, color: Colors.indigo[700], size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Payment Details',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              _buildDetailRow('School', payment.schoolName),
              _buildDetailRow('Email', payment.schoolEmail),
              _buildDetailRow('Title', payment.title),
              _buildDetailRow('Type', payment.type.toUpperCase()),
              _buildDetailRow('Amount', '₹${payment.amount.toStringAsFixed(2)}'),
              _buildDetailRow('Due Date', payment.dueDate),
              _buildDetailRow('Status', payment.status.toUpperCase()),
              _buildDetailRow('Invoice #', payment.invoiceNumber ?? payment.paymentId),
              _buildDetailRow('Created', DateFormat('MMM dd, yyyy HH:mm').format(payment.createdAt)),
              if (payment.paidAt != null)
                _buildDetailRow('Paid On', DateFormat('MMM dd, yyyy HH:mm').format(payment.paidAt!)),
              if (payment.notes != null && payment.notes!.isNotEmpty)
                _buildDetailRow('Notes', payment.notes!),
              
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmMarkAsPaid(PaymentModel payment) {
    Get.dialog(
      AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text('Mark payment of ₹${payment.amount.toStringAsFixed(2)} from ${payment.schoolName} as paid?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back(); // Close dialog first
              await controller.markAsPaid(payment.paymentId); // Then mark as paid
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
