import 'package:get/get.dart';
import 'package:listen1_xuan/settings.dart';

import 'settings_controller.dart';

export 'cache_controller.dart';
export 'lyric_controller.dart';
export 'play_controller.dart';
export 'audioHandler_controller.dart';
export 'settings_controller.dart';

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
    Get.find<SettingsController>().setSettings({
      'hideOrMinimize': hideOrMinimize.value,
    });
  }

  Future<void> loadSettings() async {
    var settings = settings_getsettings();
    hideOrMinimize.value = settings['hideOrMinimize'] ?? false;
  }
}
