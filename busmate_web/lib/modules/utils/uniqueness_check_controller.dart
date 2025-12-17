import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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
      } catch (_) {
        if (currentRequestId != _requestId) return;

        // Don’t hard-block on network errors; keep submit-time guard.
        isTaken.value = false;
        errorText.value = 'Could not verify';
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
        final methods =
            await FirebaseAuth.instance.fetchSignInMethodsForEmail(value);
        return methods.isNotEmpty;
        
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
