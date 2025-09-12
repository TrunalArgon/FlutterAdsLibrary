// ads_manager.dart
// Updated: One-call initialize loads all configured ads automatically.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Simple holder for platform ad unit ids
class AdUnitIds {
  final String? android;
  final String? ios;
  AdUnitIds({this.android, this.ios});

  String? forTargetPlatform(TargetPlatform platform) {
    if (platform == TargetPlatform.android) return android;
    if (platform == TargetPlatform.iOS) return ios;
    return android ?? ios;
  }
}

enum AdsEnvironment { production, testing }
enum AdsLoadState { idle, loading, loaded, failed }

typedef AdEventCallback = void Function(String key);
typedef AdErrorCallback = void Function(String key, LoadAdError error);

class AdsManager {
  AdsManager._internal();
  static final AdsManager _singleton = AdsManager._internal();
  static AdsManager get instance => _singleton;

  static bool _initialized = false;
  static AdsEnvironment _env = AdsEnvironment.production;

  // Default AdUnit sets
  static AdUnitIds? bannerIds;
  static AdUnitIds? interstitialIds;
  static AdUnitIds? rewardedIds;
  static AdUnitIds? nativeIds;
  static AdUnitIds? appOpenIds;
  static AdUnitIds? rewardedInterstitialIds;

  // Storages
  static final Map<String, BannerAd> _banners = {};
  static final Map<String, Widget> _bannerWidgets = {};
  static final Map<String, AdsLoadState> _bannerStates = {};

  static final Map<String, InterstitialAd> _interstitials = {};
  static final Map<String, AdsLoadState> _interstitialStates = {};

  static final Map<String, NativeAd> _natives = {};
  static final Map<String, AdsLoadState> _nativeStates = {};

  static final Map<String, RewardedAd> _rewardedAds = {};
  static final Map<String, AdsLoadState> _rewardedStates = {};

  static final Map<String, RewardedInterstitialAd> _rewardedInterstitials = {};
  static final Map<String, AdsLoadState> _rewardedInterstitialStates = {};

  static AppOpenAd? _appOpenAd;
  static DateTime? _appOpenLoadTime;
  static AdsLoadState _appOpenState = AdsLoadState.idle;

  /// ---------------- INIT ----------------
  static Future<void> initialize({
    AdsEnvironment env = AdsEnvironment.production,
    List<String>? testDeviceIds,
    AdUnitIds? banner,
    AdUnitIds? interstitial,
    AdUnitIds? rewarded,
    AdUnitIds? native,
    AdUnitIds? appOpen,
    AdUnitIds? rewardedInterstitial,
  }) async {
    if (_initialized) return;
    _env = env;

    // Set Ad Unit IDs
    setAdUnitIds(
      banner: banner,
      interstitial: interstitial,
      rewarded: rewarded,
      native: native,
      appOpen: appOpen,
      rewardedInterstitial: rewardedInterstitial,
    );

    final cfg = RequestConfiguration(
      testDeviceIds: (env == AdsEnvironment.testing) ? (testDeviceIds ?? <String>[]) : null,
    );
    await MobileAds.instance.updateRequestConfiguration(cfg);
    await MobileAds.instance.initialize();
    _initialized = true;

    // Automatically load ads if IDs are set
    if (_resolve(bannerIds) != null) {
      await loadBanner(key: "default_banner", size: AdSize.banner);
    }
    if (_resolve(interstitialIds) != null) {
      await loadInterstitial("default_interstitial");
    }
    if (_resolve(rewardedIds) != null) {
      await loadRewarded("default_rewarded");
    }
    if (_resolve(nativeIds) != null) {
      await loadNative("default_native");
    }
    if (_resolve(appOpenIds) != null) {
      await loadAppOpen();
    }
    if (_resolve(rewardedInterstitialIds) != null) {
      await loadRewardedInterstitial("default_rewarded_interstitial");
    }
  }

  static void setAdUnitIds({
    AdUnitIds? banner,
    AdUnitIds? interstitial,
    AdUnitIds? rewarded,
    AdUnitIds? native,
    AdUnitIds? appOpen,
    AdUnitIds? rewardedInterstitial,
  }) {
    bannerIds = banner ?? bannerIds;
    interstitialIds = interstitial ?? interstitialIds;
    rewardedIds = rewarded ?? rewardedIds;
    nativeIds = native ?? nativeIds;
    appOpenIds = appOpen ?? appOpenIds;
    rewardedInterstitialIds = rewardedInterstitial ?? rewardedInterstitialIds;
  }

  static String? _resolve(AdUnitIds? ids, {String? override}) {
    if (override != null) return override;
    if (ids == null) return null;
    return ids.forTargetPlatform(defaultTargetPlatform);
  }

  /// ---------------- BANNER ----------------
  static Future<void> loadBanner({
    required String key,
    required AdSize size,
    String? adUnitId,
  }) async {
    final resolved = _resolve(bannerIds, override: adUnitId);
    if (resolved == null) return;
    _bannerStates[key] = AdsLoadState.loading;

    final ad = BannerAd(
      adUnitId: resolved,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (a) {
          _banners[key] = a as BannerAd;
          _bannerWidgets[key] = SizedBox(
            width: a.size.width.toDouble(),
            height: a.size.height.toDouble(),
            child: AdWidget(ad: a),
          );
          _bannerStates[key] = AdsLoadState.loaded;
        },
        onAdFailedToLoad: (a, e) {
          a.dispose();
          _bannerStates[key] = AdsLoadState.failed;
        },
      ),
    );
    await ad.load();
  }

  static Widget bannerWidget(String key) =>
      _bannerWidgets[key] ?? const SizedBox.shrink();

  static void disposeBanner(String key) {
    _banners[key]?.dispose();
    _banners.remove(key);
    _bannerWidgets.remove(key);
    _bannerStates.remove(key);
  }

  /// ---------------- INTERSTITIAL ----------------
  static Future<void> loadInterstitial(String key, {String? adUnitId}) async {
    final resolved = _resolve(interstitialIds, override: adUnitId);
    if (resolved == null) return;
    _interstitialStates[key] = AdsLoadState.loading;

    InterstitialAd.load(
      adUnitId: resolved,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitials[key] = ad;
          _interstitialStates[key] = AdsLoadState.loaded;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (a) {
              a.dispose();
              _interstitials.remove(key);
              _interstitialStates[key] = AdsLoadState.idle;
            },
          );
        },
        onAdFailedToLoad: (_) => _interstitialStates[key] = AdsLoadState.failed,
      ),
    );
  }

  static bool showInterstitial(String key) {
    if (_interstitials.containsKey(key)) {
      _interstitials[key]!.show();
      return true;
    }
    return false;
  }

  /// ---------------- REWARDED ----------------
  static Future<void> loadRewarded(String key, {String? adUnitId}) async {
    final resolved = _resolve(rewardedIds, override: adUnitId);
    if (resolved == null) return;
    _rewardedStates[key] = AdsLoadState.loading;

    RewardedAd.load(
      adUnitId: resolved,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAds[key] = ad;
          _rewardedStates[key] = AdsLoadState.loaded;
        },
        onAdFailedToLoad: (_) => _rewardedStates[key] = AdsLoadState.failed,
      ),
    );
  }

  static bool showRewarded(String key, {required void Function(RewardItem) onEarned}) {
    if (_rewardedAds.containsKey(key)) {
      _rewardedAds[key]!.show(onUserEarnedReward: (_, reward) => onEarned(reward));
      return true;
    }
    return false;
  }

  /// ---------------- REWARDED INTERSTITIAL ----------------
  static Future<void> loadRewardedInterstitial(String key, {String? adUnitId}) async {
    final resolved = _resolve(rewardedInterstitialIds, override: adUnitId);
    if (resolved == null) return;
    _rewardedInterstitialStates[key] = AdsLoadState.loading;

    RewardedInterstitialAd.load(
      adUnitId: resolved,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitials[key] = ad;
          _rewardedInterstitialStates[key] = AdsLoadState.loaded;
        },
        onAdFailedToLoad: (_) => _rewardedInterstitialStates[key] = AdsLoadState.failed,
      ),
    );
  }

  static bool showRewardedInterstitial(String key, {required void Function(RewardItem) onEarned}) {
    if (_rewardedInterstitials.containsKey(key)) {
      _rewardedInterstitials[key]!.show(onUserEarnedReward: (_, reward) => onEarned(reward));
      return true;
    }
    return false;
  }

  /// ---------------- NATIVE ----------------
  static Future<void> loadNative(String key, {String? adUnitId}) async {
    final resolved = _resolve(nativeIds, override: adUnitId);
    if (resolved == null) return;
    _nativeStates[key] = AdsLoadState.loading;

    final ad = NativeAd(
      adUnitId: resolved,
      factoryId: "defaultFactory", // must register in platform side
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (a) {
          _natives[key] = a as NativeAd;
          _nativeStates[key] = AdsLoadState.loaded;
        },
        onAdFailedToLoad: (a, e) {
          a.dispose();
          _nativeStates[key] = AdsLoadState.failed;
        },
      ),
    );
    await ad.load();
  }

  /// ---------------- APP OPEN ----------------
  static Future<void> loadAppOpen({String? adUnitId}) async {
    final resolved = _resolve(appOpenIds, override: adUnitId);
    if (resolved == null) return;
    _appOpenState = AdsLoadState.loading;

    AppOpenAd.load(
      adUnitId: resolved,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenLoadTime = DateTime.now();
          _appOpenState = AdsLoadState.loaded;
        },
        onAdFailedToLoad: (_) => _appOpenState = AdsLoadState.failed,
      ),
    );
  }

  static bool showAppOpen() {
    if (_appOpenAd == null) return false;
    if (_appOpenLoadTime != null &&
        DateTime.now().difference(_appOpenLoadTime!).inHours >= 6) {
      _appOpenAd!.dispose();
      _appOpenAd = null;
      return false;
    }
    _appOpenAd!.show();
    return true;
  }

  /// ---------------- CLEANUP ----------------
  static void disposeAll() {
    _banners.forEach((_, v) => v.dispose());
    _banners.clear();
    _bannerWidgets.clear();
    _bannerStates.clear();

    _interstitials.forEach((_, v) => v.dispose());
    _interstitials.clear();
    _interstitialStates.clear();

    _rewardedAds.forEach((_, v) => v.dispose());
    _rewardedAds.clear();
    _rewardedStates.clear();

    _natives.forEach((_, v) => v.dispose());
    _natives.clear();
    _nativeStates.clear();

    _rewardedInterstitials.forEach((_, v) => v.dispose());
    _rewardedInterstitials.clear();
    _rewardedInterstitialStates.clear();

    _appOpenAd?.dispose();
    _appOpenAd = null;
    _appOpenLoadTime = null;
    _appOpenState = AdsLoadState.idle;
  }
}