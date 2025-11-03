// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:listen1_xuan/models/SupaContinuePlay.dart';

import 'package:logger/logger.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../global_settings_animations.dart';
import 'settings_controller.dart';
import 'websocket_card_controller.dart';
import 'supabase_auth_controller.dart';
import 'BroadcastWsController.dart';
import 'package:windows_taskbar/windows_taskbar.dart';
import '../play.dart'; // 导入 safeCallWindowsTaskbar

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
  final logger = Logger();
  final _next_track = Rx<Track?>(null);

  // Windows任务栏进度 (0-100)
  final taskbarProgress = 0.obs;

  // Sheet 控制相关
  final SheetController sheetController = SheetController();
  double get sheetMinHeight => 256.0.w;
  SheetOffset get sheetMinOffset =>
      SheetOffset(sheetMinHeight / playVMaxHeight);
  double get sheetMidHeight => 0.8.sw;
  SheetOffset get sheetMidOffset =>
      SheetOffset(sheetMidHeight / playVMaxHeight);
  double get playVMaxHeight => _playVMaxHeight ?? 0.8.sh;
  double? _playVMaxHeight;
  SheetOffset get playVMaxOffset => SheetOffset(1);
  set playVMaxHeight(double value) {
    _playVMaxHeight = value;
  }

  final sheetExpandRatio = 0.0.obs; // 展开比例 0.0-1.0

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

    androidEQEnabled =
        Get.find<SettingsController>().settings[androidEQEnabledKey] ?? false;
    if (is_windows || !androidEQEnabled) {
      music_player = AudioPlayer();
    } else {
      equalizer = AndroidEqualizer();
      music_player = AudioPlayer(
        audioPipeline: AudioPipeline(androidAudioEffects: [equalizer]),
      );
      initAndroidEqualizer();
    }
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
      updateContinuePlay();
    });
    
    // 使用 interval 控制任务栏进度更新频率(每500ms最多更新一次)
    if (is_windows) {
      interval(
        taskbarProgress,
        (progress) {
          safeCallWindowsTaskbar(
            () => WindowsTaskbar.setProgress(progress, 100),
            'setProgress',
          );
        },
        time: Duration(milliseconds: 500),
      );
    }
  }

  final RxMap<int, AndroidEQBand> _bands = RxMap<int, AndroidEQBand>();
  final androidEQInited = false.obs;

  // Getter 用于访问频段数据
  Map<int, AndroidEQBand> get bands => _bands;
  double minGain = -1.0;
  double maxGain = 1.0;
  bool androidEQEnabled = false;
  static const String androidEQEnabledKey = 'android_equalizer_enabled';
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
    logger.d('Saved equalizer bands: $bandsList');

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

  /// 更新当前播放状态到 Supabase
  /// 将当前曲目、播放状态等信息同步到云端
  Future<void> updateContinuePlay() async {
    try {
      // 检查是否已登录
      final authController = Get.find<SupabaseAuthController>();
      if (!authController.isLoggedIn.value) {
        logger.w('用户未登录，跳过同步播放状态');
        return;
      }

      // 获取当前曲目
      if (_current_playing.isEmpty) {
        logger.w('当前播放列表为空，跳过同步');
        return;
      }

      final track = currentTrack;
      if (track.id.isEmpty) {
        logger.w('当前曲目ID为空，跳过同步');
        return;
      }

      // 获取设备ID
      final broadcastController = Get.find<BroadcastWsController>();
      final deviceId = broadcastController.deviceId;

      // 创建 SupaContinuePlay 对象
      final continuePlay = SupaContinuePlay(
        track: track,
        playing: isplaying.value,
        deviceId: deviceId,
        ext: {
          'volume': _player_settings['volume'],
          'playmode': _player_settings['playmode'],
        },
      );

      // 使用 upsert 操作（insert on conflict update）
      final supabase = Supabase.instance.client;
      final userId = authController.currentUser.value?.id;

      await supabase.from('continue_play').upsert(
        {
          'user_id': userId,
          'track': continuePlay.track.toJson(),
          'playing': continuePlay.playing,
          'ext': continuePlay.ext,
          'device_id': continuePlay.deviceId,
        },
        onConflict: 'user_id', // 根据 user_id 冲突时更新
      );

      logger.d('成功同步播放状态到 Supabase');
    } catch (e) {
      logger.e('同步播放状态失败: $e');
    }
  }

  /// 从 Supabase 查询当前用户的播放状态
  /// 返回 SupaContinuePlay 对象，如果没有数据返回 null
  Future<SupaContinuePlay?> getContinuePlay() async {
    try {
      // 检查是否已登录
      final authController = Get.find<SupabaseAuthController>();
      if (!authController.isLoggedIn.value) {
        logger.w('用户未登录，无法查询播放状态');
        return null;
      }

      final supabase = Supabase.instance.client;
      final userId = authController.currentUser.value?.id;

      final response = await supabase
          .from('continue_play')
          .select()
          .eq('user_id', userId!)
          .maybeSingle();

      if (response == null) {
        logger.d('当前用户没有播放状态数据');
        return null;
      }

      // 解析数据
      final continuePlay = SupaContinuePlay(
        track: Track.fromJson(response['track'] as Map<String, dynamic>),
        updTime: DateTime.parse(response['upd_time'] as String),
        playing: response['playing'] as bool,
        ext: response['ext'] as Map<String, dynamic>?,
        deviceId: response['device_id'] as String,
      );

      logger.d('成功获取播放状态: ${continuePlay.track.title}');
      return continuePlay;
    } catch (e) {
      logger.e('查询播放状态失败: $e');
      return null;
    }
  }
}
