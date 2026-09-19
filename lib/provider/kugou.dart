import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:listen1_xuan/constants/const.dart';
import 'package:listen1_xuan/controllers/DioController.dart';
import 'package:listen1_xuan/models/PlayListFilters.dart';
import 'package:listen1_xuan/models/Playlist.dart';
import 'package:listen1_xuan/models/SearchPlayListRes.dart';
import 'package:listen1_xuan/models/SearchRes.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:listen1_xuan/models/bootStrapTrackRes.dart';
import 'package:listen1_xuan/settings.dart';
import 'package:listen1_xuan/utils/response_utils.dart';

import 'base.dart';

enum KgPlaylistType {
  playlist('kgplaylist'),
  album('kgalbum'),
  artist('kgartist');

  final String prefix;
  const KgPlaylistType(this.prefix);
}

enum KgTrackType {
  track('kgtrack');

  final String prefix;
  const KgTrackType(this.prefix);
}

class Kugou extends BaseProvider {
  @override
  String get id => 'kg';

  @override
  String get name => 'kugou';

  @override
  String get shortDisplayName => '酷狗';

  @override
  bool get searchable => true;

  /// 酷狗无需登录即可搜索 / 播放，也没有用户歌单接口。
  @override
  bool get supportLogin => false;

  @override
  bool get supportLyric => true;

  @override
  bool get supportShowPlaylist => true;

  static String get sourceName => PlatformSource.kugou.name;

  static const Map<String, String> _mobileHeaders = {
    'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 14_3 like Mac OS X) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30',
    'Accept': 'application/json, text/plain, */*',
    'accept-language': 'zh-CN',
    'origin': 'https://www.kugou.com/',
    'referer': 'https://www.kugou.com/',
  };

  // #region 歌单详情

  @override
  Future<PlayList> getPlaylist(String listId) async {
    final prefix = listId.split('_').first;
    if (prefix == KgPlaylistType.playlist.prefix) {
      return _getPlaylist(listId);
    }
    if (prefix == KgPlaylistType.album.prefix) return _getAlbum(listId);
    if (prefix == KgPlaylistType.artist.prefix) return _getArtist(listId);
    throw Exception('不支持的酷狗歌单类型: $listId');
  }

  /// 歌单：`kgplaylist_<specialid>`
  Future<PlayList> _getPlaylist(String listId) async {
    final id = listId.split('_').last;
    final targetUrl = 'https://m.kugou.com/plist/list/$id?json=true';
    final response = await _getFollowingRedirects(targetUrl);
    final data = decodeResponseData(response.data);
    final listInfo = data['info']['list'];
    final info = {
      'cover_img_url': _replaceSize(listInfo['imgurl']),
      'title': listInfo['specialname'],
      'id': '${KgPlaylistType.playlist.prefix}_${listInfo['specialid']}',
      'source_url':
          'https://www.kugou.com/yy/special/single/${listInfo['specialid']}.html',
    };
    final tracks = await _convertAll(
      data['list']['list']['info'] as List,
      _convertPlaylistItem,
    );
    return PlayList.fromJson({'info': info, 'tracks': tracks});
  }

  /// 专辑：`kgalbum_<albumid>`
  Future<PlayList> _getAlbum(String listId) async {
    final albumId = listId.split('_').last;
    final infoResponse = await dioWithCookieManager.get(
      'http://mobilecdnbj.kugou.com/api/v3/album/info?albumid=$albumId',
    );
    final infoData = decodeResponseData(infoResponse.data)['data'];
    final info = {
      'cover_img_url': _replaceSize(infoData['imgurl']),
      'title': infoData['albumname'],
      'id': '${KgPlaylistType.album.prefix}_${infoData['albumid']}',
      'source_url': 'https://www.kugou.com/album/${infoData['albumid']}.html',
    };
    final songResponse = await dioWithCookieManager.get(
      'http://mobilecdnbj.kugou.com/api/v3/album/song?albumid=$albumId&page=1&pagesize=-1',
    );
    final songs = decodeResponseData(songResponse.data)['data']['info'] as List;
    final tracks = await _convertAll(
      songs,
      (item) => _convertAlbumItem(item, info['title']!, albumId),
    );
    return PlayList.fromJson({'info': info, 'tracks': tracks});
  }

  /// 歌手：`kgartist_<singerid>`
  Future<PlayList> _getArtist(String listId) async {
    final artistId = listId.split('_').last;
    final infoResponse = await dioWithCookieManager.get(
      'http://mobilecdnbj.kugou.com/api/v3/singer/info?singerid=$artistId',
    );
    final infoData = decodeResponseData(infoResponse.data)['data'];
    final info = {
      'cover_img_url': _replaceSize(infoData['imgurl']),
      'title': infoData['singername'],
      'id': '${KgPlaylistType.artist.prefix}_$artistId',
      'source_url': 'https://www.kugou.com/singer/$artistId.html',
    };
    final songResponse = await dioWithCookieManager.get(
      'http://mobilecdnbj.kugou.com/api/v3/singer/song?singerid=$artistId&page=1&pagesize=30',
    );
    final songs = decodeResponseData(songResponse.data)['data']['info'] as List;
    final tracks = await _convertAll(
      songs,
      (item) => _convertArtistItem(item, info['id'] as String),
    );
    return PlayList.fromJson({'info': info, 'tracks': tracks});
  }

  /// 酷狗部分接口会 3xx 跳转，这里手动跟随重定向。
  Future<Response<dynamic>> _getFollowingRedirects(String url) async {
    final options = Options(
      headers: _mobileHeaders,
      followRedirects: false,
      validateStatus: (status) =>
          status != null && status >= 200 && status < 400,
    );
    var response = await dioWithCookieManager.get(url, options: options);
    while (response.statusCode != null &&
        response.statusCode! >= 300 &&
        response.statusCode! < 400) {
      final location = response.headers.value('location');
      if (location == null) {
        break;
      }
      response = await dioWithCookieManager.get(location, options: options);
    }
    return response;
  }

  // #endregion

  // #region 热门歌单

  @override
  Future<List<PlayList>>? showPlaylist({int? offset, dynamic filterId}) async {
    final page = ((offset ?? 0) ~/ 30) + 1;
    final targetUrl = 'https://m.kugou.com/plist/index&json=true&page=$page';
    final response = await dioWithCookieManager.get(targetUrl);
    final list =
        decodeResponseData(response.data)['plist']['list']['info'] as List;
    return list.map((item) {
      return PlayList.fromJson({
        'info': {
          'cover_img_url': _replaceSize(item['imgurl']),
          'title': item['specialname'],
          'id': '${KgPlaylistType.playlist.prefix}_${item['specialid']}',
          'source_url':
              'https://www.kugou.com/yy/special/single/${item['specialid']}.html',
        },
      });
    }).toList();
  }

  // #endregion

  // #region 搜索

  @override
  Future<SearchRes>? searchSong(String keywords, int curpage) async {
    final targetUrl =
        'https://songsearch.kugou.com/song_search_v2?keyword=${Uri.encodeComponent(keywords)}&page=$curpage';
    try {
      final response = await dioWithCookieManager.get(targetUrl);
      final data = decodeResponseData(response.data);
      final tracks = await _convertAll(
        data['data']['lists'] as List,
        _convertSearchItem,
      );
      return SearchRes(result: tracks, total: data['data']['total'] as int);
    } catch (e) {
      logger.e('酷狗搜索失败', error: e);
      return SearchRes.error('酷狗搜索失败: $e');
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
    final targetUrl =
        'http://mobilecdnbj.kugou.com/api/v3/search/special?keyword=${Uri.encodeComponent(keywords)}&pagesize=20&filter=0&page=$curpage';
    try {
      final response = await dioWithCookieManager.get(targetUrl);
      final data = decodeResponseData(response.data);
      return SearchPlayListRes(
        result: (data['data']['info'] as List).map((item) {
          final id = '${KgPlaylistType.playlist.prefix}_${item['specialid']}';
          return SearchPlayListItem(
            id: id,
            title: item['specialname'] as String?,
            source: name,
            sourceUrl:
                'https://www.kugou.com/yy/special/single/${item['specialid']}.html',
            imgUrl: _replaceSize(item['imgurl']),
            url: id,
            author: item['nickname'] as String?,
            count: item['songcount'] as int?,
          );
        }).toList(),
        total: data['data']['total'] as int,
      );
    } catch (e) {
      logger.e('酷狗搜索失败', error: e);
      return SearchPlayListRes.error('酷狗搜索失败: $e');
    }
  }

  // #endregion

  // #region 歌词

  @override
  Future<(String lyric, String? tlyric)> lyric(Track track) async {
    final trackId = track.id.split('_').last;
    final albumId = (track.album_id ?? '').split('_').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final lyricUrl =
        'https://wwwapi.kugou.com/yy/index.php?r=play/getdata&callback=jQuery&mid=1&hash=$trackId&platid=4&album_id=$albumId&_=$timestamp';
    final response = await dioWithCookieManager.get(lyricUrl);
    // 接口返回 JSONP，需要剥掉 `jQuery(...)` 外壳
    final data = response.data as String;
    final jsonString = data.substring('jQuery('.length, data.length - 2);
    final info = jsonDecode(jsonString);
    final lyric = info['data']?['lyrics'] as String? ?? '';
    return (lyric, null);
  }

  // #endregion

  // #region 播放地址

  @override
  Future<void> bootStrapTrack(
    Track track,
    Function(BootSuccessRes res, Track track) success,
    Function(Track track, Object? error) failure,
  ) async {
    final trackId = track.id.replaceFirst('${KgTrackType.track.prefix}_', '');
    try {
      final targetUrl =
          'https://m.kugou.com/app/i/getSongInfo.php?cmd=playInfo&hash=$trackId';
      final response = await dioWithCookieManager.get(targetUrl);
      final info = decodeResponseData(response.data);
      final url = info['url'] as String?;
      if (url == null || url.isEmpty) {
        failure(
          track,
          Exception('酷狗音乐未返回播放地址: ${track.id}, info: $info'),
        );
        return;
      }
      success(
        BootSuccessRes(
          url: url,
          platform: name,
          bitrate: '${info['bitRate']}kbps',
        ),
        track,
      );
    } catch (e) {
      failure(track, e);
    }
  }

  // #endregion

  // #region 链接解析

  /// 解析粘贴的酷狗歌单链接。
  Future<Map<String, dynamic>?> parseUrl(String url) async {
    final match = RegExp(
      r'//www.kugou.com/yy/special/single/([0-9]+).html',
    ).firstMatch(url);
    if (match != null) {
      return {
        'type': 'playlist',
        'id': '${KgPlaylistType.playlist.prefix}_${match.group(1)}',
      };
    }
    return null;
  }

  // #endregion

  // #region 数据转换

  /// 并发执行 [convert]，并按原顺序返回结果。
  Future<List<T>> _convertAll<T>(
    List items,
    Future<T> Function(dynamic item) convert,
  ) {
    return Future.wait(items.map(convert));
  }

  /// 歌曲图片地址中的 `{size}` 占位符统一替换为 400
  String _replaceSize(dynamic url) {
    if (url == null) {
      return '';
    }
    return (url as String).replaceAll('{size}', '400');
  }

  /// 搜索结果项：酷狗返回的字段大小写与其它接口不同
  Track _convertSong(dynamic song) {
    final track = Track(
      id: '${KgTrackType.track.prefix}_${song['FileHash']}',
      title: song['SongName'],
      artist: '',
      artist_id: '',
      album: song['AlbumName'],
      album_id: '${KgPlaylistType.album.prefix}_${song['AlbumID']}',
      source: name,
      source_url:
          'https://www.kugou.com/song/#hash=${song['FileHash']}&album_id=${song['AlbumID']}',
      img_url: '',
      lyric_url: song['FileHash'],
    );
    var singerId = song['SingerId'];
    var singerName = song['SingerName'];
    if (singerId is List) {
      singerId = singerId[0];
      singerName = (singerName as String).split('、')[0];
    }
    track.artist = singerName;
    track.artist_id = '${KgPlaylistType.artist.prefix}_$singerId';
    return track;
  }

  /// 搜索结果补全封面图
  Future<Track> _convertSearchItem(dynamic item) async {
    final track = _convertSong(item);
    try {
      final response = await dioWithCookieManager.get(
        'https://www.kugou.com/yy/index.php?r=play/getdata&hash=${track.lyric_url}',
        options: Options(headers: _mobileHeaders),
      );
      track.img_url =
          decodeResponseData(response.data)['data']['img'] as String?;
    } catch (e) {
      track.img_url = '';
    }
    return track;
  }

  Future<Track> _convertPlaylistItem(dynamic item) async {
    final hash = item['hash'];
    final track = Track(
      id: '${KgTrackType.track.prefix}_$hash',
      artist: '',
      artist_id: '',
      album: '',
      album_id: '${KgPlaylistType.album.prefix}_${item['album_id']}',
      source: name,
      source_url:
          'https://www.kugou.com/song/#hash=$hash&album_id=${item['album_id']}',
      img_url: '',
      lyric_url: hash,
    );
    try {
      final response = await dioWithCookieManager.get(
        'https://m.kugou.com/app/i/getSongInfo.php?cmd=playInfo&hash=$hash',
      );
      final data = decodeResponseData(response.data);
      track.title = data['songName'];
      track.artist = data['singerId'] == 0 ? '未知' : data['singerName'];
      track.artist_id = '${KgPlaylistType.artist.prefix}_${data['singerId']}';
      if (data['album_img'] != null) {
        track.img_url = _replaceSize(data['album_img']);
      }
      final albumResponse = await dioWithCookieManager.get(
        'http://mobilecdnbj.kugou.com/api/v3/album/info?albumid=${item['album_id']}',
      );
      final albumData = decodeResponseData(albumResponse.data);
      track.album = (albumData['status'] != 0 && albumData['data'] != null)
          ? albumData['data']['albumname']
          : '';
    } catch (e) {
      logger.e('酷狗歌单曲目信息补全失败: $hash', error: e);
    }
    return track;
  }

  Future<Track> _convertAlbumItem(
    dynamic item,
    String albumTitle,
    String albumId,
  ) async {
    final hash = item['hash'];
    final track = Track(
      id: '${KgTrackType.track.prefix}_$hash',
      artist: '',
      artist_id: '',
      album: albumTitle,
      album_id: '${KgPlaylistType.album.prefix}_$albumId',
      source: name,
      source_url: 'https://www.kugou.com/song/#hash=$hash&album_id=$albumId',
      img_url: '',
      lyric_url: hash,
    );
    try {
      final response = await dioWithCookieManager.get(
        'https://m.kugou.com/app/i/getSongInfo.php?cmd=playInfo&hash=$hash',
      );
      final data = decodeResponseData(response.data);
      track.title = data['songName'];
      track.artist = data['singerId'] == 0 ? '未知' : data['singerName'];
      track.artist_id = '${KgPlaylistType.artist.prefix}_${data['singerId']}';
      track.img_url = _replaceSize(data['imgUrl']);
    } catch (e) {
      logger.e('酷狗专辑曲目信息补全失败: $hash', error: e);
    }
    return track;
  }

  Future<Track> _convertArtistItem(dynamic item, String artistId) async {
    final hash = item['hash'];
    final track = Track(
      id: '${KgTrackType.track.prefix}_$hash',
      artist: '',
      artist_id: artistId,
      album: '',
      album_id: '${KgPlaylistType.album.prefix}_${item['album_id']}',
      source: name,
      source_url:
          'https://www.kugou.com/song/#hash=$hash&album_id=${item['album_id']}',
      img_url: '',
      lyric_url: hash,
    );
    // 歌名形如「歌手 - 歌曲名」
    final parts = (item['filename'] as String? ?? '').split('-');
    track.title = parts.length > 1 ? parts[1].trim() : parts.first.trim();
    track.artist = parts.first.trim();

    try {
      final albumResponse = await dioWithCookieManager.get(
        'http://mobilecdnbj.kugou.com/api/v3/album/info?albumid=${item['album_id']}',
      );
      final albumData = decodeResponseData(albumResponse.data);
      track.album = (albumData['status'] != 0 && albumData['data'] != null)
          ? albumData['data']['albumname']
          : '';

      final imgResponse = await dioWithCookieManager.get(
        'https://www.kugou.com/yy/index.php?r=play/getdata&hash=$hash',
        options: Options(headers: _mobileHeaders),
      );
      track.img_url =
          decodeResponseData(imgResponse.data)['data']['img'] as String?;
    } catch (e) {
      logger.e('酷狗歌手曲目信息补全失败: $hash', error: e);
    }
    return track;
  }

  // #endregion
}
