import 'package:ads_library/ads_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../controllers/native_screen_controller.dart';

class NativeScreenView extends GetView {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<NativeScreenController>(
      init: NativeScreenController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(title: Text('Native'), centerTitle: true),
          body: Center(
            child: Column(
              children: [
                AdsManager.showNativeTemplate(templateType: TemplateType.small),

                SizedBox(height: 100),

                AdsManager.showNativeTemplate(templateType: TemplateType.medium, height: 350),
              ],
            ),
          ),
        );
      },
    );
  }
}