// File: lib/screens/splash_screen.dart
import 'package:busmate_web/modules/Authentication/auth_controller.dart';
import 'package:busmate_web/modules/Routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final AuthController _authController;
  Worker? _userWorker;
  bool _navigated = false;

  void _routeIfNeeded() {
    if (!mounted || _navigated) return;

    // Logged-in users are routed by AuthController role logic.
    if (_authController.user.value == null && !_authController.isLoading.value) {
      _navigated = true;
      Get.offAllNamed(Routes.LOGIN);
    }
  }

  @override
  void initState() {
    super.initState();
    _authController = Get.find<AuthController>();

    // React when Firebase auth state changes.
    _userWorker = ever(_authController.user, (_) => _routeIfNeeded());
    _routeIfNeeded();

    // Fallback to avoid staying forever on splash if no auth event arrives.
    Future.delayed(const Duration(seconds: 6), _routeIfNeeded);
  }

  @override
  void dispose() {
    _userWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade800,
              Colors.blue.shade600,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // BusMate logo only
              Image.asset(
                'assets/images/LOGO.png',
                width: 130,
                height: 130,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  'BusMate',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'School Bus Tracking System',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
