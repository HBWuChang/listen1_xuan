import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:listen1_xuan/models/Track.dart';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_controller.dart';

class PlayListInfo {
  String id;
  String? cover_img_url;
  String? title;
  String? source_url;

  PlayListInfo({
    required this.id,
    this.cover_img_url,
    this.title,
    this.source_url,
  });
  factory PlayListInfo.fromJson(Map<String, dynamic> json) {
    return PlayListInfo(
      id: json['id'] as String,
      cover_img_url: json['cover_img_url'] as String?,
      title: json['title'] as String?,
      source_url: json['source_url'] as String?,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cover_img_url': cover_img_url,
      'title': title,
      'source_url': source_url,
    };
  }
}

class PlayList {
  PlayListInfo info;
  int is_mine;
  int is_fav;
  List<Track>? tracks;
  PlayList({
    required this.info,
    this.is_mine = 0,
    this.is_fav = 0,
    this.tracks,
  });
  factory PlayList.fromJson(Map<String, dynamic> json) {
    var tracks = json['tracks'];
    if (tracks is List) {
      if (tracks.isNotEmpty) {
        if (tracks[0] is Map<String, dynamic>) {
          tracks = tracks.map((track) => Track.fromJson(track)).toList();
        } else if (tracks[0] is Track) {
          // If already a list of Track objects, no conversion needed
        } else {
          throw Exception('Invalid track data format');
        }
      }
    }
    tracks = tracks != null ? List<Track>.from(tracks) : null;
    return PlayList(
      info: PlayListInfo.fromJson(json['info']),
      is_mine: json['is_mine'] as int? ?? 0,
      is_fav: json['is_fav'] as int? ?? 0,
      tracks: tracks,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'info': info.toJson(),
      'is_mine': is_mine,
      'is_fav': is_fav,
      'tracks': tracks?.map((track) => track.toJson()).toList(),
    };
  }
}

class MyPlayListController extends GetxController {
  var playerlists = <String, PlayList>{}.obs;
  var favoriteplayerlists = <String, PlayList>{}.obs;
  Set<String> get savedIds {
    Set<String> ids = {};
    for (var playlist in playerlists.values) {
      ids.addAll(playlist.tracks?.map((track) => track.id).toSet() ?? {});
    }
    return ids;
  }

  @override
  void onInit() {
    super.onInit();
    debounce(playerlists, (callback) async {
      final prefs = SharedPreferencesAsync();
      await prefs.setStringList('playerlists', playerlists.keys.toList());
      for (var playlist in playerlists.entries) {
        String jsonString = await compute(
          (PlayList pl) => jsonEncode(pl.toJson()),
          playlist.value,
        );
        await prefs.setString(playlist.key, jsonString);
      }
    });
    debounce(favoriteplayerlists, (callback) async {
      final prefs = SharedPreferencesAsync();
      await prefs.setStringList(
        'favoriteplayerlists',
        favoriteplayerlists.keys.toList(),
      );
      for (var playlist in favoriteplayerlists.entries) {
        String jsonString = await compute(
          (PlayList pl) => jsonEncode(pl.toJson()),
          playlist.value,
        );
        await prefs.setString(playlist.key, jsonString);
      }
    });
  }

  void loadDatas() {
    playerlists.value =
        Get.find<SettingsController>().MyPlayListController_playerlists;
    favoriteplayerlists.value =
        Get.find<SettingsController>().MyPlayListController_favoriteplayerlists;
    update();
  }
}
