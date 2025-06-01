// File: lib/modules/SuperAdmin/school_management/add_school_screen.dart
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

class AddSchoolScreen extends StatelessWidget {
  AddSchoolScreen({super.key});

  // Controllers for input fields
  final TextEditingController schoolNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  // Using an RxString for reactive dropdown value
  final RxString selectedPackageType = "With Attendance".obs;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final RxMap<String, bool> _allpermissions = {
    "busManagement": true,
    "driverManagement": true,
    "routeManagement": true,
    "viewingBusStatus": true,
    "studentManagement": true,
    "paymentManagement": true,
    "notifications": true,
    "adminManagement": true,
  }.obs;

  /// Generates an 8-character random alphanumeric password.
  String generatePassword(int length) {
    const chars =
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  /// Sends a custom email using the Cloud Function.
  Future<void> sendCustomEmail({
    required String email,
    required String subject,
    required String body,
  }) async {
    final url =
        Uri.parse('https://sendcredentialemail-gnxzq4evda-uc.a.run.app');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'subject': subject,
          'body': body,
        }),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) print('✅ Email sent successfully.');
      } else {
        if (kDebugMode)
          print('❌ Failed to send email. Response: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error sending email: $e');
    }
  }

  /// Adds the school to Firebase and sends a welcome email.
  void addSchool() async {
    String schoolName = schoolNameController.text.trim();
    String email = emailController.text.trim();
    String phone = phoneNumberController.text.trim();
    String address = addressController.text.trim();
    String packageType = selectedPackageType.value;

    if (schoolName.isEmpty || email.isEmpty) {
      Get.snackbar("Error", "School name and email are required");
      return;
    }

    // Generate a random temporary password.
    String password = generatePassword(8);

    // Build the email subject and body.
    String subject =
        "Welcome to BusMate – Your School Manager Portal is Ready!";

    String emailContent = """
Dear $schoolName Team,

We are delighted to welcome you to BusMate, your smart school bus tracking solution! Your school has been successfully onboarded, and you can now manage transportation operations effortlessly.

Login Instructions:
1️. Visit the School Manager Portal: https://busmate-b80e8.firebaseapp.com
2️. Enter your login credentials:
   • Login ID: $email
   • Password: $password
3️. You will receive a One-Time Password (OTP) on your registered email.
4️. Enter the OTP to verify and log in successfully.

For any assistance, our support team is here to help! Contact us at jupentaindia@gmail.com or call +918610078332.

Thank you for choosing BusMate. We look forward to making school transport management smoother and smarter for you!

Best Regards,
Kanish SS
Jupenta Technologies
jupentaindia@gmail.com | +918610078332
""";

    try {
      // First, generate a temporary UID for the school (for schoolId).
      // We'll use Firestore's auto-ID generation for consistency.
      DocumentReference tempDocRef = firestore.collection('schools').doc();
      String schoolUid = tempDocRef.id;

      // Call the Firebase Function to create the user, including schoolId.
      final response = await http
          .post(
            Uri.parse("https://createschooluser-gnxzq4evda-uc.a.run.app"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "email": email,
              "password": password,
              "role": "schoolAdmin",
              "schoolId": schoolUid, // Add this field
              "permissions": _allpermissions,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception("Failed to create user: ${response.body}");
      }

      // Parse the response to get the UID (should match schoolUid).
      final responseData = jsonDecode(response.body);
      // Use the UID returned by backend if needed, else keep schoolUid.
      String backendUid = responseData["uid"] ?? schoolUid;

      // Save school details in Firestore.
      await firestore.collection('schools').doc(backendUid).set({
        'school_id': backendUid,
        'school_name': schoolName,
        'email': email,
        'phone_number': phone,
        'address': address,
        'package_type': packageType,
        'password': password,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'uid': backendUid,
      });

      // Send the welcome email after adding the school.
      await sendCustomEmail(
        email: email,
        subject: subject,
        body: emailContent,
      );

      Get.snackbar("Success", "School added successfully");
    } catch (e) {
      Get.snackbar("Error", "Failed to add school: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add School")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ListView(
              shrinkWrap: true,
              children: [
                TextField(
                  controller: schoolNameController,
                  decoration: const InputDecoration(
                    labelText: "School Name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: phoneNumberController,
                  decoration: const InputDecoration(
                    labelText: "Phone Number",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: "Address",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                Obx(() => DropdownButtonFormField<String>(
                      value: selectedPackageType.value,
                      items: ["With Attendance", "Without Attendance"]
                          .map((package) => DropdownMenuItem<String>(
                                value: package,
                                child: Text(package),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          selectedPackageType.value = val;
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: "Package Type",
                        border: OutlineInputBorder(),
                      ),
                    )),
                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: addSchool,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text("Add School"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
