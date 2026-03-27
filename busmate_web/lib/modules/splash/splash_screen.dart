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
  Worker? _authReadyWorker;

  void _routeIfReady() {
    if (!mounted) return;
    if (!_authController.authReady.value) return;

    // Logged-in users are routed by AuthController role logic.
    if (!_authController.isLoggedIn()) {
      Get.offAllNamed(Routes.LOGIN);
    }
  }

  @override
  void initState() {
    super.initState();
    _authController = Get.find<AuthController>();
    _authReadyWorker = ever<bool>(_authController.authReady, (_) => _routeIfReady());
    _routeIfReady();
  }

  @override
  void dispose() {
    _authReadyWorker?.dispose();
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
