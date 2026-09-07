import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/settings_controller.dart';
import 'package:listen1_xuan/models/Playlist.dart';
import 'package:listen1_xuan/models/bootStrapTrackRes.dart';

import '../models/Track.dart';

enum SearchType { song, album, dj }

abstract class BaseProvider {
  String get id;
  String get name;
  String get shortDisplayName => name;
  bool get searchable;
  bool get supportLogin;
  bool get hidden => false;

  ///为了未来适配纯音源
  List<String> get supportProcessIds => [id];

  Future<dynamic>? search(String keywords, int curpage, SearchType type) =>
      null;

  /// 获取歌单详情
  Future<dynamic>? getPlaylist(String listId) => null;

  /// 获取热门歌单分类
  Future<Map<String, dynamic>>? getPlaylistFilters() => null;

  /// 获取热门歌单列表
  Future<List<PlayList>>? showPlaylist({int? offset, dynamic filterId}) => null;
  Future<List<PlayList>>? getUserFavoritePlaylist(String userId) => null;
  Future<List<PlayList>>? getUserCreatedPlaylist(String userId) => null;
  Future<(String lyric, String? tlyric)>? lyric(String trackId) => null;

  /// 获取歌曲播放地址
  Future<void> bootStrapTrack(
    Track track,
    Function(BootSuccessRes res, Track track) success,
    Function(Track track) failure,
  );

  SettingsController get settingsController => Get.find<SettingsController>();
}
