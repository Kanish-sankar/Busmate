import 'package:busmate_web/modules/Authentication/auth_controller.dart';
import 'package:busmate_web/modules/Routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RegisterScreen extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  // Using Rx to reactively handle the selected role
  final RxString selectedRole = 'schoolAdmin'.obs; // Default role
  final AuthController authController = Get.find<AuthController>();

  // Available roles (you can expand these if needed)
  final List<String> roles = ['schoolAdmin', 'superAdmin'];

  RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Removing the default app bar for a full-screen, immersive design.
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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: 600,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Create an Account',
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
                      Obx(
                        () => DropdownButtonFormField<String>(
                          value: selectedRole.value,
                          items: roles
                              .map(
                                (role) => DropdownMenuItem<String>(
                                  value: role,
                                  child: Text(
                                    role,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) selectedRole.value = val;
                          },
                          decoration: InputDecoration(
                            labelText: 'Select Role',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Obx(
                        () => ElevatedButton(
                          onPressed: authController.isLoading.value
                              ? null
                              : () async {
                                  if (emailController.text.isEmpty ||
                                      passwordController.text.isEmpty) {
                                    Get.snackbar(
                                      'Error',
                                      'Please enter email and password',
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                    return;
                                  }
                                  await authController.register(
                                    emailController.text.trim(),
                                    passwordController.text,
                                    selectedRole.value,
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: authController.isLoading.value
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                )
                              : const Text(
                                  'Register',
                                  style: TextStyle(fontSize: 18),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Get.offNamed(Routes.LOGIN);
                        },
                        child: const Text('Already have an account? Login'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
