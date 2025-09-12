import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// -------------------- AD UNIT IDS --------------------
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
    if (rewardedInterstitialIds != null) await _loadRewardedInterstitial('default');
    if (interstitialIds != null) await _loadInterstitial('default');
    if (rewardedIds != null) await _loadRewarded('default');
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

  /// -------------------- BANNER --------------------
  static Widget showBanner(String key, {String? adUnitId}) {
    _banners[key]?.dispose();
    _bannerWidgets.remove(key);

    final resolved = _resolveBanner(adUnitId);
    if (resolved == null) return const SizedBox.shrink();

    final widget = _AdaptiveBannerWidget(bannerKey: key, adUnitId: resolved);
    _bannerWidgets[key] = widget;
    return widget;
  }

  /// -------------------- INTERSTITIAL --------------------
  static Future<void> _loadInterstitial(String key, {String? adUnitId}) async {
    final resolved = _resolveInterstitial(adUnitId);
    if (resolved == null) return;

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

  static void showInterstitial(String key,
      {String? adUnitId, VoidCallback? onDismissed}) {
    final ad = _interstitials[key];
    if (ad == null) {
      _loadInterstitial(key, adUnitId: adUnitId);
      return;
    }

    _isShowingVideoAd = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitials[key] = null;
        interstitialStates[key] = AdsLoadState.idle;
        _isShowingVideoAd = false;
        _loadInterstitial(key);
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitials[key] = null;
        interstitialStates[key] = AdsLoadState.idle;
        _isShowingVideoAd = false;
        _loadInterstitial(key);
        onDismissed?.call();
      },
    );

    ad.show();
    _interstitials[key] = null;
  }

  /// -------------------- REWARDED --------------------
  static Future<void> _loadRewarded(String key, {String? adUnitId}) async {
    final resolved = _resolveRewarded(adUnitId);
    if (resolved == null) return;

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

  static void showRewarded(String key,
      {String? adUnitId, required VoidCallback onReward, VoidCallback? onDismissed}) {
    final ad = _rewardedAds[key];
    if (ad == null) {
      _loadRewarded(key, adUnitId: adUnitId);
      return;
    }

    _isShowingVideoAd = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAds[key] = null;
        rewardedStates[key] = AdsLoadState.idle;
        _isShowingVideoAd = false;
        _loadRewarded(key);
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAds[key] = null;
        rewardedStates[key] = AdsLoadState.idle;
        _isShowingVideoAd = false;
        _loadRewarded(key);
        onDismissed?.call();
      },
    );

    ad.show(onUserEarnedReward: (ad, reward) => onReward());
    _rewardedAds[key] = null;
  }

  /// -------------------- REWARDED INTERSTITIAL --------------------
  static Future<void> _loadRewardedInterstitial(String key, {String? adUnitId}) async {
    final resolved = _resolveRewardedInterstitial(adUnitId);
    if (resolved == null) return;

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

  static void showRewardedInterstitial(String key,
      {String? adUnitId, required VoidCallback onReward, VoidCallback? onDismissed}) {
    final ad = _rewardedInterstitials[key];
    if (ad == null) {
      _loadRewardedInterstitial(key, adUnitId: adUnitId);
      return;
    }

    _isShowingVideoAd = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedInterstitials[key] = null;
        rewardedInterstitialStates[key] = AdsLoadState.idle;
        _isShowingVideoAd = false;
        _loadRewardedInterstitial(key);
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedInterstitials[key] = null;
        rewardedInterstitialStates[key] = AdsLoadState.idle;
        _isShowingVideoAd = false;
        _loadRewardedInterstitial(key);
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
    if (resolved == null) return;

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
        },
      ),
    );
  }

  static void showAppOpenAd() {
    if (_isShowingVideoAd) return;
    final ad = _appOpenAd;
    if (ad == null) return;

    ad.fullScreenContentCallback = FullScreenContentCallback(
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
      },
    );

    ad.show();
    _appOpenAd = null;
  }

  /// -------------------- NATIVE --------------------
  static Widget showNative(String key,
      {String? adUnitId, double height = 100, String factoryId = 'listTile'}) {
    _nativeAds[key]?.dispose();
    _nativeWidgets.remove(key);

    final resolved = _resolveNative(adUnitId);
    if (resolved == null) return const SizedBox.shrink();

    final widget = _NativeAdWidget(
      adUnitId: resolved,
      adKey: key,
      height: height,
      factoryId: factoryId,
    );
    _nativeWidgets[key] = widget;
    return widget;
  }

  static Widget showNativeTemplate(
      String key, {
        String? adUnitId,
        TemplateType templateType = TemplateType.medium,
        double height = 200,
      }) {
    _nativeAds[key]?.dispose();
    _nativeWidgets.remove(key);

    final resolved = _resolveNative(adUnitId);
    if (resolved == null) return const SizedBox.shrink();

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
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _rewardedInterstitials[key] = null;
                rewardedInterstitialStates[key] = AdsLoadState.idle;
                _isShowingVideoAd = false;
                _loadRewardedInterstitial(key);
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
      ad.show(onUserEarnedReward: (ad, reward) => onReward());
    }
  }
}

/// -------------------- ADAPTIVE BANNER --------------------
class _AdaptiveBannerWidget extends StatefulWidget {
  final String bannerKey;
  final String adUnitId;
  const _AdaptiveBannerWidget({required this.bannerKey, required this.adUnitId, super.key});

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
      if (size == null) return;
      _adHeight = size.height.toDouble();
      final banner = BannerAd(
        adUnitId: widget.adUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) => setState(() => _loadState = AdsLoadState.loaded),
          onAdFailedToLoad: (ad, _) {
            ad.dispose();
            setState(() => _loadState = AdsLoadState.failed);
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
    super.key,
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
        onAdLoaded: (_) => setState(() => _loadState = AdsLoadState.loaded),
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          setState(() => _loadState = AdsLoadState.failed);
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
enum TemplateType { small, medium, custom }

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
    super.key,
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
      factoryId: widget.templateType.name, // "small" | "medium" | "custom"
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) => setState(() => _loadState = AdsLoadState.loaded),
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          setState(() => _loadState = AdsLoadState.failed);
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

/// -------------------- APP LIFECYCLE HANDLER --------------------
class AdsLifecycleHandler extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AdsManager.showAppOpenAd();
    }
  }
}