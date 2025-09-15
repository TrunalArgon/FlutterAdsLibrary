Got it ✅
Here’s a **complete README.md** file you can directly put in your GitHub repo:

````markdown
# 📘 Flutter Ads Library

A lightweight Flutter library to easily manage **App Open, Banner, Native, Interstitial, Rewarded, and Rewarded Interstitial Ads** with a single API.  
This package wraps around **Google Mobile Ads SDK** and provides simple callbacks for better ad management.

---

## 🚀 Installation

Add this library in your **pubspec.yaml**:

```yaml
ads_library:
  git:
    url: https://github.com/TrunalArgon/FlutterAdsLibrary.git
    ref: main
````

Install dependencies:

```sh
flutter pub get
```

---

## ⚙️ Initialization

Initialize `AdsKit` using a **local JSON configuration** (or remote if required).
Here’s an example with **static JSON**:

```dart
import 'dart:convert';
import 'package:ads_library/ads_kit.dart';

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdsKit.initFromJson(jsonEncode(adsConfig));
  runApp(MyApp());
}
```

---

## 🎬 Showing Ads

All ads are controlled using **AdsManager**.
Each ad type has optional **callbacks** to track load, failure, and close events.

---

### 📂 App Open Ad

```dart
AdsManager.showAppOpenAd(
  onLoaded: () => print("AppOpen Loaded ✅"),
  onFailed: () => print("AppOpen Failed ❌"),
  onDismissed: () => print("AppOpen Closed 👋"),
);
```

**Callbacks:** `onLoaded`, `onFailed`, `onDismissed`

---

### 📂 Banner Ad

```dart
AdsManager.showBanner(); // Simple banner
AdsManager.showBanner(isShowAdaptive: false); // Non-adaptive
Scaffold(
  bottomNavigationBar: AdsManager.showBanner(),
);
```

⚠️ **Note:** Banners **do not support callbacks**.

---

### 📂 Native Ad

```dart
AdsManager.showNativeTemplate(
  templateType: TemplateType.small,
  onLoaded: () => print("Native Loaded ✅"),
  onFailed: () => print("Native Failed ❌"),
);
```

**Callbacks:** `onLoaded`, `onFailed`

---

### 📂 Interstitial Ad

```dart
AdsManager.showInterstitial(
  onLoaded: () => print("Interstitial Loaded ✅"),
  onFailed: () => print("Interstitial Failed ❌"),
  onDismissed: () => print("Interstitial Closed 👋"),
);
```

**Callbacks:** `onLoaded`, `onFailed`, `onDismissed`

---

### 📂 Rewarded Ad

```dart
AdsManager.showRewarded(
  onLoaded: () => print("Rewarded Loaded ✅"),
  onFailed: () => print("Rewarded Failed ❌"),
  onReward: () => print("User Earned Reward 🎉"),
  onDismissed: () => print("Rewarded Closed 👋"),
);
```

**Callbacks:** `onLoaded`, `onFailed`, `onReward`, `onDismissed`

---

### 📂 Rewarded Interstitial Ad

```dart
AdsManager.showRewardedInterstitialWithCallbacks(
  onLoaded: () => print("Rewarded Interstitial Loaded ✅"),
  onFailed: () => print("Rewarded Interstitial Failed ❌"),
  onReward: () => print("User Rewarded 🎉"),
  onDismissed: () => print("Rewarded Interstitial Closed 👋"),
);
```

**Callbacks:** `onLoaded`, `onFailed`, `onReward`, `onDismissed`

---

## ✅ Best Practices

1. **AppOpen Ads** → Show only on **cold start or resume**, not every foreground event.
2. **Banner Ads** → Multiple banners are allowed, but avoid **spamming** (AdMob policy).
3. **Interstitial / Rewarded Ads** → Show **after user interaction**, not instantly.
4. **Frequency Control** → Use `adsFrequencySec` to **limit excessive ad showing**.
5. **Failure Handling** → Always implement `onFailed` callbacks to gracefully handle load failures.

---

## 📌 Roadmap

* [ ] Add support for **custom ad layouts**
* [ ] Add **Ad Inspector** integration
* [ ] Improve **adaptive native templates**
* [ ] Add **sample Flutter demo app**

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!
Feel free to **fork** this repo and submit a **PR**.

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).

---

💡 *Made with ❤️ by [Trunal Argon](https://github.com/TrunalArgon)* 🚀

```

Would you like me to also include a **usage diagram** (like a flow of how AdsManager works) in the README so it looks more professional for GitHub?
```
