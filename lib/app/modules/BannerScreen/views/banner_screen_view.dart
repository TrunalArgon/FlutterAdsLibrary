import 'package:ads_library/ads_manager.dart';
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
          appBar: AppBar(title: Text('Banner'), centerTitle: true),
          body: SizedBox(),
          bottomNavigationBar: AdsManager.showBanner('bottom_banner'),
        );
      },
    );
  }
}