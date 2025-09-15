import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// This must exist in your app bootstrap (kept here for clarity)
final box = GetStorage();

/// -------------------- (Legacy key names for compatibility) --------------------
class ArgumentConstant {
  static const String isInterstitialStartTime = 'isInterstitialStartTime';      // Interstitial last show ts (ms)
  static const String isAppOpenStartTime = 'isAppOpenStartTime';                // AppOpen last show ts (ms)

  // ✅ Added for Rewarded / Rewarded Interstitial cooldowns
  static const String isRewardedStartTime = 'isRewardedStartTime';              // Rewarded last show ts (ms)
  static const String isRewardedInterStartTime = 'isRewardedInterStartTime';    // Rewarded Interstitial last show ts (ms)
}

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

    debugPrint("Difference := $difference");
    debugPrint("StartTime := $start");
    debugPrint("currentDate := $current");

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

  /// -------------------- NATIVE --------------------
  static final Map<String, NativeAd?> _nativeAds = {};
  static final Map<String, AdsLoadState> nativeStates = {};
  static final Map<String, Widget> _nativeWidgets = {};

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

    // 👇 Preload AppOpen once
    if (appOpenIds != null && (appOpenIds!.adsDisable != true)) {
      await loadAppOpenAd();
      WidgetsBinding.instance.addObserver(AdsLifecycleHandler());
      _appOpenInitialized = true;
    }
  }

  static bool get isAppOpenInitialized => _appOpenInitialized;

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
  static Widget showBanner({String key = "banner1", String? adUnitId, bool isShowAdaptive = true}) {
    _banners[key]?.dispose();
    _bannerWidgets.remove(key);

    final resolved = _resolveBanner(adUnitId);
    if (resolved == null || (bannerIds?.adsDisable ?? false)) return const SizedBox.shrink();

    final widget = _AdaptiveBannerWidget(bannerKey: key, adUnitId: resolved, isShowAdaptive: isShowAdaptive);
    _bannerWidgets[key] = widget;
    return widget;
  }

  /// -------------------- INTERSTITIAL --------------------
  static Future<void> _loadInterstitial({String key = "inter", String? adUnitId}) async {
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
  static void showInterstitial({
    String key = "inter",
    String? adUnitId,
    VoidCallback? onDismissed,
  }) {
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
  static void showRewarded({
    String key = "rewarded",
    String? adUnitId,
    required VoidCallback onReward,
    VoidCallback? onDismissed,
  }) {
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
      onAdShowedFullScreenContent: (ad) {
        // ✅ Stamp show time for Rewarded cooldown
        box.write(ArgumentConstant.isRewardedStartTime, DateTime.now().millisecondsSinceEpoch);
      },
      onAdDismissedFullScreenContent: (ad) {
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
  static void showRewardedInterstitial({
    String key = "rewarded_inter",
    String? adUnitId,
    required VoidCallback onReward,
    VoidCallback? onDismissed,
  }) {
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
      onAdShowedFullScreenContent: (ad) {
        // ✅ Stamp show time for Rewarded Interstitial cooldown
        box.write(ArgumentConstant.isRewardedInterStartTime, DateTime.now().millisecondsSinceEpoch);
      },
      onAdDismissedFullScreenContent: (ad) {
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
          debugPrint("AppOpen load error: $error");
        },
      ),
    );
  }

  /// Shows AppOpen only if its cooldown (adsFrequencySec) has elapsed.
  static void showAppOpenAd() {
    if (_isShowingVideoAd) return;
    if (appOpenIds?.adsDisable ?? false) return;

    // Respect frequency using legacy key for compatibility
    final freq = _freqOrDefault(appOpenIds, 40);
    final ready = _Cooldown.isReadyVerboseSeconds(ArgumentConstant.isAppOpenStartTime, freq);
    if (!ready) return;

    final ad = _appOpenAd;
    if (ad == null) return;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        box.write(ArgumentConstant.isAppOpenStartTime, DateTime.now().millisecondsSinceEpoch);
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        appOpenState = AdsLoadState.idle;
        loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _appOpenAd = null;
        appOpenState = AdsLoadState.idle;
        loadAppOpenAd();
      },
    );

    ad.show();
    _appOpenAd = null;
  }

  /// -------------------- NATIVE --------------------
  static Widget showNative(
      String key, {
        String? adUnitId,
        double height = 100,
        String factoryId = 'listTile',
      }) {
    _nativeAds[key]?.dispose();
    _nativeWidgets.remove(key);

    final resolved = _resolveNative(adUnitId);
    if (resolved == null || (nativeIds?.adsDisable ?? false)) return const SizedBox.shrink();

    final widget = _NativeAdWidget(
      adUnitId: resolved,
      adKey: key,
      height: height,
      factoryId: factoryId,
    );
    _nativeWidgets[key] = widget;
    return widget;
  }

  static Widget showNativeTemplate({
    String key = 'native1',
    String? adUnitId,
    TemplateType templateType = TemplateType.medium,
    double height = 100,
  }) {
    _nativeAds[key]?.dispose();
    _nativeWidgets.remove(key);

    final resolved = _resolveNative(adUnitId);
    if (resolved == null || (nativeIds?.adsDisable ?? false)) return const SizedBox.shrink();

    final widget = _NativeTemplateAdWidget(
      adUnitId: resolved,
      adKey: key,
      templateType: templateType,
      height: height,
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

/// -------------------- ADAPTIVE BANNER --------------------
class _AdaptiveBannerWidget extends StatefulWidget {
  final String bannerKey;
  final String adUnitId;
  final bool isShowAdaptive;
  const _AdaptiveBannerWidget({required this.bannerKey, required this.adUnitId, required this.isShowAdaptive});

  @override
  State<_AdaptiveBannerWidget> createState() => _AdaptiveBannerWidgetState();
}

class _AdaptiveBannerWidgetState extends State<_AdaptiveBannerWidget> {
  BannerAd? _bannerAd;
  AdsLoadState _loadState = AdsLoadState.idle;
  double _adHeight = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBanner();
  }

  void _loadBanner() {
    AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      MediaQuery.of(context).size.width.truncate(),
    ).then((size) {
      if (!mounted || size == null) return;
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
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadState != AdsLoadState.loaded || _bannerAd == null) return const SizedBox.shrink();
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _adHeight,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

/// -------------------- NATIVE AD WIDGET --------------------
class _NativeAdWidget extends StatefulWidget {
  final String adUnitId;
  final String adKey;
  final double height;
  final String factoryId;

  const _NativeAdWidget({
    required this.adUnitId,
    required this.adKey,
    this.height = 100,
    this.factoryId = 'listTile',
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
    if (_loadState != AdsLoadState.loaded || _nativeAd == null) return const SizedBox.shrink();
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

  const _NativeTemplateAdWidget({
    required this.adUnitId,
    required this.adKey,
    this.templateType = TemplateType.medium,
    this.height = 200,
  });

  @override
  State<_NativeTemplateAdWidget> createState() => _NativeTemplateAdWidgetState();
}

class _NativeTemplateAdWidgetState extends State<_NativeTemplateAdWidget> {
  NativeAd? _nativeAd;
  AdsLoadState _loadState = AdsLoadState.idle;

  @override
  void initState() {
    super.initState();
    _loadNativeTemplate();
  }

  void _loadNativeTemplate() {
    _nativeAd = NativeAd(
      adUnitId: widget.adUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) => mounted ? setState(() => _loadState = AdsLoadState.loaded) : null,
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _loadState = AdsLoadState.failed);
        },
      ),
      // ✅ Theme these to your UI
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
    if (_loadState != AdsLoadState.loaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: widget.height,
      child: AdWidget(ad: _nativeAd!),
    );
  }
}

/// -------------------- APP LIFECYCLE HANDLER --------------------
class AdsLifecycleHandler extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppStateEventNotifier.startListening();
    AppStateEventNotifier.appStateStream.forEach((appState) {
      if (appState == AppState.foreground) {
        AdsManager.showAppOpenAd();
      }
    });
  }
}