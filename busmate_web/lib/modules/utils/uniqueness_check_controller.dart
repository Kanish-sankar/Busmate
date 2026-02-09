import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

enum UniquenessCheckType {
  /// Checks if `adminusers.email` already exists.
  adminusersCredential,

  /// Checks if a Firebase Auth account already exists for the email.
  firebaseAuthEmail,
  
  /// Checks if `adminusers.email` or `adminusers.phone` already exists (school-scoped).
  adminusersEmailOrPhone,
}

class UniquenessCheckController extends GetxController {
  UniquenessCheckController(this.type, {this.schoolId, this.authTypeGetter});

  final UniquenessCheckType type;
  final String? schoolId;
  final String Function()? authTypeGetter;

  final RxBool isChecking = false.obs;
  final RxBool isTaken = false.obs;
  final RxString errorText = ''.obs;

  Timer? _debounce;
  int _requestId = 0;

  void onValueChanged(
    String rawValue, {
    String? excludeDocId,
    Duration debounce = const Duration(milliseconds: 350),
  }) {
    final value = rawValue.trim();

    _debounce?.cancel();

    if (value.isEmpty) {
      isChecking.value = false;
      isTaken.value = false;
      errorText.value = '';
      return;
    }

    final currentRequestId = ++_requestId;

    // Mark checking state immediately for fast UX feedback.
    isChecking.value = true;
    errorText.value = '';

    _debounce = Timer(debounce, () async {
      try {
        // If a newer change happened while waiting, cancel this run.
        if (currentRequestId != _requestId) return;

        final taken = await _isValueTaken(value, excludeDocId: excludeDocId);

        if (currentRequestId != _requestId) return;

        isTaken.value = taken;
        errorText.value = taken ? 'Already exists' : '';
      } catch (error) {
        if (currentRequestId != _requestId) return;

        print('❌ UniquenessCheck error: $error');
        // On error, assume taken to be safe (prevent false positives)
        isTaken.value = true;
        errorText.value = 'Verification failed - may be taken';
      } finally {
        if (currentRequestId == _requestId) {
          isChecking.value = false;
        }
      }
    });
  }

  Future<bool> _isValueTaken(String value, {String? excludeDocId}) async {
    switch (type) {
      case UniquenessCheckType.adminusersCredential:
        final snap = await FirebaseFirestore.instance
            .collection('adminusers')
            .where('email', isEqualTo: value)
            .limit(1)
            .get();

        if (snap.docs.isEmpty) return false;
        if (excludeDocId != null && snap.docs.first.id == excludeDocId) {
          return false;
        }
        return true;

      case UniquenessCheckType.firebaseAuthEmail:
        // Avoid calling Auth for clearly invalid inputs.
        if (!GetUtils.isEmail(value)) return false;
        
        try {
          print('🔍 Checking email in Firestore/Auth: $value');

          // First check Firestore to avoid the callable when we already know it's taken.
          final firestoreResults = await Future.wait([
            FirebaseFirestore.instance
                .collection('adminusers')
                .where('email', isEqualTo: value)
                .limit(1)
                .get(),
            FirebaseFirestore.instance
                .collection('admins')
                .where('email', isEqualTo: value)
                .limit(1)
                .get(),
          ]);
          
          final adminusersQuery = firestoreResults[0] as QuerySnapshot;
          final adminsQuery = firestoreResults[1] as QuerySnapshot;
          
          if (adminusersQuery.docs.isNotEmpty) {
            if (excludeDocId != null && adminusersQuery.docs.first.id == excludeDocId) {
              print('✅ Email $value belongs to current user in adminusers (editing), allowing it');
              return false;
            }
            print('❌ Email $value is TAKEN (adminusers collection)');
            return true;
          }
          
          if (adminsQuery.docs.isNotEmpty) {
            if (excludeDocId != null && adminsQuery.docs.first.id == excludeDocId) {
              print('✅ Email $value belongs to current user in admins (editing), allowing it');
              return false;
            }
            print('❌ Email $value is TAKEN (admins collection)');
            return true;
          }

          // Firestore is clear; now ask the callable (Auth-backed) for the final verdict.
          try {
            final callable = FirebaseFunctions.instance.httpsCallable('checkEmailExists');
            final result = await callable.call({'email': value});
            final data = result.data;
            final exists = (data is Map && data['exists'] == true);

            print(exists
                ? '❌ Email $value is TAKEN (Auth)'
                : '✅ Email $value is AVAILABLE (Auth)');

            return exists;
          } catch (e) {
            print('⚠️ Warning: Could not verify email $value with Auth (callable error), assuming AVAILABLE: $e');
            // On callable error, be optimistic - Firestore is already checked
            // Final duplicate check happens at account creation anyway
            return false;
          }
        } catch (e) {
          print('❌ Error checking email $value in Firestore: $e');
          // On Firestore error, be safe and assume taken
          return true;
        }
        
      case UniquenessCheckType.adminusersEmailOrPhone:
        // Determine if checking email or phone based on authType
        final authType = authTypeGetter?.call() ?? 'email';
        final fieldName = authType == 'email' ? 'email' : 'phone';
        
        // Query with school scope
        var query = FirebaseFirestore.instance
            .collection('adminusers')
            .where(fieldName, isEqualTo: value);
        
        if (schoolId != null) {
          query = query.where('schoolId', isEqualTo: schoolId);
        }
        
        final snap = await query.limit(1).get();

        if (snap.docs.isEmpty) return false;
        if (excludeDocId != null && snap.docs.first.id == excludeDocId) {
          return false;
        }
        return true;
    }
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}
