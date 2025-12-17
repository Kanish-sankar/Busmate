import 'package:busmate/meta/nav/pages.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class SplashController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    Future.delayed(
      const Duration(seconds: 3),
      () async {
        // Check if Firebase Auth user exists (not just cached login state)
        final currentUser = FirebaseAuth.instance.currentUser;
        
        if (currentUser == null) {
          // No Firebase user - clear any stale cached data and go to login
          GetStorage().erase();
          Get.offAllNamed(Routes.sigIn);
          return;
        }
        
        // User exists in Firebase Auth, check cached role
        bool isLoggedInStudent = GetStorage().read('isLoggedInStudent') ?? false;
        bool isLoggedInDriver = GetStorage().read('isLoggedInDriver') ?? false;
        
        if (isLoggedInStudent) {
          Get.offAllNamed(Routes.dashBoard);
        } else if (isLoggedInDriver) {
          Get.offAllNamed(Routes.driverScreen);
        } else {
          // Logged in but no role - go to login to re-authenticate
          Get.offAllNamed(Routes.sigIn);
        }
      },
    );
  }
}
