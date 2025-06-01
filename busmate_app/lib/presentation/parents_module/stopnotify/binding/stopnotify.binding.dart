import 'package:busmate/presentation/parents_module/stopnotify/controller/stopnotify.controller.dart';
import 'package:get/get.dart';

class StopNotifyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => StopNotifyController());
  }
}
