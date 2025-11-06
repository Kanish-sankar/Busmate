import 'package:busmate/meta/nav/pages.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class AuthLogin extends GetxController {
  // REMOVED: Unused GetStudent and GetDriver instances to reduce Firebase reads
  // They were automatically fetching all students/drivers on initialization
  final FirebaseAuth auth = FirebaseAuth.instance;
  bool isStudent = false;

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
              await FirebaseFirestore.instance
                  .collection('students')
                  .doc(authenticatedUserId)
                  .update({'fcmToken': token});
              print("DEBUG: FCM token updated successfully");
            } catch (fcmError) {
              print("DEBUG: FCM token update failed (non-critical): $fcmError");
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
        duration: Duration(seconds: 5),
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
        duration: Duration(seconds: 5),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
