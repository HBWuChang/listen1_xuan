import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../global_settings_animations.dart';

class PlayController extends GetxController {
  final music_player = AudioPlayer();
  var _player_settings = <String, dynamic>{}.obs;
  Timer? _save_player_settings_Timer;
  double get currentVolume => (_player_settings['volume'] ?? 50.0) / 100.0;
  set currentVolume(double value) {
    _player_settings['volume'] = value* 100.0;
    music_player.setVolume(value);
  }

  @override
  void onInit() {
    super.onInit();
    ever(_player_settings, (callback) {
      _addTimer(_save_player_settings_Timer, 'player-settings');
    });
  }

  void _addTimer(Timer? timer, String key) {
    if (timer?.isActive ?? false) {
      timer!.cancel();
    }
    timer = Timer(const Duration(seconds: 1), () {
      _saveSingleSetting(key);
    });
  }

  Future<void> _saveSingleSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    switch (key) {
      case 'player-settings':
        String jsonString = jsonEncode(_player_settings);
        await prefs.setString(key, jsonString);
        break;
      default:
        throw Exception('Unknown key: $key');
    }
  }

  dynamic getPlayerSettings(String key) {
    return _player_settings[key];
  }

  void setPlayerSetting(String key, dynamic value) {
    if (key == 'playmode') {
      switch (value) {
        case 0:
          xuan_toast(
            msg: '循环',
          );
          break;
        case 1:
          xuan_toast(
            msg: '随机',
          );
          break;
        case 2:
          xuan_toast(
            msg: '单曲',
          );
          break;
        default:
          break;
      }
    }
    _player_settings[key] = value;
  }

  Future<void> loadDatas() async {
    final prefs = await SharedPreferences.getInstance();
    final player_settings = await prefs.getString('player-settings');
    if (player_settings != null) {
      try {
        _player_settings.value = jsonDecode(player_settings);
      } catch (e) {}
    }
  }
}
