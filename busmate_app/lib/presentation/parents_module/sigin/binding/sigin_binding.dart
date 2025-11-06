import 'package:busmate/meta/firebase_helper/auth_login.dart';
import 'package:busmate/presentation/parents_module/sigin/controller/signin_controller.dart';
import 'package:get/get.dart';

class SigInBinding extends Bindings {
  @override
  void dependencies() {
    // Make AuthLogin permanent so it's available everywhere (for logout, etc.)
    Get.put(AuthLogin(), permanent: true);
    Get.lazyPut(() => SignInController());
  }
}