.📘 Ads Library Documentation

Add This Library in pubspec.yaml file:
ads_library:
    git:
        url: https://github.com/TrunalArgon/FlutterAdsLibrary.git
        ref: main


1. Initialization

Initialize AdsKit using a local JSON configuration (or remote if required).
This example shows a static JSON setup:



final adsConfig = {
"env": "production",
"testDeviceIds": [""],
"placements": {
"appOpen": {"android": "", "ios": "", "adsDisable": false, "adsFrequencySec": 40},
"banner": {"android": "", "ios": "", "adsDisable": false},
"native": {"android": "", "ios": "", "adsDisable": false},
"interstitial": {"android": "", "ios": "", "adsDisable": false, "adsFrequencySec": 40},
"rewarded": {"android": "", "ios": "", "adsDisable": false, "adsFrequencySec": 40},
"rewardedInterstitial": {"android": "", "ios": "", "adsDisable": false, "adsFrequencySec": 40}
}
};
await AdsKit.initFromJson(jsonEncode(adsConfig));


2. Showing Ads
   All ads are handled via AdsManager. Below are usage examples with callbacks.
   App Open Ad

AdsManager.showAppOpenAd(
onLoaded: () => print("AppOpen Loaded ✅"),
onFailed: () => print("AppOpen Failed ❌"),
onDismissed: () => print("AppOpen Closed 👋"),
);


Callbacks: onLoaded, onFailed, onDismissed
Banner Ad

AdsManager.showBanner(); // Simple banner
AdsManager.showBanner(isShowAdaptive: false); // Non-adaptive
Scaffold(bottomNavigationBar: AdsManager.showBanner());


Note: Banners do not have callbacks.
Native Ads

AdsManager.showNativeTemplate(
templateType: TemplateType.small,
onLoaded: () => print("Native Loaded ✅"),
onFailed: () => print("Native Failed ❌"),
);


Callbacks: onLoaded, onFailed
Interstitial Ad

AdsManager.showInterstitial(
onLoaded: () => print("Interstitial Loaded ✅"),
onFailed: () => print("Interstitial Failed ❌"),
onDismissed: () => print("Interstitial Closed 👋"),
);


Callbacks: onLoaded, onFailed, onDismissed
Rewarded Ad

AdsManager.showRewarded(
onLoaded: () => print("Rewarded Loaded ✅"),
onFailed: () => print("Rewarded Failed ❌"),
onReward: () => print("User Earned Reward 🎉"),
onDismissed: () => print("Rewarded Closed 👋"),
);


Callbacks: onLoaded, onFailed, onReward, onDismissed
Rewarded Interstitial

AdsManager.showRewardedInterstitialWithCallbacks(
onLoaded: () => print("Rewarded Interstitial Loaded ✅"),
onFailed: () => print("Rewarded Interstitial Failed ❌"),
onReward: () => print("User Rewarded 🎉"),
onDismissed: () => print("Rewarded Interstitial Closed 👋"),
);


Callbacks: onLoaded, onFailed, onReward, onDismissed
3. Best Practices

1. AppOpen Ads → Only use on cold start or resume, not every foreground event.
2. Banner Ads → Can place multiple, but avoid spamming (AdMob policy).
3. Interstitial / Rewarded Ads → Trigger after user action, not instantly.
4. Frequency Control → Use adsFrequencySec to avoid over-showing.
5. Always add onFailed callbacks to handle load failures gracefully.