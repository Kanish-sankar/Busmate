import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:busmate_web/models/payment_model.dart';

class PaymentController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  var payments = <PaymentModel>[].obs;
  var isLoading = false.obs;
  var selectedFilter = 'all'.obs; // 'all', 'pending', 'paid', 'overdue'
  
  // Stream subscription to cancel on logout
  StreamSubscription<QuerySnapshot>? _paymentsSubscription;
  
  // Get payments collection reference (ROOT level)
  CollectionReference get paymentsCollection => _firestore.collection('payments');
  
  /// Fetch all payments (for Super Admin)
  void fetchAllPayments() {
    // Cancel existing listener before creating new one
    _paymentsSubscription?.cancel();
    
    isLoading.value = true;
    _paymentsSubscription = paymentsCollection
        .snapshots()
        .listen((snapshot) {
      // Sort in memory to avoid index requirement
      final paymentsList = snapshot.docs
          .map((doc) => PaymentModel.fromDocument(doc))
          .toList();
      
      // Sort by createdAt descending
      paymentsList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      payments.value = paymentsList;
      isLoading.value = false;
    });
  }
  
  /// Fetch payments for a specific school (for School Admin)
  void fetchSchoolPayments(String schoolId) {
    // Cancel existing listener before creating new one
    _paymentsSubscription?.cancel();
    
    isLoading.value = true;
    
    _paymentsSubscription = paymentsCollection
        .where('schoolId', isEqualTo: schoolId)
        .snapshots()
        .listen(
          (snapshot) {
            // Sort in memory instead of in query to avoid index requirement
            final paymentsList = snapshot.docs
                .map((doc) => PaymentModel.fromDocument(doc))
                .toList();
            
            // Sort by createdAt descending
            paymentsList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            
            payments.value = paymentsList;
            isLoading.value = false;
          },
          onError: (error) {
            isLoading.value = false;
            Get.snackbar(
              'Error',
              'Unable to load payments. Please try again.',
              snackPosition: SnackPosition.BOTTOM,
            );
          },
        );
  }
  
  /// Get filtered payments based on status
  List<PaymentModel> get filteredPayments {
    if (selectedFilter.value == 'all') {
      return payments;
    }
    return payments.where((payment) {
      if (selectedFilter.value == 'overdue') {
        return payment.isOverdue && payment.status.toLowerCase() != 'paid';
      }
      return payment.status.toLowerCase() == selectedFilter.value;
    }).toList();
  }
  
  /// Create a new payment request (appears immediately in school's My Payments)
  Future<void> createPayment({
    required String schoolId,
    required String schoolName,
    required String schoolEmail,
    required String title,
    required String type,
    required double amount,
    required String dueDate,
    String? notes,
  }) async {
    try {
      // Generate invoice number
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final invoiceNumber = 'INV-$timestamp';
      
      await paymentsCollection.add({
        'schoolId': schoolId,
        'schoolName': schoolName,
        'schoolEmail': schoolEmail,
        'title': title,
        'type': type,
        'amount': amount,
        'dueDate': dueDate,
        'status': 'pending',
        'emailSent': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'notes': notes,
        'invoiceNumber': invoiceNumber,
      });
      
      Get.snackbar(
        '✅ Success',
        'Payment request created for $schoolName. They can see it in their dashboard.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      Get.snackbar(
        '❌ Error',
        'Failed to create payment: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
  
  /// Mark payment as paid
  Future<void> markAsPaid(String paymentId) async {
    try {
      await paymentsCollection.doc(paymentId).update({
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      Get.snackbar(
        '✅ Success',
        'Payment marked as paid',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        '❌ Error',
        'Failed to update payment: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
  
  /// Cancel payment
  Future<void> cancelPayment(String paymentId) async {
    try {
      await paymentsCollection.doc(paymentId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      Get.snackbar(
        '✅ Success',
        'Payment cancelled',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        '❌ Error',
        'Failed to cancel payment: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
  
  /// Delete payment
  Future<void> deletePayment(String paymentId) async {
    try {
      await paymentsCollection.doc(paymentId).delete();
      
      Get.snackbar(
        '✅ Success',
        'Payment deleted',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        '❌ Error',
        'Failed to delete payment: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
  
  /// Get payment statistics
  Map<String, dynamic> getStats(String? schoolId) {
    List<PaymentModel> relevantPayments = schoolId != null
        ? payments.where((p) => p.schoolId == schoolId).toList()
        : payments;
    
    double totalPending = 0;
    double totalPaid = 0;
    int countPending = 0;
    int countPaid = 0;
    int countOverdue = 0;
    
    for (var payment in relevantPayments) {
      if (payment.status.toLowerCase() == 'paid') {
        totalPaid += payment.amount;
        countPaid++;
      } else if (payment.status.toLowerCase() == 'pending') {
        totalPending += payment.amount;
        countPending++;
        if (payment.isOverdue) countOverdue++;
      }
    }
    
    return {
      'totalPending': totalPending,
      'totalPaid': totalPaid,
      'countPending': countPending,
      'countPaid': countPaid,
      'countOverdue': countOverdue,
      'totalPayments': relevantPayments.length,
    };
  }
  
  @override
  void onClose() {
    // Cancel Firestore listener when controller is disposed
    _paymentsSubscription?.cancel();
    super.onClose();
  }
}