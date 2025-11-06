import 'dart:developer';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Centralized error handling system for BusMate app
/// Provides consistent error logging, user feedback, and crash reporting
class ErrorHandler {
  
  /// Log error with context information
  static void logError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? additionalData,
  }) {
    final errorMessage = error.toString();
    final timestamp = DateTime.now().toIso8601String();
    
    // Log to console in debug mode
    if (kDebugMode) {
      log(
        '🔴 ERROR [$timestamp]: $errorMessage',
        name: 'BusMate',
        error: error,
        stackTrace: stackTrace,
      );
      
      if (context != null) {
        log('📍 Context: $context', name: 'BusMate');
      }
      
      if (additionalData != null) {
        log('📊 Additional Data: $additionalData', name: 'BusMate');
      }
    }
    
    // In production, you could send to crash reporting service
    // like Firebase Crashlytics, Sentry, etc.
    _reportToCrashlytics(error, stackTrace, context, additionalData);
  }
  
  /// Handle Firebase errors with user-friendly messages
  static String handleFirebaseError(dynamic error) {
    final errorCode = error.toString().toLowerCase();
    
    if (errorCode.contains('network')) {
      return 'Network connection failed. Please check your internet connection.';
    } else if (errorCode.contains('permission-denied')) {
      return 'Access denied. Please check your permissions.';
    } else if (errorCode.contains('not-found')) {
      return 'Requested data not found.';
    } else if (errorCode.contains('already-exists')) {
      return 'Data already exists.';
    } else if (errorCode.contains('invalid-argument')) {
      return 'Invalid data provided. Please check your input.';
    } else if (errorCode.contains('deadline-exceeded')) {
      return 'Request timed out. Please try again.';
    } else if (errorCode.contains('unavailable')) {
      return 'Service temporarily unavailable. Please try again later.';
    } else if (errorCode.contains('unauthenticated')) {
      return 'Authentication required. Please sign in again.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
  
  /// Show user-friendly error message
  static void showErrorSnackbar(
    dynamic error, {
    String? context,
    Duration duration = const Duration(seconds: 3),
  }) {
    String message;
    
    if (error is String) {
      message = error;
    } else {
      message = handleFirebaseError(error);
    }
    
    // Log the error
    logError(error, context: context);
    
    // Show user-friendly message
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.colorScheme.error.withOpacity(0.9),
      colorText: Get.theme.colorScheme.onError,
      duration: duration,
      isDismissible: true,
      animationDuration: const Duration(milliseconds: 300),
    );
  }
  
  /// Handle network errors specifically
  static void handleNetworkError({String? context}) {
    showErrorSnackbar(
      'Network connection failed. Please check your internet connection and try again.',
      context: context ?? 'Network Error',
    );
  }
  
  /// Handle authentication errors
  static void handleAuthError(dynamic error, {String? context}) {
    logError(error, context: context ?? 'Authentication Error');
    
    // Redirect to login if authentication fails
    if (error.toString().toLowerCase().contains('unauthenticated')) {
      Get.offAllNamed('/login');
      showErrorSnackbar('Session expired. Please sign in again.');
    } else {
      showErrorSnackbar(error, context: context);
    }
  }
  
  /// Handle validation errors
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }
    
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }
  
  /// Handle validation errors
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    
    if (password.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    
    return null;
  }
  
  /// Handle validation errors
  static String? validatePhone(String? phone) {
    if (phone == null || phone.isEmpty) {
      return 'Phone number is required';
    }
    
    final phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');
    if (!phoneRegex.hasMatch(phone.replaceAll(RegExp(r'[^\d+]'), ''))) {
      return 'Please enter a valid phone number';
    }
    
    return null;
  }
  
  /// Wrap async operations with error handling
  static Future<T?> handleAsync<T>(
    Future<T> Function() operation, {
    String? context,
    bool showErrorToUser = true,
    T? fallbackValue,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      logError(error, stackTrace: stackTrace, context: context);
      
      if (showErrorToUser) {
        showErrorSnackbar(error, context: context);
      }
      
      return fallbackValue;
    }
  }
  
  /// Wrap sync operations with error handling
  static T? handleSync<T>(
    T Function() operation, {
    String? context,
    bool showErrorToUser = true,
    T? fallbackValue,
  }) {
    try {
      return operation();
    } catch (error, stackTrace) {
      logError(error, stackTrace: stackTrace, context: context);
      
      if (showErrorToUser) {
        showErrorSnackbar(error, context: context);
      }
      
      return fallbackValue;
    }
  }
  
  /// Report errors to crash reporting service
  static void _reportToCrashlytics(
    dynamic error,
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? additionalData,
  ) {
    // In production, implement crash reporting
    // Example with Firebase Crashlytics:
    /*
    FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      information: [
        if (context != null) 'Context: $context',
        if (additionalData != null) 'Data: $additionalData',
      ],
    );
    */
  }
  
  /// Show success message
  static void showSuccessSnackbar(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    Get.snackbar(
      'Success',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.primaryColor.withOpacity(0.9),
      colorText: Get.theme.colorScheme.onPrimary,
      duration: duration,
      isDismissible: true,
      animationDuration: const Duration(milliseconds: 300),
    );
  }
  
  /// Show loading indicator with error handling
  static Future<T?> showLoadingWhile<T>(
    Future<T> Function() operation, {
    String loadingMessage = 'Loading...',
    String? context,
  }) async {
    try {
      // Show loading indicator
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );
      
      final result = await operation();
      
      // Hide loading indicator
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      
      return result;
    } catch (error, stackTrace) {
      // Hide loading indicator
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      
      logError(error, stackTrace: stackTrace, context: context);
      showErrorSnackbar(error, context: context);
      
      return null;
    }
  }
}