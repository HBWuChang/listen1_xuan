import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse;
import 'package:listen1_xuan/constants/const.dart';
import 'package:listen1_xuan/controllers/DioController.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/models/PlayListFilter.dart';
import 'package:listen1_xuan/models/PlayListFilters.dart';
import 'package:listen1_xuan/models/Playlist.dart';
import 'package:listen1_xuan/models/ProviderUser.dart';
import 'package:listen1_xuan/models/SearchPlayListRes.dart';
import 'package:listen1_xuan/models/SearchRes.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:listen1_xuan/models/bootStrapTrackRes.dart';
import 'package:listen1_xuan/settings.dart';
import 'package:listen1_xuan/utils/cookie_utils.dart';
import 'package:listen1_xuan/utils/response_utils.dart';

import 'base.dart';

enum QQPlaylistType {
  playlist('qqplaylist'),
  album('qqalbum'),
  artist('qqartist'),
  toplist('qqtoplist');

  final String prefix;
  const QQPlaylistType(this.prefix);
}

enum QQTrackType {
  track('qqtrack');

  final String prefix;
  const QQTrackType(this.prefix);
}

class QQ extends BaseProvider {
  @override
  String get id => 'qq';

  @override
  String get name => 'qq';

  @override
  String get shortDisplayName => 'QQ';

  @override
  bool get searchable => true;

  @override
  bool get supportLogin => true;

  @override
  bool get supportLyric => true;

  @override
  bool get supportShowPlaylist => true;

  @override
  bool get supportGetUserCreatedPlaylist => true;

  @override
  bool get supportGetUserFavoritePlaylist => true;

  @override
  String get userCreatedPlaylistSectionTitle => '我创建的QQ音乐歌单';

  @override
  Widget get userCreatedPlaylistSectionLeading => _qqSectionIcon;

  @override
  String get userFavoritePlaylistSectionTitle => '我收藏的QQ音乐歌单';

  @override
  Widget get userFavoritePlaylistSectionLeading => _qqSectionIcon;

  Widget get _qqSectionIcon => ExtendedImage.network(
    'https://ts2.cn.mm.bing.net/th?id=ODLS.07d947f8-8fdd-4949-8b9a-be5283268438&w=32&h=32&qlt=90&pcl=fffffa&o=6&pid=1.2',
    width: 18,
    height: 18,
    cache: true,
  );

  static String get sourceName => PlatformSource.qq.name;

  Future<Response<dynamic>> dioGetWithCookieAndCsrf(String url) async {
    return await dioWithCookieManager.get(
      url,
      options: Options(
        headers: {
          'referer': 'https://y.qq.com/',
          'origin': 'https://y.qq.com',
          'priority': 'u=1, i',
          'sec-ch-ua-platform': '"Windows"',
          'user-agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0',
          'accept': 'application/json, text/plain, */*',
          'sec-ch-ua':
              '"Microsoft Edge";v="131", "Chromium";v="131", "Not_A Brand";v="24"',
        },
      ),
    );
  }

  // #region 登录 / 用户

  @override
  Future<ProviderUser?> getUser() async {
    loginStatus.value = LoginStatus.processing;
    try {
      final settings = lengcyGetSettings();
      final cookie = settings['qq'];
      if (isEmpty(cookie)) {
        loginStatus.value = LoginStatus.noLogin;
        return null;
      }
      final cookies = CookieUtils.parseCookieString(cookie);
      var uin = CookieUtils.getCookieValue(cookies, 'uin');
      if (uin == null) {
        final wxuin = CookieUtils.getCookieValue(cookies, 'wxuin');
        if (wxuin != null) {
          // 微信登录的 uin 会带一个 'o' 前缀，替换为 '1'
          uin = '1${wxuin.substring('o'.length)}';
        }
      }
      if (uin == null) {
        loginStatus.value = LoginStatus.noLogin;
        return null;
      }
      final user = await _fetchUser(uin);
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

  Future<ProviderUser?> _fetchUser(String uin) async {
    final infoUrl =
        'https://u.y.qq.com/cgi-bin/musicu.fcg?format=json&&loginUin=$uin&hostUin=0inCharset=utf8&outCharset=utf-8&platform=yqq.json&needNewCode=0&data=${Uri.encodeComponent(jsonEncode({
          'comm': {'ct': 24, 'cv': 0},
          'vip': {
            'module': 'userInfo.VipQueryServer',
            'method': 'SRFVipQuery_V2',
            'param': {
              'uin_list': [uin],
            },
          },
          'base': {
            'module': 'userInfo.BaseUserInfoServer',
            'method': 'get_user_baseinfo_v2',
            'param': {
              'vec_uin': [uin],
            },
          },
        }))}';
    final response = await dioGetWithCookieAndCsrf(infoUrl);
    final data = decodeResponseData(response.data);
    final info = data['base']['data']['map_userinfo'][uin];
    if (info == null) {
      return null;
    }
    return ProviderUser(
      platform: name,
      userId: uin,
      name: info['nick'] as String? ?? uin,
    );
  }

  @override
  Future<void> logout() async {
    loginStatus.value = LoginStatus.noLogin;
  }

  // #endregion

  // #region 我的歌单

  /// 我创建的歌单（含“我喜欢”）
  @override
  Future<List<PlayList>> getUserCreatedPlaylist(String userId) async {
    const size = 100;
    final targetUrl =
        'https://c.y.qq.com/rsc/fcgi-bin/fcg_user_created_diss?cv=4747474&ct=24&format=json&inCharset=utf-8&outCharset=utf-8&notice=0&platform=yqq.json&needNewCode=1&uin=$userId&hostuin=$userId&sin=0&size=$size';
    final response = await dioGetWithCookieAndCsrf(targetUrl);
    final dissList =
        decodeResponseData(response.data)['data']['disslist'] as List;

    final playlists = <PlayList>[];
    for (final item in dissList) {
      if (item['dir_show'] == 0) {
        if (item['tid'] == 0) {
          continue;
        }
        if (item['diss_name'] == '我喜欢') {
          playlists.add(
            _userPlaylist(
              item,
              coverImgUrl:
                  'https://y.gtimg.cn/mediastyle/y/img/cover_love_300.jpg',
            ),
          );
        }
      } else {
        playlists.add(_userPlaylist(item));
      }
    }
    return playlists;
  }

  /// 我收藏的歌单
  @override
  Future<List<PlayList>> getUserFavoritePlaylist(String userId) async {
    const size = 100;
    final targetUrl =
        'https://c.y.qq.com/fav/fcgi-bin/fcg_get_profile_order_asset.fcg?ct=20&cid=205360956&userid=$userId&reqtype=3&sin=0&ein=$size';
    final response = await dioGetWithCookieAndCsrf(targetUrl);
    final cdList = decodeResponseData(response.data)['data']['cdlist'] as List;

    final playlists = <PlayList>[];
    for (final item in cdList) {
      if (item['dir_show'] == 0) {
        continue;
      }
      playlists.add(
        PlayList.fromJson({
          'info': {
            'cover_img_url': item['logo'],
            'id': '${QQPlaylistType.playlist.prefix}_${item['dissid']}',
            'source_url': 'https://y.qq.com/n/ryqq/playlist/${item['dissid']}',
            'title': item['dissname'],
          },
        }),
      );
    }
    return playlists;
  }

  PlayList _userPlaylist(dynamic item, {String? coverImgUrl}) {
    return PlayList.fromJson({
      'info': {
        'cover_img_url': coverImgUrl ?? item['diss_cover'],
        'id': '${QQPlaylistType.playlist.prefix}_${item['tid']}',
        'source_url': 'https://y.qq.com/n/ryqq/playlist/${item['tid']}',
        'title': item['diss_name'],
      },
    });
  }

  // #endregion

  // #region 歌单详情

  @override
  Future<PlayList> getPlaylist(String listId) async {
    final prefix = listId.split('_').first;
    if (prefix == QQPlaylistType.playlist.prefix) {
      return _getPlaylist(listId);
    }
    if (prefix == QQPlaylistType.album.prefix) return _getAlbum(listId);
    if (prefix == QQPlaylistType.artist.prefix) return _getArtist(listId);
    if (prefix == QQPlaylistType.toplist.prefix) return _getToplist(listId);
    throw Exception('不支持的QQ音乐歌单类型: $listId');
  }

  Future<PlayList> _getPlaylist(String listId) async {
    final id = listId.split('_').last;
    final targetUrl =
        'https://i.y.qq.com/qzone-music/fcg-bin/fcg_ucc_getcdinfo_'
        'byids_cp.fcg?type=1&json=1&utf8=1&onlysong=0'
        '&nosign=1&disstid=$id&g_tk=5381&loginUin=0&hostUin=0'
        '&format=json&inCharset=GB2312&outCharset=utf-8&notice=0'
        '&platform=yqq&needNewCode=0';
    final response = await dioGetWithCookieAndCsrf(targetUrl);
    final cdList = decodeResponseData(response.data)['cdlist'][0];
    final info = {
      'cover_img_url': cdList['logo'],
      'title': cdList['dissname'],
      'id': '${QQPlaylistType.playlist.prefix}_$id',
      'source_url': 'https://y.qq.com/n/ryqq/playlist/$id',
    };
    final tracks = _dedupTracks(
      (cdList['songlist'] as List)
          .map((item) => _convertSong(item as Map<String, dynamic>))
          .toList(),
    );
    return PlayList.fromJson({'info': info, 'tracks': tracks});
  }

  Future<PlayList> _getAlbum(String listId) async {
    final albumMid = listId.split('_').last;
    final targetUrl =
        'https://i.y.qq.com/v8/fcg-bin/fcg_v8_album_info_cp.fcg'
        '?platform=h5page&albummid=$albumMid&g_tk=938407465'
        '&uin=0&format=json&inCharset=utf-8&outCharset=utf-8'
        '&notice=0&platform=h5&needNewCode=1&_=1459961045571';
    final response = await dioGetWithCookieAndCsrf(targetUrl);
    final data = decodeResponseData(response.data)['data'];
    final info = {
      'cover_img_url': _getImageUrl(albumMid, 'album'),
      'title': data['name'],
      'id': '${QQPlaylistType.album.prefix}_$albumMid',
      'source_url': 'https://y.qq.com/#type=album&mid=$albumMid',
    };
    final tracks = _dedupTracks(
      (data['list'] as List)
          .map((item) => _convertSong(item as Map<String, dynamic>))
          .toList(),
    );
    return PlayList.fromJson({'info': info, 'tracks': tracks});
  }

  Future<PlayList> _getArtist(String listId) async {
    final artistMid = listId.split('_').last;
    final targetUrl =
        'https://u.y.qq.com/cgi-bin/musicu.fcg?format=json&loginUin=0&hostUin=0inCharset=utf8&outCharset=utf-8&platform=yqq.json&needNewCode=0&data=${Uri.encodeComponent(jsonEncode({
          'comm': {'ct': 24, 'cv': 0},
          'singer': {
            'method': 'get_singer_detail_info',
            'param': {'sort': 5, 'singermid': artistMid, 'sin': 0, 'num': 50},
            'module': 'music.web_singer_info_svr',
          },
        }))}';
    final response = await dioGetWithCookieAndCsrf(targetUrl);
    final data = decodeResponseData(response.data)['singer']['data'];
    final info = {
      'cover_img_url': _getImageUrl(artistMid, 'artist'),
      'title': data['singer_info']['name'],
      'id': '${QQPlaylistType.artist.prefix}_$artistMid',
      'source_url': 'https://y.qq.com/#type=singer&mid=$artistMid',
    };
    final tracks = (data['songlist'] as List)
        .map((item) => _convertSong2(item as Map<String, dynamic>))
        .toList();
    return PlayList.fromJson({'info': info, 'tracks': tracks});
  }

  Future<PlayList> _getToplist(String listId) async {
    final id = listId.split('_').last;
    final period = await _periodOf(id);
    const limit = 100;
    final targetUrl = _toplistUrl(id, period, limit);
    final response = await dioGetWithCookieAndCsrf(targetUrl);
    final data = decodeResponseData(response.data);
    try {
      final info = {
        'cover_img_url': data['toplist']['data']['data']['frontPicUrl'],
        'title': data['toplist']['data']['data']['title'],
        'id': '${QQPlaylistType.toplist.prefix}_$id',
        'source_url': 'https://y.qq.com/n/yqq/toplist/$id.html',
      };
      final tracks = (data['toplist']['data']['songInfoList'] as List)
          .map((item) => _convertSong2(item as Map<String, dynamic>))
          .toList();
      return PlayList.fromJson({'info': info, 'tracks': tracks});
    } catch (e) {
      throw Exception('QQ音乐获取排行榜失败: $e');
    }
  }

  String _toplistUrl(String id, String period, int limit) {
    return 'https://u.y.qq.com/cgi-bin/musicu.fcg?format=json&inCharset=utf8&outCharset=utf-8&platform=yqq.json&needNewCode=0&data=${Uri.encodeComponent(jsonEncode({
      'comm': {'cv': 1602, 'ct': 20},
      'toplist': {
        'module': 'musicToplist.ToplistInfoServer',
        'method': 'GetDetail',
        'param': {'topid': id, 'num': limit, 'period': period},
      },
    }))}';
  }

  /// 排行榜的期数（用于热门榜等带周期的榜单）
  Future<String> _periodOf(String topid) async {
    const periodUrl = 'https://c.y.qq.com/node/pc/wk_v15/top.html';
    final periodListReg = RegExp(
      r'<i class="play_cover__btn c_tx_link js_icon_play" data-listkey=".+?" data-listname=".+?" data-tid=".+?" data-date=".+?" .+?</i>',
    );
    final periodReg = RegExp(
      r'data-listname="(.+?)" data-tid=".*?/(.+?)" data-date="(.+?)" .+?</i>',
    );
    final periods = <String, String>{};
    final response = await dioGetWithCookieAndCsrf(periodUrl);
    final matches = periodListReg.allMatches(response.data as String);
    if (matches.isEmpty) {
      return '';
    }
    for (final match in matches) {
      final periodMatch = periodReg.firstMatch(match.group(0)!);
      if (periodMatch == null) {
        continue;
      }
      periods[periodMatch.group(2)!] = periodMatch.group(3)!;
    }
    return periods[topid] ?? '';
  }

  /// 按 track id 去重
  List<Map<String, dynamic>> _dedupTracks(List<Map<String, dynamic>> tracks) {
    final seen = <String>{};
    return tracks.where((track) => seen.add(track['id'] as String)).toList();
  }

  // #endregion

  // #region 热门歌单

  @override
  Future<List<PlayList>>? showPlaylist({int? offset, dynamic filterId}) async {
    final off = offset ?? 0;
    if (filterId == 'toplist') {
      return _showToplist(off);
    }
    final categoryId = (filterId == null || filterId == '')
        ? '10000000'
        : filterId.toString();
    final targetUrl =
        'https://c.y.qq.com/splcloud/fcgi-bin/fcg_get_diss_by_tag.fcg'
        '?picmid=1&rnd=${Random().nextDouble()}&g_tk=732560869'
        '&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8'
        '&notice=0&platform=yqq.json&needNewCode=0'
        '&categoryId=$categoryId&sortId=5&sin=$off&ein=${29 + off}';
    final response = await dioGetWithCookieAndCsrf(targetUrl);
    final list = decodeResponseData(response.data)['data']['list'] as List;
    return list.map((item) {
      return PlayList.fromJson({
        'info': {
          'cover_img_url': item['imgurl'],
          'title': _htmlDecode(item['dissname']),
          'id': '${QQPlaylistType.playlist.prefix}_${item['dissid']}',
          'source_url': 'https://y.qq.com/n/ryqq/playlist/${item['dissid']}',
        },
      });
    }).toList();
  }

  Future<List<PlayList>> _showToplist(int offset) async {
    if (offset > 0) {
      return [];
    }
    const url =
        'https://c.y.qq.com/v8/fcg-bin/fcg_myqq_toplist.fcg?g_tk=5381&inCharset=utf-8&outCharset=utf-8&notice=0&format=json&uin=0&needNewCode=1&platform=h5';
    final response = await dioGetWithCookieAndCsrf(url);
    final topList =
        decodeResponseData(response.data)['data']['topList'] as List;
    return topList.map((item) {
      return PlayList.fromJson({
        'info': {
          'cover_img_url': item['picUrl'],
          'id': '${QQPlaylistType.toplist.prefix}_${item['id']}',
          'source_url': 'https://y.qq.com/n/yqq/toplist/${item['id']}.html',
          'title': item['topTitle'],
        },
      });
    }).toList();
  }

  @override
  Future<PlayListFilters> getPlaylistFilters() async {
    final targetUrl =
        'https://c.y.qq.com/splcloud/fcgi-bin/fcg_get_diss_tag_conf.fcg'
        '?picmid=1&rnd=${Random().nextDouble()}&g_tk=732560869'
        '&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8'
        '&notice=0&platform=yqq.json&needNewCode=0';
    const fallback = PlayListFilters(
      recommended: [
        PlayListFilter(id: '', name: '全部'),
        PlayListFilter(id: 'toplist', name: '排行榜'),
      ],
      filters: [],
    );
    try {
      final response = await dioGetWithCookieAndCsrf(targetUrl);
      final data = decodeResponseData(response.data);
      final categories = data['data']?['categories'];
      if (categories == null) {
        return fallback;
      }
      final all = <PlayListCategoryFilters>[];
      for (final cate in categories as List) {
        if (cate['usable'] != 1) {
          continue;
        }
        all.add(
          PlayListCategoryFilters(
            name: cate['categoryGroupName'] as String,
            filters: (cate['items'] as List)
                .map(
                  (item) => PlayListFilter(
                    id: item['categoryId'],
                    name: _htmlDecode(item['categoryName']),
                  ),
                )
                .toList(),
          ),
        );
      }
      const recommendLimit = 8;
      return PlayListFilters(
        recommended: [
          const PlayListFilter(id: '', name: '全部'),
          const PlayListFilter(id: 'toplist', name: '排行榜'),
          if (all.length > 1) ...all[1].filters.take(recommendLimit),
        ],
        filters: all,
      );
    } catch (e) {
      return fallback;
    }
  }

  // #endregion

  // #region 搜索

  @override
  Future<SearchRes>? searchSong(String keywords, int curpage) async {
    try {
      final data = await _search(keywords, curpage, '0');
      return SearchRes(
        result: (data['result'] as List)
            .map((item) => Track.fromJson(item as Map<String, dynamic>))
            .toList(),
        total: data['total'] as int,
      );
    } catch (e) {
      logger.e('QQ音乐搜索失败', error: e);
      return SearchRes.error('QQ音乐搜索失败: $e');
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
      final data = await _search(keywords, curpage, '1');
      return SearchPlayListRes(
        result: (data['result'] as List)
            .map(
              (item) =>
                  SearchPlayListItem.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        total: data['total'] as int,
      );
    } catch (e) {
      logger.e('QQ音乐搜索失败', error: e);
      return SearchPlayListRes.error('QQ音乐搜索失败: $e');
    }
  }

  Future<Map<String, dynamic>> _search(
    String keywords,
    int curpage,
    String searchType,
  ) async {
    const targetUrl = 'https://u.y.qq.com/cgi-bin/musicu.fcg';
    const searchTypeMapping = {'0': 0, '1': 3};
    const limit = 50;
    final query = {
      'comm': {'ct': '19', 'cv': '1859', 'uin': '0'},
      'req': {
        'method': 'DoSearchForQQMusicDesktop',
        'module': 'music.search.SearchCgiService',
        'param': {
          'grp': 1,
          'num_per_page': limit,
          'page_num': curpage,
          'query': keywords,
          'search_type': searchTypeMapping[searchType],
        },
      },
    };
    final response = await dioWithCookieManager.post(targetUrl, data: query);
    final data = decodeResponseData(response.data);
    final meta = data['req']['data']['meta'];
    if (searchType == '0') {
      final result = (data['req']['data']['body']['song']['list'] as List)
          .map((item) => _convertSong2(item as Map<String, dynamic>))
          .toList();
      return {'result': result, 'total': meta['sum']};
    }
    final result = (data['req']['data']['body']['songlist']['list'] as List)
        .map((info) {
          return {
            'id': '${QQPlaylistType.playlist.prefix}_${info['dissid']}',
            'title': _htmlDecode(info['dissname']),
            'source': name,
            'source_url': 'https://y.qq.com/n/ryqq/playlist/${info['dissid']}',
            'img_url': info['imgurl'],
            'url': '${QQPlaylistType.playlist.prefix}_${info['dissid']}',
            'author': _unicodeToAscii(info['creator']['name']),
            'count': info['song_count'],
          };
        })
        .toList();
    return {'result': result, 'total': meta['sum']};
  }

  // #endregion

  // #region 歌词

  @override
  Future<(String lyric, String? tlyric)> lyric(Track track) async {
    final trackId = track.id.split('_').last;
    final targetUrl =
        'https://i.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?'
        'songmid=$trackId&g_tk=5381&format=json&inCharset=utf8&outCharset=utf-8&nobase64=1';
    final response = await dioGetWithCookieAndCsrf(targetUrl);
    final data = decodeResponseData(response.data);
    final lrc = data['lyric'] as String? ?? '';
    final tlrc = (data['trans'] as String? ?? '').replaceAll('//', '');
    return (lrc, tlrc.isNotEmpty ? tlrc : null);
  }

  // #endregion

  // #region 播放地址

  @override
  Future<void> bootStrapTrack(
    Track track,
    Function(BootSuccessRes res, Track track) success,
    Function(Track track, Object? error) failure,
  ) async {
    try {
      final settings = lengcyGetSettings();
      final qqCookie = settings['qq'] is String?
          ? (settings['qq'] as String? ?? '')
          : '';
      final songId = track.id.replaceFirst('${QQTrackType.track.prefix}_', '');
      const targetUrl = 'https://u.y.qq.com/cgi-bin/musicu.fcg';
      final guid = Random().nextDouble().toStringAsFixed(10).substring(2);
      final songMidList = [songId];
      final uin = qqCookie
          .split(';')
          .firstWhere(
            (element) => element.startsWith('uin='),
            orElse: () => 'uin=0',
          )
          .split('=')[1];
      const fileType = '128';
      const fileConfig = <String, Map<String, String>>{
        'm4a': {'s': 'C400', 'e': '.m4a', 'bitrate': 'M4A'},
        '128': {'s': 'M500', 'e': '.mp3', 'bitrate': '128kbps'},
        '320': {'s': 'M800', 'e': '.mp3', 'bitrate': '320kbps'},
        'ape': {'s': 'A000', 'e': '.ape', 'bitrate': 'APE'},
        'flac': {'s': 'F000', 'e': '.flac', 'bitrate': 'FLAC'},
      };
      final fileInfo = fileConfig[fileType]!;
      final file = songMidList.length == 1
          ? '${fileInfo['s']}$songId$songId${fileInfo['e']}'
          : null;
      final reqData = {
        'req_1': {
          'module': 'vkey.GetVkeyServer',
          'method': 'CgiGetVkey',
          'param': {
            'filename': file != null ? [file] : [],
            'guid': guid,
            'songmid': songMidList,
            'songtype': [0],
            'uin': uin,
            'loginflag': 1,
            'platform': '20',
          },
        },
        'loginUin': uin,
        'comm': {'uin': uin, 'format': 'json', 'ct': 24, 'cv': 0},
      };
      final response = await dioWithCookieManager.post(
        targetUrl,
        data: reqData,
      );
      final data = decodeResponseData(response.data);
      final purl = data['req_1']['data']['midurlinfo'][0]['purl'] as String;
      if (purl == '') {
        failure(track, Exception('QQ音乐未返回播放地址: ${track.id}, data: $data'));
        return;
      }
      final url = data['req_1']['data']['sip'][0] + purl;
      final prefix = purl.substring(0, 4);
      final found = fileConfig.values.where((i) => i['s'] == prefix);
      success(
        BootSuccessRes(
          url: url as String,
          platform: name,
          bitrate: found.isNotEmpty ? found.first['bitrate'] : null,
        ),
        track,
      );
    } catch (e) {
      failure(track, e);
    }
  }

  // #endregion

  // #region 链接解析

  /// 解析粘贴的 QQ 音乐链接。
  Future<Map<String, dynamic>?> parseUrl(String url) async {
    final patterns = <RegExp>[
      RegExp(r'//y.qq.com/n/yqq/playlist/([0-9]+)'),
      RegExp(r'//y.qq.com/n/yqq/playsquare/([0-9]+)'),
      RegExp(r'//y.qq.com/n/m/detail/taoge/index.html\?id=([0-9]+)'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) {
        return {
          'type': 'playlist',
          'id': '${QQPlaylistType.playlist.prefix}_${match.group(1)}',
        };
      }
    }
    final shortLink = RegExp(
      r'//c.y.qq.com/base/fcgi-bin/u\?__=([0-9a-zA-Z]+)',
    ).firstMatch(url);
    if (shortLink != null) {
      final response = await dioGetWithCookieAndCsrf(url);
      final responseUrl = response.requestOptions.uri.toString();
      return {
        'type': 'playlist',
        'id':
            '${QQPlaylistType.playlist.prefix}_${Uri.parse(responseUrl).queryParameters['id']}',
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

  String _unicodeToAscii(String str) {
    return str.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      return String.fromCharCode(int.parse(match.group(1)!));
    });
  }

  String _getImageUrl(dynamic qqImgId, String imgType) {
    if (qqImgId == null || qqImgId == 0) {
      return '';
    }
    var category = '';
    if (imgType == 'artist') {
      category = 'T001R300x300M000';
    }
    if (imgType == 'album') {
      category = 'T002R300x300M000';
    }
    return 'https://y.gtimg.cn/music/photo_new/$category$qqImgId.jpg';
  }

  bool _isPlayable(Map<String, dynamic> song) {
    try {
      // switch 为位标志，转为二进制后判断是否可播放
      var switchFlag = song['switch'].toRadixString(2).split('');
      switchFlag.removeLast();
      switchFlag = switchFlag.reversed.toList();
      final playFlag = switchFlag[0];
      final tryFlag = switchFlag[13];
      return playFlag == '1' || (playFlag == '1' && tryFlag == '1');
    } catch (e) {
      return false;
    }
  }

  Map<String, dynamic> _convertSong(Map<String, dynamic> song) {
    return {
      'id': '${QQTrackType.track.prefix}_${song['songmid']}',
      'title': _htmlDecode(song['songname']),
      'artist': _htmlDecode(song['singer'][0]['name']),
      'artist_id':
          '${QQPlaylistType.artist.prefix}_${song['singer'][0]['mid']}',
      'album': _htmlDecode(song['albumname']),
      'album_id': '${QQPlaylistType.album.prefix}_${song['albummid']}',
      'img_url': _getImageUrl(song['albummid'], 'album'),
      'source': name,
      'source_url':
          'https://y.qq.com/#type=song&mid=${song['songmid']}&tpl=yqq_song_detail',
      'url': !_isPlayable(song) ? '' : null,
    };
  }

  Map<String, dynamic> _convertSong2(Map<String, dynamic> song) {
    return {
      'id': '${QQTrackType.track.prefix}_${song['mid']}',
      'title': _htmlDecode(song['name']),
      'artist': _htmlDecode(song['singer'][0]['name']),
      'artist_id':
          '${QQPlaylistType.artist.prefix}_${song['singer'][0]['mid']}',
      'album': _htmlDecode(song['album']['name']),
      'album_id': '${QQPlaylistType.album.prefix}_${song['album']['mid']}',
      'img_url': _getImageUrl(song['album']['mid'], 'album'),
      'source': name,
      'source_url':
          'https://y.qq.com/#type=song&mid=${song['mid']}&tpl=yqq_song_detail',
      'url': '',
    };
  }

  // #endregion
}
