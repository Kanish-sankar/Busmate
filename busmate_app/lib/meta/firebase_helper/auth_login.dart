import 'package:busmate/meta/nav/pages.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

  // Hash password using SHA-256
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> login(String email, String pass) async {
    try {
      // ignore: unused_local_variable
      UserCredential userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );
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

  // Simple login using adminusers collection with hashed password (NO Firebase Auth)
  Future<void> simpleLogin(String emailOrId, String password) async {
    try {
      print("DEBUG: Simple login attempt for: $emailOrId");
      
      // Hash the entered password
      String hashedPassword = hashPassword(password);
      print("DEBUG: Password hashed");
      
      // Query adminusers by email
      QuerySnapshot emailQuery = await FirebaseFirestore.instance
          .collection('adminusers')
          .where('email', isEqualTo: emailOrId.toLowerCase())
          .limit(1)
          .get();
      
      // If not found by email, try by studentId or employeeId
      if (emailQuery.docs.isEmpty) {
        print("DEBUG: Not found by email, trying by ID");
        
        // Try studentId
        QuerySnapshot idQuery = await FirebaseFirestore.instance
            .collection('adminusers')
            .where('studentId', isEqualTo: emailOrId)
            .limit(1)
            .get();
        
        // If still not found, try employeeId
        if (idQuery.docs.isEmpty) {
          idQuery = await FirebaseFirestore.instance
              .collection('adminusers')
              .where('employeeId', isEqualTo: emailOrId)
              .limit(1)
              .get();
        }
        
        if (idQuery.docs.isEmpty) {
          throw Exception("User not found");
        }
        
        emailQuery = idQuery;
      }
      
      // Get user document
      DocumentSnapshot userDoc = emailQuery.docs.first;
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String userId = userDoc.id;
      String role = userData['role'] as String;
      
      print("DEBUG: User found with role: $role");
      
      // Check password - support both bcrypt (old) and SHA-256 (new)
      String storedPassword = userData['password'] as String? ?? '';
      bool passwordValid = false;
      
      // Check if stored password is bcrypt (starts with $2a$, $2b$, or $2y$)
      if (storedPassword.startsWith(RegExp(r'\$2[aby]\$'))) {
        print("DEBUG: Stored password is bcrypt format (${storedPassword.length} chars)");
        // Verify using bcrypt
        try {
          passwordValid = BCrypt.checkpw(password, storedPassword);
          print("DEBUG: Bcrypt check result: $passwordValid");
        } catch (e) {
          print("DEBUG: Bcrypt comparison error: $e");
          passwordValid = false;
        }
      } else {
        print("DEBUG: Stored password is SHA-256 format");
        print("DEBUG: Stored password: ${storedPassword.substring(0, 20)}...");
        print("DEBUG: Entered hashed: ${hashedPassword.substring(0, 20)}...");
        // Compare SHA-256 hashes
        passwordValid = (storedPassword == hashedPassword);
      }
      
      if (!passwordValid) {
        print("DEBUG: Password verification failed");
        throw Exception("Invalid password");
      }
      
      print("DEBUG: Password verified!");
      
      // Store data based on role
      GetStorage().write('isLoggedIn', true);
      GetStorage().write('adminUserId', userId);
      GetStorage().write('userRole', role);
      GetStorage().write('userEmail', userData['email'] ?? '');
      GetStorage().write('userName', userData['name'] ?? '');
      
      // Try to update FCM token and last login (non-blocking)
      try {
        String? token = await FirebaseMessaging.instance.getToken();
        GetStorage().write('fcmToken', token);

        final adminDoc = FirebaseFirestore.instance.collection('adminusers').doc(userId);
        final adminUpdate = <String, dynamic>{
          'lastLogin': FieldValue.serverTimestamp(),
        };

        if (role == 'student') {
          adminUpdate['fcmToken'] = FieldValue.delete();
          String? schoolId = userData['schoolId'] as String?;
          await _updateStudentFcmToken(
            studentId: userId,
            schoolId: schoolId,
            token: token,
          );
        } else {
          if (token != null && token.isNotEmpty) {
            adminUpdate['fcmToken'] = token;
          }
        }

        await adminDoc.update(adminUpdate);
        print("DEBUG: FCM token synced for $role login");
      } catch (fcmError) {
        print("DEBUG: FCM update failed (non-critical): $fcmError");
      }
      
      // Route based on role
      if (role == 'student') {
        isStudent = true;
        GetStorage().write('isLoggedInStudent', true);
        GetStorage().write('studentId', userId);
        
        // Get schoolId and assignedBusId from adminusers
        String? schoolId = userData['schoolId'] as String?;
        String? assignedBusId = userData['assignedBusId'] as String?;
        
        // If schoolId exists in adminusers, try to fetch full student data
        if (schoolId != null) {
          try {
            // Fetch from correct path: schooldetails/{schoolId}/students/{studentId}
            DocumentSnapshot studentDoc = await FirebaseFirestore.instance
                .collection('schooldetails')
                .doc(schoolId)
                .collection('students')
                .doc(userId)
                .get();
            
            if (studentDoc.exists) {
              Map<String, dynamic> studentData = studentDoc.data() as Map<String, dynamic>;
              // Update with latest data from students collection
              assignedBusId = studentData['assignedBusId'] as String?;
              print("DEBUG: Fetched student data from schooldetails");
            }
          } catch (e) {
            print("DEBUG: Could not fetch from schooldetails/students: $e");
          }
        }
        
        if (schoolId != null) GetStorage().write('studentSchoolId', schoolId);
        if (assignedBusId != null) GetStorage().write('studentBusId', assignedBusId);
        
        print("DEBUG: Student schoolId: $schoolId, busId: $assignedBusId");
        print("DEBUG: Navigating to student screen");
        Get.offAllNamed(Routes.stopLocation);
      } else if (role == 'driver') {
        isStudent = false;
        GetStorage().write('isLoggedInDriver', true);
        GetStorage().write('driverId', userId);
        
        String? schoolId = userData['schoolId'] as String?;
        String? assignedBusId = userData['assignedBusId'] as String?;
        
        print("DEBUG: Driver data from adminusers:");
        print("  userId: $userId");
        print("  schoolId: $schoolId");
        print("  assignedBusId: $assignedBusId");
        
        if (schoolId != null) GetStorage().write('driverSchoolId', schoolId);
        if (assignedBusId != null) GetStorage().write('driverBusId', assignedBusId);
        
        print("DEBUG: Saved to GetStorage:");
        print("  driverId: ${GetStorage().read('driverId')}");
        print("  driverSchoolId: ${GetStorage().read('driverSchoolId')}");
        print("  driverBusId: ${GetStorage().read('driverBusId')}");
        
        print("DEBUG: Navigating to driver screen");
        Get.offAllNamed(Routes.driverScreen);
      } else {
        throw Exception("Invalid role: $role");
      }
      
      Get.snackbar(
        "Welcome!",
        "Login successful",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green[400],
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      
    } catch (e) {
      print("DEBUG: Login error: $e");
      String errorMessage = e.toString().replaceAll('Exception: ', '');
      
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

  // Login with role (Student or Driver) using adminusers collection (DEPRECATED - kept for reference)
  Future<void> loginWithRole(String email, String password, String role) async {
    try {
      print("DEBUG: Starting login for email: $email, role: $role");
      
      // Step 1: Authenticate with Firebase Auth
      UserCredential userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      String uid = userCredential.user!.uid;
      print("DEBUG: Firebase Auth successful for UID: $uid");
      
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
      
      print("DEBUG: User found in adminusers with role: $role");
      
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

        final adminDoc = FirebaseFirestore.instance.collection('adminusers').doc(adminUserId);
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
        print("DEBUG: FCM token synced for $role role login");
      } catch (fcmError) {
        print("DEBUG: FCM token update failed (non-critical): $fcmError");
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
        if (assignedBusId != null) GetStorage().write('studentBusId', assignedBusId);
        
        print("DEBUG: Navigating to student stop location");
        Get.offAllNamed(Routes.stopLocation);
      } else if (role == 'driver') {
        isStudent = false;
        GetStorage().write('isLoggedInDriver', true);
        GetStorage().write('driverId', adminUserId);
        
        // Get assigned bus and school info if available
        String? schoolId = userData['schoolId'] as String?;
        String? assignedBusId = userData['assignedBusId'] as String?;
        
        if (schoolId != null) GetStorage().write('driverSchoolId', schoolId);
        if (assignedBusId != null) GetStorage().write('driverBusId', assignedBusId);
        
        print("DEBUG: Navigating to driver screen");
        Get.offAllNamed(Routes.driverScreen);
      } else {
        throw Exception("Invalid role: $role");
      }
      
    } on FirebaseAuthException catch (e) {
      print("DEBUG: Firebase Auth failed: ${e.code} - ${e.message}");
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
      print("DEBUG: Login error: $e");
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
      print("DEBUG: Skipping student FCM update, missing schoolId");
      return;
    }

    if (token == null || token.isEmpty) {
      print("DEBUG: Skipping student FCM update, missing token");
      return;
    }

    final updateData = <String, dynamic>{
      'fcmToken': token,
      'notified': false,
      'tokenUpdatedAt': FieldValue.serverTimestamp(),
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
      print(
          "DEBUG: Student FCM token update skipped - doc missing in schooldetails and schools");
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
        print(
            "DEBUG: $collectionName/$schoolId/students/$studentId not found while updating token");
        return false;
      }

      await docRef.set(updateData, SetOptions(merge: true));
      print(
          "DEBUG: Student FCM token stored in $collectionName/$schoolId/students/$studentId");
      return true;
    } catch (e) {
      print(
          "DEBUG: Error updating $collectionName/$schoolId/students/$studentId token: $e");
      return false;
    }
  }

  // Legacy login method (kept for backward compatibility)
  Future<void> isStudentLogin(String userId, String password) async {
    try {
      print("DEBUG: Starting login attempt for userId: $userId");
      
      // First, try to authenticate with Firebase Auth directly using email/password
      // This will work if the userId is actually an email address
      try {
        UserCredential userCredential = await auth.signInWithEmailAndPassword(
          email: userId,
          password: password,
        );
        
        String authenticatedUserId = userCredential.user!.uid;
        print("DEBUG: Firebase Auth successful for UID: $authenticatedUserId");
        
        // Now check if this authenticated user is a student or driver
        try {
          DocumentSnapshot studentDoc = await FirebaseFirestore.instance
              .collection('students')
              .doc(authenticatedUserId)
              .get();
              
          if (studentDoc.exists) {
            print("DEBUG: User is a student");
            isStudent = true;
            // Store student data
            Map<String, dynamic> studentData = studentDoc.data() as Map<String, dynamic>;
            GetStorage().write('isLoggedIn', true);
            GetStorage().write('isLoggedInStudent', true);
            GetStorage().write('studentId', authenticatedUserId);
            GetStorage().write('studentBusId', studentData['assignedBusId'] ?? '');
            GetStorage().write('studentSchoolId', studentData['schoolId'] ?? '');
            GetStorage().write('studentDriverId', studentData['assignedDriverId'] ?? '');
            
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
                  await schoolsDoc.reference.update({'fcmToken': token, 'notified': false});
                  print("✅ FCM token updated in schools/$schoolId/students/$authenticatedUserId");
                } else {
                  // Update in schooldetails collection
                  await FirebaseFirestore.instance
                      .collection('schooldetails')
                      .doc(schoolId)
                      .collection('students')
                      .doc(authenticatedUserId)
                      .update({'fcmToken': token, 'notified': false});
                  print("✅ FCM token updated in schooldetails/$schoolId/students/$authenticatedUserId");
                }
              }
            } catch (fcmError) {
              print("❌ FCM token update failed (non-critical): $fcmError");
              // Continue with login even if FCM fails
            }
                
            print("DEBUG: Navigating to stop location");
            Get.offAllNamed(Routes.stopLocation);
            return;
          }
        } catch (e) {
          print("DEBUG: Error checking student document: $e");
        }
        
        // Check if user is a driver
        try {
          DocumentSnapshot driverDoc = await FirebaseFirestore.instance
              .collection('drivers')
              .doc(authenticatedUserId)
              .get();
              
          if (driverDoc.exists) {
            print("DEBUG: User is a driver");
            isStudent = false;
            // Store driver data
            Map<String, dynamic> driverData = driverDoc.data() as Map<String, dynamic>;
            GetStorage().write('isLoggedIn', true);
            GetStorage().write('isLoggedInDriver', true);
            GetStorage().write('driverId', authenticatedUserId);
            GetStorage().write('driverSchoolId', driverData['schoolId'] ?? '');
            GetStorage().write('driverBusId', driverData['assignedBusId'] ?? '');
            
            // Try to update FCM token (non-blocking)
            try {
              String? token = await FirebaseMessaging.instance.getToken();
              GetStorage().write('fcmToken', token);
              await FirebaseFirestore.instance
                  .collection('drivers')
                  .doc(authenticatedUserId)
                  .update({'fcmToken': token});
              print("DEBUG: FCM token updated successfully");
            } catch (fcmError) {
              print("DEBUG: FCM token update failed (non-critical): $fcmError");
              // Continue with login even if FCM fails
            }
                
            print("DEBUG: Navigating to driver screen");
            Get.offAllNamed(Routes.driverScreen);
            return;
          }
        } catch (e) {
          print("DEBUG: Error checking driver document: $e");
        }
        
        // If authenticated but neither student nor driver found
        await auth.signOut(); // Sign out the authenticated user
        throw Exception("User authenticated but no student/driver record found");
        
      } on FirebaseAuthException catch (e) {
        print("DEBUG: Firebase Auth failed: ${e.code} - ${e.message}");
        // If direct email login fails, the user might not exist or wrong credentials
        throw Exception("Invalid email or password");
      }
    } catch (e) {
      print("DEBUG: Login error: $e");
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
      print("Creating test user...");
      
      // Create Firebase Auth user
      UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: 'kanish@gmail.com',
        password: '123456',
      );
      
      String uid = userCredential.user!.uid;
      print("Test user created with UID: $uid");
      
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
      
      print('✅ Test user created successfully!');
      print('Email: kanish@gmail.com');
      print('Password: 123456');
      print('UID: $uid');
      
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
      print('❌ Error creating test user: $e');
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
