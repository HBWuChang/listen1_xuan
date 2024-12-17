import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' show parse;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'lowebutil.dart';
import 'settings.dart';

final netease = Netease();

Future<String> get_csrf() async {
  final tokens = await settings_getsettings();
  try {
    final _cookies = tokens['ne'];
    return _cookies
        .split(';')
        .firstWhere((element) => element.contains('__csrf'))
        .split('=')
        .last;
  } catch (e) {
    return '';
  }
}

class Netease {
  Future<dynamic> dio_get_with_cookie_and_csrf(String url) async {
    final tokens = await settings_getsettings();
    try {
      final _cookies = tokens['ne'];
      final _csrf = _cookies
          .split(';')
          .firstWhere((element) => element.contains('__csrf'))
          .split('=')
          .last;
      if (url.contains('?')) {
        url = url + '&csrf_token=$_csrf';
      } else {
        url = url + '?csrf_token=$_csrf';
      }
      return await Dio()
          .get(url, options: Options(headers: {'cookie': _cookies}));
    } catch (e) {
      return await Dio().get(url);
    }
  }

  Future<dynamic> dio_post_with_cookie_and_csrf(
      String url, dynamic data) async {
    final tokens = await settings_getsettings();
    try {
      final _cookies = tokens['ne'];
      final _csrf = _cookies
          .split(';')
          .firstWhere((element) => element.contains('__csrf'))
          .split('=')
          .last;
      if (url.contains('?')) {
        url = url + '&csrf_token=$_csrf';
      } else {
        url = url + '?csrf_token=$_csrf';
      }
      return await Dio().post(url,
          data: FormData.fromMap(data),
          options: Options(headers: {'cookie': _cookies}));
    } catch (e) {
      return await Dio().post(url, data: FormData.fromMap(data));
    }
  }

  static String _createSecretKey(int size) {
    const choice = '012345679abcdef';
    final result = List.generate(size, (index) {
      final randomIndex = (choice.length *
              (new DateTime.now().millisecondsSinceEpoch % 1000) /
              1000)
          .floor();
      return choice[randomIndex];
    });
    return result.join('');
  }

  static String _aesEncrypt(String text, String secKey, String algo) {
    final key = encrypt.Key.fromUtf8(secKey);
    final iv = encrypt.IV.fromUtf8('0102030405060708');
    final encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(text, iv: iv);
    return encrypted.base64;
  }

  static String _rsaEncrypt(String text, String pubKey, String modulus) {
    final reversedText = text.split('').reversed.join('');
    final n = BigInt.parse(modulus, radix: 16);
    final e = BigInt.parse(pubKey, radix: 16);
    final b = BigInt.parse(
        utf8.encode(reversedText).map((e) => e.toRadixString(16)).join(),
        radix: 16);
    final enc = b.modPow(e, n).toRadixString(16).padLeft(256, '0');
    return enc;
  }

  static Map<String, String> weapi(Map<String, dynamic> text) {
    const modulus =
        '00e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b72'
        '5152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ecbd'
        'a92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813cfe48'
        '75d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7';
    const nonce = '0CoJUm6Qyw8W8jud';
    const pubKey = '010001';
    final secKey = _createSecretKey(16);
    final encText = base64Encode(utf8.encode(
      _aesEncrypt(
        base64Encode(
            utf8.encode(_aesEncrypt(jsonEncode(text), nonce, 'AES-CBC'))),
        secKey,
        'AES-CBC',
      ),
    ));
    final encSecKey = _rsaEncrypt(secKey, pubKey, modulus);
    return {
      'params': encText,
      'encSecKey': encSecKey,
    };
  }

  static Map<String, dynamic> eapi(String url, dynamic object) {
    const eapiKey = 'e82ckenh8dichen8';
    final text = object is Map ? jsonEncode(object) : object;
    final message = 'nobody' + url + 'use' + text + 'md5forencrypt';
    final digest = md5.convert(utf8.encode(message)).toString();
    final data = '$url-36cd479b6b5-$text-36cd479b6b5-$digest';
    return {
      'params': _aesEncrypt(data, eapiKey, 'AES-ECB').toUpperCase(),
    };
  }

  Future<void> neShowToplist(
      int? offset, Function(Map<String, dynamic>) callback) async {
    if (offset != null && offset > 0) {
      callback({'result': []});
      return;
    }
    const url = 'https://music.163.com/weapi/toplist/detail';
    final data = await weapi({});
    final response = await dio_post_with_cookie_and_csrf(url, data);
    final result = response.data['list'].map((item) {
      return {
        'cover_img_url': item['coverImgUrl'],
        'id': 'neplaylist_${item['id']}',
        'source_url': 'https://music.163.com/#/playlist?id=${item['id']}',
        'title': item['name'],
      };
    }).toList();
    callback({'result': result});
  }

  Future<void> showPlaylist(
      String url, Function(Map<String, dynamic>) callback) async {
    const order = 'hot';
    final offset = getParameterByName('offset', url);
    final filterId = getParameterByName('filter_id', url);

    if (filterId == 'toplist') {
      await neShowToplist(
          offset != null ? int.tryParse(offset) : null, callback);
      return;
    }

    String filter = '';
    if (filterId.isNotEmpty) {
      filter = '&cat=$filterId';
    }
    String targetUrl;
    if (offset != null) {
      targetUrl =
          'https://music.163.com/discover/playlist/?order=$order$filter&limit=35&offset=$offset';
    } else {
      targetUrl =
          'https://music.163.com/discover/playlist/?order=$order$filter';
    }

    final response = await dio_get_with_cookie_and_csrf(targetUrl);
    final document = parse(response.data);
    final listElements =
        document.getElementsByClassName('m-cvrlst')[0].children;
    final result = listElements.map((item) {
      final imgElement = item.getElementsByTagName('img')[0];
      final divElement = item.getElementsByTagName('div')[0];
      final aElement = divElement.getElementsByTagName('a')[0];
      // return {
      //   'cover_img_url': imgElement.src.replaceAll('140y140', '512y512'),
      //   'title': aElement.title,
      //   'id': 'neplaylist_${getParameterByName('id', aElement.href)}',
      //   'source_url':
      //       'https://music.163.com/#/playlist?id=${getParameterByName('id', aElement.href)}',
      // };
      return {
        'cover_img_url':
            imgElement.attributes['src']!.replaceAll('140y140', '512y512'),
        'title': aElement.attributes['title']!,
        'id':
            'neplaylist_${Uri.parse(aElement.attributes['href']!).queryParameters['id']}',
        'source_url':
            'https://music.163.com/#/playlist?id=${Uri.parse(aElement.attributes['href']!).queryParameters['id']}',
      };
    }).toList();
    callback({'result': result});
  }

  static Future<void> neEnsureCookie(Function callback) async {
    const domain = 'https://music.163.com';
    const nuidName = '_ntes_nuid';
    const nnidName = '_ntes_nnid';

    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(nuidName)) {
      final nuidValue = _createSecretKey(32);
      final nnidValue = '$nuidValue,${DateTime.now().millisecondsSinceEpoch}';
      final expire =
          DateTime.now().add(Duration(days: 365 * 100)).millisecondsSinceEpoch /
              1000;

      await prefs.setString(nuidName, nuidValue);
      await prefs.setString(nnidName, nnidValue);
      callback(null);
    } else {
      callback(null);
    }
  }

  Future<void> asyncProcessList(
      List<dynamic> dataList,
      Future<dynamic> Function(int, dynamic, List<dynamic>) handler,
      List<dynamic> handlerExtraParamList,
      Function callback) async {
    try {
      final futures = dataList.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return handler(index, item, handlerExtraParamList);
      }).toList();

      final results = await Future.wait(futures);
      callback(null, results);
    } catch (e) {
      callback(e, null);
    }
  }

  Future<void> ngRenderPlaylistResultItem(
      int index, dynamic item, Function callback) async {
    const targetUrl = 'https://music.163.com/weapi/v3/song/detail';
    final queryIds = [item['id']];
    final d = {
      'c': '[${queryIds.map((id) => '{"id":$id}').join(',')}]',
      'ids': '[${queryIds.join(',')}]',
    };
    final data = await weapi(d);
    final response = await dio_post_with_cookie_and_csrf(targetUrl, data);
    final trackJson = response.data['songs'][0];
    final track = {
      'id': 'netrack_${trackJson['id']}',
      'title': trackJson['name'],
      'artist': trackJson['ar'][0]['name'],
      'artist_id': 'neartist_${trackJson['ar'][0]['id']}',
      'album': trackJson['al']['name'],
      'album_id': 'nealbum_${trackJson['al']['id']}',
      'source': 'netease',
      'source_url': 'https://music.163.com/#/song?id=${trackJson['id']}',
      'img_url': trackJson['al']['picUrl'],
      // 'url': 'netrack_${trackJson['id']}',
    };
    callback(null, track);
  }

  // static Future<void> neGetPlaylist(String url, Function fn) async {
  Future<Map<String, dynamic>> neGetPlaylist(String url) async {
    final listId = Uri.parse(url).queryParameters['list_id']!.split('_').last;
    const targetUrl = 'https://music.163.com/weapi/v3/playlist/detail';
    final data = weapi({
      'id': listId,
      'offset': 0,
      'total': true,
      'limit': 1000,
      'n': 1000,
      'csrf_token': '',
    });
    await neEnsureCookie((_) async {
      final response = await dio_post_with_cookie_and_csrf(targetUrl, data);
      final resData = response.data;
      final info = {
        'id': 'neplaylist_$listId',
        'cover_img_url': resData['playlist']['coverImgUrl'],
        'title': resData['playlist']['name'],
        'source_url': 'https://music.163.com/#/playlist?id=$listId',
      };
      final maxAllowSize = 1000;
      final trackIdsArray =
          _splitArray(resData['playlist']['trackIds'], maxAllowSize);

      final tracks = <Map<String, dynamic>>[];
      for (final trackIds in trackIdsArray) {
        final trackData = await _ngParsePlaylistTracks(trackIds);
        tracks.addAll(trackData);
      }
      return {'tracks': tracks, 'info': info};
    });
    return {};
  }

  static List<List<dynamic>> _splitArray(List<dynamic> array, int size) {
    final count = (array.length / size).ceil();
    final result = <List<dynamic>>[];
    for (var i = 0; i < count; i++) {
      result.add(array.sublist(i * size, (i + 1) * size));
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _ngParsePlaylistTracks(
      List<dynamic> trackIds) async {
    const targetUrl = 'https://music.163.com/weapi/v3/song/detail';
    final data = weapi({
      'c': '[${trackIds.map((id) => '{"id":$id}').join(',')}]',
      'ids': '[${trackIds.join(',')}]',
    });
    final response = await dio_post_with_cookie_and_csrf(targetUrl, data);
    final tracks = (response.data['songs'] as List).map((trackJson) {
      return {
        'id': 'netrack_${trackJson['id']}',
        'title': trackJson['name'],
        'artist': trackJson['ar'][0]['name'],
        'artist_id': 'neartist_${trackJson['ar'][0]['id']}',
        'album': trackJson['al']['name'],
        'album_id': 'nealbum_${trackJson['al']['id']}',
        'source': 'netease',
        'source_url': 'https://music.163.com/#/song?id=${trackJson['id']}',
        'img_url': trackJson['al']['picUrl'],
      };
    }).toList();
    return tracks;
  }

  Future<void> bootstrapTrack(
      Map<String, dynamic> track, Function success, Function failure) async {
    final sound = <String, dynamic>{};
    const targetUrl =
        'https://interface3.music.163.com/eapi/song/enhance/player/url';
    var songId = track['id'].toString().replaceFirst('netrack_', '');
    const eapiUrl = '/api/song/enhance/player/url';

    final data = eapi(eapiUrl, {
      'ids': '[$songId]',
      'br': 999000,
    });
    final expire = (DateTime.now().millisecondsSinceEpoch +
            1e3 * 60 * 60 * 24 * 365 * 100) /
        1000;

    // await Dio()
    //     .post(targetUrl + '?csrf_token=${await get_csrf()}',
    //         data: FormData.fromMap(data))
    //     .then((response) {
    final response = await dio_post_with_cookie_and_csrf(targetUrl, data);
    final resData = response.data['data'][0];
    final url = resData['url'];
    final br = resData['br'];
    if (url != null) {
      sound['url'] = url;
      sound['bitrate'] = '${(br / 1000).toStringAsFixed(0)}kbps';
      sound['platform'] = 'netease';
      success(sound);
    } else {
      failure(sound);
    }
    ;
  }

  static bool isPlayable(Map<String, dynamic> song) {
    return song['fee'] != 4 && song['fee'] != 1;
  }

  // static Future<void> search(String url, Function fn) async {
  Future<Map<String, dynamic>> search(String url) async {
    const targetUrl = 'https://music.163.com/api/search/pc';
    final keyword = Uri.parse(url).queryParameters['keywords'];
    final curpage = Uri.parse(url).queryParameters['curpage'];
    final searchType = Uri.parse(url).queryParameters['type'];
    var neSearchType = '1';
    if (searchType == '1') {
      neSearchType = '1000';
    }
    final reqData = {
      's': keyword,
      'offset': 20 * (int.parse(curpage!) - 1),
      'limit': 20,
      'type': neSearchType,
    };
    final response = await dio_post_with_cookie_and_csrf(targetUrl, reqData);
    final data = response.data;
    var result = <Map<String, dynamic>>[];
    var total = 0;
    if (searchType == '0') {
      result = (data['result']['songs'] as List).map((songInfo) {
        return {
          'id': 'netrack_${songInfo['id']}',
          'title': songInfo['name'],
          'artist': songInfo['artists'][0]['name'],
          'artist_id': 'neartist_${songInfo['artists'][0]['id']}',
          'album': songInfo['album']['name'],
          'album_id': 'nealbum_${songInfo['album']['id']}',
          'source': 'netease',
          'source_url': 'https://music.163.com/#/song?id=${songInfo['id']}',
          'img_url': songInfo['album']['picUrl'],
          'url': !isPlayable(songInfo) ? '' : null,
        };
      }).toList();
      total = data['result']['songCount'];
    } else if (searchType == '1') {
      result = (data['result']['playlists'] as List).map((info) {
        return {
          'id': 'neplaylist_${info['id']}',
          'title': info['name'],
          'source': 'netease',
          'source_url': 'https://music.163.com/#/playlist?id=${info['id']}',
          'img_url': info['coverImgUrl'],
          'url': 'neplaylist_${info['id']}',
          'author': info['creator']['nickname'],
          'count': info['trackCount'],
        };
      }).toList();
      total = data['result']['playlistCount'];
    }
    return {'result': result, 'total': total, 'type': searchType};
  }

  // static Future<void> neAlbum(String url, Function fn) async {
  Future<Map<String, dynamic>> neAlbum(String url) async {
    final albumId = Uri.parse(url).queryParameters['list_id']!.split('_').last;
    final targetUrl = 'https://music.163.com/api/album/$albumId';
    final response =
        await dio_get_with_cookie_and_csrf(targetUrl);
    final data = response.data;
    final info = {
      'cover_img_url': data['album']['picUrl'],
      'title': data['album']['name'],
      'id': 'nealbum_${data['album']['id']}',
      'source_url': 'https://music.163.com/#/album?id=${data['album']['id']}',
    };
    final tracks = (data['album']['songs'] as List).map((songInfo) {
      return {
        'id': 'netrack_${songInfo['id']}',
        'title': songInfo['name'],
        'artist': songInfo['artists'][0]['name'],
        'artist_id': 'neartist_${songInfo['artists'][0]['id']}',
        'album': songInfo['album']['name'],
        'album_id': 'nealbum_${songInfo['album']['id']}',
        'source': 'netease',
        'source_url': 'https://music.163.com/#/song?id=${songInfo['id']}',
        'img_url': songInfo['album']['picUrl'],
        'url': !isPlayable(songInfo) ? '' : null,
      };
    }).toList();
    return {'tracks': tracks, 'info': info};
  }

  // static Future<void> neArtist(String url, Function fn) async {
  Future<Map<String, dynamic>> neArtist(String url) async {
    final artistId = Uri.parse(url).queryParameters['list_id']!.split('_').last;
    final targetUrl = 'https://music.163.com/api/artist/$artistId';
    // final response =
    //     await Dio().get(targetUrl + '?csrf_token=${await get_csrf()}');
    final response = await dio_get_with_cookie_and_csrf(targetUrl);
    final data = response.data;
    final info = {
      'cover_img_url': data['artist']['picUrl'],
      'title': data['artist']['name'],
      'id': 'neartist_${data['artist']['id']}',
      'source_url': 'https://music.163.com/#/artist?id=${data['artist']['id']}',
    };
    final tracks = (data['hotSongs'] as List).map((songInfo) {
      return {
        'id': 'netrack_${songInfo['id']}',
        'title': songInfo['name'],
        'artist': songInfo['artists'][0]['name'],
        'artist_id': 'neartist_${songInfo['artists'][0]['id']}',
        'album': songInfo['album']['name'],
        'album_id': 'nealbum_${songInfo['album']['id']}',
        'source': 'netease',
        'source_url': 'https://music.163.com/#/song?id=${songInfo['id']}',
        'img_url': songInfo['album']['picUrl'],
        'url': !isPlayable(songInfo) ? '' : null,
      };
    }).toList();
    // fn({'tracks': tracks, 'info': info});
    return {'tracks': tracks, 'info': info};
  }

  // static Future<void> lyric(String url, Function fn) async {
  Future<Map<String, dynamic>> lyric(String url) async {
    final trackId = Uri.parse(url).queryParameters['track_id']!.split('_').last;
    const targetUrl = 'https://music.163.com/weapi/song/lyric';
    final data = weapi({
      'id': trackId,
      'lv': -1,
      'tv': -1,
      'csrf_token': await get_csrf(),
    });
    // final response = await Dio().post(
    //     targetUrl + '?csrf_token=${await get_csrf()}',
    //     data: FormData.fromMap(data));
    final response = await dio_post_with_cookie_and_csrf(targetUrl, data);
    final resData = response.data;
    var lrc = '';
    var tlrc = '';
    if (resData['lrc'] != null) {
      lrc = resData['lrc']['lyric'];
    }
    if (resData['tlyric'] != null && resData['tlyric']['lyric'] != null) {
      tlrc = resData['tlyric']['lyric']
          .replaceAll(RegExp(r'(|\\)'), '')
          .replaceAll(RegExp(r'[\u2005]+'), ' ');
    }
    // fn({'lyric': lrc, 'tlyric': tlrc});
    return {'lyric': lrc, 'tlyric': tlrc};
  }

  // static Future<void> parseUrl(String url, Function fn) async {
  static Future<Map<String, dynamic>> parseUrl(String url) async {
    var result;
    var id = '';
    url = url.replaceAll(
        'music.163.com/#/discover/toplist?', 'music.163.com/#/playlist?');
    url = url.replaceAll('music.163.com/#/my/m/music/', 'music.163.com/');
    url = url.replaceAll('music.163.com/#/m/', 'music.163.com/');
    url = url.replaceAll('music.163.com/#/', 'music.163.com/');
    if (url.contains('//music.163.com/playlist')) {
      final match =
          RegExp(r'\/\/music.163.com\/playlist\/([0-9]+)').firstMatch(url);
      id = match != null
          ? match.group(1)!
          : Uri.parse(url).queryParameters['id']!;
      result = {
        'type': 'playlist',
        'id': 'neplaylist_$id',
      };
    } else if (url.contains('//music.163.com/artist')) {
      result = {
        'type': 'playlist',
        'id': 'neartist_${Uri.parse(url).queryParameters['id']}',
      };
    } else if (url.contains('//music.163.com/album')) {
      final match =
          RegExp(r'\/\/music.163.com\/album\/([0-9]+)').firstMatch(url);
      id = match != null
          ? match.group(1)!
          : Uri.parse(url).queryParameters['id']!;
      result = {
        'type': 'playlist',
        'id': 'nealbum_$id',
      };
    }
    // fn(result);
    return result;
  }

  // static Future<void> getPlaylist(String url, Function fn) async {
  Future<Map<String, dynamic>> getPlaylist(String url) async {
    final listId = Uri.parse(url).queryParameters['list_id']!.split('_')[0];
    switch (listId) {
      case 'neplaylist':
        // await neGetPlaylist(url, fn);
        return await neGetPlaylist(url);
        break;
      case 'nealbum':
        // await neAlbum(url, fn);
        return await neAlbum(url);
        break;
      case 'neartist':
        // await neArtist(url, fn);
        return await neArtist(url);
        break;
      default:
        return {};
    }
  }

  Future<Map<String, dynamic>> getplaylistfilters() {
    final recommend = [
      {'id': '', 'name': '全部'},
      {'id': 'toplist', 'name': '排行榜'},
      {'id': '流行', 'name': '流行'},
      {'id': '民谣', 'name': '民谣'},
      {'id': '电子', 'name': '电子'},
      {'id': '舞曲', 'name': '舞曲'},
      {'id': '说唱', 'name': '说唱'},
      {'id': '轻音乐', 'name': '轻音乐'},
      {'id': '爵士', 'name': '爵士'},
      {'id': '乡村', 'name': '乡村'},
    ];

    final all = [
      {
        'category': '语种',
        'filters': [
          {'id': '华语', 'name': '华语'},
          {'id': '欧美', 'name': '欧美'},
          {'id': '日语', 'name': '日语'},
          {'id': '韩语', 'name': '韩语'},
          {'id': '粤语', 'name': '粤语'},
        ],
      },
      {
        'category': '风格',
        'filters': [
          {'id': '流行', 'name': '流行'},
          {'id': '民谣', 'name': '民谣'},
          {'id': '电子', 'name': '电子'},
          {'id': '舞曲', 'name': '舞曲'},
          {'id': '说唱', 'name': '说唱'},
          {'id': '轻音乐', 'name': '轻音乐'},
          {'id': '爵士', 'name': '爵士'},
          {'id': '乡村', 'name': '乡村'},
          {'id': 'R%26B%2FSoul', 'name': 'R&B/Soul'},
          {'id': '古典', 'name': '古典'},
          {'id': '民族', 'name': '民族'},
          {'id': '英伦', 'name': '英伦'},
          {'id': '金属', 'name': '金属'},
          {'id': '朋克', 'name': '朋克'},
          {'id': '蓝调', 'name': '蓝调'},
          {'id': '雷鬼', 'name': '雷鬼'},
          {'id': '世界音乐', 'name': '世界音乐'},
          {'id': '拉丁', 'name': '拉丁'},
          {'id': 'New Age', 'name': 'New Age'},
          {'id': '古风', 'name': '古风'},
          {'id': '后摇', 'name': '后摇'},
          {'id': 'Bossa Nova', 'name': 'Bossa Nova'},
        ],
      },
      {
        'category': '场景',
        'filters': [
          {'id': '清晨', 'name': '清晨'},
          {'id': '夜晚', 'name': '夜晚'},
          {'id': '学习', 'name': '学习'},
          {'id': '工作', 'name': '工作'},
          {'id': '午休', 'name': '午休'},
          {'id': '下午茶', 'name': '下午茶'},
          {'id': '地铁', 'name': '地铁'},
          {'id': '驾车', 'name': '驾车'},
          {'id': '运动', 'name': '运动'},
          {'id': '旅行', 'name': '旅行'},
          {'id': '散步', 'name': '散步'},
          {'id': '酒吧', 'name': '酒吧'},
        ],
      },
      {
        'category': '情感',
        'filters': [
          {'id': '怀旧', 'name': '怀旧'},
          {'id': '清新', 'name': '清新'},
          {'id': '浪漫', 'name': '浪漫'},
          {'id': '伤感', 'name': '伤感'},
          {'id': '治愈', 'name': '治愈'},
          {'id': '放松', 'name': '放松'},
          {'id': '孤独', 'name': '孤独'},
          {'id': '感动', 'name': '感动'},
          {'id': '兴奋', 'name': '兴奋'},
          {'id': '快乐', 'name': '快乐'},
          {'id': '安静', 'name': '安静'},
          {'id': '思念', 'name': '思念'},
        ],
      },
      {
        'category': '主题',
        'filters': [
          {'id': '综艺', 'name': '综艺'},
          {'id': '影视原声', 'name': '影视原声'},
          {'id': 'ACG', 'name': 'ACG'},
          {'id': '儿童', 'name': '儿童'},
          {'id': '校园', 'name': '校园'},
          {'id': '游戏', 'name': '游戏'},
          {'id': '70后', 'name': '70后'},
          {'id': '80后', 'name': '80后'},
          {'id': '90后', 'name': '90后'},
          {'id': '网络歌曲', 'name': '网络歌曲'},
          {'id': 'KTV', 'name': 'KTV'},
          {'id': '经典', 'name': '经典'},
          {'id': '翻唱', 'name': '翻唱'},
          {'id': '吉他', 'name': '吉他'},
          {'id': '钢琴', 'name': '钢琴'},
          {'id': '器乐', 'name': '器乐'},
          {'id': '榜单', 'name': '榜单'},
          {'id': '00后', 'name': '00后'},
        ],
      },
    ];
    // return {
    //   success: (fn) => fn({ recommend, all }),
    // };
    return Future.value({'recommend': recommend, 'all': all});
  }

  // static Future<void> getUserPlaylist(
  //     String url, String playlistType, Function fn) async {
  Future<Map<String, dynamic>> getUserPlaylist(
      String url, String playlistType) async {
    final userId = Uri.parse(url).queryParameters['user_id'];
    const targetUrl = 'https://music.163.com/api/user/playlist';

    final reqData = {
      'uid': userId,
      'limit': 1000,
      'offset': 0,
      'includeVideo': true,
    };

    // final response = await Dio().post(
    //     targetUrl + '?csrf_token=${await get_csrf()}',
    //     data: FormData.fromMap(reqData));
    final response = await dio_post_with_cookie_and_csrf(targetUrl, reqData);
    final playlists = (response.data['playlist'] as List).where((item) {
      if (playlistType == 'created' && item['subscribed'] != false) {
        return false;
      }
      if (playlistType == 'favorite' && item['subscribed'] != true) {
        return false;
      }
      return true;
    }).map((item) {
      return {
        'cover_img_url': item['coverImgUrl'],
        'id': 'neplaylist_${item['id']}',
        'source_url': 'https://music.163.com/#/playlist?id=${item['id']}',
        'title': item['name'],
      };
    }).toList();
    // fn({
    //   'status': 'success',
    //   'data': {'playlists': playlists}
    // });
    return {
      'status': 'success',
      'data': {'playlists': playlists}
    };
  }

  // static Future<void> getUserCreatedPlaylist(String url, Function fn) async {
  Future<Map<String, dynamic>> getUserCreatedPlaylist(String url) async {
    // await getUserPlaylist(url, 'created', fn);
    return await getUserPlaylist(url, 'created');
  }

  // static Future<void> getUserFavoritePlaylist(String url, Function fn) async {
  //   await getUserPlaylist(url, 'favorite', fn);
  // }
  Future<Map<String, dynamic>> getUserFavoritePlaylist(
      String url) async {
    return await getUserPlaylist(url, 'favorite');
  }

  // static Future<void> getRecommendPlaylist(Function fn) async {
  Future<Map<String, dynamic>> getRecommendPlaylist() async {
    const targetUrl = 'https://music.163.com/weapi/personalized/playlist';

    final reqData = {
      'limit': 30,
      'total': true,
      'n': 1000,
    };

    final encryptReqData = weapi(reqData);

    // final response = await Dio().post(
    //     targetUrl + '?csrf_token=${await get_csrf()}',
    //     data: FormData.fromMap(encryptReqData));
    final response = await dio_post_with_cookie_and_csrf(targetUrl, encryptReqData);
    final playlists = (response.data['result'] as List).map((item) {
      return {
        'cover_img_url': item['picUrl'],
        'id': 'neplaylist_${item['id']}',
        'source_url': 'https://music.163.com/#/playlist?id=${item['id']}',
        'title': item['name'],
      };
    }).toList();
    // fn({
    //   'status': 'success',
    //   'data': {'playlists': playlists}
    // });
    return {
      'status': 'success',
      'data': {'playlists': playlists}
    };
  }

  // static Future<void> getUser(Function fn) async {
  Future<Map<String, dynamic>> getUser() async {
    const url = 'https://music.163.com/api/nuser/account/get';

    final encryptReqData = weapi({});
    // final response = await Dio().post(url + '?csrf_token=${await get_csrf()}',
    //     data: FormData.fromMap(encryptReqData));
    final response = await dio_post_with_cookie_and_csrf(url, encryptReqData);
    dynamic result = {'is_login': false};
    var status = 'fail';
    if (response.data['account'] != null) {
      status = 'success';
      final data = response.data;
      result = {
        'is_login': true,
        'user_id': data['account']['id'],
        'user_name': data['account']['userName'],
        'nickname': data['profile']['nickname'],
        'avatar': data['profile']['avatarUrl'],
        'platform': 'netease',
        'data': data,
      };
    }
    // fn({'status': status, 'result': result});
    return {'status': status, 'result': result};
  }
}
