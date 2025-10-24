// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_connect/http/src/utils/utils.dart';
import 'package:listen1_xuan/models/websocket_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:listen1_xuan/models/Track.dart';

import '../bl.dart';
import '../main.dart';
import '../netease.dart';
import '../qq.dart';
import '../settings.dart';
import 'myPlaylist_controller.dart';

class SettingsController extends GetxController {
  final settings = <String, dynamic>{}.obs;

  bool get tryShowLyricInNotification =>
      settings['tryShowLyricInNotification'] ?? true;
  set tryShowLyricInNotification(bool value) {
    settings['tryShowLyricInNotification'] = value;
  }

  var showLyricTranslation = true.obs; // 歌词翻译显示设置
  // var hideOrMinimize = false.obs;
  bool get hideOrMinimize => settings['hideOrMinimize'] ?? false;
  set hideOrMinimize(bool value) {
    settings['hideOrMinimize'] = value;
  }

  RxSet<int> settingsPageExpansion = <int>{}.obs;
  Set<int> _lastSettingsPageExpansion = <int>{};

  final String CacheController_localCacheListKey = 'local-cache-list';
  final CacheController_localCacheList = <String, String>{};
  var PlayController_player_settings = <String, dynamic>{};
  var PlayController_current_playing = <Track>[];
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
      if (callback.contains(0) &&
          _lastSettingsPageExpansion.contains(0) == false) {
        refreshLoginData();
      }
      _lastSettingsPageExpansion = Set<int>.from(callback); // 创建新的 Set 副本
    });
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('settings');
    if (jsonString != null) {
      settings.value = jsonDecode(jsonString);
    }
    // 加载 showLyricTranslation 的值
    showLyricTranslation.value = settings['showLyricTranslation'] ?? true;
    final localCacheListJson = prefs.getString(
      CacheController_localCacheListKey,
    );
    if (localCacheListJson != null) {
      final localCacheList = jsonDecode(localCacheListJson);
      CacheController_localCacheList.assignAll(
        Map<String, String>.from(localCacheList),
      );
    } else {
      CacheController_localCacheList.clear();
    }
    settingsPageExpansion.value = Set<int>.from(
      settings['settingsPageExpansion'] ?? <int>[],
    );
    _lastSettingsPageExpansion = Set<int>.from(settingsPageExpansion.value);
    
    final player_settings = await prefs.getString('player-settings');
    if (player_settings != null) {
      try {
        PlayController_player_settings = jsonDecode(player_settings);
      } catch (e) {}
    }
    final current_playing = await prefs.getString('current-playing');
    if (current_playing != null) {
      try {
        PlayController_current_playing = (jsonDecode(current_playing) as List)
            .map((track) => Track.fromJson(track))
            .toList();
      } catch (e) {}
    }
    MyPlayListController_playerlists.clear();
    MyPlayListController_favoriteplayerlists.clear();
    List<String>? playlists = prefs.getStringList('playerlists');
    for (var playlist in playlists ?? []) {
      final playlistJson = prefs.getString(playlist);
      if (playlistJson != null) {
        MyPlayListController_playerlists[playlist] = PlayList.fromJson(
          jsonDecode(playlistJson),
        );
      }
    }
    List<String>? favoritePlaylists = prefs.getStringList(
      'favoriteplayerlists',
    );
    for (var playlist in favoritePlaylists ?? []) {
      final playlistJson = prefs.getString(playlist);
      if (playlistJson != null) {
        MyPlayListController_favoriteplayerlists[playlist] = PlayList.fromJson(
          jsonDecode(playlistJson),
        );
      }
    }
  }

  Future<void> saveSettings() async {
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

  final readmeContent = ''.obs;
  bool get hasReadmeContent =>
      readmeContent.value.isNotEmpty && readmeContent.value != '加载失败';
  Future<void> loadReadme() async {
    try {
      readmeContent.value = '';
      final treadmeContent = await dio_with_ProxyAdapter.get(
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
}
