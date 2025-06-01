import 'package:busmate/presentation/parents_module/dashboard/binding/dashboard.binding.dart';
import 'package:busmate/presentation/parents_module/dashboard/screens/dashboard_screen.dart';
import 'package:busmate/presentation/parents_module/driver_module/binding/driver.binding.dart';
import 'package:busmate/presentation/parents_module/driver_module/screen/driver_screen.dart';
import 'package:busmate/presentation/parents_module/forgotpass/binding/forgot_binding.dart';
import 'package:busmate/presentation/parents_module/forgotpass/screen/forgot_pass.dart';
import 'package:busmate/presentation/parents_module/sigin/binding/sigin_binding.dart';
import 'package:busmate/presentation/parents_module/sigin/screen/sigin_screen.dart';
import 'package:busmate/presentation/parents_module/splash/binding/splash_binding.dart';
import 'package:busmate/presentation/parents_module/splash/screen/splash_screen.dart';
import 'package:busmate/presentation/parents_module/stoplocation/binding/stoplocation.binding.dart';
import 'package:busmate/presentation/parents_module/stoplocation/screen/stop_location_screen.dart';
import 'package:busmate/presentation/parents_module/stopnotify/binding/stopnotify.binding.dart';
import 'package:busmate/presentation/parents_module/stopnotify/screen/stop_notify_screen.dart';
import 'package:get/get.dart';

part 'routes.dart';

class AppPages {
  AppPages._();

  static const initial = Routes.splash;

  static final routes = [
    GetPage(
      name: Routes.splash,
      page: () => const SplashScreen(),
      binding: SplashBindings(),
    ),
    GetPage(
      name: Routes.sigIn,
      page: () => const SignInScreen(),
      binding: SigInBinding(),
    ),
    GetPage(
      name: Routes.stopLocation,
      page: () => const StopLocation(),
      binding: StoplocationBinding(),
    ),
    GetPage(
      name: Routes.forgotPassword,
      page: () => const ForgotPass(),
      binding: ForgotPassBinding(),
    ),
    GetPage(
      name: Routes.stopNotify,
      page: () => const StopNotifyScreen(),
      binding: StopNotifyBinding(),
    ),
    GetPage(
      name: Routes.dashBoard,
      page: () => const DashboardScreen(),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: Routes.driverScreen,
      page: () => const DriverScreen(),
      binding: DriverBinding(),
    ),
  ];
}
