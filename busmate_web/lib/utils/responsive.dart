import 'package:flutter/material.dart';

class Responsive extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const Responsive({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 768;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 768 &&
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    if (size.width >= 1200) {
      return desktop;
    } else if (size.width >= 768 && tablet != null) {
      return tablet!;
    } else {
      return mobile;
    }
  }
}

class ResponsiveLayout {
  static double getHorizontalPadding(BuildContext context) {
    if (Responsive.isMobile(context)) return 16;
    if (Responsive.isTablet(context)) return 24;
    return 32;
  }

  static double getVerticalSpacing(BuildContext context) {
    if (Responsive.isMobile(context)) return 16;
    if (Responsive.isTablet(context)) return 24;
    return 32;
  }

  static int getGridCrossAxisCount(BuildContext context, {int desktop = 3, int tablet = 2, int mobile = 1}) {
    if (Responsive.isDesktop(context)) return desktop;
    if (Responsive.isTablet(context)) return tablet;
    return mobile;
  }

  static double getFontSize(BuildContext context, {required double desktop, double? tablet, double? mobile}) {
    if (Responsive.isDesktop(context)) return desktop;
    if (Responsive.isTablet(context)) return tablet ?? desktop * 0.9;
    return mobile ?? desktop * 0.8;
  }
}
