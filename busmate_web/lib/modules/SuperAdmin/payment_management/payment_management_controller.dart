// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/foundation.dart';

// import 'package:get/get.dart';

// class SchoolModel {
//   final String id;
//   final String schoolName;
//   final String email;
//   // add other fields as needed

//   SchoolModel({
//     required this.id,
//     required this.schoolName,
//     required this.email,
//   });

//   factory SchoolModel.fromDocument(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>;
//     return SchoolModel(
//       id: doc.id,
//       schoolName: data['school_name'] ?? '',
//       email: data['email'] ?? '',
//     );
//   }
// }

// class PaymentRequestModel {
//   final String id;
//   final double amount;
//   final DateTime dueDate;
//   final String status;

//   PaymentRequestModel({
//     required this.id,
//     required this.amount,
//     required this.dueDate,
//     required this.status,
//   });

//   factory PaymentRequestModel.fromDocument(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>;
//     return PaymentRequestModel(
//       id: doc.id,
//       amount: (data['amount'] ?? 0).toDouble(),
//       dueDate: (data['dueDate'] as Timestamp).toDate(),
//       status: data['status'] ?? 'PENDING',
//     );
//   }
// }

// // payment_controller.dart

// class PaymentController extends GetxController {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   // Observable list of payment requests
//   var paymentRequests = <PaymentRequestModel>[].obs;

//   // Fetch payment requests for a given school ID
//   Future<void> fetchPaymentRequests(String schoolId) async {
//     try {
//       final snapshot = await _firestore
//           .collection('schools')
//           .doc(schoolId)
//           .collection('paymentRequests')
//           .orderBy('created_at', descending: true)
//           .get();

//       paymentRequests.value = snapshot.docs
//           .map((doc) => PaymentRequestModel.fromDocument(doc))
//           .toList();
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error fetching payment requests: $e');
//       }
//     }
//   }

//   // Observables
//   var schools = <SchoolModel>[].obs; // List of all schools
//   var selectedSchoolId = ''.obs; // Which school is selected
//   // var paymentRequests =
//   //     <PaymentRequestModel>[].obs; // Payment requests for the selected school

//   //---------------------------------------------------------------------------------------------
//   // 1. Fetch all schools for Super Admin
//   //---------------------------------------------------------------------------------------------

//   Future<List<SchoolModel>> fetchAllSchools() async {
//     try {
//       QuerySnapshot snapshot = await FirebaseFirestore.instance
//           .collection('schools')
//           .orderBy('created_at')
//           .get();

//       List<SchoolModel> schools =
//           snapshot.docs.map((doc) => SchoolModel.fromDocument(doc)).toList();

//       return schools;
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error fetching schools: $e');
//       }
//       return [];
//     }
//   }
//   //---------------------------------------------------------------------------------------------
//   // 2. Fetch payment requests for the selected school
//   //    - You could also use a real-time stream if you want automatic updates.
//   //---------------------------------------------------------------------------------------------
// // import 'package:cloud_firestore/cloud_firestore.dart';
// // import 'package:your_app/models/payment_request_model.dart';

//   // Future<List<PaymentRequestModel>> fetchPaymentRequests(
//   //     String schoolId) async {
//   //   try {
//   //     QuerySnapshot snapshot = await FirebaseFirestore.instance
//   //         .collection('schools')
//   //         .doc(schoolId)
//   //         .collection('paymentRequests')
//   //         .orderBy('created_at', descending: true)
//   //         .get();

//   //     List<PaymentRequestModel> requests = snapshot.docs
//   //         .map((doc) => PaymentRequestModel.fromDocument(doc))
//   //         .toList();

//   //     return requests;
//   //   } catch (e) {
//   //     print('Error fetching payment requests for school $schoolId: $e');
//   //     return [];
//   //   }
//   // }

//   //---------------------------------------------------------------------------------------------
//   // 3. Generate a new bill (invoice) for a school
//   //---------------------------------------------------------------------------------------------
//   Future<void> generateBill({
//     required String schoolId,
//     required double amount,
//     required DateTime dueDate,
//   }) async {
//     try {
//       final docRef = _firestore
//           .collection('schools')
//           .doc(schoolId)
//           .collection('paymentRequests')
//           .doc();

//       await docRef.set({
//         'amount': amount,
//         'dueDate': Timestamp.fromDate(dueDate),
//         'status': 'PENDING',
//         'createdAt': FieldValue.serverTimestamp(),
//         'updatedAt': FieldValue.serverTimestamp(),
//       });
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error generating bill: $e');
//       }
//     }
//   }

//   //---------------------------------------------------------------------------------------------
//   // 4. Update payment status (Mark as Paid, etc.)
//   //---------------------------------------------------------------------------------------------
//   Future<void> updatePaymentStatus({
//     required String schoolId,
//     required String paymentId,
//     required String status,
//   }) async {
//     try {
//       await _firestore
//           .collection('schools')
//           .doc(schoolId)
//           .collection('paymentRequests')
//           .doc(paymentId)
//           .update({
//         'status': status,
//         'updatedAt': FieldValue.serverTimestamp(),
//       });

//       // Refresh local list (optional if using streams)
//       fetchPaymentRequests(schoolId);
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error updating payment status: $e');
//       }
//     }
//   }
// }
