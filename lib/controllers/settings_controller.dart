// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:hive/hive.dart';

import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/controllers.dart';
import 'package:listen1_xuan/models/websocket_message.dart';
import 'package:listen1_xuan/play.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:window_manager/window_manager.dart';

import '../bl.dart';
import '../const.dart';
import '../global_settings_animations.dart';
import '../main.dart';
import '../models/Playlist.dart';
import '../models/SongReplaceSettings.dart';
import '../netease.dart';
import '../qq.dart';
import '../settings.dart';
import 'myPlaylist_controller.dart';

class SettingsController extends GetxController {
  static const String hiveStoreKey = 'hive_store';
  bool useHive = false;
  Box<dynamic>? box;
  final prefs = SharedPreferencesAsync();
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

  static const String tryShowLyricInNotificationKey =
      'tryShowLyricInNotification';
  static const String tryShowLyricInNotificationUseTitleKey =
      'tryShowLyricInNotificationUseTitle';
  bool get tryShowLyricInNotification =>
      settings[tryShowLyricInNotificationKey] ?? true;
  set tryShowLyricInNotification(bool value) {
    settings[tryShowLyricInNotificationKey] = value;
    if (!value && isAndroid) {
      change_playback_state(null, onDisableLyricUpdate: true);
    }
  }

  bool get tryShowLyricInNotificationInTitle =>
      settings[tryShowLyricInNotificationUseTitleKey] ?? false;
  set tryShowLyricInNotificationInTitle(bool value) {
    settings[tryShowLyricInNotificationUseTitleKey] = value;
    if (!value && !isAndroid) {
      change_playback_state(null, onDisableLyricUpdate: true);
    }
  }

  double get lyricBackgroundBlurRadius =>
      settings['lyricBackgroundBlurRadius'] ?? (globalHorizon ? 20.0 : 10.0);
  set lyricBackgroundBlurRadius(double value) {
    settings['lyricBackgroundBlurRadius'] = value;
  }

  static const String globalLyricDelayKey = 'globalLyricDelay';
  double get globalLyricDelay => settings[globalLyricDelayKey] ?? 0.0;
  set globalLyricDelay(double value) {
    settings[globalLyricDelayKey] = value;
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

  ///歌曲替换按钮位置及大小设置
  static const String songReplaceFabLocationKey = 'songReplaceFabLocation';
  static const String songReplaceFabMiniKey = 'songReplaceFabMini';
  SongReplaceFabLocation get songReplaceFabLocation {
    int? locationIndex = settings[songReplaceFabLocationKey];
    return SongReplaceFabLocation.values.firstWhere(
      (element) => element.index == locationIndex,
      orElse: () => SongReplaceFabLocation.startFloat,
    );
  }

  set songReplaceFabLocation(SongReplaceFabLocation location) {
    settings[songReplaceFabLocationKey] = location.index;
  }

  bool get songReplaceFabMini => settings[songReplaceFabMiniKey] ?? true;
  set songReplaceFabMini(bool value) {
    settings[songReplaceFabMiniKey] = value;
  }

  static const String songReplaceAutoRepTragetTrackInAllPlaylistKey =
      'songReplaceAutoRepTragetTrackInAllPlaylist';
  bool? get songReplaceAutoRepTragetTrackInAllPlaylist =>
      settings[songReplaceAutoRepTragetTrackInAllPlaylistKey];
  set songReplaceAutoRepTragetTrackInAllPlaylist(bool? value) {
    settings[songReplaceAutoRepTragetTrackInAllPlaylistKey] = value;
  }

  static const String supabaseBackupPlayListUpdateIdMapKey =
      'supabaseBackupPlayListUpdateIdMap';
  Map<String, String?> get supabaseBackupPlayListUpdateIdMap {
    final value = settings[supabaseBackupPlayListUpdateIdMapKey];
    if (value is Map) {
      return Map<String, String?>.from(value);
    }
    return <String, String?>{};
  }

  set supabaseBackupPlayListUpdateIdMap(Map<String, String?> value) {
    settings[supabaseBackupPlayListUpdateIdMapKey] = value;
  }

  static const String useDebugModeKey = 'useDebugMode';
  bool get useDebugMode {
    return settings[useDebugModeKey] ?? false;
  }

  set useDebugMode(bool value) {
    settings[useDebugModeKey] = value;
  }

  static const String getPreReleaseKey = 'getPreRelease';
  bool get getPreRelease {
    return settings[getPreReleaseKey] ?? false;
  }

  set getPreRelease(bool value) {
    settings[getPreReleaseKey] = value;
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

  Future<void> init() async {
    await initFlutterHive();
    await loadSettings();
  }

  Future<void> initFlutterHive() async {
    try {
      if (isWindows) {
        final path = p.join(
          ((await getApplicationSupportDirectory()).path),
          'hive_data',
        );
        if (!(await Directory(path).exists())) {
          await Directory(path).create(recursive: true);
        }
        logger.i(path);
        Hive.init(path);
        box = await Hive.openBox(SettingsController.hiveStoreKey);
        useHive = true;
      }
    } catch (e) {
      logger.e('Init Hive failed:$e');
    }
  }

  Future<void> loadSettings() async {
    if (kDebugMode) {
      await _loadSettingsDir();
    } else {
      await _loadSettingsAwait();
    }
  }

  /// 直接顺序加载设置（不使用 compute，用于 debug 模式）
  Future<void> _loadSettingsDir() async {
    // 顺序获取所有字符串数据
    final jsonString = await prefs.getString('settings');
    final localCacheListJson = await prefs.getString(
      CacheController_localCacheListKey,
    );
    final player_settings = await prefs.getString('player-settings');
    final current_playing = await prefs.getString('current-playing');
    final playlists = await prefs.getStringList('playerlists');
    final favoritePlaylists = await prefs.getStringList('favoriteplayerlists');
    final play_replace = await prefs.getString(PlayController_play_replaceKey);

    // 直接解析 JSON 数据（不使用 compute）
    if (jsonString != null) {
      settings.value = jsonDecode(jsonString) as Map<String, dynamic>;
    }
    showLyricTranslation.value = settings['showLyricTranslation'] ?? true;

    if (localCacheListJson != null) {
      CacheController_localCacheList.assignAll(
        Map<String, String>.from(
          jsonDecode(localCacheListJson) as Map<String, dynamic>,
        ),
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

    if (player_settings != null) {
      try {
        PlayController_player_settings =
            jsonDecode(player_settings) as Map<String, dynamic>;
      } catch (_) {
        PlayController_player_settings = <String, dynamic>{};
      }
    }

    if (current_playing != null) {
      try {
        PlayController_current_playing = (jsonDecode(current_playing) as List)
            .map((track) => Track.fromJson(track))
            .toList();
      } catch (_) {
        PlayController_current_playing = <Track>[];
      }
    }

    if (play_replace != null) {
      try {
        PlayController_play_replace = SongReplaceSettings.fromJson(
          jsonDecode(play_replace) as Map<String, dynamic>,
        );
      } catch (_) {
        PlayController_play_replace = SongReplaceSettings();
      }
    }

    // 顺序获取所有播放列表数据
    MyPlayListController_playerlists.clear();
    MyPlayListController_favoriteplayerlists.clear();

    for (var playlist in playlists ?? []) {
      final playlistJson = await prefs.getString(playlist);
      if (playlistJson != null) {
        final decoded = jsonDecode(playlistJson);
        MyPlayListController_playerlists[playlist] = PlayList.fromJson(decoded);
      }
    }

    for (var playlist in favoritePlaylists ?? []) {
      final playlistJson = await prefs.getString(playlist);
      if (playlistJson != null) {
        final decoded = jsonDecode(playlistJson);
        MyPlayListController_favoriteplayerlists[playlist] = PlayList.fromJson(
          decoded,
        );
      }
    }
  }

  /// 并行异步加载设置（使用 compute，用于 release 模式）
  Future<void> _loadSettingsAwait() async {
    // 第一批：并行获取所有字符串数据
    final results = await Future.wait([
      getString('settings'),
      getString(CacheController_localCacheListKey),
      getString('player-settings'),
      getString('current-playing'),
      getStringList('playerlists'),
      getStringList('favoriteplayerlists'),
      getString(PlayController_play_replaceKey),
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
        computeResults[4] as Map<String, dynamic>,
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
    String jsonString = jsonEncode(settings);
    await setString('settings', jsonString);
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

  bool get use => useHive && box != null;

  // === HiveBox Or SharedPreferences ===
  Future<String?> getString(String key) async {
    if (use && box!.containsKey(key)) {
      return box!.get(key) as String?;
    } else {
      String? ret = await prefs.getString(key);
      if (use) {
        await box!.put(key, ret);
        await prefs.remove(key);
      }
      return ret;
    }
  }

  Future<bool> containsKey(String key) async {
    if (use && box!.containsKey(key)) {
      return box!.containsKey(key);
    } else {
      bool ret = await prefs.containsKey(key);
      if (use) {
        var value = await prefs.getString(key);
        await box!.put(key, value);
        await prefs.remove(key);
      }
      return ret;
    }
  }

  Future<void> setString(String key, String value) async {
    if (use) {
      await box!.put(key, value);
    } else {
      await prefs.setString(key, value);
    }
  }

  Future<void> setStringList(String key, List<String> value) async {
    if (use) {
      await box!.put(key, value);
    } else {
      await prefs.setStringList(key, value);
    }
  }

  Future<List<String>?> getStringList(String key) async {
    if (use && box!.containsKey(key)) {
      return List<String>.from(box!.get(key) as List);
    } else {
      List<String>? ret = await prefs.getStringList(key);
      if (use) {
        await box!.put(key, ret);
        await prefs.remove(key);
      }
      return ret;
    }
  }

  Future<Set<String>> getKeys({Set<String>? allowList}) async {
    if (use) {
      Set<String> perfsRes = await prefs.getKeys();
      if (allowList != null) {
        return box!.keys
            .where((key) => allowList.contains(key))
            .map((e) => e.toString())
            .toSet()
            .union(perfsRes);
      } else {
        return box!.keys.map((e) => e.toString()).toSet().union(perfsRes);
      }
    } else {
      if (allowList != null) {
        final allKeys = await prefs.getKeys();
        return allKeys.where((key) => allowList.contains(key)).toSet();
      } else {
        return await prefs.getKeys();
      }
    }
  }
}

///歌曲替换按钮位置及大小设置
enum SongReplaceFabLocation {
  startTop(
    'StartTop',
    FloatingActionButtonLocation.startTop,
    FloatingActionButtonLocation.miniStartTop,
  ),
  centerTop(
    'CenterTop',
    FloatingActionButtonLocation.centerTop,
    FloatingActionButtonLocation.miniCenterTop,
  ),
  endTop(
    'EndTop',
    FloatingActionButtonLocation.endTop,
    FloatingActionButtonLocation.miniEndTop,
  ),
  startFloat(
    'StartFloat',
    FloatingActionButtonLocation.startFloat,
    FloatingActionButtonLocation.miniStartFloat,
  ),
  centerFloat(
    'CenterFloat',
    FloatingActionButtonLocation.centerFloat,
    FloatingActionButtonLocation.miniCenterFloat,
  ),
  endFloat(
    'EndFloat',
    FloatingActionButtonLocation.endFloat,
    FloatingActionButtonLocation.miniEndFloat,
  ),
  startDocked(
    'StartDocked',
    FloatingActionButtonLocation.startDocked,
    FloatingActionButtonLocation.miniStartDocked,
  ),
  centerDocked(
    'CenterDocked',
    FloatingActionButtonLocation.centerDocked,
    FloatingActionButtonLocation.miniCenterDocked,
  ),
  endDocked(
    'EndDocked',
    FloatingActionButtonLocation.endDocked,
    FloatingActionButtonLocation.miniEndDocked,
  );

  final String desc;
  final FloatingActionButtonLocation fabLocation;
  final FloatingActionButtonLocation fabMiniLocation;
  const SongReplaceFabLocation(
    this.desc,
    this.fabLocation,
    this.fabMiniLocation,
  );
}
