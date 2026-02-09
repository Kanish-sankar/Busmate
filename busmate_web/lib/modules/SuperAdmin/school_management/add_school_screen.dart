import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:busmate_web/modules/utils/uniqueness_check_controller.dart';

class AddSchoolScreen extends StatefulWidget {
  const AddSchoolScreen({super.key});

  @override
  State<AddSchoolScreen> createState() => _AddSchoolScreenState();
}

class _AddSchoolScreenState extends State<AddSchoolScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // School Details Controllers
  final schoolNameController = TextEditingController();
  final schoolCodeController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  
  // Admin Details Controllers
  final adminNameController = TextEditingController();
  final adminEmailController = TextEditingController();
  final adminPhoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  
  final RxBool isLoading = false.obs;
  final RxBool showPassword = false.obs;
  final RxBool showConfirmPassword = false.obs;

  late final UniquenessCheckController adminEmailCheck;
  late final String _adminEmailCheckTag;

  @override
  void initState() {
    super.initState();

    _adminEmailCheckTag =
        'createSchoolAdminEmail-${DateTime.now().millisecondsSinceEpoch}';
    adminEmailCheck = Get.put(
      UniquenessCheckController(UniquenessCheckType.firebaseAuthEmail),
      tag: _adminEmailCheckTag,
    );

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    Get.delete<UniquenessCheckController>(tag: _adminEmailCheckTag, force: true);
    _animationController.dispose();
    schoolNameController.dispose();
    schoolCodeController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    adminNameController.dispose();
    adminEmailController.dispose();
    adminPhoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (adminEmailCheck.isChecking.value) {
      Get.snackbar(
        'Please wait',
        'Checking email availability...',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    if (adminEmailCheck.isTaken.value) {
      Get.snackbar(
        'Duplicate Email',
        'This admin email already exists',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: const Icon(Icons.error, color: Colors.white),
      );
      return;
    }
    
    // Check if passwords match
    if (passwordController.text != confirmPasswordController.text) {
      Get.snackbar(
        'Error',
        'Passwords do not match!',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: const Icon(Icons.error, color: Colors.white),
      );
      return;
    }
    
    isLoading.value = true;
    
    try {
      // Store current super admin credentials to re-login later
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in to create a school');
      }
      
      // Generate unique school ID
      final schoolId = 'SCH${DateTime.now().millisecondsSinceEpoch}';
      final newAdminEmail = adminEmailController.text.trim();
      final newAdminPassword = passwordController.text;

      // Guard: prevent creation if email already exists in Firebase Auth.
      final methods = await FirebaseAuth.instance
          .fetchSignInMethodsForEmail(newAdminEmail);
      if (methods.isNotEmpty) {
        throw Exception('Admin email already exists: $newAdminEmail');
      }
      
      // 1. Create school document in schooldetails collection
      await FirebaseFirestore.instance.collection('schooldetails').doc(schoolId).set({
        'schoolId': schoolId,
        'schoolName': schoolNameController.text.trim(),
        'schoolCode': schoolCodeController.text.trim().toUpperCase(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'totalBuses': 0,
        'totalStudents': 0,
        'totalDrivers': 0,
        'totalRoutes': 0,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // 2. Create a temporary auth instance for the new admin
      // This prevents logging out the current super admin
      final secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp-${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      
      try {
        // Create admin user in Firebase Auth using secondary instance
        final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
        final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
          email: newAdminEmail,
          password: newAdminPassword,
        );
        
        final newAdminUid = userCredential.user!.uid;
        
        // 3. Create admin document in admins collection
        await FirebaseFirestore.instance.collection('admins').doc(newAdminUid).set({
          'adminId': newAdminUid,
          'schoolId': schoolId,
          'name': adminNameController.text.trim(),
          'email': newAdminEmail,
          'phone': adminPhoneController.text.trim(),
          'role': 'school_admin',
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Sign out from secondary instance
        await secondaryAuth.signOut();
      } finally {
        // Delete the secondary app
        await secondaryApp.delete();
      }
      
      isLoading.value = false;
      
      // Show success dialog
      _showSuccessDialog();
      
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: const Icon(Icons.error, color: Colors.white),
        duration: const Duration(seconds: 4),
      );
    }
  }

  void _showSuccessDialog() {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(40),
          constraints: const BoxConstraints(maxWidth: 550),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [Colors.green[50]!, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 600),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 56),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              const Text(
                'School Created Successfully!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'The school and admin account have been created.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue[200]!, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 Admin Login Credentials:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCredentialRow('School', schoolNameController.text),
                    const Divider(height: 24),
                    _buildCredentialRow('School Code', schoolCodeController.text.toUpperCase()),
                    const Divider(height: 24),
                    _buildCredentialRow('Admin Email', adminEmailController.text),
                    const Divider(height: 24),
                    _buildCredentialRow('Password', passwordController.text),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Get.back(); // Close dialog
                        // Clear form
                        schoolNameController.clear();
                        schoolCodeController.clear();
                        emailController.clear();
                        phoneController.clear();
                        addressController.clear();
                        adminNameController.clear();
                        adminEmailController.clear();
                        adminPhoneController.clear();
                        passwordController.clear();
                        confirmPasswordController.clear();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Another'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: const BorderSide(color: Colors.blue, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Get.back(); // Close dialog
                        Get.back(); // Go back to schools list
                      },
                      icon: const Icon(Icons.done_all),
                      label: const Text('Done'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Add New School',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isMobile ? 18 : 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Stack(
            children: [
              // Animated background decorations - hide on mobile
              if (!isMobile) ...[
                Positioned(
                  top: -150,
                  right: -150,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.blue.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -100,
                  left: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.green.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              
              // Main content
              SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 24 : 32)),
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 1000),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // School Details Card
                          _buildSchoolDetailsCard(isMobile, isTablet),
                          
                          SizedBox(height: isMobile ? 20 : 32),
                          
                          // Admin Details Card
                          _buildAdminDetailsCard(isMobile, isTablet),
                          
                          SizedBox(height: isMobile ? 24 : 40),
                          
                          // Action buttons
                          _buildActionButtons(isMobile),
                          
                          SizedBox(height: isMobile ? 20 : 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolDetailsCard(bool isMobile, bool isTablet) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 600),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: EdgeInsets.all(isMobile ? 20 : (isTablet ? 28 : 36)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.08),
              blurRadius: isMobile ? 15 : 30,
              offset: const Offset(0, 10),
              spreadRadius: isMobile ? 2 : 5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 10 : 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[400]!, Colors.blue[600]!],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.school,
                    color: Colors.white,
                    size: isMobile ? 24 : 32,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'School Information',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : (isTablet ? 22 : 26),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Enter the school details',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 20 : 32),
            
            isMobile || isTablet
                ? Column(
                    children: [
                      _buildTextField(
                        controller: schoolNameController,
                        label: 'School Name *',
                        hint: 'e.g., St. Mary\'s High School',
                        icon: Icons.apartment,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter school name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: schoolCodeController,
                        label: 'School Code *',
                        hint: 'e.g., SMHS001',
                        icon: Icons.qr_code_2,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter school code';
                          }
                          return null;
                        },
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: schoolNameController,
                          label: 'School Name *',
                          hint: 'e.g., St. Mary\'s High School',
                          icon: Icons.apartment,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter school name';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildTextField(
                          controller: schoolCodeController,
                          label: 'School Code *',
                          hint: 'e.g., SMHS001',
                          icon: Icons.qr_code_2,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter school code';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
            
            SizedBox(height: isMobile ? 16 : 24),
            
            isMobile || isTablet
                ? Column(
                    children: [
                      _buildTextField(
                        controller: emailController,
                        label: 'School Email *',
                        hint: 'school@example.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter email';
                          }
                          if (!GetUtils.isEmail(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: phoneController,
                        label: 'Phone Number *',
                        hint: '+1 (234) 567-8900',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter phone number';
                          }
                          return null;
                        },
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: emailController,
                          label: 'School Email *',
                          hint: 'school@example.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter email';
                            }
                            if (!GetUtils.isEmail(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildTextField(
                          controller: phoneController,
                          label: 'Phone Number *',
                          hint: '+1 (234) 567-8900',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter phone number';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
            
            SizedBox(height: isMobile ? 16 : 24),
            
            _buildTextField(
              controller: addressController,
              label: 'Complete Address *',
              hint: 'Street, City, State, ZIP Code',
              icon: Icons.location_on_outlined,
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter address';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminDetailsCard(bool isMobile, bool isTablet) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 800),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: EdgeInsets.all(isMobile ? 20 : (isTablet ? 28 : 36)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.08),
              blurRadius: isMobile ? 15 : 30,
              offset: const Offset(0, 10),
              spreadRadius: isMobile ? 2 : 5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 10 : 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[400]!, Colors.green[600]!],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: isMobile ? 24 : 32,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'School Admin Account',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : (isTablet ? 22 : 26),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Create admin credentials for this school',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 20 : 32),
            
            _buildTextField(
              controller: adminNameController,
              label: 'Admin Full Name *',
              hint: 'e.g., John Doe',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter admin name';
                }
                return null;
              },
            ),
            
            SizedBox(height: isMobile ? 16 : 24),
            
            isMobile || isTablet
                ? Column(
                    children: [
                      Obx(() => _buildTextField(
                            controller: adminEmailController,
                            label: 'Admin Email *',
                            hint: 'admin@example.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (v) => adminEmailCheck.onValueChanged(v),
                            suffixIcon: adminEmailCheck.isChecking.value
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : adminEmailCheck.isTaken.value
                                    ? const Icon(Icons.error, color: Colors.red)
                                    : (!adminEmailCheck.isChecking.value && adminEmailController.text.isNotEmpty)
                                        ? const Icon(Icons.check_circle, color: Colors.green)
                                        : null,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter admin email';
                              }
                              if (!GetUtils.isEmail(value)) {
                                return 'Please enter a valid email';
                              }
                              if (adminEmailCheck.isTaken.value) {
                                return 'This email is already taken';
                              }
                              return null;
                            },
                          )),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: adminPhoneController,
                        label: 'Admin Phone *',
                        hint: '+1 (234) 567-8900',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter admin phone';
                          }
                          return null;
                        },
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Obx(() => _buildTextField(
                              controller: adminEmailController,
                              label: 'Admin Email *',
                              hint: 'admin@example.com',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              onChanged: (v) => adminEmailCheck.onValueChanged(v),
                              suffixIcon: adminEmailCheck.isChecking.value
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : adminEmailCheck.isTaken.value
                                      ? const Icon(Icons.error, color: Colors.red)
                                      : (!adminEmailCheck.isChecking.value && adminEmailController.text.isNotEmpty)
                                          ? const Icon(Icons.check_circle, color: Colors.green)
                                          : null,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter admin email';
                                }
                                if (!GetUtils.isEmail(value)) {
                                  return 'Please enter a valid email';
                                }
                                if (adminEmailCheck.isTaken.value) {
                                  return 'Email already exists';
                                }
                                return null;
                              },
                            )),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildTextField(
                          controller: adminPhoneController,
                          label: 'Admin Phone *',
                          hint: '+1 (234) 567-8900',
                          icon: Icons.phone_android_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter phone number';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
            
            SizedBox(height: isMobile ? 16 : 24),
            
            isMobile || isTablet
                ? Column(
                    children: [
                      Obx(() => _buildTextField(
                            controller: passwordController,
                            label: 'Password *',
                            hint: 'Enter strong password',
                            icon: Icons.lock_outline,
                            obscureText: !showPassword.value,
                            suffixIcon: IconButton(
                              icon: Icon(
                                showPassword.value ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey[600],
                              ),
                              onPressed: () => showPassword.value = !showPassword.value,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          )),
                      const SizedBox(height: 20),
                      Obx(() => _buildTextField(
                            controller: confirmPasswordController,
                            label: 'Confirm Password *',
                            hint: 'Re-enter password',
                            icon: Icons.lock_outline,
                            obscureText: !showConfirmPassword.value,
                            suffixIcon: IconButton(
                              icon: Icon(
                                showConfirmPassword.value ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey[600],
                              ),
                              onPressed: () =>
                                  showConfirmPassword.value = !showConfirmPassword.value,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm password';
                              }
                              if (value != passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          )),
                    ],
                  )
                : Row(
                    children: [
                Expanded(
                  child: Obx(() => _buildTextField(
                    controller: passwordController,
                    label: 'Password *',
                    hint: 'Enter strong password',
                    icon: Icons.lock_outline,
                    obscureText: !showPassword.value,
                    suffixIcon: IconButton(
                      icon: Icon(
                        showPassword.value ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey[600],
                      ),
                      onPressed: () => showPassword.value = !showPassword.value,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  )),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Obx(() => _buildTextField(
                    controller: confirmPasswordController,
                    label: 'Confirm Password *',
                    hint: 'Re-enter password',
                    icon: Icons.lock_outline,
                    obscureText: !showConfirmPassword.value,
                    suffixIcon: IconButton(
                      icon: Icon(
                        showConfirmPassword.value ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey[600],
                      ),
                      onPressed: () => showConfirmPassword.value = !showConfirmPassword.value,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm password';
                      }
                      if (value != passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  )),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange[200]!, width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Make sure to save these credentials! The admin will need them to login.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange[900],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    int maxLines = 1,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
    String? errorText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          validator: validator,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(icon, color: Colors.grey[600], size: 22),
            suffixIcon: suffixIcon,
            errorText: errorText,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isMobile) {
    return isMobile
        ? Column(
            children: [
              Obx(() => ElevatedButton.icon(
                    onPressed: isLoading.value ? null : _submitForm,
                    icon: isLoading.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.add_circle, size: 22),
                    label: Text(
                      isLoading.value ? 'Creating School...' : 'Create School & Admin Account',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                      shadowColor: Colors.blue.withOpacity(0.3),
                    ),
                  )),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.cancel_outlined, size: 20),
                label: const Text('Cancel', style: TextStyle(fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(color: Colors.grey[400]!, width: 2),
                ),
              ),
            ],
          )
        : Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.cancel_outlined, size: 22),
                  label: const Text('Cancel', style: TextStyle(fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: Colors.grey[400]!, width: 2),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: Obx(() => ElevatedButton.icon(
                      onPressed: isLoading.value ? null : _submitForm,
                      icon: isLoading.value
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.add_circle, size: 24),
                      label: Text(
                        isLoading.value ? 'Creating School...' : 'Create School & Admin Account',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                        shadowColor: Colors.blue.withOpacity(0.3),
                      ),
                    )),
              ),
            ],
          );
  }
}
