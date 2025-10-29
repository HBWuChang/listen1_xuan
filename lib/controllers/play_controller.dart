// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/models/Track.dart';

import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../global_settings_animations.dart';
import 'settings_controller.dart';
import 'websocket_card_controller.dart';

class AndroidEQBand {
  int index;
  double gain;
  double? upperFrequency;
  double? lowerFrequency;
  double? centerFrequency;

  AndroidEQBand({
    required this.index,
    required this.gain,
    this.upperFrequency,
    this.lowerFrequency,
    this.centerFrequency,
  });
  AndroidEQBand.fromAndroidEqualizerBand(AndroidEqualizerBand androidEQBand)
    : index = androidEQBand.index,
      gain = androidEQBand.gain,
      upperFrequency = androidEQBand.upperFrequency,
      lowerFrequency = androidEQBand.lowerFrequency,
      centerFrequency = androidEQBand.centerFrequency;
  factory AndroidEQBand.fromJson(Map<String, dynamic> json) {
    return AndroidEQBand(index: json['index'], gain: json['gain']);
  }
  Map<String, dynamic> toJson() {
    return {'index': index, 'gain': gain};
  }
}

class PlayController extends GetxController {
  late AndroidEqualizer equalizer;
  late AudioPlayer music_player;
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
    // if (is_windows) {
      music_player = AudioPlayer();
    // } else {
    //   equalizer = AndroidEqualizer();
    //   music_player = AudioPlayer(
    //     audioPipeline: AudioPipeline(androidAudioEffects: [equalizer]),
    //   );
    //   initAndroidEqualizer();
    // }
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

  final RxMap<int, AndroidEQBand> _bands = RxMap<int, AndroidEQBand>();
  final androidEQInited = false.obs;

  // Getter 用于访问频段数据
  Map<int, AndroidEQBand> get bands => _bands;
  double minGain = -1.0;
  double maxGain = 1.0;
  Future<void> initAndroidEqualizer() async {
    // 从设置中加载保存的频段数据
    final savedBands =
        Get.find<SettingsController>().settings['android_equalizer_bands'];

    if (savedBands != null && savedBands is List) {
      // 将 List 转换为 Map
      _bands.value = Map<int, AndroidEQBand>.fromEntries(
        savedBands.map<MapEntry<int, AndroidEQBand>>(
          (value) => MapEntry(
            value['index'] as int,
            AndroidEQBand.fromJson(value as Map<String, dynamic>),
          ),
        ),
      );
    }

    await equalizer.setEnabled(true);
    final parameters = await equalizer.parameters;
    minGain = parameters.minDecibels;
    maxGain = parameters.maxDecibels;
    for (var band in _bands.values) {
      band.gain = band.gain.clamp(minGain, maxGain);
    }
    final bands = parameters.bands;
    for (var band in bands) {
      if (_bands.containsKey(band.index)) {
        await band.setGain(_bands[band.index]!.gain);
        _bands[band.index]!.upperFrequency = band.upperFrequency;
        _bands[band.index]!.lowerFrequency = band.lowerFrequency;
        _bands[band.index]!.centerFrequency = band.centerFrequency;
      } else {
        _bands[band.index] = AndroidEQBand.fromAndroidEqualizerBand(band);
      }
    }
    androidEQInited.value = true;
    debounce(_bands, (callback) {
      _saveEqualizerBands();
    }, time: Duration(milliseconds: 100));
  }

  // 设置特定频段的增益
  void setBandGain(int bandIndex, double gain) {
    if (!_bands.containsKey(bandIndex)) return;

    // 更新本地数据
    _bands[bandIndex]!.gain = gain;
    _bands.refresh();
  }

  // 保存均衡器频段设置
  Future<void> _saveEqualizerBands() async {
    // 应用到均衡器
    final parameters = await equalizer.parameters;
    final bands = parameters.bands;
    for (var band in bands) {
      final bandData = _bands[band.index];
      if (bandData != null) {
        await band.setGain(bandData.gain);
      }
    }
    final bandsList = _bands.values.map((band) => band.toJson()).toList();
    Get.find<SettingsController>().settings['android_equalizer_bands'] =
        bandsList;
    bool isPlayingBefore = music_player.playing;
    if (isPlayingBefore) await music_player.stop();
    // await music_player.load();
    if (isPlayingBefore) await music_player.play();
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
          showInfoSnackbar('循环', null);
          break;
        case 1:
          showInfoSnackbar('随机', null);
          break;
        case 2:
          showInfoSnackbar('单曲', null);
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
