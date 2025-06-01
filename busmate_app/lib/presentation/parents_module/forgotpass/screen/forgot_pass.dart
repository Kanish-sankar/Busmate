import 'package:busmate/presentation/parents_module/forgotpass/controller/forgotpass.controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ForgotPass extends GetView<ForgotPassController> {
  const ForgotPass({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GetBuilder<ForgotPassController>(
        builder: (controller) {
          return const Center(
            child: Text("ForgotPass Screen"),
          );
        },
      ),
    );
  }
}
