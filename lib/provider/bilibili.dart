import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart' hide FormData;
import 'package:html/parser.dart' show parse;
import 'package:listen1_xuan/constants/const.dart';
import 'package:listen1_xuan/controllers/DioController.dart';
import 'package:listen1_xuan/controllers/search_controller.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/models/AudioQualityOfBL.dart';
import 'package:listen1_xuan/models/PlayListFilters.dart';
import 'package:listen1_xuan/models/PlayListInfo.dart';
import 'package:listen1_xuan/models/Playlist.dart';
import 'package:listen1_xuan/models/ProviderUser.dart';
import 'package:listen1_xuan/models/SearchPlayListRes.dart';
import 'package:listen1_xuan/models/SearchRes.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:listen1_xuan/models/bootStrapTrackRes.dart';
import 'package:listen1_xuan/settings.dart';

import 'base.dart';

enum BLPlaylistType {
  playlist('biplaylist'),
  album('bialbum'),
  artist('biartist'),
  track('bitrack'),
  playlistxuan('biplaylistxuan');

  final String prefix;
  const BLPlaylistType(this.prefix);
}

enum BLPlayListXuanType {
  my('my', desc: '我创建的收藏夹'),
  toview('toview', desc: '稍后再看'),
  ugcSeason('ugcSeason', desc: '视频所处的合集'),
  mycollect('', desc: '我追的合集/收藏夹');

  final String prefix;
  final String? desc;
  const BLPlayListXuanType(this.prefix, {this.desc});
}

class Bilibili extends BaseProvider {
  @override
  String get id => 'bi';

  @override
  String get name => 'bilibili';

  @override
  String get shortDisplayName => 'B站';

  @override
  bool get searchable => true;

  @override
  bool get supportLogin => true;

  @override
  bool get supportLyric => false;

  @override
  bool get supportShowPlaylist => true;

  @override
  bool get supportGetUserCreatedPlaylist => true;

  @override
  bool get supportGetUserFavoritePlaylist => true;

  @override
  String get userCreatedPlaylistSectionTitle => '我创建的哔哩哔哩收藏夹';

  @override
  Widget get userCreatedPlaylistSectionLeading => _bilibiliSectionIcon;

  @override
  String get userFavoritePlaylistSectionTitle => '我追的哔哩哔哩合集';

  @override
  Widget get userFavoritePlaylistSectionLeading => _bilibiliSectionIcon;

  Widget get _bilibiliSectionIcon =>
      SvgPicture.string(_bilibiliIconSvg, width: 18, height: 18);

  static String get sourceName => PlatformSource.bilibili.name;

  static const String _bilibiliIconSvg =
      '<svg width="18" height="18" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg" class="zhuzhan-icon"><path fill-rule="evenodd" clip-rule="evenodd" d="M3.73252 2.67094C3.33229 2.28484 3.33229 1.64373 3.73252 1.25764C4.11291 0.890684 4.71552 0.890684 5.09591 1.25764L7.21723 3.30403C7.27749 3.36218 7.32869 3.4261 7.37081 3.49407H10.5789C10.6211 3.4261 10.6723 3.36218 10.7325 3.30403L12.8538 1.25764C13.2342 0.890684 13.8368 0.890684 14.2172 1.25764C14.6175 1.64373 14.6175 2.28484 14.2172 2.67094L13.364 3.49407H14C16.2091 3.49407 18 5.28493 18 7.49407V12.9996C18 15.2087 16.2091 16.9996 14 16.9996H4C1.79086 16.9996 0 15.2087 0 12.9996V7.49406C0 5.28492 1.79086 3.49407 4 3.49407H4.58579L3.73252 2.67094ZM4 5.42343C2.89543 5.42343 2 6.31886 2 7.42343V13.0702C2 14.1748 2.89543 15.0702 4 15.0702H14C15.1046 15.0702 16 14.1748 16 13.0702V7.42343C16 6.31886 15.1046 5.42343 14 5.42343H4ZM5 9.31747C5 8.76519 5.44772 8.31747 6 8.31747C6.55228 8.31747 7 8.76519 7 9.31747V10.2115C7 10.7638 6.55228 11.2115 6 11.2115C5.44772 11.2115 5 10.7638 5 10.2115V9.31747ZM12 8.31747C11.4477 8.31747 11 8.76519 11 9.31747V10.2115C11 10.7638 11.4477 11.2115 12 11.2115C12.5523 11.2115 13 10.7638 13 10.2115V9.31747C13 8.76519 12.5523 8.31747 12 8.31747Z" fill="gray"></path></svg>';

  static Map<String, String>? _wbiKey;

  // #region WBI 签名

  static Future<Map<String, String>> _fetchWbiKey() async {
    final response = await dioWithCookieManager.get(
      'https://api.bilibili.com/x/web-interface/nav',
    );
    final jsonContent = response.data;
    final imgUrl = jsonContent['data']['wbi_img']['img_url'] as String;
    final subUrl = jsonContent['data']['wbi_img']['sub_url'] as String;
    return {
      'img_key': imgUrl.substring(
        imgUrl.lastIndexOf('/') + 1,
        imgUrl.lastIndexOf('.'),
      ),
      'sub_key': subUrl.substring(
        subUrl.lastIndexOf('/') + 1,
        subUrl.lastIndexOf('.'),
      ),
    };
  }

  static void clearWbiKey() {
    _wbiKey = null;
  }

  static Future<Map<String, String>> _getWbiKey() async {
    final cached = _wbiKey;
    if (cached != null) {
      return cached;
    }
    final key = await _fetchWbiKey();
    _wbiKey = key;
    return key;
  }

  static Future<String> _encWbi(Map<String, dynamic> params) async {
    final key = await _getWbiKey();
    final imgKey = key['img_key']!;
    final subKey = key['sub_key']!;
    const mixinKeyEncTab = [
      46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5,
      49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24,
      55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63,
      57, 62, 11, 36, 20, 34, 44, 52,
    ];

    String getMixinKey(String original) {
      var temp = '';
      for (final n in mixinKeyEncTab) {
        temp += original[n];
      }
      return temp.substring(0, 32);
    }

    final mixinKey = getMixinKey(imgKey + subKey);
    final currTime = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    final chrFilter = RegExp(r"[!'()*]");
    final query = <String>[];
    params['wts'] = currTime;
    final sortedKeys = params.keys.toList()..sort();
    for (final key in sortedKeys) {
      query.add(
        '${Uri.encodeComponent(key)}=${Uri.encodeComponent(params[key].toString().replaceAll(chrFilter, ''))}',
      );
    }
    final queryString = query.join('&');
    final wbiSign = md5.convert(utf8.encode(queryString + mixinKey)).toString();
    return '$queryString&w_rid=$wbiSign';
  }

  static Future<dynamic> wrapWbiRequest(
    String url,
    Map<String, dynamic> params, {
    ResponseType? responseType,
  }) async {
    final queryString = await _encWbi(params);
    final targetUrl = '$url?$queryString';
    return dioWithCookieManager.get(
      targetUrl,
      options: Options(
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36',
          'Connection': 'keep-alive',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Encoding': 'gzip, deflate, br',
          'accept-language': 'zh-CN',
          'referer': 'https://www.bilibili.com/',
          'sec-fetch-dest': 'empty',
          'sec-fetch-mode': 'cors',
          'sec-fetch-site': 'cross-site',
        },
        validateStatus: (status) => status != null && status < 500,
        responseType: responseType,
      ),
    );
  }

  // #endregion

  // #region 登录 / 用户

  /// 检查 B 站 cookie 是否有效，有效时返回用户名，否则返回空字符串。
  Future<String> checkBlCookie() async {
    final settings = lengcyGetSettings();
    final cookie = settings['bl'];
    if (isEmpty(cookie)) {
      return '';
    }
    try {
      final response = await dioWithCookieManager.get(
        'https://api.bilibili.com/x/web-interface/nav',
        options: Options(
          headers: {
            'cookie': cookie,
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36 Edg/125.0.0.0',
            'Referer': 'https://www.bilibili.com/',
            'Origin': 'https://www.bilibili.com',
          },
        ),
      );
      if (response.data['code'] == 0) {
        return response.data['data']['uname'] as String;
      }
    } catch (e) {
      logger.e('Bilibili cookie 无效', error: e);
    }
    return '';
  }

  @override
  Future<ProviderUser?> getUser() async {
    loginStatus.value = LoginStatus.processing;
    try {
      final user = await _fetchUser();
      if (user != null) {
        loginStatus.value = LoginStatus.loggedIn;
        return user;
      }
      loginStatus.value = LoginStatus.noLogin;
      return null;
    } catch (e) {
      loginError.value = e.toString();
      loginStatus.value = LoginStatus.failed;
      return null;
    }
  }

  Future<ProviderUser?> _fetchUser() async {
    final settings = lengcyGetSettings();
    final cookie = settings['bl'];
    if (isEmpty(cookie)) {
      return null;
    }
    final response = await dioWithCookieManager.get(
      'https://api.bilibili.com/x/web-interface/nav',
      options: Options(
        headers: {
          'cookie': cookie,
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36 Edg/125.0.0.0',
          'Referer': 'https://www.bilibili.com/',
          'Origin': 'https://www.bilibili.com',
        },
      ),
    );
    final data = response.data['data'];
    if (response.data['code'] == 0 && data?['isLogin'] == true) {
      return ProviderUser(
        platform: name,
        userId: '${data['mid']}',
        name: data['uname'] as String,
      );
    }
    return null;
  }

  @override
  Future<void> logout() async {
    loginStatus.value = LoginStatus.noLogin;
  }

  // #endregion

  // #region 我的歌单

  /// 我创建的收藏夹（含“稍后再看”）
  @override
  Future<List<PlayList>> getUserCreatedPlaylist(String userId) async {
    final response = await dioWithCookieManager.get(
      'https://api.bilibili.com/x/v3/fav/folder/list4navigate',
      options: Options(headers: {'content-type': 'application/json'}),
    );
    final playlists = <PlayList>[
      PlayList(
        info: PlayListInfo(
          id: '${BLPlaylistType.playlistxuan.prefix}_${BLPlayListXuanType.toview.prefix}$userId',
          title: BLPlayListXuanType.toview.desc,
          cover_img_url: '',
          source_url: 'https://www.bilibili.com/watchlater/list',
        ),
      ),
    ];
    final data = response.data['data'];
    if (data is List) {
      for (final item in data) {
        final list = item['mediaListResponse']?['list'];
        if (list is List) {
          for (final element in list) {
            playlists.add(
              PlayList.fromJson({
                'info': {
                  'cover_img_url': element['cover'],
                  'title': element['title'],
                  'id':
                      '${BLPlaylistType.playlistxuan.prefix}_${BLPlayListXuanType.my.prefix}${element['id']}',
                  'source_url':
                      'https://api.bilibili.com/x/v3/fav/resource/list?ps=20&keyword&order=mtime&type=0&tid=0&platform=web&pn=1&media_id=${element['id']}',
                },
              }),
            );
          }
        }
      }
    }
    return playlists;
  }

  /// 我追的合集/收藏夹
  @override
  Future<List<PlayList>> getUserFavoritePlaylist(String userId) async {
    const url = 'https://api.bilibili.com/x/v3/fav/folder/collected/list';
    final playlists = <PlayList>[];

    void collect(dynamic data) {
      final list = data['data']['list'];
      if (list is List) {
        for (final item in list) {
          playlists.add(
            PlayList.fromJson({
              'info': {
                'cover_img_url': item['cover'],
                'title': item['title'],
                'id':
                    '${BLPlaylistType.playlistxuan.prefix}_${BLPlayListXuanType.mycollect.prefix}${item['id']}',
                'source_url':
                    'https://api.bilibili.com/x/space/fav/season/list?pn=1&ps=20&season_id=${item['id']}',
              },
            }),
          );
        }
      }
    }

    var pn = 1;
    var hasMore = true;
    while (hasMore) {
      final response = await dioWithCookieManager.get(
        '$url?pn=$pn&ps=20&up_mid=$userId&platform=web',
        options: Options(headers: {'content-type': 'application/json'}),
      );
      collect(response.data);
      hasMore = response.data['data']['has_more'] == true;
      pn++;
    }
    return playlists;
  }

  // #endregion

  // #region 歌单详情

  @override
  Future<PlayList> getPlaylist(String listId) async {
    final prefix = listId.split('_').first;
    if (prefix == BLPlaylistType.playlist.prefix) {
      return _getAudioPlaylist(listId);
    }
    if (prefix == BLPlaylistType.playlistxuan.prefix) {
      return _getPlaylistXuan(listId);
    }
    if (prefix == BLPlaylistType.album.prefix) {
      return _getAlbum(listId);
    }
    if (prefix == BLPlaylistType.artist.prefix) {
      return _getArtist(listId);
    }
    if (prefix == BLPlaylistType.track.prefix) {
      return _getVideoTrack(listId);
    }
    throw Exception('不支持的哔哩哔哩歌单类型: $listId');
  }

  /// 音频区歌单：`biplaylist_<menuId>`
  Future<PlayList> _getAudioPlaylist(String listId) async {
    final menuId = listId.split('_').last;
    final infoResponse = await dioWithCookieManager.get(
      'https://www.bilibili.com/audio/music-service-c/web/menu/info?sid=$menuId',
    );
    final data = infoResponse.data['data'];
    final info = {
      'cover_img_url': data['cover'],
      'title': data['title'],
      'id': '${BLPlaylistType.playlist.prefix}_$menuId',
      'source_url': 'https://www.bilibili.com/audio/am$menuId',
    };
    final trackResponse = await dioWithCookieManager.get(
      'https://www.bilibili.com/audio/music-service-c/web/song/of-menu?pn=1&ps=100&sid=$menuId',
    );
    final tracks = (trackResponse.data['data']['data'] as List)
        .map((item) => _convertAudioSong(item))
        .toList();
    return PlayList.fromJson({'info': info, 'tracks': tracks});
  }

  /// 收藏夹/合集/稍后再看：`biplaylistxuan_<type><id>`
  Future<PlayList> _getPlaylistXuan(String listId) async {
    final selectMid = listId.split('_').last;

    if (selectMid.startsWith(BLPlayListXuanType.my.prefix)) {
      return _getMyFavFolder(listId, selectMid);
    }
    if (selectMid.startsWith(BLPlayListXuanType.ugcSeason.prefix)) {
      return _getUgcSeason(listId, selectMid);
    }
    if (selectMid.startsWith(BLPlayListXuanType.toview.prefix)) {
      return _getToView(listId);
    }
    return _getCollectedSeason(listId, selectMid);
  }

  /// 我创建的收藏夹
  Future<PlayList> _getMyFavFolder(String listId, String selectMid) async {
    final mediaId = selectMid.substring(BLPlayListXuanType.my.prefix.length);
    const url =
        'https://api.bilibili.com/x/v3/fav/resource/list?ps=20&keyword&order=mtime&type=0&tid=0&platform=web&';
    final headers = {'content-type': 'application/json'};
    final medias = <dynamic>[];

    var pn = 1;
    var hasMore = true;
    dynamic firstData;
    while (hasMore) {
      final response = await dioWithCookieManager.get(
        '${url}pn=$pn&media_id=$mediaId',
        options: Options(headers: headers),
      );
      final data = response.data['data'];
      firstData ??= data;
      (data['medias'] as List).forEach(medias.add);
      hasMore = data['has_more'] == true;
      pn++;
    }
    final info = {
      'cover_img_url': firstData['info']['cover'],
      'title': firstData['info']['title'],
      'id': '${BLPlaylistType.playlistxuan.prefix}_$selectMid',
      'source_url':
          'https://api.bilibili.com/x/v3/fav/resource/list?ps=20&keyword&order=mtime&type=0&tid=0&platform=web&pn=1&media_id=$mediaId',
    };
    final tracks = medias.map((item) => _convertFavVideo(item)).toList();
    return PlayList.fromJson({'info': info, 'tracks': tracks});
  }

  /// 视频所属合集
  Future<PlayList> _getUgcSeason(String listId, String selectMid) async {
    final bvid = selectMid.substring(BLPlayListXuanType.ugcSeason.prefix.length);
    final response = await dioWithCookieManager.get(
      'https://api.bilibili.com/x/web-interface/wbi/view/detail',
      queryParameters: {'bvid': bvid},
      options: Options(
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36 Edg/142.0.0.0',
          'Referer': 'https://www.bilibili.com/',
          'Origin': 'https://space.bilibili.com',
        },
      ),
    );
    final data = response.data['data'] as Map<String, dynamic>;
    final ugcSeason = data['View']?['ugc_season'];
    if (ugcSeason?['id'] == null) {
      Get.find<XSearchController>().toListByIDOrSearch(
        '${BLPlaylistType.track.prefix}_v_$bvid',
        off: true,
      );
      throw Exception('该视频没有所属合集信息，无法获取歌单\n已尝试跳转到分P信息');
    }
    final info = {
      'cover_img_url': ugcSeason['cover'],
      'title': ugcSeason['title'],
      'id': '${BLPlaylistType.playlistxuan.prefix}_$selectMid',
      'source_url':
          'https://space.bilibili.com/${data['View']?['owner']['mid']}/lists?sid=${ugcSeason['id']}',
    };
    final tracks = (ugcSeason['sections'] as List<dynamic>)
        .map((item) => _convertUgcSeasonSectionToTracks(item))
        .fold(<Track>[], (prev, element) => [...prev, ...element]);
    return PlayList.fromJson({'info': info, 'tracks': tracks});
  }

  /// 稍后再看
  Future<PlayList> _getToView(String listId) async {
    final response = await dioWithCookieManager.get(
      'https://api.bilibili.com/x/v2/history/toview/web',
      options: Options(
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36 Edg/142.0.0.0',
          'Referer': 'https://www.bilibili.com/',
          'Origin': 'https://space.bilibili.com',
        },
      ),
    );
    final info = {
      'cover_img_url': '',
      'title': BLPlayListXuanType.toview.desc,
      'id': listId,
      'source_url': 'https://www.bilibili.com/watchlater/list',
    };
    final tracks = (response.data['data']['list'] as List)
        .map((item) => _convertToviewVideo(item))
        .toList();
    return PlayList.fromJson({'info': info, 'tracks': tracks});
  }

  /// 我追的合集/收藏夹
  Future<PlayList> _getCollectedSeason(String listId, String selectMid) async {
    final response = await dioWithCookieManager.get(
      'https://api.bilibili.com/x/space/fav/season/list?pn=1&ps=20&season_id=$selectMid',
      options: Options(headers: {'content-type': 'application/json'}),
    );
    final data = response.data['data'];
    final info = {
      'cover_img_url': data['info']['cover'],
      'title': data['info']['title'],
      'id': '${BLPlaylistType.playlistxuan.prefix}_$selectMid',
      'source_url':
          'https://api.bilibili.com/x/space/fav/season/list?pn=1&ps=20&season_id=$selectMid',
    };
    final tracks = (data['medias'] as List)
        .map((item) => _convertFavVideo(item))
        .toList();
    return PlayList.fromJson({'info': info, 'tracks': tracks});
  }

  Future<PlayList> _getAlbum(String listId) async {
    // 音频区暂未支持专辑
    throw Exception('不支持的哔哩哔哩歌单类型: $listId');
  }

  /// 音频区歌手 / UP 主：`biartist_<uid>` 或 `biartist_v_<mid>`
  Future<PlayList> _getArtist(String listId) async {
    final parts = listId.split('_');
    final artistId = parts.last;
    final response = await wrapWbiRequest(
      'https://api.bilibili.com/x/space/wbi/acc/info',
      {'mid': artistId},
    );
    final data = response.data['data'];
    final info = {
      'cover_img_url': data['face'],
      'title': data['name'],
      'id': '${BLPlaylistType.artist.prefix}_$artistId',
      'source_url': 'https://space.bilibili.com/$artistId/#/audio',
    };

    List<Map<String, dynamic>> tracks;
    if (parts.length == 3) {
      // biartist_v_<mid>：UP 主投稿视频
      final res = await wrapWbiRequest(
        'https://api.bilibili.com/x/space/wbi/arc/search',
        {'mid': artistId, 'pn': 1, 'ps': 25, 'order': 'click', 'index': 1},
      );
      tracks = (res.data['data']['list']['vlist'] as List)
          .map((item) => _convertVideoSong(item))
          .toList();
    } else {
      final res = await dioWithCookieManager.get(
        'https://api.bilibili.com/audio/music-service-c/web/song/upper?pn=1&ps=0&order=2&uid=$artistId',
      );
      tracks = (res.data['data']['data'] as List)
          .map((item) => _convertAudioSong(item))
          .toList();
    }
    return PlayList.fromJson({'info': info, 'tracks': tracks});
  }

  /// 视频分 P：`bitrack_v_<bvid>` 或 `bitrack_v_<bvid>-<cid>`
  Future<PlayList> _getVideoTrack(String listId) async {
    final trackId = listId.split('_').last.split('-').first;
    final response = await dioWithCookieManager.get(
      'https://api.bilibili.com/x/web-interface/view?bvid=$trackId',
    );
    final data = response.data['data'];
    final info = {
      'cover_img_url': data['pic'],
      'title': data['title'],
      'id': '${BLPlaylistType.track.prefix}_v_$trackId',
      'source_url': 'https://www.bilibili.com/video/$trackId',
    };
    final author = data['owner'] as Map<String, dynamic>;
    final defaultImg = data['pic'] as String;
    final tracks = (data['pages'] as List)
        .map((item) => _convertVideoPage(item, trackId, author, defaultImg))
        .toList();
    return PlayList.fromJson({'info': info, 'tracks': tracks});
  }

  // #endregion

  // #region 热门歌单

  @override
  Future<List<PlayList>>? showPlaylist({int? offset, dynamic filterId}) async {
    final page = ((offset ?? 0) / 20).ceil() + 1;
    final response = await dioWithCookieManager.get(
      'https://www.bilibili.com/audio/music-service-c/web/menu/hit?ps=20&pn=$page',
    );
    final data = response.data['data']['data'] as List;
    return data.map((item) {
      return PlayList.fromJson({
        'info': {
          'cover_img_url': item['cover'],
          'title': item['title'],
          'id': '${BLPlaylistType.playlist.prefix}_${item['menuId']}',
          'source_url': 'https://www.bilibili.com/audio/am${item['menuId']}',
        },
      });
    }).toList();
  }

  @override
  Future<PlayListFilters>? getPlaylistFilters() async {
    return const PlayListFilters(recommended: [], filters: []);
  }

  // #endregion

  // #region 搜索

  Future<Map<String, dynamic>> _searchVideo(
    String keywords,
    int curpage,
  ) async {
    final targetUrl =
        'https://api.bilibili.com/x/web-interface/search/type?__refresh__=true&_extra=&context=&page=$curpage&page_size=42&platform=pc&highlight=1&single_column=0&keyword=${Uri.encodeComponent(keywords)}&category_id=&search_type=video&dynamic_offset=0&preload=true&com2co=true';
    final response = await dioWithCookieManager.get(targetUrl);
    return response.data['data'] as Map<String, dynamic>;
  }

  @override
  Future<SearchRes>? searchSong(String keywords, int curpage) async {
    try {
      final data = await _searchVideo(keywords, curpage);
      final list = data['result'] as List?;
      final tracks = (list ?? [])
          .map((song) => Track.fromJson(_convertVideoSong(song)))
          .toList();
      return SearchRes(result: tracks, total: data['numResults'] as int? ?? 0);
    } catch (e) {
      logger.e('Bilibili 搜索失败', error: e);
      return SearchRes.error('Bilibili 搜索失败: $e');
    }
  }

  @override
  Future<SearchPlayListRes>? searchPlaylist(
    String keywords,
    int curpage,
    SearchType type,
  ) async {
    if (type != SearchType.album) {
      return SearchPlayListRes.empty();
    }
    try {
      final data = await _searchVideo(keywords, curpage);
      final list = data['result'] as List?;
      final items = (list ?? [])
          .map((song) => _convertSongToPlayListUgcSeason(song))
          .toList();
      return SearchPlayListRes(
        result: items,
        total: data['numResults'] as int? ?? 0,
      );
    } catch (e) {
      logger.e('Bilibili 搜索失败', error: e);
      return SearchPlayListRes.error('Bilibili 搜索失败: $e');
    }
  }

  // #endregion

  // #region 播放地址

  @override
  Future<void> bootStrapTrack(
    Track track,
    Function(BootSuccessRes res, Track track) success,
    Function(Track track) failure,
  ) async {
    final trackId = track.id;
    if (trackId.startsWith('bitrack_v_')) {
      await _bootstrapVideoTrack(track, success, failure);
    } else {
      await _bootstrapAudioTrack(track, success, failure);
    }
  }

  Future<void> _bootstrapVideoTrack(
    Track track,
    Function(BootSuccessRes res, Track track) success,
    Function(Track track) failure,
  ) async {
    final trackId = track.id;
    var bvid = trackId.substring('bitrack_v_'.length);
    final trackIdCheck = trackId.split('-');
    if (trackIdCheck.length > 1) {
      bvid = trackIdCheck[0].substring('bitrack_v_'.length);
    }
    try {
      final viewResponse = await dioWithCookieManager.get(
        'https://api.bilibili.com/x/web-interface/view?bvid=$bvid',
      );
      var cid = viewResponse.data['data']['pages'][0]['cid'];
      if (trackIdCheck.length > 1) {
        cid = trackIdCheck[1];
      }
      final response = await dioWithCookieManager.get(
        'https://api.bilibili.com/x/player/playurl?fnval=4048&bvid=$bvid&cid=$cid',
      );

      final audioTracks = <int, dynamic>{};
      final selectQuality = settingsController.selectAudioQualityOfBL;
      final canSelectQualities = AudioQualityOfBL.values
          .where((quality) => quality.index <= selectQuality.index)
          .toList();
      try {
        final dash = response.data['data']['dash'];
        try {
          final flac = dash['flac'];
          if (flac != null &&
              flac['display'] == true &&
              isNotEmpty(flac['audio'])) {
            audioTracks[flac['audio']['id']] = flac['audio'];
          }
        } catch (_) {}
        try {
          final dolby = dash['dolby'];
          if (dolby != null &&
              dolby['audio'] != null &&
              isNotEmpty(dolby['audio'])) {
            for (final item in dolby['audio']) {
              audioTracks[item['id']] = item;
            }
          }
        } catch (_) {}
        try {
          final audioList = dash['audio'];
          if (isNotEmpty(audioList)) {
            for (final item in audioList) {
              audioTracks[item['id']] = item;
            }
          }
        } catch (_) {}

        while (canSelectQualities.isNotEmpty) {
          final quality = canSelectQualities.removeLast();
          if (audioTracks.containsKey(quality.code)) {
            success(
              BootSuccessRes(
                url: audioTracks[quality.code]['baseUrl'] as String,
                platform: name,
                audioQualityOfBL: quality,
              ),
              track,
            );
            return;
          }
        }
        failure(track);
      } catch (e) {
        final durl = response.data['data']['durl'];
        if (durl != null && (durl as List).isNotEmpty) {
          success(
            BootSuccessRes(url: durl[0]['url'] as String, platform: name),
            track,
          );
        } else {
          failure(track);
        }
      }
    } catch (e) {
      failure(track);
    }
  }

  Future<void> _bootstrapAudioTrack(
    Track track,
    Function(BootSuccessRes res, Track track) success,
    Function(Track track) failure,
  ) async {
    final songId = track.id.substring('bitrack_'.length);
    try {
      final response = await dioWithCookieManager.get(
        'https://www.bilibili.com/audio/music-service-c/web/url?sid=$songId',
      );
      final data = response.data;
      if (data['code'] == 0) {
        success(
          BootSuccessRes(url: data['data']['cdns'][0] as String, platform: name),
          track,
        );
      } else {
        failure(track);
      }
    } catch (e) {
      failure(track);
    }
  }

  // #endregion

  // #region 链接解析

  /// 解析粘贴的 B 站链接，仅支持音频区歌单。
  Future<Map<String, dynamic>?> parseUrl(String url) async {
    final match = RegExp(
      r'\/\/www.bilibili.com\/audio\/am([0-9]+)',
    ).firstMatch(url);
    if (match != null) {
      return {
        'type': 'playlist',
        'id': '${BLPlaylistType.playlist.prefix}_${match.group(1)}',
      };
    }
    return null;
  }

  // #endregion

  // #region 数据转换

  String _htmlDecode(String value) {
    final document = parse(value);
    return document.body?.text ?? '';
  }

  Map<String, dynamic> _convertAudioSong(Map<String, dynamic> songInfo) {
    return {
      'id': '${BLPlaylistType.track.prefix}_${songInfo['id']}',
      'title': songInfo['title'],
      'artist': songInfo['uname'],
      'artist_id': '${BLPlaylistType.artist.prefix}_${songInfo['uid']}',
      'source': name,
      'source_url': 'https://www.bilibili.com/audio/au${songInfo['id']}',
      'img_url': songInfo['cover'],
      'lyric_url': songInfo['lyric'],
    };
  }

  Map<String, dynamic> _convertVideoSong(Map<String, dynamic> songInfo) {
    var imgUrl = songInfo['pic'] as String;
    if (imgUrl.startsWith('//')) {
      imgUrl = 'https:$imgUrl';
    }
    return {
      'id': '${BLPlaylistType.track.prefix}_v_${songInfo['bvid']}',
      'title': _htmlDecode(songInfo['title']),
      'artist': _htmlDecode(songInfo['author']),
      'artist_id': '${BLPlaylistType.artist.prefix}_v_${songInfo['mid']}',
      'source': name,
      'source_url': 'https://www.bilibili.com/video/${songInfo['bvid']}',
      'img_url': imgUrl,
      'total_dur_msg': songInfo['duration']?.toString(),
    };
  }

  SearchPlayListItem _convertSongToPlayListUgcSeason(
    Map<String, dynamic> songInfo,
  ) {
    var imgUrl = songInfo['pic'] as String;
    if (imgUrl.startsWith('//')) {
      imgUrl = 'https:$imgUrl';
    }
    return SearchPlayListItem(
      id:
          '${BLPlaylistType.playlistxuan.prefix}_${BLPlayListXuanType.ugcSeason.prefix}${songInfo['bvid']}',
      title: _htmlDecode(songInfo['title']),
      source: name,
      sourceUrl: 'https://www.bilibili.com/video/${songInfo['bvid']}',
      imgUrl: imgUrl,
      url: 'https://www.bilibili.com/video/${songInfo['bvid']}',
      author: _htmlDecode(songInfo['author']),
      totalDurMsg: songInfo['duration']?.toString(),
    );
  }

  List<Track> _convertUgcSeasonSectionToTracks(Map<String, dynamic> section) {
    return List<Track>.from(
      (section['episodes'] as List).map(
        (item) => Track(
          id: '${BLPlaylistType.track.prefix}_v_${item['bvid']}',
          title: _htmlDecode(item['title']),
          artist: _htmlDecode(item['arc']['author']['name']),
          artist_id:
              '${BLPlaylistType.artist.prefix}_v_${item['arc']['author']['mid']}',
          source: name,
          source_url: 'https://www.bilibili.com/video/${item['bvid']}',
          img_url: item['arc']['pic'],
        ),
      ),
    );
  }

  Map<String, dynamic> _convertFavVideo(Map<String, dynamic> songInfo) {
    return {
      'id': '${BLPlaylistType.track.prefix}_v_${songInfo['bvid']}',
      'title': _htmlDecode(songInfo['title']),
      'artist': _htmlDecode(songInfo['upper']['name']),
      'artist_id':
          '${BLPlaylistType.artist.prefix}_v_${songInfo['upper']['mid']}',
      'source': name,
      'source_url': 'https://www.bilibili.com/video/${songInfo['bvid']}',
      'img_url': songInfo['cover'],
    };
  }

  Map<String, dynamic> _convertToviewVideo(Map<String, dynamic> songInfo) {
    return {
      'id': '${BLPlaylistType.track.prefix}_v_${songInfo['bvid']}',
      'title': _htmlDecode(songInfo['title']),
      'artist': _htmlDecode(songInfo['owner']['name']),
      'artist_id':
          '${BLPlaylistType.artist.prefix}_v_${songInfo['owner']['mid']}',
      'source': name,
      'source_url': 'https://www.bilibili.com/video/${songInfo['bvid']}',
      'img_url': songInfo['cover'] ?? songInfo['pic'] ?? songInfo['cover43'],
    };
  }

  Map<String, dynamic> _convertVideoPage(
    Map<String, dynamic> songInfo,
    String bvid,
    Map<String, dynamic> author,
    String defaultImg,
  ) {
    var imgUrl = songInfo['first_frame'] ?? defaultImg;
    if (imgUrl.startsWith('//')) {
      imgUrl = 'https:$imgUrl';
    }
    return {
      'id': '${BLPlaylistType.track.prefix}_v_$bvid-${songInfo['cid']}',
      'title': _htmlDecode(songInfo['part']),
      'artist': _htmlDecode(author['name']),
      'artist_id': '${BLPlaylistType.artist.prefix}_v_${author['mid']}',
      'source': name,
      'source_url':
          'https://www.bilibili.com/video/$bvid/?p=${songInfo['page']}',
      'img_url': imgUrl,
    };
  }

  // #endregion
}
