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

    // Delay navigation by 2 seconds and then check auth state
    Future.delayed(const Duration(seconds: 2), () {
      final AuthController authController = Get.find();

      if (!authController.isLoggedIn()) {
        Get.offAllNamed(Routes.LOGIN);
      } else {
        // Navigate based on user role
        _navigateBasedOnRole(authController);
      }
    });
  }

  void _navigateBasedOnRole(AuthController authController) {
    // Wait for user role to be fetched
    if (authController.userRole.value == null) {
      // Wait a bit more for role to be loaded
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateBasedOnRole(authController);
      });
      return;
    }

    switch (authController.userRole.value) {
      case UserRole.superior:
        Get.offAllNamed(Routes.SUPER_ADMIN_DASHBOARD);
        break;
      case UserRole.schoolAdmin:
        Get.offAllNamed(Routes.SCHOOL_ADMIN_DASHBOARD);
        break;
      default:
        Get.offAllNamed(Routes.LOGIN);
        break;
    }
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
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.directions_bus,
                size: 80,
                color: Colors.white,
              ),
              SizedBox(height: 20),
              Text(
                'BusMate',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'School Bus Tracking System',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 40),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
