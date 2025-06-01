import 'package:busmate_web/modules/Authentication/auth_controller.dart';
import 'package:busmate_web/modules/Routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AuthMiddleware extends GetMiddleware {
  final UserRole requiredRole;

  AuthMiddleware({required this.requiredRole});

  @override
  RouteSettings? redirect(String? route) {
    final authController = Get.find<AuthController>();

    if (!authController.isLoggedIn()) {
      return const RouteSettings(name: Routes.LOGIN);
    }

    if (authController.userRole.value != requiredRole) {
      // Redirect to appropriate dashboard based on role
      if (authController.userRole.value == UserRole.superAdmin) {
        return const RouteSettings(name: Routes.SUPER_ADMIN_DASHBOARD);
      } else if (authController.userRole.value == UserRole.schoolAdmin) {
        return const RouteSettings(
          name: Routes.SCHOOL_ADMIN_DASHBOARD,
        );
      } else {
        // If role is not set or undefined, logout and redirect to login
        authController.logout();
        return const RouteSettings(name: Routes.LOGIN);
      }
    }
    return null; // Allow access
  }
}
