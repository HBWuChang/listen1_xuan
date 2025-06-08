import 'dart:math';

import 'package:get/get.dart';
import 'package:listen1_xuan/settings.dart';

class SthSettingsController extends GetxController {
  var hideOrMinimize = false.obs;
  @override
  void onInit() {
    super.onInit();
    ever(hideOrMinimize, (value) {
      saveSettings();
    });
  }

  Future<void> saveSettings() async {
    await settings_setsettings({
      'hideOrMinimize': hideOrMinimize.value,
    });
  }

  Future<void> loadSettings() async {
    var settings = await settings_getsettings();
    hideOrMinimize.value = settings['hideOrMinimize'] ?? false;
  }
}
