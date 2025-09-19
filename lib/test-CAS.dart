import 'package:clever_ads_solutions/clever_ads_solutions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const String _casId = 'demo';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<BannerWidgetState> _bannerKey = GlobalKey();

  final CASAppOpen _appOpen = CASAppOpen.create(_casId);
  final CASInterstitial _interstitial = CASInterstitial.create(_casId);
  final CASRewarded _rewarded = CASRewarded.create(_casId);

  String? _sdkVersion;

  final OnAdImpressionListener _impressionListener = OnAdImpressionListener(
          (ad) async => logDebug(
          '${await ad.getFormat()} ad impression: ${await ad.getSourceName()}'));

  final _bannerListener = AdViewListener(
    onAdViewLoaded: () => logDebug('Banner ad loaded!'),
    onAdViewFailed: (message) => logDebug('Banner failed! $message'),
    onAdViewClicked: () => logDebug('Banner ad clicked!'),
  );

  final ScreenAdContentCallback _contentCallback = ScreenAdContentCallback(
    onAdLoaded: (ad) async => logDebug(
        '${await ad.getFormat()} ad loaded: ${await ad.getSourceName()}'),
    onAdFailedToLoad: (format, error) =>
        logDebug('$format ad failed to load: $error'),
    onAdShowed: (ad) async => logDebug(
        '${await ad.getFormat()} ad showed: ${await ad.getSourceName()}'),
    onAdFailedToShow: (format, error) =>
        logDebug('$format ad failed to show: $error'),
    onAdClicked: (ad) async => logDebug(
        '${await ad.getFormat()} ad clicked: ${await ad.getSourceName()}'),
    onAdDismissed: (ad) async => logDebug(
        '${await ad.getFormat()} ad dismissed: ${await ad.getSourceName()}'),
  );

  @override
  void initState() {
    super.initState();
    _initializeCAS();

    _loadAppOpenAd();
    _loadInterstitialAd();
    _loadRewardedAd();

    _getNativeSDKVersion();
  }

  @override
  void dispose() {
    super.dispose();
    _appOpen.dispose();
    _interstitial.dispose();
    _rewarded.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CAS.AI Sample'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_sdkVersion != null) Text('CAS.AI $_sdkVersion'),
                const Spacer(),
                Text('Plugin version ${CAS.getPluginVersion()}'),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                children: [
                  LayoutBuilder(
                      builder: (_, constraints) =>
                          _buildBannerAdWidget(constraints.maxWidth)),
                  ElevatedButton(
                    child: const Text('Load next ad on upper widget'),
                    onPressed: () => _bannerKey.currentState?.load(),
                  ),
                  ElevatedButton(
                    onPressed: _showAppOpen,
                    child: const Text('Show App Open'),
                  ),
                  ElevatedButton(
                    onPressed: _showInterstitial,
                    child: const Text('Show Interstitial'),
                  ),
                  ElevatedButton(
                    onPressed: _showRewarded,
                    child: const Text('Show Rewarded'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _initializeCAS() {
    // Set Ads Settings
    CAS.settings.setDebugMode(true);
    CAS.settings.setTaggedAudience(Audience.notChildren);

    // Configure Consent flow
    final ConsentFlow consentFlow = ConsentFlow.create().setOnDismissCallback(_onConsentFlowDismissed).withPrivacyPolicy('https://example.com/');

    // Initialize SDK
    CAS
        .buildManager()
        .withCasId(_casId)
        .withTestMode(kDebugMode)
        .withConsentFlow(consentFlow)
        .withCompletionListener(_onInitializationCompleted)
        .build();
  }

  void _getNativeSDKVersion() async {
    final String sdkVersion = await CAS.getSDKVersion();
    setState(() {
      _sdkVersion = sdkVersion;
    });
  }

  void _onConsentFlowDismissed(int status) {
    switch (status) {
      case ConsentFlow.statusObtained:
      // Consent obtained
        break;
    }
    logDebug('Consent flow dismissed: $status');
  }

  void _onInitializationCompleted(InitConfig initConfig) async {
    final String? error = initConfig.error;
    if (error != null) {
      logDebug('Ad manager initialization failed: $error');
      return;
    }
    logDebug('Ad manager initialized');
  }

  Widget _buildBannerAdWidget(double maxWidth) {
    return BannerWidget(
      key: _bannerKey,
      casId: _casId,
      adListener: _bannerListener,
      onImpressionListener: _impressionListener,
      size: AdSize.getAdaptiveBanner(maxWidth),
      isAutoloadEnabled: true,
      refreshInterval: 30,
    );
  }

  void _loadAppOpenAd() {
    _appOpen.contentCallback = _contentCallback;
    _appOpen.impressionListener = _impressionListener;
    _appOpen.setAutoloadEnabled(false); // by default
    _appOpen.setAutoshowEnabled(false); // by default
    _appOpen.load(); // if autoload disabled
  }

  void _showAppOpen() async {
    _appOpen.show();
  }

  void _loadInterstitialAd() {
    _interstitial.contentCallback = _contentCallback;
    _interstitial.impressionListener = _impressionListener;
    _interstitial.setAutoloadEnabled(false); // by default
    _interstitial.setAutoshowEnabled(false); // by default
    _interstitial.setMinInterval(0); // by default
    _interstitial.load(); // if autoload disabled
  }

  void _showInterstitial() async {
    if (await _interstitial.isLoaded()) {
      _interstitial.show();
    } else {
      logDebug('Interstitial ad not ready to show');
    }
  }

  void _loadRewardedAd() {
    _rewarded.contentCallback = _contentCallback;
    _rewarded.impressionListener = _impressionListener;
    _rewarded.setExtraFillInterstitialAdEnabled(true); // by default
    _rewarded.setAutoloadEnabled(false); // by default
    _rewarded.load(); // if autoload disabled
  }

  void _showRewarded() async {
    if (await _rewarded.isLoaded()) {
      _rewarded.show(OnRewardEarnedListener((ad) async {
        logDebug('Rewarded ad earned reward: ${await ad.getSourceName()}');
      }));
    } else {
      logDebug('Rewarded ad not ready to show');
    }
  }
}

void logDebug(String message) {
  if (kDebugMode) {
    debugPrint('CAS.AI.Flutter.Example: $message');
  }
}