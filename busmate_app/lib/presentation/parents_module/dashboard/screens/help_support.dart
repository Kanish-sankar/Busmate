import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:busmate/meta/utils/constant/app_images.dart';
import 'package:busmate/presentation/parents_module/dashboard/widgets/info_box.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:easy_url_launcher/easy_url_launcher.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

void openWhatsApp(String question, String phone) async {
  String message = question;
  try {
    await EasyLauncher.sendToWhatsApp(phone: phone, message: message);
  } catch (e) {
    Get.snackbar("Error", "Could not open WhatsApp");
  }
}

// Function to open social media pages
void openSocialMedia(Uri url) async {
  try {
    await EasyLauncher.url(url: url.toString());
  } catch (e) {
    Get.snackbar("Error", "Could not open link");
  }
}

// Function to start a conversation (Redirect to Owner’s Page)
void startConversation(String phone) async {
  try {
    await EasyLauncher.sendToWhatsApp(phone: phone, message: "");
  } catch (e) {
    Get.snackbar("Error", "Could not start conversation");
  }
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  List<String> faqQuestions = [];
  String instagramPageLink = '';
  String twitterPageLink = '';
  String whatsapp = '';
  String email = '';

  @override
  void initState() {
    fetchData();
    super.initState();
  }

  Future<void> fetchData() async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      DocumentSnapshot snapshot = await firestore
          .collection(
              'basicDetails') // Change 'users' to the actual collection name
          .doc('admin') // Use the email as the document ID
          .get();

      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          faqQuestions = List<String>.from(data['faqQuestion'] ?? []);
          instagramPageLink = data['instagramPageLink'] ?? '';
          twitterPageLink = data['twitterPageLink'] ?? '';
          whatsapp = data['whatsapp'] ?? '';
          email = data['email'] ?? '';
        });
      } else {
        print("No data found for this email.");
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, String> socialLinks = {
      "whatsapp": "tel:$whatsapp",
      "email": "mailto:$email",
      "instagram": instagramPageLink,
      "twitter": twitterPageLink
    };

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(
            20.w,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Section
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 15.w, vertical: 7.h),
                  decoration: BoxDecoration(
                    color: AppColors.lightblue,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("helpsupp".tr,
                          style: TextStyle(
                              fontSize: 20.sp, fontWeight: FontWeight.bold)),
                      const Icon(Icons.local_fire_department,
                          color: Colors.orange, size: 28),
                    ],
                  ),
                ),
                SizedBox(height: 15.h),
                // Frequently Asked Questions
                Text("frqaskque".tr,
                    style: TextStyle(
                        fontSize: 18.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 10.h),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: faqQuestions.map((question) {
                      return GestureDetector(
                        onTap: () => openWhatsApp(question, whatsapp),
                        child: Container(
                          width: 150.w,
                          height: 100.h,
                          padding: EdgeInsets.all(10.w),
                          margin: EdgeInsets.only(right: 10.w),
                          decoration: BoxDecoration(
                            color: AppColors.lightblue,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          alignment: Alignment.center,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Center(
                              child: Text(question,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14.sp)),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(height: 20.h),

                // About the Company Section
                infoBox(
                  "aboutcomp".tr,
                  'comprule1'.tr,
                  "ourcoreval".tr,
                  'compkeyval'.tr,
                ),
                SizedBox(height: 20.h),

                // Start a Conversation Button
                GestureDetector(
                  onTap: () => startConversation(whatsapp),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.r),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.shade300, blurRadius: 5)
                      ],
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat, color: Colors.black),
                        SizedBox(width: 10.w),
                        Text("startconv".tr, style: TextStyle(fontSize: 16.sp)),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 30.h),

                // Contact & Support
                Text("consupp".tr,
                    style: TextStyle(
                        fontSize: 18.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 10.h),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () =>
                          openSocialMedia(Uri.parse(socialLinks["whatsapp"]!)),
                      child: CircleAvatar(
                        radius: 25.r,
                        backgroundColor: Colors.black,
                        child: const Icon(Icons.phone,
                            color: Colors.white, size: 28),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          openSocialMedia(Uri.parse(socialLinks["email"]!)),
                      child: CircleAvatar(
                        radius: 25.r,
                        backgroundColor: Colors.black,
                        child: const Icon(Icons.email,
                            color: Colors.white, size: 28),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          openSocialMedia(Uri.parse(socialLinks["instagram"]!)),
                      child: CircleAvatar(
                        radius: 25.r,
                        backgroundColor: Colors.black,
                        child: SvgPicture.asset(
                            AppImages.instagram, // Path to your SVG file
                            width: 50, // You can adjust the size
                            height: 50, // You can adjust the size
                            // ignore: deprecated_member_use
                            color: Colors.white),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          openSocialMedia(Uri.parse(socialLinks["twitter"]!)),
                      child: CircleAvatar(
                        radius: 25.r,
                        backgroundColor: Colors.black,
                        child: SvgPicture.asset(
                          AppImages.twitter, // Path to your SVG file
                          width: 28, // You can adjust the size
                          height: 28, // You can adjust the size
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
