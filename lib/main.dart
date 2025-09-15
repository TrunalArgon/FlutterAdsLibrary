import 'dart:convert';
import 'package:ads_library/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'ads_kit.dart';
import 'app/routes/app_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await AdsKit.initFromRemoteConfig(defaultParamValues: {
    "env": "production",
    "testDeviceIds": jsonEncode([""]),
    "placements": jsonEncode({
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
    }),
  });

  runApp(
    GetMaterialApp(
      title: "Ads Library Project",
      getPages: AppPages.routes,
      initialRoute: AppPages.INITIAL,
      debugShowCheckedModeBanner: false,
    ),
  );
}