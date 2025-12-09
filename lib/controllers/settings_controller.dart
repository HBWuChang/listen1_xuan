// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/controllers.dart';
import 'package:listen1_xuan/models/websocket_message.dart';
import 'package:listen1_xuan/play.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:window_manager/window_manager.dart';

import '../bl.dart';
import '../const.dart';
import '../global_settings_animations.dart';
import '../main.dart';
import '../models/SongReplaceSettings.dart';
import '../netease.dart';
import '../qq.dart';
import '../settings.dart';
import 'myPlaylist_controller.dart';

class SettingsController extends GetxController {
  final settings = <String, dynamic>{}.obs;
  static const String lyricBorderRadiusHKey = 'lyric_border_radius_h';
  static const String lyricBorderRadiusVKey = 'lyric_border_radius_v';
  double get lyricBorderRadiusH => settings[lyricBorderRadiusHKey] ?? 20.0;
  set lyricBorderRadiusH(double value) {
    settings[lyricBorderRadiusHKey] = value;
  }

  double get lyricBorderRadiusV => settings[lyricBorderRadiusVKey] ?? 48.0;
  set lyricBorderRadiusV(double value) {
    settings[lyricBorderRadiusVKey] = value;
  }

  double get lyricBorderRadius =>
      globalHorizon ? lyricBorderRadiusH : lyricBorderRadiusV.w;

  static const String cacheNamedMethodKey = 'cache_named_method';
  static const String cacheNamedDedupMethodKey = 'cache_dedup_method';
  static const String cacheNamedIfEmptyRepKey = 'cache_if_empty';
  static const String cacheNamedConKey = 'cache_named_connection';
  static const String cacheNamedUnUseableRepKey = 'cache_unuseable_rep';

  List<int> get cacheNamedMethod =>
      List<int>.from(settings[cacheNamedMethodKey] ?? [1, 2]);

  set cacheNamedMethod(List<int> value) {
    if (value.isEmpty) {
      value = [1, 2];
    }
    settings[cacheNamedMethodKey] = value;
  }

  int get cacheDedupMethod => settings[cacheNamedDedupMethodKey] ?? 0;
  set cacheDedupMethod(int value) {
    settings[cacheNamedDedupMethodKey] = value;
  }

  String get cacheIfEmptyRep => settings[cacheNamedIfEmptyRepKey] ?? '';
  set cacheIfEmptyRep(String value) {
    settings[cacheNamedIfEmptyRepKey] = value;
  }

  String get cacheNamedConnection => settings[cacheNamedConKey] ?? '-';
  set cacheNamedConnection(String value) {
    settings[cacheNamedConKey] = value;
  }

  String get cacheUnUseableRep => settings[cacheNamedUnUseableRepKey] ?? '·';
  set cacheUnUseableRep(String value) {
    for (var char in cacheUnUseableRepUnUseable.split('')) {
      if (value.contains(char)) {
        value = value.replaceAll(char, '');
      }
    }
    settings[cacheNamedUnUseableRepKey] = value;
  }

  static const String windowsProxyKey = 'proxy';
  String get windowsProxyAddr => settings[windowsProxyKey] ?? '';
  set windowsProxyAddr(String value) {
    settings[windowsProxyKey] = value;
  }

  bool get tryShowLyricInNotification =>
      settings['tryShowLyricInNotification'] ?? true;
  set tryShowLyricInNotification(bool value) {
    settings['tryShowLyricInNotification'] = value;
  }

  double get lyricBackgroundBlurRadius =>
      settings['lyricBackgroundBlurRadius'] ?? (globalHorizon ? 20.0 : 10.0);
  set lyricBackgroundBlurRadius(double value) {
    settings['lyricBackgroundBlurRadius'] = value;
  }

  var showLyricTranslation = true.obs; // 歌词翻译显示设置
  // var hideOrMinimize = false.obs;
  bool get hideOrMinimize => settings['hideOrMinimize'] ?? true;
  set hideOrMinimize(bool value) {
    settings['hideOrMinimize'] = value;
  }

  static const String searchUseLastSourceKey = 'searchUseLastSource';
  bool get searchUseLastSource => settings[searchUseLastSourceKey] ?? true;
  set searchUseLastSource(bool value) {
    settings[searchUseLastSourceKey] = value;
  }

  static const String searchLastSourceKey = 'searchLastSource';
  String get searchLastSource => settings[searchLastSourceKey] ?? '网易云';
  set searchLastSource(String value) {
    settings[searchLastSourceKey] = value;
  }

  RxSet<int> settingsPageExpansion = <int>{}.obs;
  Set<int> _lastSettingsPageExpansion = <int>{};

  static const String nextTrackQueueOrStackMethodKey =
      'nextTrackQueueOrStackMethod';

  /// true 队列模式 false 栈模式
  bool get nextTrackQueueOrStackMethod =>
      settings[nextTrackQueueOrStackMethodKey] ?? true;
  set nextTrackQueueOrStackMethod(bool value) {
    settings[nextTrackQueueOrStackMethodKey] = value;
  }

  static const String androidCompactActionIndicesKey =
      'androidCompactActionIndices';
  List<int> get androidActionSort =>
      List<int>.from(settings[androidCompactActionIndicesKey] ?? [2, 0, 1]);
  set androidActionSort(List<int> value) {
    settings[androidCompactActionIndicesKey] = value;
    Get.find<PlayController>().updatePosToAudioServiceNow.value++;
  }

  static const String supabaseSubPlayKey = 'supabaseSubPlay';
  bool get supabaseSubPlay => settings[supabaseSubPlayKey] ?? true;
  set supabaseSubPlay(bool value) {
    settings[supabaseSubPlayKey] = value;
    if (value) {
      Get.find<SupabaseAuthController>().subscribeToContinuePlay();
    } else {
      Get.find<SupabaseAuthController>().unsubscribeFromContinuePlay();
    }
  }

  // Supabase 账号密码保存（用于自动重连）
  static const String supabaseEmailKey = 'supabaseEmail';
  String get supabaseEmail => settings[supabaseEmailKey] ?? '';
  set supabaseEmail(String value) {
    settings[supabaseEmailKey] = value;
  }

  static const String supabasePasswordKey = 'supabasePassword';
  String get supabasePassword => settings[supabasePasswordKey] ?? '';
  set supabasePassword(String value) {
    settings[supabasePasswordKey] = value;
  }

  static const String supabaseUploadTimeoutDurationOnExitKey =
      'supabaseUploadTimeoutDurationOnExit';
  int get supabaseUploadTimeoutDurationOnExit =>
      settings[supabaseUploadTimeoutDurationOnExitKey] ?? 3000;
  set supabaseUploadTimeoutDurationOnExit(int value) {
    settings[supabaseUploadTimeoutDurationOnExitKey] = value;
  }

  static const String playVShowBtnsKey = 'playVShowBtns';
  Set<int> get playVShowBtns {
    final value = settings[playVShowBtnsKey];
    if (value is List) {
      return value.map((e) => e as int).toSet();
    }
    return {PlayVBtns.playPause.index, PlayVBtns.nowPlayinglist.index};
  }

  set playVShowBtns(Set<int> value) {
    if (value.length != 2) {
      throw '按钮个数必须为2';
    }
    settings[playVShowBtnsKey] = value.toList();
  }

  static const String playVBtnsKey = 'playVBtns';
  List<int> get playVBtns {
    final value = settings[playVBtnsKey];
    if (value is List) {
      return value.map((e) => e as int).toList();
    }
    return List.generate(PlayVBtns.values.length, (index) => index);
  }

  set playVBtns(List<int> value) {
    if (value.length != PlayVBtns.values.length) {
      throw '按钮个数必须为${PlayVBtns.values.length}';
    }
    settings[playVBtnsKey] = value;
  }

  final String CacheController_localCacheListKey = 'local-cache-list';
  final CacheController_localCacheList = <String, String>{};
  var PlayController_player_settings = <String, dynamic>{};
  var PlayController_current_playing = <Track>[];
  static const String PlayController_play_replaceKey =
      'song_replace_settings_xuan';
  SongReplaceSettings PlayController_play_replace = SongReplaceSettings();
  var MyPlayListController_playerlists = <String, PlayList>{};
  var MyPlayListController_favoriteplayerlists = <String, PlayList>{};
  @override
  void onInit() {
    super.onInit();
    debounce(settings, (callback) {
      saveSettings();
    });

    // 监听 showLyricTranslation 变化并保存到 settings
    ever(showLyricTranslation, (value) {
      settings['showLyricTranslation'] = value;
    });
    ever(settingsPageExpansion, (callback) async {
      settings['settingsPageExpansion'] = callback.toList();
      if (callback.contains(1) &&
          _lastSettingsPageExpansion.contains(1) == false) {
        refreshLoginData();
      }
      _lastSettingsPageExpansion = Set<int>.from(callback); // 创建新的 Set 副本
    });
  }

  Future<void> loadSettings() async {
    final prefs = SharedPreferencesAsync();

    // 第一批：并行获取所有字符串数据
    final results = await Future.wait([
      prefs.getString('settings'),
      prefs.getString(CacheController_localCacheListKey),
      prefs.getString('player-settings'),
      prefs.getString('current-playing'),
      prefs.getStringList('playerlists'),
      prefs.getStringList('favoriteplayerlists'),
      prefs.getString(PlayController_play_replaceKey),
    ]);

    final jsonString = results[0] as String?;
    final localCacheListJson = results[1] as String?;
    final player_settings = results[2] as String?;
    final current_playing = results[3] as String?;
    final playlists = results[4] as List<String>?;
    final favoritePlaylists = results[5] as List<String>?;
    final play_replace = results[6] as String?;

    // 第二批：并行解析所有 JSON 数据
    final computeTasks = <Future<dynamic>>[];

    if (jsonString != null) {
      computeTasks.add(
        compute(
          (String jsonStr) => jsonDecode(jsonStr) as Map<String, dynamic>,
          jsonString,
        ),
      );
    } else {
      computeTasks.add(Future.value(null));
    }

    if (localCacheListJson != null) {
      computeTasks.add(
        compute(
          (String jsonStr) => jsonDecode(jsonStr) as Map<String, dynamic>,
          localCacheListJson,
        ),
      );
    } else {
      computeTasks.add(Future.value(null));
    }

    if (player_settings != null) {
      computeTasks.add(
        compute(
          (String jsonStr) => jsonDecode(jsonStr) as Map<String, dynamic>,
          player_settings,
        ).catchError((_) => <String, dynamic>{}),
      );
    } else {
      computeTasks.add(Future.value(null));
    }

    if (current_playing != null) {
      computeTasks.add(
        compute(
          (String jsonStr) => jsonDecode(jsonStr) as List,
          current_playing,
        ).catchError((_) => <dynamic>[]),
      );
    } else {
      computeTasks.add(Future.value(null));
    }
    if (play_replace != null) {
      computeTasks.add(
        compute(
          (String jsonStr) => jsonDecode(jsonStr) as Map<String, dynamic>,
          play_replace,
        ).catchError((_) => <String, dynamic>{}),
      );
    } else {
      computeTasks.add(Future.value(null));
    }
    final computeResults = await Future.wait(computeTasks);

    // 应用解析结果
    if (computeResults[0] != null) {
      settings.value = computeResults[0] as Map<String, dynamic>;
    }
    showLyricTranslation.value = settings['showLyricTranslation'] ?? true;

    if (computeResults[1] != null) {
      CacheController_localCacheList.assignAll(
        Map<String, String>.from(computeResults[1] as Map<String, dynamic>),
      );
    } else {
      CacheController_localCacheList.clear();
    }

    final expansionValue = settings['settingsPageExpansion'];
    final expansionSet = expansionValue is List
        ? expansionValue.map((e) => e as int).toSet()
        : <int>{};
    settingsPageExpansion.clear();
    settingsPageExpansion.addAll(expansionSet);
    _lastSettingsPageExpansion = Set<int>.from(settingsPageExpansion);

    if (computeResults[2] != null) {
      PlayController_player_settings =
          computeResults[2] as Map<String, dynamic>;
    }

    if (computeResults[3] != null) {
      PlayController_current_playing = (computeResults[3] as List)
          .map((track) => Track.fromJson(track))
          .toList();
    }
    if (computeResults[4] != null) {
      PlayController_play_replace = await compute(
        (Map<String, dynamic> json) => SongReplaceSettings.fromJson(json),
        computeResults[6] as Map<String, dynamic>,
      );
    }

    // 第三批：并行获取所有播放列表数据
    MyPlayListController_playerlists.clear();
    MyPlayListController_favoriteplayerlists.clear();

    final playlistFutures = <Future<MapEntry<String, PlayList>?>>[];

    for (var playlist in playlists ?? []) {
      playlistFutures.add(
        prefs.getString(playlist).then((playlistJson) async {
          if (playlistJson != null) {
            final decoded = await compute(
              (String jsonStr) => jsonDecode(jsonStr),
              playlistJson,
            );
            return MapEntry(playlist, PlayList.fromJson(decoded));
          }
          return null;
        }),
      );
    }

    for (var playlist in favoritePlaylists ?? []) {
      playlistFutures.add(
        prefs.getString(playlist).then((playlistJson) async {
          if (playlistJson != null) {
            final decoded = await compute(
              (String jsonStr) => jsonDecode(jsonStr),
              playlistJson,
            );
            return MapEntry(playlist, PlayList.fromJson(decoded));
          }
          return null;
        }),
      );
    }

    final playlistResults = await Future.wait(playlistFutures);

    // 将结果分配到对应的 Map
    final playlistCount = (playlists ?? []).length;
    for (var i = 0; i < playlistResults.length; i++) {
      final result = playlistResults[i];
      if (result != null) {
        if (i < playlistCount) {
          MyPlayListController_playerlists[result.key] = result.value;
        } else {
          MyPlayListController_favoriteplayerlists[result.key] = result.value;
        }
      }
    }
  }

  Future<void> saveSettings() async {
    final prefs = SharedPreferencesAsync();
    String jsonString = jsonEncode(settings);
    await prefs.setString('settings', jsonString);
  }

  setSettings(Map<String, dynamic> settings) {
    this.settings.addAll(settings);
  }

  setSetting(String key, dynamic value) {
    settings[key] = value;
  }

  final readmeContent = ''.obs;
  bool get hasReadmeContent =>
      readmeContent.value.isNotEmpty && readmeContent.value != '加载失败';
  Future<void> loadReadme() async {
    try {
      readmeContent.value = '';
      final treadmeContent = await dioWithProxyAdapter.get(
        'https://api.github.com/repos/HBWuChang/listen1_xuan/readme',
      );
      String decodeBase64(String data) {
        return utf8.decode(base64Decode(data));
      }

      // 使用base64对content进行解码
      // _readmeContent_setstate(() {
      readmeContent.value = decodeBase64(
        treadmeContent.data['content'].replaceAll("\n", ''),
      );
      // });
    } catch (e) {
      // _readmeContent_setstate(() {
      //   _readmeContent = '加载失败';
      // });
      readmeContent.value = '加载失败';
    }
  }

  // 登陆管理
  final loginData = <String, dynamic>{}.obs;
  final loginDataLoading = Set().obs;
  Future<void> refreshLoginData() async {
    final tasks = Future.wait([
      Future.microtask(() async {
        loginDataLoading.add(PlantformCodes.bl);
        loginData[PlantformCodes.bl] = await bilibili.check_bl_cookie();
        loginDataLoading.remove(PlantformCodes.bl);
      }),
      Future.microtask(() async {
        loginDataLoading.add(PlantformCodes.ne);
        loginData[PlantformCodes.ne] = await netease.get_user();
        loginDataLoading.remove(PlantformCodes.ne);
      }),
      Future.microtask(() async {
        loginDataLoading.add(PlantformCodes.qq);
        loginData[PlantformCodes.qq] = await qq.get_user();
        loginDataLoading.remove(PlantformCodes.qq);
      }),
      Future.microtask(() async {
        loginDataLoading.add(PlantformCodes.github);
        loginData[PlantformCodes.github] = await Github.updateStatus();
        loginDataLoading.remove(PlantformCodes.github);
      }),
    ]);
    await tasks;
  }

  // windows 窗口大小及是否全屏
  static const String windowsWindowWidth = 'windowWidth';
  static const String windowsWindowHeight = 'windowHeight';
  static const String windowsWindowX = 'windowX';
  static const String windowsWindowY = 'windowY';
  static const String windowsWindowIsMaximized = 'isWindowMaximized';
  static const String windowsRememberWindowSizeAndPosition =
      'rememberWindowSizeAndPosition';
  bool get rememberWindowsSizeAndPosition {
    if (isWindows || isMacOS) {
      return settings[windowsRememberWindowSizeAndPosition] ?? true;
    }
    throw 'Not Windows platform';
  }

  set rememberWindowsSizeAndPosition(bool value) {
    if (isWindows || isMacOS) {
      settings[windowsRememberWindowSizeAndPosition] = value;
    } else
      throw 'Not Windows platform';
  }

  bool get isWindowMaximized {
    if (isWindows || isMacOS) {
      return settings[windowsWindowIsMaximized] ?? false;
    }
    throw 'Not Windows platform';
  }

  Rect get windowsWindowBounds {
    if (isWindows || isMacOS) {
      double width = (settings[windowsWindowWidth] ?? 1000).toDouble();
      double height = (settings[windowsWindowHeight] ?? 700).toDouble();
      double x = (settings[windowsWindowX] ?? 100).toDouble();
      double y = (settings[windowsWindowY] ?? 100).toDouble();
      return Rect.fromLTWH(x, y, width, height);
    }
    throw 'Not Windows platform';
  }

  void saveWindowsSizeAndPosition() {
    if (isWindows || isMacOS) {
      windowManager.getBounds().then((bounds) {
        settings[windowsWindowWidth] = bounds.width;
        settings[windowsWindowHeight] = bounds.height;
        settings[windowsWindowX] = bounds.left;
        settings[windowsWindowY] = bounds.top;
      });
    }
  }

  void onWindowMaximize() {
    if (isWindows || isMacOS) {
      settings[windowsWindowIsMaximized] = true;
    }
  }

  void onWindowUnmaximize() {
    if (isWindows || isMacOS) {
      settings[windowsWindowIsMaximized] = false;
    }
  }

  static const String playButtonRotationCurveKey = 'play_button_rotation_curve';
  static const String playVPlayBtnProcessControllerDurationKey =
      'play_v_play_btn_process_controller_duration';
  int get playVPlayBtnProcessControllerDuration {
    return (settings[playVPlayBtnProcessControllerDurationKey] ?? 8280) < 100
        ? 8280
        : (settings[playVPlayBtnProcessControllerDurationKey] ?? 8280);
  }

  set playVPlayBtnProcessControllerDuration(int value) {
    settings[playVPlayBtnProcessControllerDurationKey] = value;
  }
}
