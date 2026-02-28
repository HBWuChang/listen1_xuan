import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:get/get.dart';

import '../models/Playlist.dart';
import '../models/Track.dart';
import 'settings_controller.dart';

class MyPlayListController extends GetxController {
  final playerlists = <String, PlayList>{}.obs;
  final favoriteplayerlists = <String, PlayList>{}.obs;
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
      final s = Get.find<SettingsController>();
      await s.setStringList('playerlists', playerlists.keys.toList());
      for (var playlist in playerlists.entries) {
        String jsonString = kDebugMode
            ? jsonEncode(playlist.value.toJson())
            : await compute(
                (PlayList pl) => jsonEncode(pl.toJson()),
                playlist.value,
              );
        await s.setString(playlist.key, jsonString);
      }
      Get.find<SettingsController>().getMyPlayLists().then((playlists) async {
        Set<String> keysToRemove = playlists.difference(
          playerlists.keys.toSet(),
        );
        for (var key in keysToRemove) {
          await s.remove(key: key);
        }
      });
    });
    debounce(favoriteplayerlists, (callback) async {
      final s = Get.find<SettingsController>();
      await s.setStringList(
        'favoriteplayerlists',
        favoriteplayerlists.keys.toList(),
      );
      for (var playlist in favoriteplayerlists.entries) {
        String jsonString = kDebugMode
            ? jsonEncode(playlist.value.toJson())
            : await compute(
                (PlayList pl) => jsonEncode(pl.toJson()),
                playlist.value,
              );
        await s.setString(playlist.key, jsonString);
      }
      Get.find<SettingsController>().getPlayLists().then((playlists) async {
        Set<String> keysToRemove = playlists.difference(
          favoriteplayerlists.keys.toSet(),
        );
        for (var key in keysToRemove) {
          await s.remove(key: key);
        }
      });
    });
  }

  void loadDatas() {
    playerlists.value =
        Get.find<SettingsController>().MyPlayListController_playerlists;
    favoriteplayerlists.value =
        Get.find<SettingsController>().MyPlayListController_favoriteplayerlists;
    update();
  }

  Future<void> replaceTrack(Track newTrack, String repTrackId) async {
    // 使用 compute 在后台线程处理数据替换
    final updatedPlaylists = await compute(
      _replaceTrackInPlaylists,
      _ReplacementArgs(
        Map<String, PlayList>.from(playerlists),
        newTrack,
        repTrackId,
      ),
    );

    // 将修改后的数据赋给 playerlists
    playerlists.value = updatedPlaylists;
  }

  /// 后台线程中执行的歌曲替换逻辑
  static Map<String, PlayList> _replaceTrackInPlaylists(_ReplacementArgs args) {
    for (var playlist in args.playlists.values) {
      if (playlist.tracks == null || playlist.tracks!.isEmpty) continue;

      // 检查歌单中是否已经包含了要替换成的新歌曲
      bool hasNewTrack = playlist.tracks!.any(
        (track) => track.id == args.newTrack.id,
      );

      if (hasNewTrack) {
        // 如果已经包含新歌曲，只删除旧歌曲，避免重复
        playlist.tracks!.removeWhere((track) => track.id == args.repTrackId);
      } else {
        // 如果不包含新歌曲，将旧歌曲替换为新歌曲
        for (int i = 0; i < playlist.tracks!.length; i++) {
          if (playlist.tracks![i].id == args.repTrackId) {
            playlist.tracks![i] = args.newTrack;
          }
        }
      }
    }

    return args.playlists;
  }
}

/// 用于传递给 compute 的参数类
class _ReplacementArgs {
  final Map<String, PlayList> playlists;
  final Track newTrack;
  final String repTrackId;

  _ReplacementArgs(this.playlists, this.newTrack, this.repTrackId);
}
