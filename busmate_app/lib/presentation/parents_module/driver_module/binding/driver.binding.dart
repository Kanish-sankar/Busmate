import 'package:busmate/presentation/parents_module/driver_module/controller/driver.controller.dart';
import 'package:get/get.dart';

class DriverBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => DriverController());
  }
}
