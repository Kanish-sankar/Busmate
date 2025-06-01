import 'package:busmate_web/modules/Authentication/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ResetPasswordScreen extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final AuthController authController = Get.find<AuthController>();

  ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Card(
            elevation: 4.0,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Reset Your Password',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter your email address and we\'ll send you instructions to reset your password.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 24),
                    Obx(() => ElevatedButton(
                          onPressed: authController.isLoading.value
                              ? null
                              : () async {
                                  if (emailController.text.isEmpty) {
                                    Get.snackbar(
                                      'Error',
                                      'Please enter your email',
                                    );
                                    return;
                                  }
                                  await authController.resetPassword(
                                    emailController.text.trim(),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 0),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 24,
                            ),
                            child: authController.isLoading.value
                                ? const CircularProgressIndicator()
                                : const Text('Send Reset Link',
                                    style: TextStyle(fontSize: 16)),
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
