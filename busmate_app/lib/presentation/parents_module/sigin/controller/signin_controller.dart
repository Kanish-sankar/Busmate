import 'package:busmate/meta/firebase_helper/auth_login.dart';
import 'package:busmate/meta/nav/pages.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class SigInController extends GetxController {
  final AuthLogin getLogin = Get.put(AuthLogin());

  // boolean to control visibility of password
  RxBool isShowPass = false.obs;
  // boolean to control visibility of remember me
  RxBool isRemeber = false.obs;

  RxBool isLoading = false.obs;

  //text field controller
  TextEditingController txtId = TextEditingController();
  TextEditingController txtPassword = TextEditingController();

  // global key for form
  final formKey = GlobalKey<FormState>();

  // local storage instance
  GetStorage storage = GetStorage();

  // Password validation function
  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'passVal1'.tr;
    } else if (value.length < 8) {
      return 'passVal2'.tr;
    } else if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'passVal3'.tr;
    } else if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'passVal4'.tr;
    } else if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'passVal5'.tr;
    }
    return null;
  }

  String? validateUserId(String? value) {
    if (value == null || value.isEmpty) {
      return 'userVal1'.tr;
    }
    return null;
  }

  // Method to handle form submission
  // login button
  void submitForm() {
    isLoading.value = true;
    getLogin.isStudentLogin(txtId.text.trim(), txtPassword.text.trim());
    isLoading.value = false;
    // validate form fields
    // if (formKey.currentState?.validate() ?? false) {
    //   // save data on local storage
    //   if (isRemeber.value) {
    //     storage.write('isRemeber', isRemeber.value);
    //     // storage.write('studentId', txtId.text);
    //     // storage.write('password', txtPassword.text);
    //   }
    //   // navigate to stopping location
    //   Get.offAllNamed(Routes.stopLocation);
    // }
    // clear form fields
    txtId.clear();
    txtPassword.clear();
  }

  // logout  button
  void logout() async {
    // await getLogin.logout();
    FirebaseAuth.instance.signOut();
    // clear local storage
    storage.erase();
    // navigate to sign in screen
    Get.offAllNamed(Routes.sigIn);
  }

  // forgot password button
  void forgotPassword() {
    // Navigate to forgot password screen
    // Get.toNamed(Routes.forgotPassword);
  }

  void showEmailDialog() {
    final TextEditingController emailController = TextEditingController();
    Get.defaultDialog(
      title: "Enter Email",
      content: Column(
        children: [
          TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: "Email",
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 10.h),
          ElevatedButton(
            onPressed: () {
              String email = emailController.text.trim();
              getLogin.resetPassword(email);
              Get.back(); // Close the dialog
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }
}
