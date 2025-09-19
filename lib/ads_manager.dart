import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';

/// This must exist in your app bootstrap (kept here for clarity)
final box = GetStorage();

/// -------------------- (Legacy key names for compatibility) --------------------
class ArgumentConstant {
  static const String isInterstitialStartTime = 'isInterstitialStartTime';      // Interstitial last show ts (ms)
  static const String isAppOpenStartTime = 'isAppOpenStartTime';                // AppOpen last show ts (ms)
  static const String isRewardedStartTime = 'isRewardedStartTime';              // Rewarded last show ts (ms)
  static const String isRewardedInterStartTime = 'isRewardedInterStartTime';    // Rewarded Interstitial last show ts (ms)
}

/// -------------------- BANNER TYPE ENUM --------------------
enum BannerType { google, custom }

/// -------------------- AD UNIT IDS --------------------
class AdUnitIds {
  final String? android;
  final String? ios;
  /// Minimum seconds between shows for this placement
  final int? adsFrequencySec;
  /// If true, the placement will never show
  final bool? adsDisable;

  AdUnitIds({
    this.android,
    this.ios,
    this.adsFrequencySec = 40,
    this.adsDisable = false,
  });

  String? forTargetPlatform(TargetPlatform platform) {
    if (platform == TargetPlatform.android) return android;
    if (platform == TargetPlatform.iOS) return ios;
    return android ?? ios;
  }
}

enum AdsEnvironment { production, testing }
enum AdsLoadState { idle, loading, loaded, failed }

/// -------------------- INTERNAL COOLDOWN/TIMING HELPERS --------------------
class _Cooldown {
  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  static int _readMs(String key) {
    final v = box.read(key);
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  static void _writeNow(String key) => box.write(key, _nowMs());

  /// Compatibility helper that mirrors your previous "difference" printouts
  /// and uses a dynamic threshold (seconds).
  static bool isReadyVerboseSeconds(String key, int thresholdSec) {
    final start = _readMs(key);
    final current = _nowMs();
    final difference = current - start;
    final differenceTimeSec = difference ~/ 1000;


    DateTime startTime = DateTime.fromMillisecondsSinceEpoch(start);
    DateTime currentTime = DateTime.fromMillisecondsSinceEpoch(current);
    final getDifference = currentTime.difference(startTime).inSeconds;

    if(kDebugMode) debugPrint("Difference := $getDifference");
    if(kDebugMode) debugPrint("StartTime := $start");
    if(kDebugMode) debugPrint("currentDate := $current");

    final ready = differenceTimeSec > thresholdSec;
    if (ready) _writeNow(key); // pre-stamp on allow, same pattern as inter/app open guard
    return ready;
  }
}

/// -------------------- ADS MANAGER --------------------
class AdsManager {
  AdsManager._internal();
  static final AdsManager instance = AdsManager._internal();

  static bool _initialized = false;
  static AdsEnvironment _env = AdsEnvironment.production;

  static AdUnitIds? bannerIds;
  static AdUnitIds? interstitialIds;
  static AdUnitIds? rewardedIds;
  static AdUnitIds? rewardedInterstitialIds;
  static AdUnitIds? appOpenIds;
  static AdUnitIds? nativeIds;

  /// -------------------- BANNERS --------------------
  static final Map<String, BannerAd> _banners = {};
  static final Map<String, AdsLoadState> bannerStates = {};
  static final Map<String, Widget> _bannerWidgets = {};
  static final Map<String, BannerAd> _preloadedBanners = {};

  /// -------------------- INTERSTITIAL --------------------
  static final Map<String, InterstitialAd?> _interstitials = {};
  static final Map<String, AdsLoadState> interstitialStates = {};
  static bool _isShowingVideoAd = false;

  /// -------------------- REWARDED --------------------
  static final Map<String, RewardedAd?> _rewardedAds = {};
  static final Map<String, AdsLoadState> rewardedStates = {};

  /// -------------------- REWARDED INTERSTITIAL --------------------
  static final Map<String, RewardedInterstitialAd?> _rewardedInterstitials = {};
  static final Map<String, AdsLoadState> rewardedInterstitialStates = {};

  /// -------------------- APP OPEN --------------------
  static AppOpenAd? _appOpenAd;
  static AdsLoadState appOpenState = AdsLoadState.idle;
  static bool _appOpenInitialized = false;

  static final Map<String, NativeAd?> _nativeAds = {};
  static final Map<String, AdsLoadState> nativeStates = {};
  static final Map<String, Widget> _nativeWidgets = {};
  static final Map<String, NativeAd> _preloadedNativeAds = {};

  /// -------------------- INITIALIZE --------------------
  static Future<void> initialize({
    AdsEnvironment env = AdsEnvironment.production,
    List<String>? testDeviceIds,
    AdUnitIds? banner,
    AdUnitIds? interstitial,
    AdUnitIds? rewarded,
    AdUnitIds? rewardedInterstitial,
    AdUnitIds? appOpen,
    AdUnitIds? native,
    bool preloadBanners = true,
    bool preloadNativeAds = true,
  }) async {
    if (_initialized) return;

    _env = env;
    bannerIds = banner ?? bannerIds;
    interstitialIds = interstitial ?? interstitialIds;
    rewardedIds = rewarded ?? rewardedIds;
    rewardedInterstitialIds = rewardedInterstitial ?? rewardedInterstitialIds;
    appOpenIds = appOpen ?? appOpenIds;
    nativeIds = native ?? nativeIds;

    final cfg = RequestConfiguration(
      testDeviceIds: env == AdsEnvironment.testing ? (testDeviceIds ?? []) : null,
    );

    await MobileAds.instance.updateRequestConfiguration(cfg);
    await MobileAds.instance.initialize();
    _initialized = true;

    // Preload defaults
    if (rewardedInterstitialIds != null && (rewardedInterstitialIds!.adsDisable != true)) {
      await _loadRewardedInterstitial();
    }
    if (interstitialIds != null && (interstitialIds!.adsDisable != true)) {
      await _loadInterstitial();
    }
    if (rewardedIds != null && (rewardedIds!.adsDisable != true)) {
      await _loadRewarded();
    }

    // Preload banners if enabled
    if (preloadBanners && bannerIds != null && (bannerIds!.adsDisable != true)) {
      await _preloadBanners();
    }

    // Preload native ads if enabled
    if (preloadNativeAds && nativeIds != null && (nativeIds!.adsDisable != true)) {
      await _preloadNativeAds();
    }

    // 👇 Preload AppOpen once
    if (appOpenIds != null && (appOpenIds!.adsDisable != true)) {
      await loadAppOpenAd();
      WidgetsBinding.instance.addObserver(AdsLifecycleHandler());
      _appOpenInitialized = true;
    }
  }

  static bool get isAppOpenInitialized => _appOpenInitialized;

  /// -------------------- PRELOADING METHODS --------------------
  static Future<void> _preloadBanners() async {
    final adUnitId = bannerIds?.forTargetPlatform(defaultTargetPlatform);
    if (adUnitId == null) return;

    // Preload default banner
    await _preloadSingleBanner('default', adUnitId);
  }

  static Future<void> _preloadSingleBanner(String key, String adUnitId) async {
    try {
      final banner = BannerAd(
        adUnitId: adUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            bannerStates[key] = AdsLoadState.loaded;
            if (kDebugMode) debugPrint("Preloaded banner for key: $key");
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            bannerStates[key] = AdsLoadState.failed;
            if (kDebugMode) debugPrint("Failed to preload banner for key: $key, error: $error");
          },
        ),
      );

      bannerStates[key] = AdsLoadState.loading;
      await banner.load();
      _preloadedBanners[key] = banner;
    } catch (e) {
      if (kDebugMode) debugPrint("Exception preloading banner: $e");
    }
  }

  static Future<void> _preloadNativeAds() async {
    final adUnitId = nativeIds?.forTargetPlatform(defaultTargetPlatform);
    if (adUnitId == null) return;

    // Preload default native ad
    await _preloadSingleNativeAd('default', adUnitId);
  }

  static Future<void> _preloadSingleNativeAd(String key, String adUnitId) async {
    try {
      final nativeAd = NativeAd(
        adUnitId: adUnitId,
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (_) {
            nativeStates[key] = AdsLoadState.loaded;
            if (kDebugMode) debugPrint("Preloaded native ad for key: $key");
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            nativeStates[key] = AdsLoadState.failed;
            if (kDebugMode) debugPrint("Failed to preload native ad for key: $key, error: $error");
          },
        ),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.small,
          mainBackgroundColor: Colors.white,
          cornerRadius: 8.0,
        ),
      );

      nativeStates[key] = AdsLoadState.loading;
      await nativeAd.load();
      _preloadedNativeAds[key] = nativeAd;
    } catch (e) {
      if (kDebugMode) debugPrint("Exception preloading native ad: $e");
    }
  }

  /// -------------------- HELPERS --------------------
  static String? _resolveBanner(String? adUnitId) =>
      adUnitId ?? bannerIds?.forTargetPlatform(defaultTargetPlatform);

  static String? _resolveInterstitial(String? adUnitId) =>
      adUnitId ?? interstitialIds?.forTargetPlatform(defaultTargetPlatform);

  static String? _resolveRewarded(String? adUnitId) =>
      adUnitId ?? rewardedIds?.forTargetPlatform(defaultTargetPlatform);

  static String? _resolveRewardedInterstitial(String? adUnitId) =>
      adUnitId ?? rewardedInterstitialIds?.forTargetPlatform(defaultTargetPlatform);

  static String? _resolveAppOpen(String? adUnitId) =>
      adUnitId ?? appOpenIds?.forTargetPlatform(defaultTargetPlatform);

  static String? _resolveNative(String? adUnitId) =>
      adUnitId ?? nativeIds?.forTargetPlatform(defaultTargetPlatform);

  static int _freqOrDefault(AdUnitIds? ids, int fallback) =>
      (ids?.adsFrequencySec ?? fallback).clamp(0, 7 * 24 * 60 * 60);

  /// -------------------- BANNER --------------------
  static Widget showBanner({
    String key = "banner1",
    String? adUnitId,
    bool isShowAdaptive = true,
    BannerType bannerType = BannerType.google,
    Map<String, List<Map<String, Object?>>> bannerItem = const {},
  }) {
    _banners[key]?.dispose();
    _bannerWidgets.remove(key);

    final resolved = _resolveBanner(adUnitId);
    if (resolved == null || (bannerIds?.adsDisable ?? false)) return const SizedBox.shrink();

    Widget widget;

    if (bannerType == BannerType.google) {
      widget = _AdaptiveBannerWidget(
        bannerKey: key,
        adUnitId: resolved,
        isShowAdaptive: isShowAdaptive,
        usePreloaded: _preloadedBanners.containsKey(key),
      );
    } else {
      widget = BannerCarousel(bannerItem: bannerItem);
    }

    _bannerWidgets[key] = widget;
    return widget;
  }

  /// -------------------- INTERSTITIAL --------------------
  static Future<void> _loadInterstitial({String key = "inter", String? adUnitId}) async {
    if (interstitialStates[key] == AdsLoadState.loading) return; // guard
    interstitialStates[key] = AdsLoadState.loading;

    _interstitials[key]?.dispose();
    _interstitials[key] = null;

    final resolved = _resolveInterstitial(adUnitId);
    if (resolved == null || (interstitialIds?.adsDisable ?? false)) return;

    interstitialStates[key] = AdsLoadState.loading;
    InterstitialAd.load(
      adUnitId: resolved,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitials[key] = ad;
          interstitialStates[key] = AdsLoadState.loaded;
        },
        onAdFailedToLoad: (error) {
          _interstitials[key] = null;
          interstitialStates[key] = AdsLoadState.failed;
        },
      ),
    );
  }

  /// Shows interstitial only if its cooldown (adsFrequencySec) has elapsed.
  static void showInterstitial({String key = "inter", String? adUnitId, VoidCallback? onDismissed}) {
    if (interstitialIds?.adsDisable ?? false) {
      onDismissed?.call();
      return;
    }

    final freq = _freqOrDefault(interstitialIds, 40);
    final ready = _Cooldown.isReadyVerboseSeconds(ArgumentConstant.isInterstitialStartTime, freq);
    if (!ready) {
      onDismissed?.call();
      return;
    }

    final ad = _interstitials[key];
    if (ad == null) {
      _loadInterstitial(adUnitId: adUnitId);
      onDismissed?.call();
      return;
    }

    _isShowingVideoAd = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        box.write(ArgumentConstant.isInterstitialStartTime, DateTime.now().millisecondsSinceEpoch);
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitials[key] = null;
        interstitialStates[key] = AdsLoadState.idle;
        _isShowingVideoAd = false;
        _loadInterstitial();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitials[key] = null;
        interstitialStates[key] = AdsLoadState.idle;
        _isShowingVideoAd = false;
        _loadInterstitial();
        onDismissed?.call();
      },
    );

    ad.show();
    _interstitials[key] = null;
  }

  /// -------------------- REWARDED --------------------
  static Future<void> _loadRewarded({String key = "rewarded", String? adUnitId}) async {
    if (rewardedStates[key] == AdsLoadState.loading) return; // guard
    rewardedStates[key] = AdsLoadState.loading;

    _rewardedAds[key]?.dispose();
    _rewardedAds[key] = null;

    final resolved = _resolveRewarded(adUnitId);
    if (resolved == null || (rewardedIds?.adsDisable ?? false)) return;

    rewardedStates[key] = AdsLoadState.loading;
    RewardedAd.load(
      adUnitId: resolved,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAds[key] = ad;
          rewardedStates[key] = AdsLoadState.loaded;
        },
        onAdFailedToLoad: (error) {
          _rewardedAds[key] = null;
          rewardedStates[key] = AdsLoadState.failed;
        },
      ),
    );
  }

  /// Shows rewarded only if its cooldown has elapsed (same guard as inter/app-open).
  static void showRewarded({String key = "rewarded", String? adUnitId, required VoidCallback onReward, VoidCallback? onDismissed}) {
    if (rewardedIds?.adsDisable ?? false) {
      onDismissed?.call();
      return;
    }

    // ✅ Cooldown guard using isReadyVerboseSeconds
    final freq = _freqOrDefault(rewardedIds, 40);
    final ready = _Cooldown.isReadyVerboseSeconds(ArgumentConstant.isRewardedStartTime, freq);
    if (!ready) {
      onDismissed?.call();
      return;
    }

    final ad = _rewardedAds[key];
    if (ad == null) {
      _loadRewarded(adUnitId: adUnitId);
      onDismissed?.call();
      return;
    }

    _isShowingVideoAd = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        box.write(ArgumentConstant.isRewardedStartTime, DateTime.now().millisecondsSinceEpoch);
        ad.dispose();
        _rewardedAds[key] = null;
        rewardedStates[key] = AdsLoadState.idle;
        _isShowingVideoAd = false;
        _loadRewarded();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAds[key] = null;
        rewardedStates[key] = AdsLoadState.idle;
        _isShowingVideoAd = false;
        _loadRewarded();
        onDismissed?.call();
      },
    );

    ad.show(onUserEarnedReward: (ad, reward) => onReward());
    _rewardedAds[key] = null;
  }

  /// -------------------- REWARDED INTERSTITIAL --------------------
  static Future<void> _loadRewardedInterstitial({String key = "rewarded_inter", String? adUnitId}) async {
    if (rewardedInterstitialStates[key] == AdsLoadState.loading) return; // guard
    rewardedInterstitialStates[key] = AdsLoadState.loading;

    _rewardedInterstitials[key]?.dispose();
    _rewardedInterstitials[key] = null;

    final resolved = _resolveRewardedInterstitial(adUnitId);
    if (resolved == null || (rewardedInterstitialIds?.adsDisable ?? false)) return;

    rewardedInterstitialStates[key] = AdsLoadState.loading;
    RewardedInterstitialAd.load(
      adUnitId: resolved,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitials[key] = ad;
          rewardedInterstitialStates[key] = AdsLoadState.loaded;
        },
        onAdFailedToLoad: (error) {
          _rewardedInterstitials[key] = null;
          rewardedInterstitialStates[key] = AdsLoadState.failed;
        },
      ),
    );
  }

  /// Shows rewarded-interstitial only if its cooldown has elapsed.
  static void showRewardedInterstitial({String key = "rewarded_inter", String? adUnitId, required VoidCallback onReward, VoidCallback? onDismissed}) {
    if (rewardedInterstitialIds?.adsDisable ?? false) {
      onDismissed?.call();
      return;
    }

    // ✅ Cooldown guard using isReadyVerboseSeconds
    final freq = _freqOrDefault(rewardedInterstitialIds, 40);
    final ready = _Cooldown.isReadyVerboseSeconds(ArgumentConstant.isRewardedInterStartTime, freq);
    if (!ready) {
      onDismissed?.call();
      return;
    }

    final ad = _rewardedInterstitials[key];
    if (ad == null) {
      _loadRewardedInterstitial(adUnitId: adUnitId);
      onDismissed?.call();
      return;
    }

    _isShowingVideoAd = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        box.write(ArgumentConstant.isRewardedInterStartTime, DateTime.now().millisecondsSinceEpoch);
        ad.dispose();
        _rewardedInterstitials[key] = null;
        rewardedInterstitialStates[key] = AdsLoadState.idle;
        _isShowingVideoAd = false;
        _loadRewardedInterstitial();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedInterstitials[key] = null;
        rewardedInterstitialStates[key] = AdsLoadState.idle;
        _isShowingVideoAd = false;
        _loadRewardedInterstitial();
        onDismissed?.call();
      },
    );

    ad.show(onUserEarnedReward: (ad, reward) => onReward());
    _rewardedInterstitials[key] = null;
  }

  /// -------------------- APP OPEN --------------------
  static Future<void> loadAppOpenAd({String? adUnitId}) async {

    // 🔒 Guard: if one is loading, skip
    if (appOpenState == AdsLoadState.loading) return;

    // 🔒 Guard: if one is already loaded and not expired, skip
    if (_appOpenAd != null && appOpenState == AdsLoadState.loaded) return;

    _appOpenAd?.dispose();
    _appOpenAd = null;

    if (_isShowingVideoAd) return;
    final resolved = _resolveAppOpen(adUnitId);
    if (resolved == null || (appOpenIds?.adsDisable ?? false)) return;

    appOpenState = AdsLoadState.loading;
    AppOpenAd.load(
      adUnitId: resolved,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          appOpenState = AdsLoadState.loaded;
        },
        onAdFailedToLoad: (error) {
          _appOpenAd = null;
          appOpenState = AdsLoadState.failed;
          if(kDebugMode) debugPrint("AppOpen load error: $error");
        },
      ),
    );
  }

  /// Shows AppOpen only if its cooldown (adsFrequencySec) has elapsed.
  static void showAppOpenAd({VoidCallback? onLoaded, VoidCallback? onDismissed, VoidCallback? onFailed}) {
    if (_isShowingVideoAd) return;
    if (appOpenIds?.adsDisable ?? false) {
      onDismissed?.call();
      return;
    }

    // Respect frequency using legacy key for compatibility
    final freq = _freqOrDefault(appOpenIds, 40);
    final ready = _Cooldown.isReadyVerboseSeconds(ArgumentConstant.isAppOpenStartTime, freq);
    if (!ready) return;

    final ad = _appOpenAd;
    if (ad == null) return;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        box.write(ArgumentConstant.isAppOpenStartTime, DateTime.now().millisecondsSinceEpoch);
        onLoaded?.call();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        appOpenState = AdsLoadState.idle;
        loadAppOpenAd();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _appOpenAd = null;
        appOpenState = AdsLoadState.idle;
        loadAppOpenAd();
        onFailed?.call();
      },
    );

    ad.show();
    _appOpenAd = null;
  }

  /// -------------------- NATIVE --------------------
  static Widget showNativeTemplate({
    String key = 'native1',
    String? adUnitId,
    TemplateType templateType = TemplateType.small,
    double height = 120,
  }) {
    _nativeAds[key]?.dispose();
    _nativeWidgets.remove(key);

    final resolved = _resolveNative(adUnitId);
    if (resolved == null || (nativeIds?.adsDisable ?? false)) {
      return const SizedBox.shrink();
    }

    final widget = _NativeTemplateAdWidget(
      adUnitId: resolved,
      adKey: key,
      templateType: templateType,
      height: height,
      usePreloaded: _preloadedNativeAds.containsKey(key),
    );

    _nativeWidgets[key] = widget;
    return widget;
  }

  /// -------------------- REWARDED INTERSTITIAL WITH CALLBACKS --------------------
  static void showRewardedInterstitialWithCallbacks({
    String key = 'default',
    String? adUnitId,
    required VoidCallback onLoaded,
    required VoidCallback onReward,
    required VoidCallback onDismissed,
    required VoidCallback onFailed,
  }) {
    if (rewardedInterstitialIds?.adsDisable ?? false) {
      onFailed();
      return;
    }

    // ✅ Cooldown guard before any load/show attempts
    final freq = _freqOrDefault(rewardedInterstitialIds, 40);
    final ready = _Cooldown.isReadyVerboseSeconds(ArgumentConstant.isRewardedInterStartTime, freq);
    if (!ready) {
      onFailed(); // or onDismissed(); choose based on your UX
      return;
    }

    final ad = _rewardedInterstitials[key];

    if (ad == null) {
      final resolved = _resolveRewardedInterstitial(adUnitId);
      if (resolved == null) {
        onFailed();
        return;
      }

      RewardedInterstitialAd.load(
        adUnitId: resolved,
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedInterstitials[key] = ad;
            rewardedInterstitialStates[key] = AdsLoadState.loaded;
            onLoaded();

            _isShowingVideoAd = true;
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                // ✅ Stamp show time for Rewarded Interstitial cooldown (callbacks path)
                box.write(ArgumentConstant.isRewardedInterStartTime, DateTime.now().millisecondsSinceEpoch);
              },
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _rewardedInterstitials[key] = null;
                rewardedInterstitialStates[key] = AdsLoadState.idle;
                _isShowingVideoAd = false;
                _loadRewardedInterstitial();
                onDismissed();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _rewardedInterstitials[key] = null;
                rewardedInterstitialStates[key] = AdsLoadState.failed;
                _isShowingVideoAd = false;
                onFailed();
              },
            );

            ad.show(onUserEarnedReward: (ad, reward) {
              onReward();
            });
          },
          onAdFailedToLoad: (error) {
            _rewardedInterstitials[key] = null;
            rewardedInterstitialStates[key] = AdsLoadState.failed;
            onFailed();
          },
        ),
      );
    } else {
      onLoaded();
      _isShowingVideoAd = true;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          box.write(ArgumentConstant.isRewardedInterStartTime, DateTime.now().millisecondsSinceEpoch);
        },
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedInterstitials[key] = null;
          rewardedInterstitialStates[key] = AdsLoadState.idle;
          _isShowingVideoAd = false;
          _loadRewardedInterstitial();
          onDismissed();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _rewardedInterstitials[key] = null;
          rewardedInterstitialStates[key] = AdsLoadState.failed;
          _isShowingVideoAd = false;
          onFailed();
        },
      );
      ad.show(onUserEarnedReward: (ad, reward) => onReward());
    }
  }
}

/// -------------------- SHIMMER HELPER --------------------
class _ShimmerHelper {
  static Widget bannerShimmer({double height = 50, double width = double.infinity}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    );
  }

  static Widget nativeShimmer({double height = 120}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: double.infinity,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 10,
                        width: 80,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 10,
              width: double.infinity,
              color: Colors.white,
            ),
            const SizedBox(height: 4),
            Container(
              height: 10,
              width: 120,
              color: Colors.white,
            ),
            const Spacer(),
            Container(
              height: 24,
              width: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------- ADAPTIVE BANNER --------------------
class _AdaptiveBannerWidget extends StatefulWidget {
  final String bannerKey;
  final String adUnitId;
  final bool isShowAdaptive;
  final bool usePreloaded;
  const _AdaptiveBannerWidget({
    required this.bannerKey,
    required this.adUnitId,
    required this.isShowAdaptive,
    this.usePreloaded = false,
  });

  @override
  State<_AdaptiveBannerWidget> createState() => _AdaptiveBannerWidgetState();
}

class _AdaptiveBannerWidgetState extends State<_AdaptiveBannerWidget> {
  BannerAd? _bannerAd;
  AdsLoadState _loadState = AdsLoadState.idle;
  double _adHeight = 50;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBanner();
  }

  void _loadBanner() {
    // Check if we can use preloaded banner
    if (widget.usePreloaded && AdsManager._preloadedBanners.containsKey(widget.bannerKey)) {
      _bannerAd = AdsManager._preloadedBanners.remove(widget.bannerKey);
      if (_bannerAd != null) {
        setState(() => _loadState = AdsLoadState.loaded);
        AdsManager._banners[widget.bannerKey] = _bannerAd!;
        return;
      }
    }

    AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(MediaQuery.of(context).size.width.truncate()).then((size) {
      if (!mounted || size == null) return;

      setState(() => _loadState = AdsLoadState.loading);
      _adHeight = size.height.toDouble();

      final banner = BannerAd(
        adUnitId: widget.adUnitId,
        size: widget.isShowAdaptive ? size : AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) => mounted ? setState(() => _loadState = AdsLoadState.loaded) : null,
          onAdFailedToLoad: (ad, _) {
            ad.dispose();
            if (mounted) setState(() => _loadState = AdsLoadState.failed);
          },
        ),
      );
      banner.load();
      _bannerAd = banner;
      AdsManager._banners[widget.bannerKey] = banner;
      AdsManager.bannerStates[widget.bannerKey] = AdsLoadState.loading;
    });
  }

  @override
  void dispose() {
    if(_bannerAd != null) _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadState == AdsLoadState.loading) {
      return _ShimmerHelper.bannerShimmer(height: _adHeight);
    }

    if (_loadState != AdsLoadState.loaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _adHeight,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

/// -------------------- MODEL --------------------
class BannerItem {
  final String? link;
  final int isDeepLink;
  final String? image;
  final int sliderTime;
  final String? title;
  final String? seriesId;
  final String? offerCode;

  BannerItem({
    this.link,
    required this.isDeepLink,
    this.image,
    required this.sliderTime,
    this.title,
    this.seriesId,
    this.offerCode,
  });

  factory BannerItem.fromJson(Map<String, dynamic> json) {
    return BannerItem(
      link: json["link"],
      isDeepLink: json["is_deep_link"] ?? 0,
      image: json["image"],
      sliderTime: json["slider_time"] ?? 3,
      title: json["title"],
      seriesId: json["series_id"],
      offerCode: json["offer_code"],
    );
  }
}

/// -------------------- BANNER CAROUSEL --------------------
class BannerCarousel extends StatefulWidget {
  final Map<String, List<Map<String, Object?>>> bannerItem;
  const BannerCarousel({required this.bannerItem});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final CarouselSliderController _carouselController = CarouselSliderController();

  List<BannerItem> bannerList = [];
  Timer? _autoPlayTimer;
  int bannerCurrentIndex = 0;
  int sliderTime = 5; // default
  bool showShimmer = true; // start shimmer ON

  @override
  void initState() {
    super.initState();

    // Parse banners
    bannerList = (widget.bannerItem["banneras"] as List)
        .map((e) => BannerItem.fromJson(e))
        .where((banner) => !(banner.image?.isEmpty ?? true))
        .toList();

    if (bannerList.isNotEmpty) {
      sliderTime = bannerList[0].sliderTime;
      _startAutoPlayTimer();
    }

    // 🔥 Keep shimmer for at least 100 ms before switching
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          showShimmer = false;
        });
      }
    });
  }

  /// -------------------- TIMER LOGIC --------------------
  /// -------------------- TIMER LOGIC --------------------
  void _startAutoPlayTimer() {
    _autoPlayTimer?.cancel();

    // use one-shot timer instead of periodic
    _autoPlayTimer = Timer(Duration(seconds: sliderTime), () {
      _onNextPage();
    });
  }

  void _onNextPage() {
    if (bannerList.isEmpty) return;

    int nextIndex = (bannerCurrentIndex + 1) % bannerList.length;

    // move to next page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carouselController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });

    setState(() {
      bannerCurrentIndex = nextIndex;
      sliderTime = bannerList[bannerCurrentIndex].sliderTime; // 🔥 update to slide-specific time
    });

    _startAutoPlayTimer(); // schedule next one with updated time
  }

  void _onPageChanged(int index, CarouselPageChangedReason reason) {
    if (bannerCurrentIndex != index) {
      setState(() {
        bannerCurrentIndex = index;
        sliderTime = bannerList[bannerCurrentIndex].sliderTime; // 🔥 slide-specific time
      });
      _startAutoPlayTimer();
    }
  }

  /// -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    if (showShimmer) {
      return _ShimmerHelper.bannerShimmer(
        height: MediaQuery.of(context).size.height * 0.071,
      );
    }

    if (bannerList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        CarouselSlider.builder(
          carouselController: _carouselController,
          itemCount: bannerList.length,
          options: CarouselOptions(
            height: MediaQuery.of(context).size.height * 0.071,
            viewportFraction: 1,
            autoPlay: false,
            onPageChanged: _onPageChanged,
          ),
          itemBuilder: (context, index, realIndex) {
            final banner = bannerList[index];
            return GestureDetector(
              onTap: () async {
                if (banner.link != null && banner.link!.isNotEmpty) {
                  final url = Uri.parse(banner.link!);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 14.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9.0),
                  child: CachedNetworkImage(
                    imageUrl: banner.image ?? "",
                    memCacheWidth: 1200,
                    memCacheHeight: 200,
                    filterQuality: FilterQuality.low,
                    fit: BoxFit.fill,
                    width: MediaQuery.of(context).size.width,
                  ),
                ),
              ),
            );
          },
        ),
        if (bannerList.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 5.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                bannerList.length,
                    (index) => _buildIndicator(bannerCurrentIndex == index),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 2.0),
      height: 6,
      width: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Colors.blue : const Color(0XFFD9D9D9),
      ),
    );
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    super.dispose();
  }
}

/// -------------------- NATIVE AD WIDGET --------------------
class _NativeAdWidget extends StatefulWidget {
  final String adUnitId;
  final String adKey;
  final double height;
  final String factoryId;
  final bool usePreloaded;

  const _NativeAdWidget({
    required this.adUnitId,
    required this.adKey,
    this.height = 100,
    this.factoryId = 'listTile',
    this.usePreloaded = false,
  });

  @override
  State<_NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<_NativeAdWidget> {
  NativeAd? _nativeAd;
  AdsLoadState _loadState = AdsLoadState.idle;

  @override
  void initState() {
    super.initState();
    _loadNative();
  }

  void _loadNative() {
    // Check if we can use preloaded native ad
    if (widget.usePreloaded && AdsManager._preloadedNativeAds.containsKey(widget.adKey)) {
      _nativeAd = AdsManager._preloadedNativeAds.remove(widget.adKey);
      if (_nativeAd != null) {
        setState(() => _loadState = AdsLoadState.loaded);
        AdsManager._nativeAds[widget.adKey] = _nativeAd;
        return;
      }
    }

    if(_nativeAd != null) {
      if(kDebugMode) debugPrint("Something went wrong");
      return;
    }

    setState(() => _loadState = AdsLoadState.loading);

    _nativeAd = NativeAd(
      adUnitId: widget.adUnitId,
      factoryId: widget.factoryId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) => mounted ? setState(() => _loadState = AdsLoadState.loaded) : null,
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _loadState = AdsLoadState.failed);
        },
      ),
    );
    _nativeAd!.load();
    AdsManager._nativeAds[widget.adKey] = _nativeAd;
    AdsManager.nativeStates[widget.adKey] = AdsLoadState.loading;
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadState == AdsLoadState.loading) {
      return _ShimmerHelper.nativeShimmer(height: widget.height);
    }

    if (_loadState != AdsLoadState.loaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: widget.height,
      child: AdWidget(ad: _nativeAd!),
    );
  }
}

/// -------------------- NATIVE TEMPLATE AD WIDGET --------------------
class _NativeTemplateAdWidget extends StatefulWidget {
  final String adUnitId;
  final String adKey;
  final TemplateType templateType;
  final double height;
  final bool usePreloaded;

  const _NativeTemplateAdWidget({
    required this.adUnitId,
    required this.adKey,
    this.templateType = TemplateType.medium,
    this.height = 120,
    this.usePreloaded = false,
  });

  @override
  State<_NativeTemplateAdWidget> createState() => _NativeTemplateAdWidgetState();
}

class _NativeTemplateAdWidgetState extends State<_NativeTemplateAdWidget> {
  NativeAd? _nativeAd;
  AdsLoadState _loadState = AdsLoadState.idle;
  double _adHeight = 120;

  @override
  void initState() {
    super.initState();
    _loadNativeTemplate();
  }

  void _loadNativeTemplate() {
    // Check if we can use preloaded native ad
    if (widget.usePreloaded && AdsManager._preloadedNativeAds.containsKey(widget.adKey)) {
      _nativeAd = AdsManager._preloadedNativeAds.remove(widget.adKey);
      if (_nativeAd != null) {
        setState(() => _loadState = AdsLoadState.loaded);
        AdsManager._nativeAds[widget.adKey] = _nativeAd;
        return;
      }
    }

    setState(() => _loadState = AdsLoadState.loading);

    _nativeAd = NativeAd(
      adUnitId: widget.adUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (Ad ad) {
          // Cast ad to NativeAd
          final nativeAd = ad as NativeAd;

          // Media height adjustment (optional)
          double height = widget.height;
          final media = nativeAd.nativeAdOptions;
          if (media != null && (media.mediaAspectRatio?.index ?? 0) != 0) {
            height = MediaQuery.of(context).size.width / (media.mediaAspectRatio?.index ?? 0);
          }

          if (mounted) {
            setState(() {
              _loadState = AdsLoadState.loaded;
              _adHeight = height;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _loadState = AdsLoadState.failed);
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: widget.templateType,
        mainBackgroundColor: Colors.white,
        cornerRadius: 8.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: Colors.blue,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.grey,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.italic,
          size: 12.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.monospace,
          size: 12.0,
        ),
      ),
    );

    _nativeAd!.load();
    AdsManager._nativeAds[widget.adKey] = _nativeAd;
    AdsManager.nativeStates[widget.adKey] = AdsLoadState.loading;
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadState == AdsLoadState.loading) {
      return _ShimmerHelper.nativeShimmer(height: widget.height);
    }

    if (_loadState != AdsLoadState.loaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    // Use SizedBox with calculated height
    return SizedBox(
      height: _adHeight,
      child: AdWidget(ad: _nativeAd!),
    );
  }
}

/// -------------------- APP LIFECYCLE HANDLER --------------------
class AdsLifecycleHandler extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppStateEventNotifier.startListening();
    AppStateEventNotifier.appStateStream.listen((appState) {
      if (appState == AppState.foreground) {
        AdsManager.showAppOpenAd();
      }
    });
  }
}