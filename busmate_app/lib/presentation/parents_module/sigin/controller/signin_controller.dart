import 'package:busmate/meta/firebase_helper/auth_login.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SignInController extends GetxController with GetTickerProviderStateMixin {

  // Form key for validation
  final formKey = GlobalKey<FormState>();
  
  // Authentication helper
  final AuthLogin authLogin = Get.put(AuthLogin());
  
  // Role from arguments (student or driver)
  String? userRole;
  
  void logout() {
    // Clear the text controllers
    txtId.clear();
    txtPassword.clear();
    // Reset the state
    isRemeber.value = false;
    
    Get.offAllNamed('/login');
  }

  final txtId = TextEditingController();
  final txtPassword = TextEditingController();
  
  final isShowPass = false.obs;
  final isRemeber = false.obs;
  final isLoading = false.obs;
  final isHovering = false.obs;
  
  // Animation controllers
  late AnimationController slideController;
  late AnimationController fadeController;
  late AnimationController pulseController;
  
  // Animations
  late Animation<Offset> slideAnimation;
  late Animation<double> fadeAnimation;
  late Animation<double> pulseAnimation;

  @override
  void onInit() {
    super.onInit();
    
    // Get role from arguments
    final arguments = Get.arguments;
    if (arguments != null && arguments is Map) {
      userRole = arguments['role'] as String?;
      print("DEBUG: SignInController initialized with role: $userRole");
    }
    
    // Initialize animations
    slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: slideController,
      curve: Curves.easeOutCubic,
    ));
    
    fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: fadeController,
      curve: Curves.easeInOut,
    ));
    
    pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    slideController.forward();
    fadeController.forward();
  }

  // Validation methods
  String? validateUserId(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your Student ID';
    }
    if (value.length < 3) {
      return 'Student ID must be at least 3 characters';
    }
    return null;
  }
  
  final txtEmail = TextEditingController();

  void resetPassword() {
    if (txtEmail.text.isEmpty) {
      Get.snackbar('Error', 'Enter your email first to reset password');
      return;
    }
    authLogin.resetPassword(txtEmail.text.trim());
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // Form submission
  Future<void> submitForm() async {
    if (!formKey.currentState!.validate()) {
      return;
    }
    
    isLoading.value = true;
    
    try {
      // Use simple login (no Firebase Auth, just adminusers with hashed password)
      print("DEBUG: Using simpleLogin");
      await authLogin.simpleLogin(
        txtEmail.text.trim(), 
        txtPassword.text.trim()
      );
      
      // If we reach here, login was successful and navigation is handled by authLogin
      // No need for additional navigation here as authLogin handles it
      
    } catch (e) {
      // Error already shown in simpleLogin method
      print("DEBUG: Login failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Forgot password dialog
  void showEmailDialog() {
    final emailController = TextEditingController();
    
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                blurRadius: 32,
                color: Colors.black.withOpacity(0.2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_reset_rounded, color: Colors.blue.shade600),
                  const SizedBox(width: 12),
                  Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Enter your email to receive a password reset link',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        Get.snackbar(
                          'Email Sent',
                          'Check your inbox for reset instructions',
                          backgroundColor: Colors.green,
                          colorText: Colors.white,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Send Link'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void onClose() {
    slideController.dispose();
    fadeController.dispose();
    pulseController.dispose();
    txtId.dispose();
    txtPassword.dispose();
    super.onClose();
  }
}