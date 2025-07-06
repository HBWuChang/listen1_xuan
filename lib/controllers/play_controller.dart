import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../global_settings_animations.dart';

class Track {
  String id;
  String? title;
  String? artist;
  String? artist_id;
  String? album;
  String? album_id;
  String? source;
  String? source_url;
  String? img_url;
  String? lyric_url;

  Track({
    required this.id,
    this.title,
    this.artist,
    this.artist_id,
    this.album,
    this.album_id,
    this.source,
    this.source_url,
    this.img_url,
    this.lyric_url,
  });

  // 从 JSON 创建 Track 对象
  factory Track.fromJson(Map<String, dynamic> json) {
    String? lyric_url;
    if (json['lyric_url'] is String) {
      lyric_url = json['lyric_url'];
    } else if (json['lyric_url'] != null) {
      lyric_url = json['lyric_url'].toString();
    } else {
      lyric_url = null;
    }
    return Track(
      id: json['id'] as String,
      title: json['title'] as String?,
      artist: json['artist'] as String?,
      artist_id: json['artist_id'] as String?,
      album: json['album'] as String?,
      album_id: json['album_id'] as String?,
      source: json['source'] as String?,
      source_url: json['source_url'] as String?,
      img_url: json['img_url'] as String?,
      lyric_url: lyric_url,
    );
  }

  // 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'artist_id': artist_id,
      'album': album,
      'album_id': album_id,
      'source': source,
      'source_url': source_url,
      'img_url': img_url,
      'lyric_url': lyric_url,
    };
  }
}

class PlayController extends GetxController {
  final music_player = AudioPlayer();
  var _player_settings = <String, dynamic>{}.obs;
  Timer? _save_player_settings_Timer;
  var _current_playing = <Track>[].obs;
  Timer? _save_current_playing_Timer;
  var isplaying = false.obs;
  double get currentVolume => (_player_settings['volume'] ?? 50.0) / 100.0;
  set currentVolume(double value) {
    _player_settings['volume'] = value * 100.0;
    music_player.setVolume(value);
  }

  @override
  void onInit() {
    super.onInit();
    ever(_player_settings, (callback) {
      _addTimer('player-settings');
    });
    ever(_current_playing, (callback) {
      _addTimer('current-playing');
    });
    music_player.playingStream.listen((event) {
      isplaying.value = event;
    });
  }

  void _addTimer(String key) {
    Timer? timer;
    switch (key) {
      case 'player-settings':
        timer = _save_player_settings_Timer;
        break;
      case 'current-playing':
        timer = _save_current_playing_Timer;
        break;
    }
    
    if (timer?.isActive ?? false) {
      timer!.cancel();
    }
    
    Timer newTimer = Timer(const Duration(seconds: 1), () {
      _saveSingleSetting(key);
    });
    
    switch (key) {
      case 'player-settings':
        _save_player_settings_Timer = newTimer;
        break;
      case 'current-playing':
        _save_current_playing_Timer = newTimer;
        break;
    }
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
          xuan_toast(
            msg: '循环',
          );
          break;
        case 1:
          xuan_toast(
            msg: '随机',
          );
          break;
        case 2:
          xuan_toast(
            msg: '单曲',
          );
          break;
        default:
          break;
      }
    }
    _player_settings[key] = value;
  }

  Future<void> loadDatas() async {
    final prefs = await SharedPreferences.getInstance();
    final player_settings = await prefs.getString('player-settings');
    if (player_settings != null) {
      try {
        _player_settings.value = jsonDecode(player_settings);
      } catch (e) {}
    }
    final current_playing = await prefs.getString('current-playing');
    if (current_playing != null) {
      try {
        _current_playing.value = (jsonDecode(current_playing) as List)
            .map((track) => Track.fromJson(track))
            .toList();
      } catch (e) {}
    }
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
  //     }
  //   }
  //   await set_current_playing(current_playing);
  // }

  // Future<void> set_current_playing(List<Map<String, dynamic>> tracks) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final current_playing = jsonEncode(tracks);
  //   await prefs.setString('current-playing', current_playing);
  // }

  // Future<List<Map<String, dynamic>>> get_current_playing() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final current_playing = await prefs.getString('current-playing');
  //   if (current_playing != null) {
  //     try {
  //       final List<dynamic> current_playing_json = jsonDecode(current_playing);
  //       return current_playing_json.cast<Map<String, dynamic>>();
  //     } catch (e) {
  //       return [];
  //     }
  //   }
  //   return [];
  // }
}
