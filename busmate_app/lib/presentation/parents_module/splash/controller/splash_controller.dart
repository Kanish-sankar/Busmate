import 'package:busmate/meta/nav/pages.dart';
import 'package:busmate/meta/services/app_update_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class SplashController extends GetxController {
  final AppUpdateService _appUpdateService = AppUpdateService();

  @override
  void onInit() {
    super.onInit();
    Future.delayed(
      const Duration(seconds: 3),
      () async {
        final updateDecision = await _appUpdateService.checkForUpdate();
        await _appUpdateService.trackVersionAdoption();

        if (updateDecision.hardUpdateRequired) {
          _showHardUpdateDialog(updateDecision);
          return;
        }

        final nextRoute = _resolveNextRoute();
        Get.offAllNamed(nextRoute);

        if (_appUpdateService.shouldShowSoftPromptNow(
          isSoftUpdateAvailable: updateDecision.softUpdateAvailable,
        )) {
          Future.delayed(const Duration(milliseconds: 700), () {
            if (Get.context != null) {
              _showSoftUpdateDialog(updateDecision);
            }
          });
        }
      },
    );
  }

  String _resolveNextRoute() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      GetStorage().erase();
      return Routes.sigIn;
    }

    final isLoggedInStudent = GetStorage().read('isLoggedInStudent') ?? false;
    final isLoggedInDriver = GetStorage().read('isLoggedInDriver') ?? false;

    if (isLoggedInStudent) {
      return Routes.dashBoard;
    }
    if (isLoggedInDriver) {
      return Routes.driverScreen;
    }
    return Routes.sigIn;
  }

  void _showHardUpdateDialog(AppUpdateDecision decision) {
    Get.dialog(
      PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Update Required'),
          content: Text(decision.message),
          actions: [
            ElevatedButton(
              onPressed: () async {
                await _appUpdateService.openStore(decision);
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _showSoftUpdateDialog(AppUpdateDecision decision) {
    Get.dialog(
      AlertDialog(
        title: const Text('Update Available'),
        content: Text(
          'A newer version is available. Please update within ${decision.graceDays} days for the best experience.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _appUpdateService.openStore(decision);
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }
}
