import 'package:busmate/meta/firebase_helper/auth_login.dart';
import 'package:busmate/presentation/parents_module/dashboard/controller/dashboard.controller.dart';
import 'package:get/get.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    // Ensure AuthLogin is available for logout
    Get.put(AuthLogin(), permanent: true);
    Get.lazyPut(() => DashboardController());
  }
}
