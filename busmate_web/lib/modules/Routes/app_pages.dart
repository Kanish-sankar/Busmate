import 'package:busmate_web/modules/Authentication/auth_controller.dart';
import 'package:busmate_web/modules/Authentication/auth_middleware.dart';
import 'package:busmate_web/modules/Authentication/login_screen.dart';
import 'package:busmate_web/modules/Authentication/register_screen.dart';
import 'package:busmate_web/modules/Authentication/reset_password.dart';
import 'package:busmate_web/modules/SchoolAdmin/dashboard/dashboard_screen.dart';
import 'package:busmate_web/modules/SuperAdmin/dashboard/dashboard_screen.dart';
import 'package:busmate_web/modules/splash/splash_screen.dart';
import 'package:get/get.dart';

class AppPages {
  // ignore: constant_identifier_names
  static const INITIAL = Routes.SPLASH;

  static final routes = [
    GetPage(
      name: Routes.SPLASH,
      page: () => SplashScreen(),
    ),
    GetPage(
      name: Routes.LOGIN,
      page: () => LoginScreen(),
    ),
    GetPage(
      name: Routes.RESET_PASSWORD,
      page: () => ResetPasswordScreen(),
    ),
    GetPage(
      name: Routes.REGISTER,
      page: () => RegisterScreen(),
    ),
    GetPage(
      name: Routes.SUPER_ADMIN_DASHBOARD,
      page: () => SuperAdminDashboard(),
      middlewares: [
        AuthMiddleware(requiredRole: UserRole.superAdmin),
      ],
    ),
    GetPage(
      name: Routes.SCHOOL_ADMIN_DASHBOARD,
      page: () => SchoolAdminDashboard(),
      middlewares: [
        AuthMiddleware(requiredRole: UserRole.schoolAdmin),
      ],
    ),
  ];
}

class Routes {
  // ignore: constant_identifier_names
  static const SPLASH = '/splash';
  // ignore: constant_identifier_names
  static const LOGIN = '/login';
  // ignore: constant_identifier_names
  static const REGISTER = '/register';
  // ignore: constant_identifier_names
  static const RESET_PASSWORD = '/reset-password';
  // ignore: constant_identifier_names
  static const SUPER_ADMIN_DASHBOARD = '/super-admin-dashboard';
  // ignore: constant_identifier_names
  static const SCHOOL_ADMIN_DASHBOARD = '/school-admin-dashboard';
}
