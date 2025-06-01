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
  @override
  void initState() {
    super.initState();

    // Delay navigation by 4 seconds and then check auth state
    Future.delayed(const Duration(seconds: 4), () {
      final AuthController authController = Get.find();

      if (!authController.isLoggedIn()) {
        Get.offAllNamed(Routes.LOGIN);
      } else {
        // Optional: Navigate to a default home route if needed
        // Get.offAllNamed(Routes.HOME);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Bus Tracking System',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
