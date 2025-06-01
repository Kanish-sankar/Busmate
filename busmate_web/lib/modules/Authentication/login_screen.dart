import 'package:busmate_web/modules/Authentication/auth_controller.dart';
import 'package:busmate_web/modules/Routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final AuthController authController = Get.find<AuthController>();
  final RxMap<String, dynamic> basicDetails = <String, dynamic>{}.obs;

  LoginScreen({super.key});

  Future<void> fetchBasicDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('basicDetails')
          .doc('admin')
          .get();
      if (doc.exists) {
        basicDetails.value = doc.data() ?? {};
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    fetchBasicDetails();
    return Scaffold(
      // Gradient background for a modern look.
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade600, Colors.blue.shade200],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: SizedBox(
              width: 600,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Bus Tracking System Admin Panel',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      Obx(() => ElevatedButton(
                            onPressed: authController.isLoading.value
                                ? null
                                : () async {
                                    if (emailController.text.isEmpty) {
                                      Get.snackbar(
                                        'Error',
                                        'Please enter email',
                                        snackPosition: SnackPosition.BOTTOM,
                                      );
                                      return;
                                    }
                                    await authController.sendOtpByEmail(
                                        emailController.text.trim());
                                  },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: authController.isOtpSent.value
                                ? const Text('OTP Sent',
                                    style: TextStyle(fontSize: 18))
                                : const Text('Send OTP',
                                    style: TextStyle(fontSize: 18)),
                          )),
                      const SizedBox(height: 16),
                      Obx(
                        () => authController.isOtpSent.value
                            ? Column(
                                children: [
                                  TextField(
                                    controller: otpController,
                                    decoration: InputDecoration(
                                      labelText: 'Enter OTP',
                                      prefixIcon:
                                          const Icon(Icons.verified_user),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: authController.isLoading.value ||
                                            authController.isVerifyingOtp.value
                                        ? null
                                        : () async {
                                            if (emailController.text.isEmpty ||
                                                passwordController
                                                    .text.isEmpty ||
                                                otpController.text.isEmpty) {
                                              Get.snackbar(
                                                'Error',
                                                'Please enter email, password and OTP',
                                                snackPosition:
                                                    SnackPosition.BOTTOM,
                                              );
                                              return;
                                            }
                                            await authController.loginWithOtp(
                                              emailController.text.trim(),
                                              passwordController.text,
                                              otpController.text.trim(),
                                            );
                                          },
                                    style: ElevatedButton.styleFrom(
                                      minimumSize:
                                          const Size(double.infinity, 50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: (authController.isLoading.value ||
                                            authController.isVerifyingOtp.value)
                                        ? const CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          )
                                        : const Text('Login',
                                            style: TextStyle(fontSize: 18)),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              Get.toNamed(Routes.RESET_PASSWORD);
                            },
                            child: const Text('Forgot Password?'),
                          ),
                          TextButton(
                            onPressed: () {
                              Get.toNamed(Routes.REGISTER);
                            },
                            child:
                                const Text('Don\'t have an account? Register'),
                          ),
                        ],
                      ),
                      // const SizedBox(height: 24),
                      // // Contact Us section
                      // Obx(() {
                      //   if (basicDetails.isEmpty) {
                      //     return const SizedBox.shrink();
                      //   }
                      //   return Column(
                      //     crossAxisAlignment: CrossAxisAlignment.start,
                      //     children: [
                      //       const Divider(),
                      //       const Text(
                      //         'Contact Us',
                      //         style: TextStyle(
                      //           fontWeight: FontWeight.bold,
                      //           fontSize: 16,
                      //         ),
                      //       ),
                      //       const SizedBox(height: 6),
                      //       if (basicDetails['email'] != null)
                      //         Text('Email: ${basicDetails['email']}'),
                      //       if (basicDetails['whatsapp'] != null)
                      //         Text('WhatsApp: ${basicDetails['whatsapp']}'),
                      //       if (basicDetails['instagramPageLink'] != null)
                      //         Text(
                      //             'Instagram: ${basicDetails['instagramPageLink']}'),
                      //       if (basicDetails['twitterPageLink'] != null)
                      //         Text(
                      //             'Twitter: ${basicDetails['twitterPageLink']}'),
                      //     ],
                      //   );
                      // }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Obx(() {
        if (basicDetails.isEmpty) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (_) => Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contact Us',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (basicDetails['email'] != null)
                      Row(
                        children: [
                          const Icon(Icons.email, size: 20),
                          const SizedBox(width: 8),
                          Text(basicDetails['email']),
                        ],
                      ),
                    if (basicDetails['whatsapp'] != null)
                      Row(
                        children: [
                          const Icon(Icons.call, size: 20, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(basicDetails['whatsapp']),
                        ],
                      ),
                    if (basicDetails['instagramPageLink'] != null)
                      Row(
                        children: [
                          const Icon(Icons.camera_alt,
                              size: 20, color: Colors.purple),
                          const SizedBox(width: 8),
                          Text(basicDetails['instagramPageLink']),
                        ],
                      ),
                    if (basicDetails['twitterPageLink'] != null)
                      Row(
                        children: [
                          const Icon(Icons.alternate_email,
                              size: 20, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(basicDetails['twitterPageLink']),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
          icon: const Icon(Icons.contact_mail),
          label: const Text('Contact Us'),
        );
      }),
    );
  }
}
