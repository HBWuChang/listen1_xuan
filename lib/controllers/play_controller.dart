// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:listen1_xuan/controllers/cache_controller.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/main.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:listen1_xuan/models/SupaContinuePlay.dart';
import 'package:smtc_windows/smtc_windows.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:logger/logger.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:rxdart/rxdart.dart' as rxdart;
import '../global_settings_animations.dart';
import '../loweb.dart';
import '../models/MediaState.dart';
import '../models/SongReplaceSettings.dart';
import '../utils/curve_utils.dart';
import 'lyric_controller.dart';
import 'nowplaying_controller.dart';
import 'routeController.dart';
import 'settings_controller.dart';
import 'websocket_card_controller.dart';
import 'supabase_auth_controller.dart';
import 'BroadcastWsController.dart';
import 'package:windows_taskbar/windows_taskbar.dart';
import '../play.dart'; // 导入 safeCallWindowsTaskbar

class PlayController extends GetxController
    with GetSingleTickerProviderStateMixin {
  // late AndroidEqualizer equalizer;
  static const String nowPlayingTrackIdKey = 'nowplaying_track_id';
  static const String nowPlayingTrackKey = 'nowplaying_track';
  late Player music_player;
  CacheController cacheController = Get.find<CacheController>();
  final _player_settings = <String, dynamic>{}.obs;
  final currentPlayingRx = <Track>[].obs;
  bool songReplaceSettingsSkipOnceSave = false;
  final songReplaceSettings = SongReplaceSettings().obs;
  // 歌曲替换临时变量：源歌曲和替换歌曲
  final Rx<Track?> songReplaceSourceTrack = Rx<Track?>(null);
  final Rx<Track?> songReplaceTargetTrack = Rx<Track?>(null);
  final RxBool songReplaceAdding = false.obs;
  final RxBool isSongReplacingSource = true.obs;
  final logger = Logger();
  final updatePosToAudioServiceNow = 0.obs;
  final needUpdatePosToAudioService = 0.obs; // 新增：触发位置更新的流
  final _next_tracks = RxList<Track>([]);
  List<MediaControl> get androidControls => [
    if (isplaying.value) MediaControl.pause else MediaControl.play,
    // MediaControl.pause,
    MediaControl.skipToNext,
    MediaControl.skipToPrevious,
    // MediaControl.stop,
  ];
  List<MediaControl> get sortedAndroidControls {
    List<int> androidActionSort =
        Get.find<SettingsController>().androidActionSort;
    List<MediaControl> controls = androidControls;
    List<MediaControl> sortedControls = [];
    for (var index in androidActionSort) {
      sortedControls.add(controls[index]);
    }
    return sortedControls;
  }

  bool get loading {
    return bootStraping.containsKey(nowPlayingTrackId);
  }

  Rx<Track?> nowPlayingTrackRx = Rx<Track?>(null);
  String get nowPlayingTrackId =>
      nowPlayingTrackRx.value?.id ??
      _player_settings[nowPlayingTrackIdKey] ??
      '';

  ///用于记录正在引导播放的曲目id及下载文件名
  final bootStraping = RxMap<String, String>();

  // Windows任务栏进度 (0-100)
  final taskbarProgress = 0.obs;

  /// 获取或设置下一首曲目
  /// 设置为 null 时表示使用了（移除）下一首曲目
  Track? get nextTrack => _next_tracks.isNotEmpty
      ? (Get.find<SettingsController>().nextTrackQueueOrStackMethod
            ? _next_tracks.first
            : _next_tracks.last)
      : null;
  set nextTrack(Track? track) {
    if (track == null) {
      Get.find<SettingsController>().nextTrackQueueOrStackMethod
          ? _next_tracks.removeAt(0)
          : _next_tracks.removeLast();
    } else {
      _next_tracks.add(track);
    }
  }

  final mediaState = Rx<MediaState>(
    MediaState(
      position: Duration.zero,
      duration: Duration.zero,
      playing: false,
    ),
  );

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

  static const String positionInMillisecondsKey = 'positionInMilliseconds';
  static const String lastPositionUpdateTimeKey = 'lastPositionUpdateTime';
  RxInt positionInMilliseconds = 0.obs;
  @override
  void onInit() {
    super.onInit();
    music_player = Player();
    // music_player.setAudioDevice()
    logger.d('PlayController initialized');
    logger.d(music_player.state.audioDevices);
    logger.d(music_player.state.audioParams);
    music_player.stream.error.listen((error) {
      logger.e('Audio Player Error: $error');
      logger.d(music_player.state.audioParams);
    });
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

    ever(nowPlayingTrackRx, (callback) {
      _player_settings[nowPlayingTrackKey] = nowPlayingTrackRx.value?.toJson();
      _player_settings[nowPlayingTrackIdKey] =
          nowPlayingTrackRx.value?.id ?? '';
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

    // 监听 music_player.position 和 needUpdatePosToAudioService
    // 当两个流都至少更新一次时，更新 updatePosToAudioServiceNow
    rxdart.Rx.combineLatest2<Duration, int, void>(
      music_player.stream.position,
      needUpdatePosToAudioService.stream,
      (position, needUpdate) => null,
    ).listen((_) {
      updatePosToAudioServiceNow.value++;
      if (updatePosToAudioServiceNow.value > 2e9) {
        updatePosToAudioServiceNow.value = 0;
      }
    });

    playButtonRotationCurve.value =
        settingsController.settings[SettingsController
            .playButtonRotationCurveKey] ??
        'easeInSine';

    /// 恢复上次播放位置
    music_player.stream.position.listen((position) {
      positionInMilliseconds.value = position.inMilliseconds;
    });
    positionInMilliseconds.value =
        settingsController.settings[positionInMillisecondsKey] ?? 0;

    toSeek = isEmpty(positionInMilliseconds.value)
        ? null
        : positionInMilliseconds.value;
    interval(positionInMilliseconds, (pos) {
      settingsController.settings[positionInMillisecondsKey] = pos;
      settingsController.settings[lastPositionUpdateTimeKey] = DateTime.now()
          .toUtc()
          .millisecondsSinceEpoch;
    }, time: Duration(milliseconds: 2000));

    ///歌曲替换保存
    debounce(songReplaceSettings, (value) async {
      if (songReplaceSettingsSkipOnceSave) {
        songReplaceSettingsSkipOnceSave = false;
        return;
      }
      await SharedPreferencesAsync().setString(
        SettingsController.PlayController_play_replaceKey,
        await compute((SongReplaceSettings s) => jsonEncode(s.toJson()), value),
      );
    });

    music_player.stream.position.listen((position) {
      // 更新 mediaState 的 position
      mediaState.update((state) {
        state?.position = position;
      });
      if (isWindows) {
        // 计算进度并更新到 PlayController 的响应式变量
        final durationMs = mediaState.value.duration.inMilliseconds;
        final progress =
            (position.inMilliseconds / (durationMs == 0 ? 1 : durationMs) * 100)
                .toInt();
        taskbarProgress.value = progress;
      }
    });
    music_player.stream.playing.listen((playing) {
      // 更新 mediaState 的 playing 状态
      mediaState.update((state) {
        state?.playing = playing;
      });
    });
    music_player.stream.duration.listen((duration) {
      // 更新 mediaState 的 duration
      mediaState.update((state) {
        state?.duration = duration;
      });
    });
    if (isWindows) {
      interval(mediaState, (state) {
        smtc.setPlaybackStatus(
          state.playing ? PlaybackStatus.playing : PlaybackStatus.paused,
        );
        smtc.updateTimeline(
          PlaybackTimeline(
            startTimeMs: 0,
            endTimeMs: state.duration.inMilliseconds,
            positionMs: state.position.inMilliseconds,
            minSeekTimeMs: 0,
            maxSeekTimeMs: state.duration.inMilliseconds,
          ),
        );
      }, time: Duration(milliseconds: 500));
    }
  }

  @override
  void onClose() {
    playVPlayBtnProcessController.dispose();
    music_player.dispose();
    super.onClose();
  }

  void setNowPlayingTrack() {
    final t = _player_settings[nowPlayingTrackKey];
    if (t != null) {
      nowPlayingTrackRx.value = Track.fromJson(t as Map<String, dynamic>);
    } else {
      nowPlayingTrackRx.value = getTrackById(
        _player_settings[nowPlayingTrackIdKey] ?? '',
      );
    }
  }

  /// 是否跳过Supabase 同步
  /// 目前设想在第一次播放完成前且未获取云端时为true
  bool receivedContinuePlay = false;
  int? toSeek;
  Future<void> playsong(
    Track track, {
    bool start = true,
    bool onBootstrapTrackSuccessCallback = false,
    bool isByClick = false,
  }) async {
    try {
      if (songReplaceAdding.value && isByClick) {
        selectReplaceSong(track);
        return;
      }
      if (isByClick) {
        showInfoSnackbar('尝试播放：${track.title}', null);
      }
      //若引导成功，但用户最终意图播放的不是该曲目，则返回
      //若意图播放的曲目已经在引导中，则返回
      if ((onBootstrapTrackSuccessCallback && nowPlayingTrackId != track.id) ||
          bootStraping.containsKey(track.id)) {
        // 若已在引导，但为点击播放，则更新当前播放id
        if (isByClick) {
          nowPlayingTrackRx.value = track;
        }
        return;
      }
      nowPlayingTrackRx.value = track;
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
        t_volume = getPlayerSettings("volume");
      } catch (e) {
        t_volume = 100;
        setPlayerSetting("volume", t_volume);
      }
      music_player.setVolume(t_volume);
      if (toSeek != null) {
        try {
          music_player.stream.duration
              .firstWhere((duration) => duration.inMilliseconds > 0)
              .then((duration) {
                if (toSeek != null && toSeek! < duration.inMilliseconds) {
                  music_player.seek(Duration(milliseconds: toSeek!));
                }
                toSeek = null;
              });
        } catch (e) {
          logger.e('seek error: $e');
        }
      }
      if (start) {
        music_player.play();
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
    Track? sTrack,
  }) async {
    try {
      if (isEmpty(await cacheController.getLocalCache(track.id))) {
        await cacheController.downloadAndCacheFile(res, track, sTrack: sTrack);
      }
      // 理论上此时应歌曲文件准备完毕
      bootStraping.remove(sTrack?.id ?? track.id);
      playsong(
        sTrack ?? track,
        start: start,
        onBootstrapTrackSuccessCallback: true,
      );
    } catch (e) {
      debugPrint('Error downloading or playing audio: $e');
      bootstrapTrackFail(sTrack ?? track);
    }
  }

  Future<void> bootstrapTrackFail(Track track, {bool start = true}) async {
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
    onPlaybackCompleted(force_next: true, start: start);
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
    final prefs = SharedPreferencesAsync();
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
    if (key == nowPlayingTrackKey) setNowPlayingTrack();
  }

  void loadDatas() {
    _player_settings.value =
        Get.find<SettingsController>().PlayController_player_settings;
    setNowPlayingTrack();
    currentPlayingRx.value =
        Get.find<SettingsController>().PlayController_current_playing;
    songReplaceSettingsSkipOnceSave = true;
    songReplaceSettings.value =
        Get.find<SettingsController>().PlayController_play_replace;
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

  void replaceTrack(Track newTrack, String repTrackId) {
    currentPlayingRx.value = currentPlayingRx.map((track) {
      if (track.id == repTrackId) {
        return newTrack;
      }
      return track;
    }).toList();
  }

  /// 更新当前播放状态到 Supabase
  /// 将当前曲目、播放状态等信息同步到云端
  Future<void> updateContinuePlay({bool onlyPlaying = false}) async {
    try {
      if (settingsController.supabaseSubPlay == false) {
        logger.d('用户设置不同步播放状态，跳过同步');
        return;
      }
      if (onlyPlaying && !isplaying.value) {
        logger.d('仅在播放时同步，当前未播放，跳过同步');
        return;
      }
      if (receivedContinuePlay == false) {
        logger.d('未接收到继续播放状态，跳过同步播放状态');
        return;
      }
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
          'pos': music_player.state.position.inMilliseconds,
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

  /// 处理 continue_play 更新事件
  /// [continuePlay] 播放状态数据
  /// [updateDeviceId] 触发更新的设备ID
  /// 由 SupabaseAuthController 调用
  void handleContinuePlayUpdate(
    SupaContinuePlay continuePlay,
    String updateDeviceId,
  ) {
    try {
      // 获取当前设备ID
      final broadcastController = Get.find<BroadcastWsController>();
      final currentDeviceId = broadcastController.deviceId;

      // 忽略自我设备触发的更新
      if (updateDeviceId == currentDeviceId && receivedContinuePlay) {
        logger.d('忽略自我设备触发的更新');
        return;
      }
      receivedContinuePlay = true;

      logger.i(
        '收到其他设备的播放状态更新: '
        '曲目=${continuePlay.track.title}, '
        '播放状态=${continuePlay.playing}, '
        '设备ID=${continuePlay.deviceId}',
      );

      // TODO: 这里可以添加处理逻辑，例如：
      // - 显示通知提示用户其他设备正在播放
      // - 根据用户设置自动同步播放状态
      // - 更新UI显示其他设备的播放信息等
      if (!bootStraping.containsKey(continuePlay.track.id) &&
          nowPlayingTrackId == continuePlay.track.id) {
        if (music_player.state.playing == false) {
          if ((continuePlay.updTime ?? DateTime.fromMillisecondsSinceEpoch(0))
              .isBefore(
                DateTime.fromMillisecondsSinceEpoch(
                  settingsController.settings[PlayController
                          .lastPositionUpdateTimeKey] ??
                      0,
                  isUtc: true,
                ),
              )) {
            return;
          }
          music_player.seek(
            Duration(milliseconds: (continuePlay.ext?['pos'] as int?) ?? 0),
          );
        }
        return;
      }
      if (music_player.state.playing) {
        showInfoSnackbar('其他设备正在播放: ${continuePlay.track.title}', null);
        return;
      }
      toSeek = continuePlay.ext?['pos'] as int?;
      playsong(continuePlay.track, start: false, isByClick: false);
    } catch (e) {
      logger.e('处理 continue_play 更新失败: $e');
    }
  }

  void selectReplaceSong(Track source) {
    if (isSongReplacingSource.value) {
      songReplaceSourceTrack.value = source;
      showInfoSnackbar('已选择 ${source.title} 作为歌曲信息及歌词来源', null);
    } else {
      songReplaceTargetTrack.value = source;
      showInfoSnackbar('已选择 ${source.title} 作为音频数据来源', null);
    }
    songReplaceAdding.value = false;
    if (!Get.find<RouteController>().inSongReplacePage.value) {
      Get.toNamed(RouteName.songReplacePage, id: 1);
    }
  }
}
