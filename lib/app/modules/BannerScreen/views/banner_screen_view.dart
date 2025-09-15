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
          appBar: AppBar(title: AdsManager.showBanner(isShowAdaptive: false), leading: SizedBox(), leadingWidth: 0, centerTitle: true,),
          body: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [

              AdsManager.showBanner(),


              AdsManager.showBanner(isShowAdaptive: false),


              AdsManager.showBanner(),

              AdsManager.showBanner(isShowAdaptive: false),
            ],
          ),
          bottomNavigationBar: AdsManager.showBanner(),
        );
      },
    );
  }
}