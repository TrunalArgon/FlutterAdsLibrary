import 'package:ads_library/ads_manager.dart';
import 'package:ads_library/app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/banner_screen_controller.dart';

class BannerScreenView extends GetView {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<BannerScreenController>(
      init: BannerScreenController(),
      builder: (controller) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Get.toNamed(Routes.SECOND),
                  child: Text("Tap"),
                ),

                SizedBox(height: 50),

                AdsManager.showBanner(bannerType: BannerType.custom, bannerItem: controller.dataModel),
              ],
            ),
          ),
          bottomNavigationBar: AdsManager.showBanner(adUnitId: "ca-app-pub-3940256099942544/9214589741"),
        );
      },
    );
  }
}