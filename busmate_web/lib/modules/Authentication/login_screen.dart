import 'package:busmate_web/modules/Authentication/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoginScreen extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthController authController = Get.find<AuthController>();

  LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 1000;
    
    return Scaffold(
      body: Container(
        width: screenWidth,
        height: screenHeight,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF5F7FA),
              Color(0xFFE8EEF5),
              Color(0xFFD6E4F5),
            ],
          ),
        ),
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isMobile ? screenWidth * 0.95 : 1200,
              maxHeight: isMobile ? screenHeight * 0.95 : 700,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: isMobile 
                ? _buildMobileLayout(context)
                : _buildDesktopLayout(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: _buildLeftPanel(),
        ),
        Expanded(
          flex: 5,
          child: _buildRightPanel(context),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildMobileHeader(),
          Padding(
            padding: const EdgeInsets.all(32),
            child: _buildLoginFormContent(context),
          ),
        ],
      ),
    );
  }

  // LEFT PANEL - Branding & Design
  Widget _buildLeftPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0D47A1), // Darker blue
            Color(0xFF1565C0),
            Color(0xFF1976D2),
            Color(0xFF1E88E5), // Lighter blue
          ],
        ),
      ),
      child: Stack(
        children: [
          // Animated background pattern
          Positioned.fill(
            child: CustomPaint(
              painter: _ModernBackgroundPainter(),
            ),
          ),
          
          // Animated floating elements
          const Positioned.fill(
            child: _FloatingElements(),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // BusMate Logo with animation
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 1200),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Image.network(
                    'https://raw.githubusercontent.com/codeashion/jupenta-busmate/main/busmate_app/assets/images/BUSMATE.FRONT.png',
                    width: 350,
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.directions_bus_rounded,
                            size: 60,
                            color: Colors.white,
                          ),
                          SizedBox(width: 16),
                          Text(
                            'BusMate',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Animated tagline
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 1500),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    'Smart School Bus\nTracking & Management',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.4,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 50),
                
                // Animated features
                ..._buildAnimatedFeatures(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAnimatedFeatures() {
    final features = [
      {'icon': Icons.location_on_rounded, 'text': 'Real-time GPS Tracking'},
      {'icon': Icons.notifications_active_rounded, 'text': 'Instant Notifications'},
      {'icon': Icons.verified_user_rounded, 'text': 'Safe & Secure'},
      {'icon': Icons.analytics_rounded, 'text': 'Advanced Analytics'},
    ];

    return List.generate(features.length, (index) {
      return TweenAnimationBuilder(
        duration: Duration(milliseconds: 800 + (index * 200)),
        tween: Tween<double>(begin: 0, end: 1),
        builder: (context, double value, child) {
          return Transform.translate(
            offset: Offset(-30 * (1 - value), 0),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildFeature(
            features[index]['icon'] as IconData,
            features[index]['text'] as String,
          ),
        ),
      );
    });
  }

  Widget _buildFeature(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  // RIGHT PANEL - Login Form
  Widget _buildRightPanel(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
          child: _buildLoginFormContent(context),
        ),
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0D47A1),
            Color(0xFF1565C0),
            Color(0xFF1E88E5),
          ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // BusMate Logo only
          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 1000),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: Image.network(
              'https://raw.githubusercontent.com/codeashion/jupenta-busmate/main/busmate_app/assets/images/BUSMATE.FRONT.png',
              width: 200,
              height: 70,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_bus_rounded, color: Colors.white, size: 40),
                    SizedBox(width: 12),
                    Text(
                      'BusMate',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginFormContent(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Welcome Text
          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 800),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: const Text(
              'Welcome Back!',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1565C0),
                height: 1.2,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 1000),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Opacity(
                opacity: value,
                child: child,
              );
            },
            child: Text(
              'Log in to access the admin dashboard',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black.withOpacity(0.6),
                height: 1.4,
              ),
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Animated Email Field
          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 1200),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Transform.translate(
                offset: Offset(-30 * (1 - value), 0),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email Address',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 8),
                _buildModernTextField(
                  controller: emailController,
                  hintText: 'Enter your email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Animated Password Field
          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 1400),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Transform.translate(
                offset: Offset(-30 * (1 - value), 0),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 8),
                _buildModernTextField(
                  controller: passwordController,
                  hintText: 'Enter your password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 35),
          
          // Animated Login Button
          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 1600),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: Obx(() => SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: authController.isLoading.value
                    ? null
                    : () async {
                        if (emailController.text.isEmpty ||
                            passwordController.text.isEmpty) {
                          Get.snackbar(
                            'Error',
                            'Please enter email and password',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.red[50],
                            colorText: Colors.red[900],
                            margin: const EdgeInsets.all(16),
                            borderRadius: 12,
                          );
                          return;
                        }
                        await authController.login(
                          emailController.text.trim(),
                          passwordController.text,
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ).copyWith(
                  elevation: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return 8;
                    }
                    return 0;
                  }),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return const Color(0xFF1976D2);
                    }
                    if (states.contains(WidgetState.disabled)) {
                      return Colors.grey[300];
                    }
                    return const Color(0xFF1565C0);
                  }),
                ),
                child: authController.isLoading.value
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Log In',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            )),
          ),
          
          const SizedBox(height: 20),
          
          // Quick Login Buttons for Development
          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 1700),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Opacity(
                opacity: value,
                child: child,
              );
            },
            child: Column(
              children: [
                // Divider with text
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Quick Login (Dev)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Super Admin Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: authController.isLoading.value
                        ? null
                        : () async {
                            emailController.text = 'kanishadmin@gmail.com';
                            passwordController.text = '123456';
                            await authController.login(
                              'kanishadmin@gmail.com',
                              '123456',
                            );
                          },
                    icon: const Icon(Icons.admin_panel_settings, size: 20),
                    label: const Text(
                      'Login as Super Admin',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1565C0),
                      side: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // School Admin Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: authController.isLoading.value
                        ? null
                        : () async {
                            emailController.text = 'school@gmail.com';
                            passwordController.text = '123456';
                            await authController.login(
                              'school@gmail.com',
                              '123456',
                            );
                          },
                    icon: const Icon(Icons.school, size: 20),
                    label: const Text(
                      'Login as School Admin',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                      side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Animated Footer
          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 1800),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Opacity(
                opacity: value,
                child: child,
              );
            },
            child: Center(
              child: Column(
                children: [
                  Text(
                    'Powered by',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Jupenta Technologies',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF1565C0), size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}

// Modern Background Painter with geometric patterns
class _ModernBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withOpacity(0.08);

    // Draw geometric patterns
    for (int i = 0; i < 5; i++) {
      final radius = size.width * (0.3 + i * 0.15);
      canvas.drawCircle(
        Offset(size.width * 0.2, size.height * 0.3),
        radius,
        paint,
      );
    }

    // Draw lines
    for (int i = 0; i < 8; i++) {
      final y = size.height * (i / 8);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width * 0.3, y + 50),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Floating animated elements for background
class _FloatingElements extends StatefulWidget {
  const _FloatingElements();

  @override
  State<_FloatingElements> createState() => _FloatingElementsState();
}

class _FloatingElementsState extends State<_FloatingElements>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<Offset>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      6,
      (index) => AnimationController(
        duration: Duration(milliseconds: 3000 + (index * 500)),
        vsync: this,
      )..repeat(reverse: true),
    );

    _animations = _controllers.asMap().entries.map((entry) {
      return Tween<Offset>(
        begin: Offset(
          (entry.key % 3) * 0.3,
          (entry.key % 2) * 0.5,
        ),
        end: Offset(
          (entry.key % 3) * 0.3 + 0.1,
          (entry.key % 2) * 0.5 + 0.3,
        ),
      ).animate(CurvedAnimation(
        parent: entry.value,
        curve: Curves.easeInOut,
      ));
    }).toList();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(6, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Positioned(
              left: MediaQuery.of(context).size.width * _animations[index].value.dx,
              top: MediaQuery.of(context).size.height * _animations[index].value.dy,
              child: Container(
                width: 80 + (index * 20).toDouble(),
                height: 80 + (index * 20).toDouble(),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0.01),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}


