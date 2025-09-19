library ads_kit;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'ads_manager.dart';

/// ------------------ AdsKit entry ------------------
class AdsKit {
  /// Initialize Ads from local JSON string
  static Future<void> initFromJson(String jsonStr) async {
    if (jsonStr.isNotEmpty) {
      try {
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        final cfg = _AdsConfig.fromMap(map).normalizeEnvAndFillTestIds();
        await _initializeAdsFromConfig(cfg);
        return;
      } catch (e, st) {
        debugPrint('ads_kit: JSON parse failed => $e\n$st');
      }
    }

    // Fallback: testing + Google test IDs everywhere
    await _initializeAdsFallback();
  }
}

/// Initialize AdsManager using parsed/normalized config
Future<void> _initializeAdsFromConfig(_AdsConfig cfg) async {
  await AdsManager.initialize(
    env: cfg.env,
    testDeviceIds: cfg.env == AdsEnvironment.testing ? cfg.testDeviceIds : null,
    appOpen: cfg.get('appOpen')?.toAdUnitIds(),
    banner: cfg.get('banner')?.toAdUnitIds(),
    native: cfg.get('native')?.toAdUnitIds(),
    interstitial: cfg.get('interstitial')?.toAdUnitIds(),
    rewarded: cfg.get('rewarded')?.toAdUnitIds(),
    rewardedInterstitial: cfg.get('rewardedInterstitial')?.toAdUnitIds(),
    preloadBanners: true,
    preloadNativeAds: true,
  );
}

/// Local safe fallback (testing + test ids)
Future<void> _initializeAdsFallback() async {
  await AdsManager.initialize(
    env: AdsEnvironment.testing,
    testDeviceIds: const ['TEST_DEVICE_ID'],
    appOpen: AdUnitIds(android: _TestIds.appOpenAndroid, ios: _TestIds.appOpenIos, adsDisable: false),
    banner: AdUnitIds(android: _TestIds.bannerAndroid, ios: _TestIds.bannerIos, adsDisable: false),
    native: AdUnitIds(android: _TestIds.nativeAndroid, ios: _TestIds.nativeIos, adsDisable: false),
    interstitial: AdUnitIds(android: _TestIds.interstitialAndroid, ios: _TestIds.interstitialIos, adsDisable: false),
    rewarded: AdUnitIds(android: _TestIds.rewardedAndroid, ios: _TestIds.rewardedIos, adsDisable: false),
    rewardedInterstitial: AdUnitIds(android: _TestIds.rewardedInterstitialAndroid, ios: _TestIds.rewardedInterstitialIos, adsDisable: false),
  );
}

/// ------------------ Lightweight config models ------------------
class _AdPlacementCfg {
  String? android;
  String? ios;
  bool adsDisable;
  int adsFrequencySec;

  _AdPlacementCfg({
    required this.android,
    required this.ios,
    required this.adsDisable,
    required this.adsFrequencySec,
  });

  factory _AdPlacementCfg.fromMap(Map<String, dynamic>? map) {
    map ??= const {};
    return _AdPlacementCfg(
      android: _asNullableStr(map['android']),
      ios: _asNullableStr(map['ios']),
      adsDisable: (map['adsDisable'] ?? false) == true,
      adsFrequencySec: (map['adsFrequencySec'] is int)
          ? (map['adsFrequencySec'] as int)
          : int.tryParse('${map['adsFrequencySec'] ?? 0}') ?? 0,
    );
  }

  AdUnitIds toAdUnitIds() => AdUnitIds(
    android: android,
    ios: ios,
    adsDisable: adsDisable,
    adsFrequencySec: adsFrequencySec,
  );

  static String? _asNullableStr(dynamic v) {
    final s = v?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  /// Fill missing/null IDs with Google test IDs for this placement
  void fillWithTestIds(String placementKey) {
    switch (placementKey) {
      case 'banner':
        android ??= _TestIds.bannerAndroid;
        ios ??= _TestIds.bannerIos;
        break;
      case 'interstitial':
        android ??= _TestIds.interstitialAndroid;
        ios ??= _TestIds.interstitialIos;
        break;
      case 'rewarded':
        android ??= _TestIds.rewardedAndroid;
        ios ??= _TestIds.rewardedIos;
        break;
      case 'rewardedInterstitial':
        android ??= _TestIds.rewardedInterstitialAndroid;
        ios ??= _TestIds.rewardedInterstitialIos;
        break;
      case 'appOpen':
        android ??= _TestIds.appOpenAndroid;
        ios ??= _TestIds.appOpenIos;
        break;
      case 'native':
        android ??= _TestIds.nativeAndroid;
        ios ??= _TestIds.nativeIos;
        break;
      default:
        break;
    }
  }
}

class _AdsConfig {
  AdsEnvironment env;
  final List<String> testDeviceIds;
  final Map<String, _AdPlacementCfg> placements;

  _AdsConfig({
    required this.env,
    required this.testDeviceIds,
    required this.placements,
  });

  factory _AdsConfig.fromMap(Map<String, dynamic> map) {
    final envStr = (map['env'] ?? 'testing').toString().toLowerCase();
    final env = envStr == 'production'
        ? AdsEnvironment.production
        : AdsEnvironment.testing;

    final tdi = <String>[];
    final rawTdi = map['testDeviceIds'];
    if (rawTdi is List) {
      for (final e in rawTdi) {
        if (e != null) tdi.add(e.toString());
      }
    }

    final plc = <String, _AdPlacementCfg>{};
    final rawPlacements = map['placements'];
    if (rawPlacements is Map<String, dynamic>) {
      for (final entry in rawPlacements.entries) {
        plc[entry.key] =
            _AdPlacementCfg.fromMap(entry.value as Map<String, dynamic>?);
      }
    }

    // Ensure all known placements exist
    for (final k in const [
      'appOpen',
      'banner',
      'native',
      'interstitial',
      'rewarded',
      'rewardedInterstitial'
    ]) {
      plc.putIfAbsent(k, () => _AdPlacementCfg.fromMap(const {}));
    }

    return _AdsConfig(env: env, testDeviceIds: tdi, placements: plc);
  }

  _AdPlacementCfg? get(String key) => placements[key];

  _AdsConfig normalizeEnvAndFillTestIds() {
    for (final entry in placements.entries) {
      entry.value.fillWithTestIds(entry.key);
    }
    return this;
  }
}

/// ------------------ Google official test IDs ------------------
class _TestIds {
  static const bannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const bannerIos = 'ca-app-pub-3940256099942544/2934735716';

  static const interstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const interstitialIos = 'ca-app-pub-3940256099942544/4411468910';

  static const rewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const rewardedIos = 'ca-app-pub-3940256099942544/1712485313';

  static const rewardedInterstitialAndroid =
      'ca-app-pub-3940256099942544/5354046379';
  static const rewardedInterstitialIos =
      'ca-app-pub-3940256099942544/6978759866';

  static const appOpenAndroid = 'ca-app-pub-3940256099942544/9257395921';
  static const appOpenIos = 'ca-app-pub-3940256099942544/5575463023';

  static const nativeAndroid = 'ca-app-pub-3940256099942544/2247696110';
  static const nativeIos = 'ca-app-pub-3940256099942544/3986624511';
}