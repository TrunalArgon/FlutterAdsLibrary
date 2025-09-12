import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ads_manager_platform_interface.dart';

/// An implementation of [AdsManagerPlatform] that uses method channels.
class MethodChannelAdsManager extends AdsManagerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ads_manager');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
