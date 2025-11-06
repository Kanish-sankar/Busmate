// File: lib/controllers/auth_controller.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Routes/app_pages.dart';
import '../utils/web_error_handler.dart';

enum UserRole { superior, schoolAdmin }

// Admin Permissions Model
class AdminPermissions {
  final bool studentManagement;
  final bool driverManagement;
  final bool busManagement;
  final bool routeManagement;
  final bool paymentManagement;
  final bool notifications;
  final bool viewingBusStatus;
  final bool adminManagement;

  AdminPermissions({
    this.studentManagement = false,
    this.driverManagement = false,
    this.busManagement = false,
    this.routeManagement = false,
    this.paymentManagement = false,
    this.notifications = false,
    this.viewingBusStatus = false,
    this.adminManagement = false,
  });

  factory AdminPermissions.fromMap(Map<String, dynamic>? map) {
    if (map == null) return AdminPermissions.allGranted();
    return AdminPermissions(
      studentManagement: map['studentManagement'] ?? false,
      driverManagement: map['driverManagement'] ?? false,
      busManagement: map['busManagement'] ?? false,
      routeManagement: map['routeManagement'] ?? false,
      paymentManagement: map['paymentManagement'] ?? false,
      notifications: map['notifications'] ?? false,
      viewingBusStatus: map['viewingBusStatus'] ?? false,
      adminManagement: map['adminManagement'] ?? false,
    );
  }

  factory AdminPermissions.allGranted() {
    return AdminPermissions(
      studentManagement: true,
      driverManagement: true,
      busManagement: true,
      routeManagement: true,
      paymentManagement: true,
      notifications: true,
      viewingBusStatus: true,
      adminManagement: true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentManagement': studentManagement,
      'driverManagement': driverManagement,
      'busManagement': busManagement,
      'routeManagement': routeManagement,
      'paymentManagement': paymentManagement,
      'notifications': notifications,
      'viewingBusStatus': viewingBusStatus,
      'adminManagement': adminManagement,
    };
  }
}

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Rx<User?> user = Rx<User?>(null);
  Rx<UserRole?> userRole = Rx<UserRole?>(null);
  Rx<AdminPermissions> permissions = AdminPermissions().obs;
  RxString schoolId = ''.obs;
  RxString adminEmail = ''.obs;
  RxBool isLoading = false.obs;
  RxBool isOtpSent = false.obs;
  RxBool isVerifyingOtp = false.obs;
  String? _adminPassword;

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
        permissions.value = AdminPermissions();
        schoolId.value = '';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.offAllNamed(Routes.LOGIN);
        });
      }
    });
  }

  Future<void> _fetchUserRole() async {
    try {
      if (user.value == null) return;

      print('🔍 Fetching user role for UID: ${user.value!.uid}');
      
      // Fetch from NEW 'admins' collection
      DocumentSnapshot adminDoc = await _firestore
          .collection("admins")
          .doc(user.value!.uid)
          .get();

      if (!adminDoc.exists || adminDoc.data() == null) {
        print('❌ No admin record found in admins collection');
        await _auth.signOut();
        Get.snackbar('Access Denied', 'No admin privileges found for this account');
        Get.offAllNamed(Routes.LOGIN);
        return;
      }

      Map<String, dynamic> adminData = adminDoc.data() as Map<String, dynamic>;
      String role = adminData['role'] ?? 'unknown';
      adminEmail.value = adminData['email'] ?? user.value!.email ?? '';
      
      print('✅ Found admin - Role: $role, Email: ${adminEmail.value}');

      if (role == 'superior') {
        // Superior Admin - Full Access
        userRole.value = UserRole.superior;
        permissions.value = AdminPermissions.allGranted();
        schoolId.value = '';
        
        print('🚀 Superior Admin logged in - Redirecting to Super Admin Dashboard');
        Get.offAllNamed(Routes.SUPER_ADMIN_DASHBOARD);
        
      } else if (role == 'schoolAdmin' || role == 'school_admin') {
        // School Admin - Permission-based Access
        userRole.value = UserRole.schoolAdmin;
        schoolId.value = adminData['schoolId'] ?? '';
        permissions.value = AdminPermissions.fromMap(adminData['permissions']);
        
        if (schoolId.value.isEmpty) {
          print('❌ School Admin missing schoolId');
          await _auth.signOut();
          Get.snackbar('Error', 'Invalid admin configuration - missing school ID');
          Get.offAllNamed(Routes.LOGIN);
          return;
        }
        
        print('🏫 School Admin logged in - School ID: ${schoolId.value}');
        print('📋 Permissions: ${permissions.value.toMap()}');
        
        Get.offAllNamed(Routes.SCHOOL_ADMIN_DASHBOARD, arguments: {
          'schoolId': schoolId.value,
          'role': role,
          'permissions': permissions.value.toMap(),
        });
        
      } else {
        print('❌ Unknown role: $role');
        await _auth.signOut();
        Get.snackbar('Access Denied', 'Invalid admin role');
        Get.offAllNamed(Routes.LOGIN);
      }
      
    } catch (e) {
      print('❌ Error in _fetchUserRole: $e');
      Get.snackbar('Error', 'Failed to fetch admin data: ${e.toString()}');
      await _auth.signOut();
      Get.offAllNamed(Routes.LOGIN);
    }
  }

  // Check if user has specific permission
  bool hasPermission(String permissionName) {
    if (userRole.value == UserRole.superior) return true; // Superior has all permissions
    
    switch (permissionName) {
      case 'studentManagement':
        return permissions.value.studentManagement;
      case 'driverManagement':
        return permissions.value.driverManagement;
      case 'busManagement':
        return permissions.value.busManagement;
      case 'routeManagement':
        return permissions.value.routeManagement;
      case 'paymentManagement':
        return permissions.value.paymentManagement;
      case 'notifications':
        return permissions.value.notifications;
      case 'viewingBusStatus':
        return permissions.value.viewingBusStatus;
      case 'adminManagement':
        return permissions.value.adminManagement;
      default:
        return false;
    }
  }

  Future<void> login(String email, String password) async {
    try {
      isLoading.value = true;
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _adminPassword = password; // Store the password after successful login.
      WebErrorHandler.showSuccess('Login successful!');
    } on FirebaseAuthException catch (e) {
      WebErrorHandler.handleError(e, 
        context: 'Login', 
        customMessage: _getFirebaseAuthErrorMessage(e.code));
    } catch (e) {
      WebErrorHandler.handleError(e, context: 'Login');
    } finally {
      isLoading.value = false;
    }
  }
  
  String _getFirebaseAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      default:
        return 'Login failed. Please try again.';
    }
  }

  String? getAdminPassword() {
    return _adminPassword; // Provide access to the stored password.
  }

  Future<void> resetPassword(String email) async {
    try {
      isLoading.value = true;
      await _auth.sendPasswordResetEmail(email: email);
      WebErrorHandler.showSuccess('Password reset email sent to $email');
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

  Future<void> register(String email, String password, String role, {String? schoolId, Map<String, bool>? permissionsMap}) async {
    try {
      isLoading.value = true;
      
      // Create user in Firebase Auth
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Prepare admin document for NEW 'admins' collection
      Map<String, dynamic> adminData = {
        'email': email,
        'role': role, // 'superior' or 'schoolAdmin' or 'school_admin'
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add school-specific data for school admins
      if (role == 'schoolAdmin' || role == 'school_admin') {
        if (schoolId == null || schoolId.isEmpty) {
          throw Exception('School ID is required for school admins');
        }
        adminData['schoolId'] = schoolId;
        adminData['permissions'] = permissionsMap ?? AdminPermissions.allGranted().toMap();
      }

      // Store in NEW 'admins' collection
      await _firestore
          .collection("admins")
          .doc(userCredential.user!.uid)
          .set(adminData);

      print('✅ Admin registered successfully: $email as $role');
      
      WebErrorHandler.showSuccess('Admin registered successfully!');
      
      // Navigate based on role
      if (role == 'superior') {
        userRole.value = UserRole.superior;
        permissions.value = AdminPermissions.allGranted();
        Get.offAllNamed(Routes.SUPER_ADMIN_DASHBOARD);
      } else if (role == 'schoolAdmin' || role == 'school_admin') {
        userRole.value = UserRole.schoolAdmin;
        this.schoolId.value = schoolId!;
        permissions.value = AdminPermissions.fromMap(permissionsMap);
        Get.offAllNamed(Routes.SCHOOL_ADMIN_DASHBOARD, arguments: {
          'schoolId': schoolId,
          'role': role,
        });
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Registration failed';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already in use';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password is too weak';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address';
      }
      Get.snackbar('Error', errorMessage);
    } catch (e) {
      Get.snackbar('Error', 'Registration error: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  bool isSuperior() {
    return userRole.value == UserRole.superior;
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      userRole.value = null;
      permissions.value = AdminPermissions();
      schoolId.value = '';
    } catch (e) {
      Get.snackbar('Error', 'Failed to logout: ${e.toString()}');
    }
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
