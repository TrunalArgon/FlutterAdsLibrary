import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'ads_manager.dart';
import 'app/routes/app_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AdsManager.initialize(
    env: AdsEnvironment.testing,
    appOpen: AdUnitIds(android: 'ca-app-pub-3940256099942544/9257395921'),
    banner: AdUnitIds(android: 'ca-app-pub-3940256099942544/9214589741'),
    interstitial: AdUnitIds(android: 'ca-app-pub-3940256099942544/1033173712'),
    native: AdUnitIds(android: 'ca-app-pub-3940256099942544/2247696110'),
    rewarded: AdUnitIds(android: 'ca-app-pub-3940256099942544/5224354917'),
    rewardedInterstitial: AdUnitIds(android: 'ca-app-pub-3940256099942544/5354046379'),
    testDeviceIds: ['F777F38A1A80E262DDC67F1B141E88B3'],
  );
  // banner: AdUnitIds(android: 'ca-app-pub-3940256099942544/9214589741'),

  WidgetsBinding.instance.addObserver(AdsLifecycleHandler());

  runApp(
    GetMaterialApp(
      title: "Application",
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
    ),
  );
}