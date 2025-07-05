import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends GetxController {
  var settings = <String, dynamic>{}.obs;

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
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('settings');
    if (jsonString != null) {
      settings.value = jsonDecode(jsonString);
    }
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
