import 'package:busmate/presentation/parents_module/stoplocation/controller/stoplocation.controller.dart';
import 'package:get/get.dart';

class StoplocationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => StoplocationController());
  }
}
