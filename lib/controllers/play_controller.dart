// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:listen1_xuan/controllers/cache_controller.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/main.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:listen1_xuan/models/SupaContinuePlay.dart';

import 'package:logger/logger.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../global_settings_animations.dart';
import '../loweb.dart';
import '../models/AndroidEQBand.dart';
import '../utils/curve_utils.dart';
import 'package:media_kit_libs_audio/media_kit_libs_audio.dart';
import 'lyric_controller.dart';
import 'nowplaying_controller.dart';
import 'settings_controller.dart';
import 'websocket_card_controller.dart';
import 'supabase_auth_controller.dart';
import 'BroadcastWsController.dart';
import 'package:windows_taskbar/windows_taskbar.dart';
import '../play.dart'; // 导入 safeCallWindowsTaskbar

class PlayController extends GetxController
    with GetSingleTickerProviderStateMixin {
  // late AndroidEqualizer equalizer;
  late Player music_player;
  CacheController cacheController = Get.find<CacheController>();
  final _player_settings = <String, dynamic>{}.obs;
  final currentPlayingRx = <Track>[].obs;
  final logger = Logger();
  final updatePosToAudioServiceNow = 0.obs;
  final _next_track = Rx<Track?>(null);
  RxString nowPlayingTrackIdRx = ''.obs;
  String get nowPlayingTrackId => nowPlayingTrackIdRx.value;
  set nowPlayingTrackId(String value) {
    nowPlayingTrackIdRx.value = value;
  }

  ///用于记录正在引导播放的曲目id及下载文件名
  final bootStraping = RxMap<String, String>();

  // Windows任务栏进度 (0-100)
  final taskbarProgress = 0.obs;

  set nextTrack(Track? track) {
    _next_track.value = track;
  }

  Track? get nextTrack => _next_track.value;

  var isplaying = false.obs;

  double get currentVolume => _player_settings['volume'] ?? 50.0;
  set currentVolume(double value) {
    _player_settings['volume'] = value;
    music_player.setVolume(value);
  }

  Set<String> get playingIds {
    return currentPlayingRx.map((track) => track.id).toSet();
  }

  Track get currentTrack => currentPlayingRx.isNotEmpty
      ? currentPlayingRx.firstWhere((track) => track.id == nowPlayingTrackId)
      : Track(id: '');

  @override
  void onInit() {
    super.onInit();
    music_player = Player();
    // 初始化播放按钮旋转动画控制器
    playVPlayBtnProcessControllerInit();
    // androidEQEnabled =
    //     Get.find<SettingsController>().settings[androidEQEnabledKey] ?? false;
    // if (!isAndroid || !androidEQEnabled) {
    //   music_player = AudioPlayer();
    // } else {
    //   equalizer = AndroidEqualizer();
    //   music_player = AudioPlayer(
    //     audioPipeline: AudioPipeline(androidAudioEffects: [equalizer]),
    //   );
    //   initAndroidEqualizer();
    // }
    ever(_player_settings, (event) {
      final t = event['nowplaying_track_id'];
      if ((!isEmpty(t)) && t is String && t != nowPlayingTrackIdRx.value) {
        nowPlayingTrackIdRx.value = event['nowplaying_track_id'];
      }
    });
    ever(nowPlayingTrackIdRx, (callback) {
      _player_settings['nowplaying_track_id'] = callback;
    });
    debounce(_player_settings, (event) {
      _saveSingleSetting('player-settings');
    });
    debounce(currentPlayingRx, (event) {
      _saveSingleSetting('current-playing');
    });
    music_player.stream.playing.listen((event) {
      isplaying.value = event;
    });
    ever(isplaying, (callback) {
      broadcastWs();
      updateContinuePlay();
    });
    debounce(showPlayVInlineLyricVisible, (value) {
      if (value) {
        showPlayVInlineLyricOp.value = true;
      }
    }, time: Duration(milliseconds: 100));
    debounce(showPlayVInlineLyricOp, (value) {
      if (!value) {
        showPlayVInlineLyricVisible.value = false;
      }
    }, time: Duration(milliseconds: 300));
    // 使用 interval 控制任务栏进度更新频率(每500ms最多更新一次)
    if (isWindows) {
      interval(taskbarProgress, (progress) {
        safeCallWindowsTaskbar(
          () => WindowsTaskbar.setProgress(progress, 100),
          'setProgress',
        );
      }, time: Duration(milliseconds: 500));
    }
    // 监听 isplaying 状态
    ever(isplaying, (playing) {
      try {
        if (playing) {
          // 开始旋转
          if (!playVPlayBtnProcessController.isAnimating) {
            playVPlayBtnProcessController.repeat();
          }
        } else {
          // 停止旋转
          playVPlayBtnProcessController.stop();
        }
      } catch (e) {
        logger.e("播放按钮旋转动画错误：$e");
      }
    });
    ever(playButtonRotationCurve, (curveName) {
      try {
        playButtonRotationCurveValue = CurveUtils.getCurveByName(curveName);
        settingsController.settings[SettingsController
                .playButtonRotationCurveKey] =
            curveName;
      } catch (e) {
        logger.e("播放按钮旋转曲线设置错误：$e");
      }
    });
    playButtonRotationCurve.value =
        settingsController.settings[SettingsController
            .playButtonRotationCurveKey] ??
        'easeInSine';
  }

  @override
  void onClose() {
    playVPlayBtnProcessController.dispose();
    music_player.dispose();
    super.onClose();
  }

  Future<void> playsong(
    Track track, {
    bool start = true,
    bool onBootstrapTrackSuccessCallback = false,
    bool isByClick = false,
  }) async {
    try {
      //若引导成功，但用户最终意图播放的不是该曲目，则返回
      //若意图播放的曲目已经在引导中，则返回
      if ((onBootstrapTrackSuccessCallback && nowPlayingTrackId != track.id) ||
          bootStraping.containsKey(track.id)) {
        // 若已在引导，但为点击播放，则更新当前播放id
        if (isByClick) {
          nowPlayingTrackId = track.id;
        }
        return;
      }
      nowPlayingTrackId = track.id;

      add_current_playing([track]);
      Get.find<NowPlayingPageController>().scrollToCurrentTrack?.call();
      final tdir = await get_local_cache(track.id);
      debugPrint('playsong');
      debugPrint(track.toString());
      debugPrint(tdir);
      if (tdir == "") {
        // 无本地文件，引导播放
        bootStraping[track.id] = "";
        MediaService.bootstrapTrack(track, start: start);
        return;
      }
      // 有缓存，直接播放
      Media media = Media(tdir);
      await music_player.open(media, play: false);
      if (!randommodetemplist.any((element) => element.id == track.id)) {
        if (randomTrackInsertAtHead) {
          randommodetemplist.insert(0, track);
          randomTrackInsertAtHead = false;
        } else {
          randommodetemplist.add(track);
        }
      } else if (isByClick) {
        // 如果是点击播放，且当前歌曲已经在随机列表中，则将其移动到列表头部
        randommodetemplist.removeWhere((element) => element.id == track.id);
        randommodetemplist.add(track);
      }

      Get.find<LyricController>().loadLyric();
      double t_volume = 100;
      try {
        t_volume = Get.find<PlayController>().getPlayerSettings("volume");
      } catch (e) {
        t_volume = 100;
        Get.find<PlayController>().setPlayerSetting("volume", t_volume);
      }
      Get.find<PlayController>().music_player.setVolume(t_volume);
      if (start) {
        Get.find<PlayController>().music_player.play();
      }
      await change_playback_state(track);
    } catch (e, stackTrace) {
      debugPrint('播放失败!!!!');
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());
    }
  }

  Future<void> bootstrapTrackSuccess(
    dynamic res,
    Track track, {
    bool start = true,
  }) async {
    try {
      if (isEmpty(await cacheController.getLocalCache(track.id))) {
        await cacheController.downloadAndCacheFile(res, track);
      }
      // 理论上此时应歌曲文件准备完毕
      bootStraping.remove(track.id);
      playsong(track, start: start, onBootstrapTrackSuccessCallback: true);
    } catch (e) {
      debugPrint('Error downloading or playing audio: $e');
      bootstrapTrackFail(track);
    }
  }

  Future<void> bootstrapTrackFail(Track track) async {
    debugPrint('bootstrapTrackFail');
    debugPrint(track.toJson().toString());
    // {id: netrack_2084034562, title: Anytime Anywhere, artist: milet, artist_id: neartist_31464106, album: Anytime Anywhere, album_id: nealbum_175250775, source: netease, source_url: https://music.163.com/#/song?id=2084034562, img_url: https://p1.music.126.net/11p2mKi5CMKJvAS43ulraQ==/109951168930518368.jpg, sourceName: 网易, $$hashKey: object:2884, disabled: false, index: 365, playNow: true, bitrate: 320kbps, platform: netease, platformText: 网易}\
    //去除引导状态
    bootStraping.remove(track.id);
    showErrorSnackbar('播放失败', track.title);
    // 若用户欲播放的曲目就是当前曲目，则触发播放完成逻辑
    if (nowPlayingTrackId != track.id) {
      return;
    }
    var connectivityResult = await (Connectivity().checkConnectivity());
    debugPrint(connectivityResult.toString());
    while (connectivityResult == ConnectivityResult.none) {
      connectivityResult = await (Connectivity().checkConnectivity());
      debugPrint(connectivityResult.toString());
      // 等待三秒
      await Future.delayed(Duration(seconds: 3));
    }
    onPlaybackCompleted(true);
  }

  // final RxMap<int, AndroidEQBand> _bands = RxMap<int, AndroidEQBand>();
  // final androidEQInited = false.obs;

  // // Getter 用于访问频段数据
  // Map<int, AndroidEQBand> get bands => _bands;
  // double minGain = -1.0;
  // double maxGain = 1.0;
  // bool androidEQEnabled = false;
  // static const String androidEQEnabledKey = 'android_equalizer_enabled';
  // Future<void> initAndroidEqualizer() async {
  //   // 从设置中加载保存的频段数据
  //   final savedBands =
  //       Get.find<SettingsController>().settings['android_equalizer_bands'];
  //   if (savedBands != null && savedBands is List) {
  //     // 将 List 转换为 Map
  //     _bands.value = Map<int, AndroidEQBand>.fromEntries(
  //       savedBands.map<MapEntry<int, AndroidEQBand>>(
  //         (value) => MapEntry(
  //           value['index'] as int,
  //           AndroidEQBand.fromJson(value as Map<String, dynamic>),
  //         ),
  //       ),
  //     );
  //   }

  //   await equalizer.setEnabled(true);
  //   final parameters = await equalizer.parameters;
  //   minGain = parameters.minDecibels;
  //   maxGain = parameters.maxDecibels;
  //   for (var band in _bands.values) {
  //     band.gain = band.gain.clamp(minGain, maxGain);
  //   }
  //   final bands = parameters.bands;
  //   for (var band in bands) {
  //     if (_bands.containsKey(band.index)) {
  //       await band.setGain(_bands[band.index]!.gain);
  //       _bands[band.index]!.upperFrequency = band.upperFrequency;
  //       _bands[band.index]!.lowerFrequency = band.lowerFrequency;
  //       _bands[band.index]!.centerFrequency = band.centerFrequency;
  //     } else {
  //       _bands[band.index] = AndroidEQBand.fromAndroidEqualizerBand(band);
  //     }
  //   }
  //   androidEQInited.value = true;
  //   debounce(_bands, (callback) {
  //     _saveEqualizerBands();
  //   }, time: Duration(milliseconds: 100));
  // }

  // // 设置特定频段的增益
  // void setBandGain(int bandIndex, double gain) {
  //   if (!_bands.containsKey(bandIndex)) return;

  //   // 更新本地数据
  //   _bands[bandIndex]!.gain = gain;
  //   _bands.refresh();
  // }

  // // 保存均衡器频段设置
  // Future<void> _saveEqualizerBands() async {
  //   // 应用到均衡器
  //   final parameters = await equalizer.parameters;
  //   final bands = parameters.bands;
  //   for (var band in bands) {
  //     final bandData = _bands[band.index];
  //     if (bandData != null) {
  //       await band.setGain(bandData.gain);
  //     }
  //   }
  //   final bandsList = _bands.values.map((band) => band.toJson()).toList();
  //   Get.find<SettingsController>().settings['android_equalizer_bands'] =
  //       bandsList;
  //   logger.d('Saved equalizer bands: $bandsList');

  //   bool isPlayingBefore = music_player.playing;
  //   if (isPlayingBefore) await music_player.stop();
  //   // await music_player.load();
  //   if (isPlayingBefore) await music_player.play();
  // }

  Future<void> _saveSingleSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    switch (key) {
      case 'player-settings':
        String jsonString = jsonEncode(_player_settings);
        await prefs.setString(key, jsonString);
        break;
      case 'current-playing':
        String jsonString = jsonEncode(currentPlayingRx);
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
    currentPlayingRx.value =
        Get.find<SettingsController>().PlayController_current_playing;
  }

  List<Track> get current_playing => currentPlayingRx.toList();
  void add_current_playing(List<Track> tracks) {
    for (var track in tracks) {
      if (!currentPlayingRx.any((element) => element.id == track.id)) {
        currentPlayingRx.add(track);
      }
    }
  }

  void set_current_playing(List<Track> tracks) {
    currentPlayingRx.value = tracks;
  }

  Track? getTrackById(String id) {
    return currentPlayingRx.firstWhereOrNull((track) => track.id == id);
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
      if (currentPlayingRx.isEmpty) {
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

  SettingsController settingsController = Get.find<SettingsController>();
  late AnimationController playVPlayBtnProcessController;

  // 播放按钮旋转曲线（默认为正弦缓入）
  final playButtonRotationCurve = 'easeInSine'.obs;
  Curve playButtonRotationCurveValue = CurveUtils.getCurveByName('easeInSine');

  void playVPlayBtnProcessControllerInit() {
    playVPlayBtnProcessController = AnimationController(
      vsync: this, // 使用 GetSingleTickerProviderStateMixin 提供的 vsync
      duration: Duration(
        milliseconds: settingsController.playVPlayBtnProcessControllerDuration,
      ),
    )..repeat(); // 无限循环旋转
  }

  RxBool showPlayVInlineLyricOp = false.obs;
  RxBool showPlayVInlineLyricVisible = false.obs;
  final sheetExpandRatio = 0.0.obs; // 展开比例 0.0-1.0
  Future<void> expandSheet() async {
    if (globalHorizon) return;
    await sheetController.animateTo(
      playVMaxOffset,
      duration: Duration(milliseconds: 300),
    );
  }

  Future<void> expandSheetToMid() async {
    if (globalHorizon) return;
    await sheetController.animateTo(
      sheetMidOffset,
      duration: Duration(milliseconds: 300),
    );
  }

  Future<void> collapseSheet() async {
    if (globalHorizon) return;
    await sheetController.animateTo(
      sheetMinOffset,
      duration: Duration(milliseconds: 300),
    );
  }

  bool tryCollapseSheet() {
    if (globalHorizon) return false;
    if ((sheetController.metrics?.offset ?? sheetMinHeight) >
        (sheetMidHeight + playVMaxHeight) / 2) {
      expandSheetToMid();
      return true;
    } else if ((sheetController.metrics?.offset ?? sheetMinHeight) >
        (sheetMinHeight + sheetMidHeight) / 2) {
      collapseSheet();
      return true;
    }
    return false;
  }
}
