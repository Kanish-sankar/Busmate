import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:busmate/meta/nav/pages.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:bcrypt/bcrypt.dart';
import 'dart:convert';

class AuthLogin extends GetxController {
  // REMOVED: Unused GetStudent and GetDriver instances to reduce Firebase reads
  // They were automatically fetching all students/drivers on initialization
  final FirebaseAuth auth = FirebaseAuth.instance;
  bool isStudent = false;

  // Phone authentication
  String? _verificationId;
  int? _resendToken;

  // Hash password using SHA-256 (DEPRECATED - kept for backward compatibility)
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> login(String email, String pass) async {
    try {
      UserCredential userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );
      
      // Ensure custom claims are properly set
      await _ensureCustomClaims(userCredential.user!);
      
      if (isStudent) {
        GetStorage().write('isLoggedIn', true);
        GetStorage().write('isLoggedInStudent', true);
        Get.offAllNamed(Routes.stopLocation);
      } else {
        GetStorage().write('isLoggedIn', true);
        GetStorage().write('isLoggedInDriver', true);
        Get.offAllNamed(Routes.driverScreen);
      }
      // Navigate to Home Screen
    } catch (e) {
      Get.snackbar("Login Failed", "Please Input Valid Id & Pass");
      rethrow; // Re-throw the exception so it can be caught by the calling method
    }
  }

  //logout function
  Future<void> logout() async {
    await auth.signOut();
    GetStorage().erase();
    Get.offAllNamed(Routes.sigIn);
  }

  Future<void> resetPassword(String email) async {
    await auth.sendPasswordResetEmail(email: email);
  }

  // Helper method to ensure custom claims are set
  Future<Map<String, dynamic>> _ensureCustomClaims(User user) async {
    final String userId = user.uid;
    
    // First, try to get existing claims
    var idTokenResult = await user.getIdTokenResult();
    var claims = idTokenResult.claims;
    
    String? role = claims?['role'] as String?;
    String? schoolId = claims?['schoolId'] as String?;
    
    // If claims are missing or empty, we need to set them
    if (role == null || role.isEmpty || schoolId == null || schoolId.isEmpty) {
      // Fetch user data from adminusers
      final adminDoc = await FirebaseFirestore.instance
          .collection('adminusers')
          .doc(userId)
          .get();

      if (!adminDoc.exists) {
        throw Exception('User profile not found. Please contact administrator.');
      }

      final adminData = adminDoc.data()!;
      
      // Call setUserClaims cloud function to set the claims
      try {
        final callable = FirebaseFunctions.instance.httpsCallable('setUserClaims');
        await callable.call({'uid': userId});
        
        // Force refresh the token to get new claims
        await user.getIdToken(true); // Force refresh
        idTokenResult = await user.getIdTokenResult(true);
        claims = idTokenResult.claims;
        
        role = claims?['role'] as String?;
        schoolId = claims?['schoolId'] as String?;
        if (role == null || role.isEmpty || schoolId == null || schoolId.isEmpty) {
          throw Exception('Permissions not ready. Please log out and log in again.');
        }
      } catch (e) {
        // Do NOT continue with missing claims: RTDB/Firestore rules will deny.
        // Fail fast so the user can re-login after claims are fixed.
        throw Exception('Failed to set permissions for this account. Please contact admin or try again.');
      }
    }
    
    return {
      'role': role,
      'schoolId': schoolId,
      'assignedBusId': claims?['assignedBusId'] as String?,
      'assignedRouteId': claims?['assignedRouteId'] as String?,
    };
  }

  // Login with Firebase Authentication (email/password or phone OTP)
  Future<void> simpleLogin(String emailOrPhone, String password) async {
    try {
      final String credential = emailOrPhone.trim();
      UserCredential? userCredential;

      // Determine if email or phone and sign in accordingly
      if (credential.contains('@')) {
        // Email login
        userCredential = await auth.signInWithEmailAndPassword(
          email: credential,
          password: password,
        );
      } else if (credential.contains('@busmate.placeholder')) {
        // Placeholder email for phone-based accounts - should not be used for login
        throw Exception('Please use phone number to login, not placeholder email');
      } else {
        // Phone login - for now, treat as email since phone requires OTP flow
        // User should use phone OTP method instead
        throw Exception('Phone login requires OTP verification. Please use "Login with Phone" option.');
      }

      final String userId = userCredential.user!.uid;
      
      // Ensure custom claims are properly set and refreshed
      final claimsData = await _ensureCustomClaims(userCredential.user!);
      
      final String? role = claimsData['role'] as String?;
      final String? schoolId = claimsData['schoolId'] as String?;
      String? assignedBusId = claimsData['assignedBusId'] as String?;
      final String? assignedRouteId = claimsData['assignedRouteId'] as String?;
      // If claims are missing, fetch from adminusers
      if (role == null || role.isEmpty) {
        final adminDoc = await FirebaseFirestore.instance
            .collection('adminusers')
            .doc(userId)
            .get();

        if (!adminDoc.exists) {
          throw Exception('User profile not found. Please contact administrator.');
        }

        final adminData = adminDoc.data()!;
        final fetchedRole = adminData['role'] as String?;
        final fetchedSchoolId = adminData['schoolId'] as String?;

        if (fetchedRole == null || fetchedRole.isEmpty) {
          throw Exception('User role not configured. Please contact administrator.');
        }

        // Store data
        GetStorage().write('isLoggedIn', true);
        GetStorage().write('adminUserId', userId);
        GetStorage().write('userRole', fetchedRole);
        GetStorage().write('userEmail', adminData['email'] ?? '');
        GetStorage().write('userName', adminData['name'] ?? '');

        await _handleRoleBasedNavigation(
          fetchedRole,
          userId,
          fetchedSchoolId,
          adminData['assignedBusId'] as String?,
        );
        return;
      }

      // Store user data
      GetStorage().write('isLoggedIn', true);
      GetStorage().write('adminUserId', userId);
      GetStorage().write('userRole', role);
      GetStorage().write('userEmail', userCredential.user?.email ?? '');
      GetStorage().write('userName', userCredential.user?.displayName ?? '');

      // Update FCM token and last login (non-blocking)
      try {
        String? fcmToken;
        
        // ✅ iOS requires APNS token before FCM token can be retrieved
        if (!kIsWeb && Platform.isIOS) {
          String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          if (apnsToken == null) {
            // Wait and retry - APNS token may not be immediately available
            await Future.delayed(const Duration(seconds: 2));
            apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          }
          debugPrint('✅ iOS APNS Token during login: ${apnsToken != null ? "Available" : "NOT Available"}');
        }
        
        fcmToken = await FirebaseMessaging.instance.getToken();
        GetStorage().write('fcmToken', fcmToken);

        final adminDoc =
            FirebaseFirestore.instance.collection('adminusers').doc(userId);
        final adminUpdate = <String, dynamic>{
          'lastLogin': FieldValue.serverTimestamp(),
        };

        if (role == 'student') {
          adminUpdate['fcmToken'] = FieldValue.delete();
          await _updateStudentFcmToken(
            studentId: userId,
            schoolId: schoolId,
            token: fcmToken,
          );
        } else {
          if (fcmToken != null && fcmToken.isNotEmpty) {
            adminUpdate['fcmToken'] = fcmToken;
          }
        }

        await adminDoc.update(adminUpdate);
      } catch (fcmError) {
      }

      // Handle role-based navigation
      await _handleRoleBasedNavigation(role, userId, schoolId, assignedBusId);

      Get.snackbar(
        "Welcome!",
        "Login successful",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green[400],
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      String errorMessage = e.toString().replaceAll('Exception: ', '');
      
      // Better error messages
      if (e.toString().contains('user-not-found')) {
        errorMessage = 'No account found with this email';
      } else if (e.toString().contains('wrong-password')) {
        errorMessage = 'Incorrect password';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Invalid email format';
      } else if (e.toString().contains('user-disabled')) {
        errorMessage = 'This account has been disabled';
      } else if (e.toString().contains('too-many-requests')) {
        errorMessage = 'Too many failed attempts. Please try again later';
      }

      Get.snackbar(
        "Login Failed",
        errorMessage,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      rethrow;
    }
  }

  // Helper method to handle role-based navigation
  Future<void> _handleRoleBasedNavigation(
    String role,
    String userId,
    String? schoolId,
    String? assignedBusId,
  ) async {
    if (role == 'student') {
      isStudent = true;
      GetStorage().write('isLoggedInStudent', true);
      GetStorage().write('studentId', userId);

      // If schoolId exists, try to fetch full student data
      if (schoolId != null) {
        try {
          DocumentSnapshot studentDoc = await FirebaseFirestore.instance
              .collection('schooldetails')
              .doc(schoolId)
              .collection('students')
              .doc(userId)
              .get();

          if (studentDoc.exists) {
            Map<String, dynamic> studentData =
                studentDoc.data() as Map<String, dynamic>;
            assignedBusId = studentData['assignedBusId'] as String?;
          }
        } catch (e) {
        }
      }

      if (schoolId != null) GetStorage().write('studentSchoolId', schoolId);
      if (assignedBusId != null) GetStorage().write('studentBusId', assignedBusId);
      Get.offAllNamed(Routes.stopLocation);
    } else if (role == 'driver') {
      isStudent = false;
      GetStorage().write('isLoggedInDriver', true);
      GetStorage().write('driverId', userId);
      if (schoolId != null) GetStorage().write('driverSchoolId', schoolId);
      if (assignedBusId != null) GetStorage().write('driverBusId', assignedBusId);
      Get.offAllNamed(Routes.driverScreen);
    } else {
      throw Exception("Invalid role: $role. Only 'student' and 'driver' are allowed.");
    }
  }

  // Login with role (Student or Driver) using adminusers collection (DEPRECATED - kept for reference)
  Future<void> loginWithRole(String email, String password, String role) async {
    try {
      // Step 1: Authenticate with Firebase Auth
      UserCredential userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Ensure custom claims are properly set
      await _ensureCustomClaims(userCredential.user!);
      
      String uid = userCredential.user!.uid;
      // Step 2: Query adminusers collection
      QuerySnapshot adminQuery = await FirebaseFirestore.instance
          .collection('adminusers')
          .where('email', isEqualTo: email)
          .where('role', isEqualTo: role)
          .limit(1)
          .get();

      if (adminQuery.docs.isEmpty) {
        // User authenticated but doesn't have this role
        await auth.signOut();
        throw Exception("No $role account found with this email");
      }

      // Step 3: Get user data from adminusers
      DocumentSnapshot userDoc = adminQuery.docs.first;
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String adminUserId = userDoc.id;
      // Step 4: Store data based on role
      GetStorage().write('isLoggedIn', true);
      GetStorage().write('adminUserId', adminUserId);
      GetStorage().write('userRole', role);
      GetStorage().write('userEmail', email);
      GetStorage().write('userName', userData['name'] ?? '');

      // Try to update FCM token (non-blocking)
      try {
        String? token = await FirebaseMessaging.instance.getToken();
        GetStorage().write('fcmToken', token);

        final adminDoc = FirebaseFirestore.instance
            .collection('adminusers')
            .doc(adminUserId);
        final adminUpdate = <String, dynamic>{
          'lastLogin': FieldValue.serverTimestamp(),
        };

        if (role == 'student') {
          adminUpdate['fcmToken'] = FieldValue.delete();
          String? schoolId = userData['schoolId'] as String?;
          await _updateStudentFcmToken(
            studentId: adminUserId,
            schoolId: schoolId,
            token: token,
          );
        } else {
          if (token != null && token.isNotEmpty) {
            adminUpdate['fcmToken'] = token;
          }
        }

        await adminDoc.update(adminUpdate);
      } catch (fcmError) {
      }

      // Step 5: Route based on role
      if (role == 'student') {
        isStudent = true;
        GetStorage().write('isLoggedInStudent', true);
        GetStorage().write('studentId', adminUserId);

        // Get assigned bus and school info if available
        String? schoolId = userData['schoolId'] as String?;
        String? assignedBusId = userData['assignedBusId'] as String?;

        if (schoolId != null) GetStorage().write('studentSchoolId', schoolId);
        if (assignedBusId != null)
          GetStorage().write('studentBusId', assignedBusId);
        Get.offAllNamed(Routes.stopLocation);
      } else if (role == 'driver') {
        isStudent = false;
        GetStorage().write('isLoggedInDriver', true);
        GetStorage().write('driverId', adminUserId);

        // Get assigned bus and school info if available
        String? schoolId = userData['schoolId'] as String?;
        String? assignedBusId = userData['assignedBusId'] as String?;

        if (schoolId != null) GetStorage().write('driverSchoolId', schoolId);
        if (assignedBusId != null)
          GetStorage().write('driverBusId', assignedBusId);
        Get.offAllNamed(Routes.driverScreen);
      } else {
        throw Exception("Invalid role: $role");
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Invalid email or password";

      if (e.code == 'user-not-found') {
        errorMessage = "No account found with this email";
      } else if (e.code == 'wrong-password') {
        errorMessage = "Incorrect password";
      } else if (e.code == 'invalid-email') {
        errorMessage = "Invalid email format";
      } else if (e.code == 'user-disabled') {
        errorMessage = "This account has been disabled";
      }

      Get.snackbar(
        "Login Failed",
        errorMessage,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
      throw Exception(errorMessage);
    } catch (e) {
      Get.snackbar(
        "Error",
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
      rethrow;
    }
  }

  Future<void> _updateStudentFcmToken({
    required String studentId,
    String? schoolId,
    String? token,
  }) async {
    if (schoolId == null || schoolId.isEmpty) {
      return;
    }

    if (token == null || token.isEmpty) {
      return;
    }

    // IMPORTANT:
    // - Do NOT set `notified=false` here. That can cause duplicate notifications mid-trip.
    // - Only update Firestore when the token actually changes (to reduce writes).
    final updateData = <String, dynamic>{
      'fcmToken': token,
      'tokenUpdatedAt': FieldValue.serverTimestamp(),
      'platform': Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'other'), // Track device platform
    };

    final updatedSchoolDetails = await _writeStudentTokenToCollection(
      collectionName: 'schooldetails',
      schoolId: schoolId,
      studentId: studentId,
      updateData: updateData,
    );

    final updatedSchools = await _writeStudentTokenToCollection(
      collectionName: 'schools',
      schoolId: schoolId,
      studentId: studentId,
      updateData: updateData,
    );

    if (!updatedSchoolDetails && !updatedSchools) {
    }
  }

  Future<bool> _writeStudentTokenToCollection({
    required String collectionName,
    required String schoolId,
    required String studentId,
    required Map<String, dynamic> updateData,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection(collectionName)
          .doc(schoolId)
          .collection('students')
          .doc(studentId);

      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        return false;
      }

      final existingData = docSnapshot.data();
      final existingToken = existingData is Map<String, dynamic>
          ? (existingData['fcmToken'] as String?)
          : null;
      final newToken = updateData['fcmToken'] as String?;

      // Avoid noisy writes when token hasn't changed.
      if (newToken != null && newToken.isNotEmpty && existingToken == newToken) {
        return true;
      }

      await docRef.set(updateData, SetOptions(merge: true));
      return true;
    } catch (e) {
      return false;
    }
  }

  // Legacy login method (kept for backward compatibility)
  Future<void> isStudentLogin(String userId, String password) async {
    try {
      // First, try to authenticate with Firebase Auth directly using email/password
      // This will work if the userId is actually an email address
      try {
        UserCredential userCredential = await auth.signInWithEmailAndPassword(
          email: userId,
          password: password,
        );

        String authenticatedUserId = userCredential.user!.uid;
        // Now check if this authenticated user is a student or driver
        try {
          DocumentSnapshot studentDoc = await FirebaseFirestore.instance
              .collection('students')
              .doc(authenticatedUserId)
              .get();

          if (studentDoc.exists) {
            isStudent = true;
            // Store student data
            Map<String, dynamic> studentData =
                studentDoc.data() as Map<String, dynamic>;
            GetStorage().write('isLoggedIn', true);
            GetStorage().write('isLoggedInStudent', true);
            GetStorage().write('studentId', authenticatedUserId);
            GetStorage()
                .write('studentBusId', studentData['assignedBusId'] ?? '');
            GetStorage()
                .write('studentSchoolId', studentData['schoolId'] ?? '');
            GetStorage().write(
                'studentDriverId', studentData['assignedDriverId'] ?? '');

            // Try to update FCM token (non-blocking)
            try {
              String? token = await FirebaseMessaging.instance.getToken();
              GetStorage().write('fcmToken', token);

              // Update FCM token in the correct subcollection path
              String? schoolId = studentData['schoolId'] as String?;
              if (schoolId != null && schoolId.isNotEmpty) {
                // Check which collection has the student document
                DocumentSnapshot schoolsDoc = await FirebaseFirestore.instance
                    .collection('schools')
                    .doc(schoolId)
                    .collection('students')
                    .doc(authenticatedUserId)
                    .get();

                if (schoolsDoc.exists) {
                  // Update in schools collection
                  await schoolsDoc.reference.update({
                    'fcmToken': token,
                    'tokenUpdatedAt': FieldValue.serverTimestamp(),
                  });
                } else {
                  // Update in schooldetails collection
                  await FirebaseFirestore.instance
                      .collection('schooldetails')
                      .doc(schoolId)
                      .collection('students')
                      .doc(authenticatedUserId)
                      .update({
                    'fcmToken': token,
                    'tokenUpdatedAt': FieldValue.serverTimestamp(),
                  });
                }
              }
            } catch (fcmError) {
              // Continue with login even if FCM fails
            }
            Get.offAllNamed(Routes.stopLocation);
            return;
          }
        } catch (e) {
        }

        // Check if user is a driver
        try {
          DocumentSnapshot driverDoc = await FirebaseFirestore.instance
              .collection('drivers')
              .doc(authenticatedUserId)
              .get();

          if (driverDoc.exists) {
            isStudent = false;
            // Store driver data
            Map<String, dynamic> driverData =
                driverDoc.data() as Map<String, dynamic>;
            GetStorage().write('isLoggedIn', true);
            GetStorage().write('isLoggedInDriver', true);
            GetStorage().write('driverId', authenticatedUserId);
            GetStorage().write('driverSchoolId', driverData['schoolId'] ?? '');
            GetStorage()
                .write('driverBusId', driverData['assignedBusId'] ?? '');

            // Try to update FCM token (non-blocking)
            try {
              String? token = await FirebaseMessaging.instance.getToken();
              GetStorage().write('fcmToken', token);
              await FirebaseFirestore.instance
                  .collection('drivers')
                  .doc(authenticatedUserId)
                  .update({'fcmToken': token});
            } catch (fcmError) {
              // Continue with login even if FCM fails
            }
            Get.offAllNamed(Routes.driverScreen);
            return;
          }
        } catch (e) {
        }

        // If authenticated but neither student nor driver found
        await auth.signOut(); // Sign out the authenticated user
        throw Exception(
            "User authenticated but no student/driver record found");
      } on FirebaseAuthException catch (e) {
        // If direct email login fails, the user might not exist or wrong credentials
        throw Exception("Invalid email or password");
      }
    } catch (e) {
      Get.snackbar("Error", "Login failed: ${e.toString()}");
      rethrow; // Re-throw the exception
    }
  }

  // forgot Password Link Send
  Future<void> resetPasswordWithNotification(String email) async {
    if (email.isEmpty) {
      Get.snackbar("Error", "Please enter your email",
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      Get.snackbar("Success", "Password reset link sent to $email",
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar("Error", e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  // TEMPORARY: Create test user for development
  // Call this once to create a test user, then remove this function
  Future<void> createTestUser() async {
    try {
      // Create Firebase Auth user
      UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: 'kanish@gmail.com',
        password: '123456',
      );

      String uid = userCredential.user!.uid;
      // Create Firestore document in students collection
      await FirebaseFirestore.instance.collection('students').doc(uid).set({
        'email': 'kanish@gmail.com',
        'name': 'Kanish Test User',
        'studentId': 'STU001',
        'schoolId': 'school_001',
        'assignedBusId': 'bus_001',
        'assignedDriverId': 'driver_001',
        'phoneNumber': '+1234567890',
        'parentName': 'Parent Test',
        'parentPhone': '+1234567890',
        'address': 'Test Address',
        'fcmToken': '',
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
      Get.snackbar(
        'Success',
        'Test user created! Login with:\nkanish@gmail.com / 123456',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        snackPosition: SnackPosition.BOTTOM,
      );

      // Sign out after creating
      await auth.signOut();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to create test user: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
