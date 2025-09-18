import 'package:ads_library/CarouselSlider.dart';
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
              children: [
                ElevatedButton(
                  onPressed: () => Get.toNamed(Routes.SECOND),
                  child: Text("Tap"),
                ),

                SizedBox(height: 50),

                BannerCarousel(bannerItem: controller.dataModel),
              ],
            ),
          ),
          bottomNavigationBar: AdsManager.showBanner(),
        );
      },
    );
  }
}