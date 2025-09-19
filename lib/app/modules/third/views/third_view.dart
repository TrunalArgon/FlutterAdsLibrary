import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/third_controller.dart';

class ThirdView extends GetView {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThirdController>(
      init: ThirdController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(title: Text('CAS TEST'), centerTitle: true),
          body: Column(
            children: [

            ],
          ),
        );
      },
    );
  }
}