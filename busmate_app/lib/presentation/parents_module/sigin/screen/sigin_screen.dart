import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'dart:math' as math;
import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:busmate/meta/utils/constant/app_images.dart';
import 'package:busmate/presentation/parents_module/sigin/controller/signin_controller.dart';

class SignInScreen extends GetView<SignInController> {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return Scaffold(
      backgroundColor: Colors.white,
      body: GetBuilder<SignInController>(
        builder: (controller) {
          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    _buildAnimatedBackground(controller),
                    _buildMovingBuses(controller),
                    SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              _buildAnimatedHeader(controller, constraints),
                              Expanded(
                                child: _buildLoginFormSection(controller, constraints),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  // ===== ANIMATED BACKGROUND WITH BUSMATE LOGO =====
  Widget _buildAnimatedBackground(SignInController controller) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.lightblue,
              AppColors.lightblue.withOpacity(0.85),
              AppColors.lightblue.withOpacity(0.7),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // White fabric pattern - Wave lines
            CustomPaint(
              painter: FabricPatternPainter(),
              size: Size.infinite,
            ),
            // Animated circles
            Positioned(
              top: -50,
              left: -50,
              child: ScaleTransition(
                scale: controller.pulseAnimation,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 100,
              right: -30,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.1).animate(
                  CurvedAnimation(
                    parent: controller.pulseController,
                    curve: const Interval(0.3, 0.8),
                  ),
                ),
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Additional decorative circles
            Positioned(
              bottom: 100,
              left: 50,
              child: ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.15).animate(
                  CurvedAnimation(
                    parent: controller.pulseController,
                    curve: const Interval(0.2, 0.7),
                  ),
                ),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== MOVING BUSES ANIMATION =====
  Widget _buildMovingBuses(SignInController controller) {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 50.h,
        child: Stack(
          children: [
            // Bus 1 - Moving left to right
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1.5, 0),
                end: const Offset(1.5, 0),
              ).animate(
                CurvedAnimation(
                  parent: controller.pulseController,
                  curve: Curves.linear,
                ),
              ),
              child: Icon(
                Icons.directions_bus_rounded,
                size: 40.sp,
                color: AppColors.lightblue.withOpacity(0.3),
              ),
            ),
            // Bus 2 - Moving right to left (delayed)
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.8, 0),
                end: const Offset(-1.8, 0),
              ).animate(
                CurvedAnimation(
                  parent: controller.pulseController,
                  curve: const Interval(0.5, 1.0, curve: Curves.linear),
                ),
              ),
              child: Transform.flip(
                flipX: true,
                child: Icon(
                  Icons.directions_bus_rounded,
                  size: 35.sp,
                  color: AppColors.lightblue.withOpacity(0.25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader(SignInController controller, BoxConstraints constraints) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 8.h),
      child: FadeTransition(
        opacity: controller.fadeAnimation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // BusMate Logo
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.5),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: controller.slideController,
                  curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                ),
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                  CurvedAnimation(
                    parent: controller.slideController,
                    curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                  ),
                ),
                child: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    AppImages.jupentaLogoFront,
                    width: 80.w,
                    height: 80.w,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            // BusMate Text
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.5),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: controller.slideController,
                  curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
                ),
              ),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  'BusMate',
                  style: TextStyle(
                    fontSize: 30.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 4.h),
            // Tagline
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.5),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: controller.slideController,
                  curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
                ),
              ),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  'We work for your safety',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: 0.8,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== LOGIN FORM SECTION =====
  Widget _buildLoginFormSection(SignInController controller, BoxConstraints constraints) {
    return SlideTransition(
      position: controller.slideAnimation,
      child: FadeTransition(
        opacity: controller.fadeAnimation,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 400.w,
            ),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
              padding: EdgeInsets.all(2.5.w), // Space for border
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(32.r),
              ),
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 50,
                      offset: const Offset(0, 25),
                      spreadRadius: -5,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Form(
            key: controller.formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Email Field
                _buildAnimatedTextField(
                  controller: controller.txtEmail,
                  validator: (v) => v!.isEmpty ? 'Enter your email' : null,
                  icon: Icons.email_outlined,
                  hintText: 'Enter your email',
                  labelText: 'Email',
                  animationController: controller.slideController,
                  interval: const Interval(0.4, 0.9),
                ),
                SizedBox(height: 12.h),
                // Password Field
                Obx(
                  () => _buildAnimatedTextField(
                    controller: controller.txtPassword,
                    validator: (v) => v!.isEmpty ? 'Enter your password' : null,
                    icon: Icons.lock_outline_rounded,
                    hintText: 'Enter your password',
                    labelText: 'Password',
                    isPassword: !controller.isShowPass.value,
                    animationController: controller.slideController,
                    interval: const Interval(0.5, 1.0),
                    suffixIcon: IconButton(
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          controller.isShowPass.value
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          key: ValueKey(controller.isShowPass.value),
                          color: AppColors.lightblue,
                          size: 22.sp,
                        ),
                      ),
                      onPressed: () => controller.isShowPass.value = !controller.isShowPass.value,
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: controller.slideController,
                      curve: const Interval(0.6, 1.0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        flex: 1,
                        child: Obx(
                          () => Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8.r),
                              onTap: () => controller.isRemeber.value = !controller.isRemeber.value,
                              child: Padding(
                                padding: EdgeInsets.all(4.w),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      width: 22.w,
                                      height: 22.h,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6.r),
                                        border: Border.all(
                                          color: controller.isRemeber.value
                                              ? AppColors.lightblue
                                              : Colors.grey.shade300,
                                          width: 2.0,
                                        ),
                                        color: controller.isRemeber.value
                                            ? AppColors.lightblue
                                            : Colors.white,
                                        boxShadow: [
                                          if (controller.isRemeber.value)
                                            BoxShadow(
                                              color: AppColors.lightblue.withOpacity(0.3),
                                              blurRadius: 8,
                                              spreadRadius: 0,
                                            ),
                                        ],
                                      ),
                                      child: controller.isRemeber.value
                                          ? const Icon(
                                              Icons.check_rounded,
                                              size: 14,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    SizedBox(width: 8.w),
                                    Flexible(
                                      child: Text(
                                        'Remember',
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Flexible(
                        flex: 1,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8.r),
                            onTap: controller.resetPassword,
                            child: Padding(
                              padding: EdgeInsets.all(4.w),
                              child: Text(
                                'Forgot?',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.lightblue,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                // Sign In Button
                Obx(
                  () => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: controller.slideController,
                        curve: const Interval(0.7, 1.0),
                      ),
                    ),
                    child: Container(
                      padding: EdgeInsets.all(2.w), // Space for border
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.3),
                            Colors.white.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        height: 50.h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: controller.isLoading.value
                                ? [Colors.grey.shade400, Colors.grey.shade500]
                                : [
                                    const Color.fromARGB(255, 120, 200, 230), // Darker/thicker lightblue
                                    const Color.fromARGB(255, 100, 185, 220), // Even thicker
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(18.r),
                          boxShadow: [
                            if (!controller.isLoading.value)
                              BoxShadow(
                                color: const Color.fromARGB(255, 120, 200, 230).withOpacity(0.5), // Match thicker lightblue
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                                spreadRadius: -3,
                              ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18.r),
                            onTap: controller.isLoading.value ? null : controller.submitForm,
                            child: Center(
                              child: controller.isLoading.value
                                ? SizedBox(
                                    height: 28.h,
                                    width: 28.h,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      ScaleTransition(
                                        scale: Tween<double>(begin: 1.0, end: 1.2).animate(
                                          CurvedAnimation(
                                            parent: controller.pulseController,
                                            curve: Curves.easeInOut,
                                          ),
                                        ),
                                        child: Container(
                                          padding: EdgeInsets.all(6.w),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Colors.white,
                                            size: 20.sp,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ),
                // Version and Powered by text
                SizedBox(height: 24.h),
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Version 2.3.28',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Powered by Jupenta Technologies',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
              ],
            ),
          ),
        ),
      ),
        ),
        ),
      ),
    );
  }

  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required String? Function(String?)? validator,
    required IconData icon,
    required String hintText,
    required String labelText,
    required AnimationController animationController,
    required Interval interval,
    bool isPassword = false,
    Widget? suffixIcon,
   }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: animationController,
          curve: interval,
        ),
      ),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animationController,
            curve: interval,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 10.w, bottom: 6.h),
              child: Text(
                labelText,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                color: Colors.grey.shade50,
                border: Border.all(
                  color: AppColors.lightblue.withOpacity(0.2),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: AppColors.lightblue.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextFormField(
                controller: controller,
                validator: validator,
                obscureText: isPassword,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 16.h,
                  ),
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(left: 10.w, right: 10.w),
                    child: Icon(
                      icon,
                      color: const Color.fromARGB(255, 120, 200, 230), // Darker version of lightblue
                      size: 24.sp, // Slightly bigger
                    ),
                  ),
                  suffixIcon: suffixIcon,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== CUSTOM PAINTER FOR FABRIC PATTERN =====
class FabricPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final paintLight = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final paintThick = Paint()
      ..color = Colors.white.withOpacity(0.20)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Draw swirly/curly decorative patterns
    for (double y = 50; y < size.height; y += 120) {
      for (double x = 0; x < size.width; x += 150) {
        _drawCurlyPattern(canvas, Offset(x, y), 40, paint);
      }
    }

    // Draw flowing wave lines with curves
    for (double y = 80; y < size.height; y += 100) {
      final path = Path();
      path.moveTo(0, y);
      
      double x = 0;
      while (x < size.width + 100) {
        path.quadraticBezierTo(
          x + 50,
          y + (30 * math.sin(x / 60)),
          x + 100,
          y,
        );
        x += 100;
      }
      canvas.drawPath(path, paint);
    }

    // Draw ornamental spirals
    for (double x = 80; x < size.width; x += 200) {
      for (double y = 100; y < size.height; y += 200) {
        _drawSpiral(canvas, Offset(x, y), 30, paintThick);
      }
    }

    // Draw decorative swirls in corners
    _drawDecorativeSwirl(canvas, const Offset(30, 30), 60, paintThick);
    _drawDecorativeSwirl(canvas, Offset(size.width - 30, 30), 60, paintThick, flipX: true);
    _drawDecorativeSwirl(canvas, Offset(30, size.height - 30), 60, paintThick, flipY: true);
    _drawDecorativeSwirl(canvas, Offset(size.width - 30, size.height - 30), 60, paintThick, flipX: true, flipY: true);

    // Draw flowing fabric curves
    for (double x = 100; x < size.width; x += 180) {
      final path = Path();
      path.moveTo(x, 0);
      
      double y = 0;
      while (y < size.height) {
        path.quadraticBezierTo(
          x + (20 * math.sin(y / 50)),
          y + 40,
          x,
          y + 80,
        );
        y += 80;
      }
      canvas.drawPath(path, paintLight);
    }

    // Draw interlocking circles pattern
    for (double x = 120; x < size.width; x += 160) {
      for (double y = 150; y < size.height; y += 160) {
        canvas.drawCircle(Offset(x, y), 25, paintLight);
        canvas.drawCircle(Offset(x + 40, y), 25, paintLight);
      }
    }
  }

  void _drawCurlyPattern(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx - size, center.dy);
    
    // Create S-curve pattern
    path.quadraticBezierTo(
      center.dx - size / 2,
      center.dy - size,
      center.dx,
      center.dy,
    );
    path.quadraticBezierTo(
      center.dx + size / 2,
      center.dy + size,
      center.dx + size,
      center.dy,
    );
    
    canvas.drawPath(path, paint);
    
    // Mirror pattern
    final path2 = Path();
    path2.moveTo(center.dx - size, center.dy);
    path2.quadraticBezierTo(
      center.dx - size / 2,
      center.dy + size,
      center.dx,
      center.dy,
    );
    path2.quadraticBezierTo(
      center.dx + size / 2,
      center.dy - size,
      center.dx + size,
      center.dy,
    );
    
    canvas.drawPath(path2, paint);
  }

  void _drawSpiral(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    const turns = 2.5;
    const steps = 50;
    
    for (int i = 0; i <= steps; i++) {
      final angle = (i / steps) * turns * 2 * math.pi;
      final r = radius * (i / steps);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
  }

  void _drawDecorativeSwirl(Canvas canvas, Offset center, double size, Paint paint, {bool flipX = false, bool flipY = false}) {
    final dirX = flipX ? -1 : 1;
    final dirY = flipY ? -1 : 1;
    
    final path = Path();
    path.moveTo(center.dx, center.dy);
    
    // Create elegant swirl
    path.quadraticBezierTo(
      center.dx + (size * 0.5 * dirX),
      center.dy + (size * 0.3 * dirY),
      center.dx + (size * dirX),
      center.dy,
    );
    
    path.quadraticBezierTo(
      center.dx + (size * 0.7 * dirX),
      center.dy - (size * 0.5 * dirY),
      center.dx + (size * 0.4 * dirX),
      center.dy - (size * 0.8 * dirY),
    );
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}