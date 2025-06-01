import 'package:busmate/meta/nav/pages.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class SplashController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    bool isLoggedIn = GetStorage().read('isLoggedIn') ?? false;
    bool isLoggedInStudent = GetStorage().read('isLoggedInStudent') ?? false;
    bool isLoggedInDriver = GetStorage().read('isLoggedInDriver') ?? false;
    Future.delayed(
      const Duration(seconds: 3),
      () {
        if (isLoggedIn) {
          if (isLoggedInStudent) {
            Get.offAllNamed(Routes.dashBoard);
          } else if (isLoggedInDriver) {
            Get.offAllNamed(Routes.driverScreen);
          } else {
            Get.offAllNamed(Routes.sigIn);
          }
        } else {
          Get.offAllNamed(Routes.sigIn);
        }
      },
    );
  }
}
