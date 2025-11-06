import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:developer';

/// Centralized error handling for the web application
class WebErrorHandler {
  
  /// Show error snackbar with consistent styling
  static void showError(String message, {String? title}) {
    Get.snackbar(
      title ?? 'Error',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red.shade100,
      colorText: Colors.red.shade800,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      icon: Icon(
        Icons.error_outline,
        color: Colors.red.shade800,
      ),
    );
  }
  
  /// Show success snackbar
  static void showSuccess(String message, {String? title}) {
    Get.snackbar(
      title ?? 'Success',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.green.shade100,
      colorText: Colors.green.shade800,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      icon: Icon(
        Icons.check_circle_outline,
        color: Colors.green.shade800,
      ),
    );
  }
  
  /// Show warning snackbar
  static void showWarning(String message, {String? title}) {
    Get.snackbar(
      title ?? 'Warning',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange.shade100,
      colorText: Colors.orange.shade800,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      icon: Icon(
        Icons.warning_outlined,
        color: Colors.orange.shade800,
      ),
    );
  }
  
  /// Show info snackbar
  static void showInfo(String message, {String? title}) {
    Get.snackbar(
      title ?? 'Info',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.blue.shade100,
      colorText: Colors.blue.shade800,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      icon: Icon(
        Icons.info_outline,
        color: Colors.blue.shade800,
      ),
    );
  }
  
  /// Handle and log errors with context
  static void handleError(
    dynamic error, {
    String? context,
    bool showSnackbar = true,
    String? customMessage,
  }) {
    // Log error for debugging
    log('🔴 Error${context != null ? ' in $context' : ''}: $error');
    
    if (showSnackbar) {
      String message = customMessage ?? _getErrorMessage(error);
      showError(message);
    }
  }
  
  /// Get user-friendly error message
  static String _getErrorMessage(dynamic error) {
    String errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network')) {
      return 'Network error. Please check your internet connection.';
    } else if (errorString.contains('permission')) {
      return 'You don\'t have permission to perform this action.';
    } else if (errorString.contains('not found')) {
      return 'The requested data was not found.';
    } else if (errorString.contains('invalid email')) {
      return 'Please enter a valid email address.';
    } else if (errorString.contains('wrong password')) {
      return 'Incorrect password. Please try again.';
    } else if (errorString.contains('user not found')) {
      return 'No account found with this email address.';
    } else if (errorString.contains('email already in use')) {
      return 'An account with this email already exists.';
    } else if (errorString.contains('weak password')) {
      return 'Password is too weak. Please choose a stronger password.';
    } else if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
  
  /// Show loading dialog
  static void showLoading({String? message}) {
    Get.dialog(
      AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message ?? 'Loading...'),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }
  
  /// Hide loading dialog
  static void hideLoading() {
    if (Get.isDialogOpen == true) {
      Get.back();
    }
  }
  
  /// Show confirmation dialog
  static Future<bool> showConfirmDialog({
    required String title,
    required String message,
    String confirmText = 'Yes',
    String cancelText = 'No',
  }) async {
    bool? result = await Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}