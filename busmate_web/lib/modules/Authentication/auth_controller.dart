// File: lib/controllers/auth_controller.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../routes/app_pages.dart';

enum UserRole { superAdmin, schoolAdmin }

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Rx<User?> user = Rx<User?>(null);
  Rx<UserRole?> userRole = Rx<UserRole?>(null);
  RxBool isLoading = false.obs;
  RxBool isOtpSent = false.obs;
  RxBool isVerifyingOtp = false.obs;
  String? _adminPassword; // Private variable to store the admin password.
  // String? _otpEmail; // Store the email for which OTP was sent

  @override
  void onInit() {
    super.onInit();
    user.value = _auth.currentUser;
    _auth.authStateChanges().listen((User? firebaseUser) async {
      user.value = firebaseUser;

      if (firebaseUser != null) {
        await _fetchUserRole();
      } else {
        userRole.value = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.offAllNamed(Routes.LOGIN);
        });
      }
    });
  }

  Future<void> _fetchUserRole() async {
    try {
      if (user.value != null) {
        // First, try to fetch from the adminusers collection.
        DocumentSnapshot adminDoc = await _firestore
            .collection("adminusers")
            .doc(user.value!.uid)
            .get();

        if (adminDoc.exists) {
          String role = adminDoc['role'];
          String? schoolId;
          if (adminDoc.data() != null &&
              (adminDoc.data() as Map<String, dynamic>)
                  .containsKey('schoolId')) {
            schoolId = adminDoc['schoolId'];
          }

          // Branch based on the role stored in adminusers.
          if (role == 'superAdmin') {
            userRole.value = UserRole.superAdmin;
            Get.offAllNamed(Routes.SUPER_ADMIN_DASHBOARD);
          } else if (role == 'schoolAdmin') {
            userRole.value = UserRole.schoolAdmin;
            if (schoolId != null) {
              Get.offAllNamed(Routes.SCHOOL_ADMIN_DASHBOARD, arguments: {
                'schoolId': schoolId,
              });
            } else {
              QuerySnapshot schoolSnapshot = await _firestore
                  .collection("schools")
                  .where("uid", isEqualTo: user.value!.uid)
                  .get();
              if (schoolSnapshot.docs.isNotEmpty) {
                Get.offAllNamed(Routes.SCHOOL_ADMIN_DASHBOARD, arguments: {
                  'schoolId': schoolSnapshot.docs.first.id,
                });
              } else {
                Get.snackbar('Error', 'School ID is missing for this admin.');
              }
            }
          } else if (role == 'schoolSuperAdmin' || role == 'regionalAdmin') {
            userRole.value = UserRole.schoolAdmin;
            if (schoolId != null) {
              Get.offAllNamed(Routes.SCHOOL_ADMIN_DASHBOARD, arguments: {
                'schoolId': schoolId,
                'role': role,
              });
            } else {
              QuerySnapshot schoolSnapshot = await _firestore
                  .collection("schools")
                  .where("adminsEmails", arrayContains: user.value!.email)
                  .get();
              if (schoolSnapshot.docs.isNotEmpty) {
                Get.offAllNamed(Routes.SCHOOL_ADMIN_DASHBOARD, arguments: {
                  'schoolId': schoolSnapshot.docs.first.id,
                  'role': role,
                });
              } else {
                Get.snackbar('Error', 'School ID is missing for this admin.');
              }
            }
          } else {
            Get.snackbar('Error', 'Undefined role: $role');
            await logout();
            Get.offAllNamed(Routes.LOGIN);
          }
        } else {
          // Fallback: If no document is found in adminusers,
          // perform a collection group query on the "admins" subcollections.
          QuerySnapshot adminManagerSnapshot = await _firestore
              .collectionGroup("admins")
              .where("email", isEqualTo: user.value!.email)
              .get();

          if (adminManagerSnapshot.docs.isNotEmpty) {
            // For a found admin manager document, extract role and schoolId.
            DocumentSnapshot managerDoc = adminManagerSnapshot.docs.first;
            String managerRole = managerDoc['role'];
            // The parent of this document is the "admins" subcollection,
            // so the parent's parent is the school document.
            String schoolId = managerDoc.reference.parent.parent!.id;

            // Check if the role is one of the manager roles.
            if (managerRole == 'schoolSuperAdmin' ||
                managerRole == 'regionalAdmin') {
              userRole.value = UserRole.schoolAdmin;
              Get.offAllNamed(Routes.SCHOOL_ADMIN_DASHBOARD, arguments: {
                'schoolId': schoolId,
                'role': managerRole,
              });
            } else {
              Get.snackbar('Error', 'Admin manager role not valid.');
            }
          } else {
            // If still no record found, display an error message.
            Get.snackbar('Error', 'No admin record found for this user.');
          }
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to fetch user role: ${e.toString()}');
    }
  }

  Future<void> login(String email, String password) async {
    try {
      isLoading.value = true;
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _adminPassword = password; // Store the password after successful login.
    } on FirebaseAuthException catch (e) {
      Get.snackbar('Login Failed', '${e.code}: ${e.message}');
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  String? getAdminPassword() {
    return _adminPassword; // Provide access to the stored password.
  }

  Future<void> resetPassword(String email) async {
    try {
      isLoading.value = true;
      await _auth.sendPasswordResetEmail(email: email);
      Get.snackbar(
        'Success',
        'Password reset email sent to $email',
        snackPosition: SnackPosition.BOTTOM,
      );
      Get.back(); // Return to login screen
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to send password reset email';
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found with this email';
      }
      Get.snackbar('Error', errorMessage);
    } catch (e) {
      Get.snackbar('Error', 'An unexpected error occurred: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> register(String email, String password, String role) async {
    try {
      isLoading.value = true;
      // Create user in Firebase Auth
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore
          .collection("adminusers")
          .doc(userCredential.user!.uid)
          .set({
        'email': email,
        'role': role, // Should be 'superAdmin' or 'schoolAdmin'
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update local role and navigate based on selected role
      if (role == 'superAdmin') {
        userRole.value = UserRole.superAdmin;
        Get.offAllNamed(Routes.SUPER_ADMIN_DASHBOARD);
      } else if (role == 'schoolAdmin') {
        userRole.value = UserRole.schoolAdmin;
        Get.offAllNamed(Routes.SCHOOL_ADMIN_DASHBOARD);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Registration failed';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already in use';
      }
      Get.snackbar('Error', errorMessage);
    } catch (e) {
      Get.snackbar('Error', 'An error occurred: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      Get.snackbar('Error', 'Failed to logout: ${e.toString()}');
    }
  }

  bool isSuperAdmin() {
    return userRole.value == UserRole.superAdmin;
  }

  bool isSchoolAdmin() {
    return userRole.value == UserRole.schoolAdmin;
  }

  bool isLoggedIn() {
    return user.value != null;
  }

  Future<void> sendOtpByEmail(String email) async {
    isLoading.value = true;
    try {
      final url = Uri.parse('https://sendotp-gnxzq4evda-uc.a.run.app');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );
      if (response.statusCode == 200) {
        isOtpSent.value = true;
        // _otpEmail = email;
        Get.snackbar('Success',
            'OTP sent to $email, If you haven\'t received it within a few minutes, kindly check your spam/junk folder.');
      } else {
        Get.snackbar('Error', 'Failed to send OTP: ${response.body}');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to send OTP: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> verifyOtp(String email, String otp) async {
    isVerifyingOtp.value = true;
    try {
      final doc = await _firestore.collection('otps').doc(email).get();
      if (doc.exists && doc['otp'] == otp) {
        // Optionally: check for OTP expiry here
        return true;
      } else {
        Get.snackbar('Error', 'Invalid OTP');
        return false;
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to verify OTP: $e');
      return false;
    } finally {
      isVerifyingOtp.value = false;
    }
  }

  Future<void> loginWithOtp(String email, String password, String otp) async {
    isLoading.value = true;
    try {
      bool otpValid = await verifyOtp(email, otp);
      if (!otpValid) return;
      await login(email, password);
    } finally {
      isLoading.value = false;
    }
  }
}
