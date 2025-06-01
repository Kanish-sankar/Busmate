import 'package:busmate/presentation/parents_module/sigin/controller/signin_controller.dart';
import 'package:get/get.dart';


class SigInBinding extends  Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => SigInController());
  }
}