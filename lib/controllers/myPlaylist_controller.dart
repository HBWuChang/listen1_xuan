import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smtc_windows/smtc_windows.dart';

import '../global_settings_animations.dart';
import '../play.dart';
import 'play_controller.dart';

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
  Timer? _savePlayerListsTimer;
  var favoriteplayerlists = <String, PlayList>{}.obs;
  Timer? _saveFavoritePlayerListsTimer;
  @override
  void onInit() {
    super.onInit();
    ever(playerlists, (callback) {
      _addTimer('playerlists');
    });
    ever(favoriteplayerlists, (callback) {
      _addTimer('favoriteplayerlists');
    });
  }

  void _addTimer(String key) {
    Timer? timer;
    switch (key) {
      case 'playerlists':
        timer = _savePlayerListsTimer;
        break;
      case 'favoriteplayerlists':
        timer = _saveFavoritePlayerListsTimer;
        break;
    }
    
    if (timer?.isActive ?? false) {
      timer!.cancel();
    }
    
    Timer newTimer = Timer(const Duration(seconds: 1), () {
      _saveSingleSetting(key);
    });
    
    switch (key) {
      case 'playerlists':
        _savePlayerListsTimer = newTimer;
        break;
      case 'favoriteplayerlists':
        _saveFavoritePlayerListsTimer = newTimer;
        break;
    }
  }

  Future<void> _saveSingleSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    switch (key) {
      case 'playerlists':
        await prefs.setStringList(key, playerlists.keys.toList());
        for (var playlist in playerlists.entries) {
          String jsonString = jsonEncode(playlist.value.toJson());
          await prefs.setString(playlist.key, jsonString);
        }
        break;
      case 'favoriteplayerlists':
        await prefs.setStringList(key, favoriteplayerlists.keys.toList());
        for (var playlist in favoriteplayerlists.entries) {
          String jsonString = jsonEncode(playlist.value.toJson());
          await prefs.setString(playlist.key, jsonString);
        }
        break;
      default:
        throw Exception('Unknown key: $key');
    }
  }

  Future<void> loadDatas() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? playlists = prefs.getStringList('playerlists');
    for (var playlist in playlists ?? []) {
      final playlistJson = prefs.getString(playlist);
      if (playlistJson != null) {
        playerlists[playlist] = PlayList.fromJson(jsonDecode(playlistJson));
      }
    }
    List<String>? favoritePlaylists =
        prefs.getStringList('favoriteplayerlists');
    for (var playlist in favoritePlaylists ?? []) {
      final playlistJson = prefs.getString(playlist);
      if (playlistJson != null) {
        favoriteplayerlists[playlist] =
            PlayList.fromJson(jsonDecode(playlistJson));
      }
    }
  }
}
