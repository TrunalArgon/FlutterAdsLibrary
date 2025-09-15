import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'ads_kit.dart';
import 'app/routes/app_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Static ads config JSON
  final adsConfig = {
    "env": "production",
    "testDeviceIds": [""],
    "placements": {
      "appOpen": {
        "android": "",
        "ios": "",
        "adsDisable": false,
        "adsFrequencySec": 40
      },
      "banner": {
        "android": "",
        "ios": "",
        "adsDisable": false
      },
      "native": {
        "android": "",
        "ios": "",
        "adsDisable": false
      },
      "interstitial": {
        "android": "",
        "ios": "",
        "adsDisable": false,
        "adsFrequencySec": 40
      },
      "rewarded": {
        "android": "",
        "ios": "",
        "adsDisable": false,
        "adsFrequencySec": 40
      },
      "rewardedInterstitial": {
        "android": "",
        "ios": "",
        "adsDisable": false,
        "adsFrequencySec": 40
      }
    }
  };

  // ✅ Initialize AdsKit from local JSON string
  await AdsKit.initFromJson(jsonEncode(adsConfig));

  runApp(
    GetMaterialApp(
      title: "Ads Library Project",
      getPages: AppPages.routes,
      initialRoute: AppPages.INITIAL,
      debugShowCheckedModeBanner: false,
    ),
  );
}