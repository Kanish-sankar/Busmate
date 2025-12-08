part of 'pages.dart';

abstract class Routes {
  Routes._();

  static const splash = _Paths.splash;
  static const roleSelection = _Paths.roleSelection;
  static const sigIn = _Paths.sigIn;
  static const stopLocation = _Paths.stopLocation;
  static const forgotPassword = _Paths.forgotPassword;
  static const stopNotify = _Paths.stopNotify;
  static const dashBoard = _Paths.dashBoard;
  static const driverScreen = _Paths.driverScreen;
}

abstract class _Paths {
  _Paths._();

  static const splash = '/splash';
  static const roleSelection = '/roleSelection';
  static const sigIn = '/signIn';
  static const stopLocation = '/stopLocation';
  static const forgotPassword = '/forgotPassword';
  static const stopNotify = '/stopNotify';
  static const dashBoard = '/dashBoard';
  static const driverScreen = '/driverScreen';
}
