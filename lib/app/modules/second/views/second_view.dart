import 'package:ads_library/ads_manager.dart';
import 'package:ads_library/app/routes/app_pages.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../controllers/second_controller.dart';

class SecondView extends GetView<SecondController> {
  const SecondView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Center(
            child: ElevatedButton(
              onPressed: () => Get.toNamed(Routes.THIRD),
              child: Text("Tap"),
            ),
          ),

          SizedBox(height: 100),

          AdsManager.showNativeTemplate(templateType: TemplateType.small),
        ],
      ),

    );
  }
}