import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/settings_controller.dart';
import 'package:listen1_xuan/models/PlayList.dart';
import 'package:listen1_xuan/models/ProviderUser.dart';
import 'package:listen1_xuan/models/SearchPlayListRes.dart';
import 'package:listen1_xuan/models/SearchRes.dart';
import 'package:listen1_xuan/models/bootStrapTrackRes.dart';

import '../models/Track.dart';

enum SearchType { song, album, dj }

enum LoginStatus { noLogin, processing, loggedIn, failed }

abstract class BaseProvider extends GetxService {
  String get id;
  String get name;
  String get shortDisplayName => name;
  bool get searchable;
  bool get supportLogin;
  bool get hidden => false;

  ///为了未来适配纯音源
  List<String> get supportProcessIds => [id];

  /// 搜索接口
  /// 应返回一个 Future，Future 的结果类型应为 SearchRes 或 SearchPlayListRes
  /// curpage 为当前页码，从 1 开始
  /// 该方法不应抛出异常，而是应返回一个包含错误信息的 SearchRes 或 SearchPlayListRes 对象
  Future<dynamic>? search(String keywords, int curpage, SearchType type) =>
      null;
  Future<SearchRes>? searchSong(String keywords, int curpage) =>
      search(keywords, curpage, SearchType.song) as Future<SearchRes>?;

  Future<SearchPlayListRes>? searchPlaylist(
    String keywords,
    int curpage,
    SearchType type,
  ) {
    assert(type != SearchType.song, 'Invalid search type: $type');
    return search(keywords, curpage, type) as Future<SearchPlayListRes>?;
  }

  /// 获取歌单详情
  Future<PlayList>? getPlaylist(String listId) => null;

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

  Rx<LoginStatus> loginStatus = LoginStatus.failed.obs;
  RxString loginError = ''.obs;
  Future<void> login() async {
    loginStatus.value = LoginStatus.processing;
  }

  Future<void> logout() async {
    loginStatus.value = LoginStatus.noLogin;
  }

  Future<ProviderUser?>? getUser() => null;
}
