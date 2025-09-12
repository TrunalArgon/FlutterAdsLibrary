import 'package:get/get.dart';
import '../controllers/native_screen_controller.dart';

class NativeScreenBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NativeScreenController>(() => NativeScreenController());
  }
}