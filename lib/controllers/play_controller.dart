// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'package:listen1_xuan/models/Track.dart';

import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../global_settings_animations.dart';
import 'settings_controller.dart';
import 'websocket_card_controller.dart';

class PlayController extends GetxController {
  final music_player = AudioPlayer();
  final _player_settings = <String, dynamic>{}.obs;
  final _current_playing = <Track>[].obs;

  final _next_track = Rx<Track?>(null);
  set nextTrack(Track? track) {
    _next_track.value = track;
  }

  Track? get nextTrack => _next_track.value;

  var isplaying = false.obs;

  double get currentVolume => (_player_settings['volume'] ?? 50.0) / 100.0;
  set currentVolume(double value) {
    _player_settings['volume'] = value * 100.0;
    music_player.setVolume(value);
  }

  Set<String> get playingIds {
    return _current_playing.map((track) => track.id).toSet();
  }

  Track get currentTrack => _current_playing.isNotEmpty
      ? _current_playing.firstWhere(
          (track) =>
              track.id ==
              Get.find<PlayController>().getPlayerSettings(
                "nowplaying_track_id",
              ),
        )
      : Track(id: '');
  @override
  void onInit() {
    super.onInit();
    debounce(_player_settings, (event) {
      _saveSingleSetting('player-settings');
    });
    debounce(_current_playing, (event) {
      _saveSingleSetting('current-playing');
    });
    music_player.playingStream.listen((event) {
      isplaying.value = event;
    });
    ever(isplaying, (callback) {
      broadcastWs();
    });
  }

  Future<void> _saveSingleSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    switch (key) {
      case 'player-settings':
        String jsonString = jsonEncode(_player_settings);
        await prefs.setString(key, jsonString);
        break;
      case 'current-playing':
        String jsonString = jsonEncode(_current_playing);
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
          xuan_toast(msg: '循环');
          break;
        case 1:
          xuan_toast(msg: '随机');
          break;
        case 2:
          xuan_toast(msg: '单曲');
          break;
        default:
          break;
      }
    }
    _player_settings[key] = value;
  }

  void loadDatas() {
    _player_settings.value =
        Get.find<SettingsController>().PlayController_player_settings;
    _current_playing.value =
        Get.find<SettingsController>().PlayController_current_playing;
  }

  List<Track> get current_playing => _current_playing.toList();
  void add_current_playing(List<Track> tracks) {
    for (var track in tracks) {
      if (!_current_playing.any((element) => element.id == track.id)) {
        _current_playing.add(track);
      }
    }
  }

  void set_current_playing(List<Track> tracks) {
    _current_playing.value = tracks;
  }

  Track? getTrackById(String id) {
    return _current_playing.firstWhereOrNull((track) => track.id == id);
  }
}
