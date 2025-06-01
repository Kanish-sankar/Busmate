import 'package:busmate/presentation/parents_module/forgotpass/controller/forgotpass.controller.dart';
import 'package:get/get.dart';

class ForgotPassBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ForgotPassController());
  }
}
