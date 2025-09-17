import 'dart:convert';
// import 'package:ads_library/firebase_options.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_crashlytics/firebase_crashlytics.dart';
// import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'ads_kit.dart';
import 'app/routes/app_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  //
  // // Pass all uncaught errors to Crashlytics.
  // FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  //
  // // Capture errors in async code
  // PlatformDispatcher.instance.onError = (error, stack) {
  //   FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  //   return true;
  // };


  // ✅ Static ads config JSON
  final adsConfig = {
    "env": "production",
    "testDeviceIds": ["F777F38A1A80E262DDC67F1B141E88B3"],
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