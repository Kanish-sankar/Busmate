import 'package:busmate/meta/firebase_helper/get_driver.dart';
import 'package:busmate/meta/firebase_helper/get_student.dart';
import 'package:busmate/meta/nav/pages.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class AuthLogin extends GetxController {
  final GetStudent getStudent = Get.put(GetStudent());
  final GetDriver getDriver = Get.put(GetDriver());
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
    }
  }

  //logout function
  Future<void> logout() async {
    await auth.signOut();
    GetStorage().erase();
    Get.offAllNamed(Routes.sigIn);
  }

  Future<void> isStudentLogin(String userId, String password) async {
    try {
      getDriver.fetchDrivers();
      for (var driver in getDriver.driverList) {
        if ((driver.email == userId || driver.contactInfo == userId)) {
          isStudent = false;
          await login(driver.email, password);
          GetStorage().write('driverSchoolId', driver.schoolId);
          GetStorage().write('driverId', driver.id);
          GetStorage().write('driverBusId', driver.assignedBusId);
          String? token = await FirebaseMessaging.instance.getToken();
          GetStorage().write('fcmToken', token);
          await FirebaseFirestore.instance
              .collection('drivers')
              .doc(driver.id)
              .update({
            'fcmToken': GetStorage().read('fcmToken'),
          });
          return;
        }
      }

      getStudent.fetchStudents();
      for (var student in getStudent.studentList) {
        if ((student.email == userId || student.parentContact == userId)) {
          isStudent = true;
          await login(student.email, password);
          GetStorage().write('studentId', student.id);
          GetStorage().write('studentBusId', student.assignedBusId);
          GetStorage().write('studentSchoolId', student.schoolId);
          GetStorage().write('studentDriverId', student.assignedDriverId);
          String? token = await FirebaseMessaging.instance.getToken();
          GetStorage().write('fcmToken', token);
          await FirebaseFirestore.instance
              .collection('students')
              .doc(student.id)
              .update({
            'fcmToken': GetStorage().read('fcmToken'),
          });
          return;
        }
      }
      Get.snackbar("User!", "User Is Not Register");
    } catch (e) {
      Get.snackbar("Error", "An error occurred during login");
    }
  }

  // forgot Password Link Send
  void resetPassword(String email) async {
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
}
