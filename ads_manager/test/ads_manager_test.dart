import 'package:flutter_test/flutter_test.dart';
import 'package:ads_manager/ads_manager.dart';
import 'package:ads_manager/ads_manager_platform_interface.dart';
import 'package:ads_manager/ads_manager_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAdsManagerPlatform
    with MockPlatformInterfaceMixin
    implements AdsManagerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final AdsManagerPlatform initialPlatform = AdsManagerPlatform.instance;

  test('$MethodChannelAdsManager is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAdsManager>());
  });

  test('getPlatformVersion', () async {
    AdsManager adsManagerPlugin = AdsManager();
    MockAdsManagerPlatform fakePlatform = MockAdsManagerPlatform();
    AdsManagerPlatform.instance = fakePlatform;

    expect(await adsManagerPlugin.getPlatformVersion(), '42');
  });
}
