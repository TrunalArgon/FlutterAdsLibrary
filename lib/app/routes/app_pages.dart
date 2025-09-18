import 'package:get/get.dart';

import '../modules/BannerScreen/bindings/banner_screen_binding.dart';
import '../modules/BannerScreen/views/banner_screen_view.dart';
import '../modules/NativeScreen/bindings/native_screen_binding.dart';
import '../modules/NativeScreen/views/native_screen_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/second/bindings/second_binding.dart';
import '../modules/second/views/second_view.dart';
import '../modules/third/bindings/third_binding.dart';
import '../modules/third/views/third_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.HOME;

  static final routes = [
    GetPage(
      name: _Paths.HOME,
      page: () => HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.BANNER_SCREEN,
      page: () => BannerScreenView(),
      binding: BannerScreenBinding(),
    ),
    GetPage(
      name: _Paths.NATIVE_SCREEN,
      page: () => NativeScreenView(),
      binding: NativeScreenBinding(),
    ),
    GetPage(
      name: _Paths.SECOND,
      page: () => const SecondView(),
      binding: SecondBinding(),
    ),
    GetPage(
      name: _Paths.THIRD,
      page: () => const ThirdView(),
      binding: ThirdBinding(),
    ),
  ];
}
