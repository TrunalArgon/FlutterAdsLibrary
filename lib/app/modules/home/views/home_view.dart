import 'package:ads_library/ads_manager.dart';
import 'package:ads_library/app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';

class HomeView extends GetView {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      init: HomeController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(title: Text("Ads Example")),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                /// ---------------- App Open ----------------
                ElevatedButton(
                  onPressed: () => AdsManager.showAppOpenAd(),
                  child: Text("App Open Ad"),
                ),

                /// ---------------- Banner Screen ----------------
                ElevatedButton(
                  onPressed: () => Get.toNamed(Routes.BANNER_SCREEN),
                  child: Text("Banner Screen"),
                ),

                /// ---------------- Interstitial ----------------
                ElevatedButton(
                  onPressed: () => AdsManager.showInterstitial('default', onDismissed: () => print('Interstitial closed')),
                  child: Text("Interstitial Ad"),
                ),

                /// ---------------- Banner Screen ----------------
                ElevatedButton(
                  onPressed: () => Get.toNamed(Routes.NATIVE_SCREEN),
                  child: Text("Native Screen"),
                ),

                /// ---------------- Rewarded ----------------
                ElevatedButton(
                  onPressed: () => AdsManager.showRewarded('default', onReward: () => print('User earned reward!'), onDismissed: () => print('Rewarded ad closed')),
                  child: Text("Rewarded Ad"),
                ),

                /// ---------------- Rewarded Interstitial ----------------
                ElevatedButton(
                  onPressed: () => AdsManager.showRewardedInterstitialWithCallbacks(onLoaded: () => print("Ad Loaded ✅"), onReward: () => print("User Rewarded 🎉"), onDismissed: () => print("Ad Closed 👋"), onFailed: () => print("Ad Failed ❌")),
                  child: Text("Rewarded Interstitial"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}