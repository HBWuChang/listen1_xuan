import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends GetxController {
  var settings = <String, dynamic>{}.obs;
  var portraitBottomBarPadding = 0.0.obs;

  Timer? _saveTimer;
  @override
  void onInit() {
    super.onInit();
    ever(settings, (callback) {
      if (_saveTimer?.isActive ?? false) _saveTimer!.cancel();
      _saveTimer = Timer(const Duration(seconds: 1), () {
        _saveSettings();
      });
    });
    
    // 监听 portraitBottomBarPadding 变化并保存到 settings
    ever(portraitBottomBarPadding, (value) {
      settings['portraitBottomBarPadding'] = value;
    });
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('settings');
    if (jsonString != null) {
      settings.value = jsonDecode(jsonString);
    }
    
    // 加载 portraitBottomBarPadding 的值
    portraitBottomBarPadding.value = (settings['portraitBottomBarPadding'] ?? 0.0).toDouble();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String jsonString = jsonEncode(settings);
    await prefs.setString('settings', jsonString);
  }

  setSettings(Map<String, dynamic> settings) {
    this.settings.addAll(settings);
  }

  setSetting(String key, dynamic value) {
    settings[key] = value;
  }
}
