// // payment_request_model.dart

// import 'package:cloud_firestore/cloud_firestore.dart';

// import 'package:get/get.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// // import 'package:your_app/models/payment_request_model.dart';
// // import 'package:your_app/models/school_model.dart';

// class PaymentRequestModel {
//   final String id;
//   final double amount;
//   final DateTime dueDate;
//   final String status;
//   final DateTime createdAt;
//   final DateTime updatedAt;

//   PaymentRequestModel({
//     required this.id,
//     required this.amount,
//     required this.dueDate,
//     required this.status,
//     required this.createdAt,
//     required this.updatedAt,
//   });

//   factory PaymentRequestModel.fromDocument(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>;
//     return PaymentRequestModel(
//       id: doc.id,
//       amount: (data['amount'] ?? 0).toDouble(),
//       dueDate: (data['dueDate'] as Timestamp).toDate(),
//       status: data['status'] ?? 'PENDING',
//       createdAt: (data['createdAt'] as Timestamp).toDate(),
//       updatedAt: (data['updatedAt'] as Timestamp).toDate(),
//     );
//   }
// }

// // payment_controller.dart

// class PaymentController extends GetxController {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   // Observables
//   var schools = <SchoolModel>[].obs; // List of all schools
//   var selectedSchoolId = ''.obs; // Which school is selected
//   var paymentRequests =
//       <PaymentRequestModel>[].obs; // Payment requests for the selected school

//   //---------------------------------------------------------------------------------------------
//   // 1. Fetch all schools for Super Admin
//   //---------------------------------------------------------------------------------------------
//   Future<void> fetchAllSchools() async {
//     try {
//       final snapshot = await _firestore.collection('schools').get();
//       final schoolList =
//           snapshot.docs.map((doc) => SchoolModel.fromDocument(doc)).toList();
//       schools.value = schoolList;
//     } catch (e) {
//       print('Error fetching schools: $e');
//     }
//   }

//   //---------------------------------------------------------------------------------------------
//   // 2. Fetch payment requests for the selected school
//   //    - You could also use a real-time stream if you want automatic updates.
//   //---------------------------------------------------------------------------------------------
//   Future<void> fetchPaymentRequests(String schoolId) async {
//     try {
//       final snapshot = await _firestore
//           .collection('schools')
//           .doc(schoolId)
//           .collection('paymentRequests')
//           .orderBy('createdAt', descending: true)
//           .get();

//       final requests = snapshot.docs
//           .map((doc) => PaymentRequestModel.fromDocument(doc))
//           .toList();
//       paymentRequests.value = requests;
//     } catch (e) {
//       print('Error fetching payment requests: $e');
//     }
//   }

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
//       print('Error generating bill: $e');
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
//       print('Error updating payment status: $e');
//     }
//   }
// }
