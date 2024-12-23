import 'dart:ffi';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' show parse;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'lowebutil.dart';
import 'settings.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:convert/convert.dart';

final netease = Netease();

Future<String> get_csrf() async {
  final tokens = await settings_getsettings();
  try {
    String _cookies = tokens['ne'];
    return _cookies
        .split(';')
        .firstWhere((element) => element.contains('__csrf'))
        .split('=')
        .last;
  } catch (e) {
    return '';
  }
}

class CookieInterceptors extends InterceptorsWrapper {
  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final tokens = await settings_getsettings();
    final _cookies = tokens['ne'];
    dynamic tcookies = _cookies.split(';');
    dynamic cookies = [];
    for (var cookie in tcookies) {
      cookie = cookie.trim();
      cookies.add(cookie);
    }
    options.queryParameters['cookie'] = cookies;

    //Vercel部署的 需要额外加一个 realIP 参数 国内的IP地址就可以 这里是百度的
    options.queryParameters['realIP'] = '202.108.22.5';
    super.onRequest(options, handler);
  }
}

class Netease {
  Future<dynamic> dio_get_with_cookie_and_csrf(String url) async {
    // final tokens = await settings_getsettings();
    // try {
    //   final _cookies = tokens['ne'];
    //   final _csrf = _cookies
    //       .split(';')
    //       .firstWhere((element) => element.contains('__csrf'))
    //       .split('=')
    //       .last;
    //   if (url.contains('?')) {
    //     url = url + '&csrf_token=$_csrf';
    //   } else {
    //     url = url + '?csrf_token=$_csrf';
    //   }
    //   return await Dio()
    //       .get(url, options: Options(headers: {'cookie': _cookies}));
    // } catch (e) {
    return await Dio().get(url);
    // }
  }

  Future<dynamic> dio_post_with_cookie_and_csrf(
      String url, dynamic data) async {
    print("dio_post_with_cookie_and_csrf");
    final tokens = await settings_getsettings();
    try {
      final _cookies = tokens['ne'];

      final _csrf = _cookies
          .split(';')
          .firstWhere((String element) => element.contains('__csrf'))
          .split('=')
          .last;
      if (url.contains('?')) {
        url = url + '&csrf_token=$_csrf';
      } else {
        url = url + '?csrf_token=$_csrf';
      }
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final tempPath = tempDir.path;
      dio.interceptors.add(CookieManager(PersistCookieJar(
        ignoreExpires: true,
        storage: FileStorage(tempPath + "/.cookies/"),
      )));
      // dio.interceptors.add(CookieInterceptors());
      // dynamic cookies = _cookies.split(';');
      // for (var cookie in cookies) {
      //   cookie = cookie.trim();
      // }

      return await dio.post(
        url,
        data: data,
        // options: Options(headers: {'cookie': _cookies}));
        // queryParameters: {'cookie': cookies},
        options: Options(headers: {
          // 'cookie': cookies,
          // ":authority": "music.163.com",
          // ":method": "POST",
          // ":path": url.substring(url.indexOf("music.163.com") + 13),
          "user-agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3",
          "referer": "https://music.163.com/",
          "origin": "https://music.163.com",
          "host": "music.163.com",
          "sec-fetch-site": "same-origin",
          "sec-fetch-mode": "cors",
          "sec-fetch-dest": "empty",
          "accept-encoding": "gzip, deflate",
          "accept-language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
          "accept": "*/*",
          "sec-ch-ua-platform": "\"Windows\"",
        }, contentType: 'application/x-www-form-urlencoded'),
      );
    } catch (e) {
      return await Dio().post(url, data: FormData.fromMap(data));
    }
  }

  Uint8List _pad(Uint8List data, int blockSize) {
    int padLength = blockSize - (data.length % blockSize);
    return Uint8List.fromList(data + List.filled(padLength, padLength));
  }

  static String _createSecretKey(int size) {
    // return '1234567890123456';
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

  Uint8List _aesEncrypt(String text, String secKey, String algo) {
    final key = utf8.encode(secKey);
    final iv = utf8.encode('0102030405060708');
    final encrypter = CBCBlockCipher(AESEngine())
      ..init(
          true,
          ParametersWithIV(
              KeyParameter(Uint8List.fromList(key)), Uint8List.fromList(iv)));
    final paddedText = _pad(utf8.encode(text), encrypter.blockSize);
    final encrypted = Uint8List(paddedText.length);
    var offset = 0;
    while (offset < paddedText.length) {
      offset += encrypter.processBlock(paddedText, offset, encrypted, offset);
    }
    return encrypted;
  }

  String _rsaEncrypt(String text, String pubKey, String modulus) {
    final reversedText = text.split('').reversed.join('');
    final n = BigInt.parse(modulus, radix: 16);
    final e = BigInt.parse(pubKey, radix: 16);
    final b = BigInt.parse(hex.encode(utf8.encode(reversedText)), radix: 16);
    final enc = b.modPow(e, n).toRadixString(16).padLeft(256, '0');
    return enc;
  }

  Map<String, String> weapi(Map<String, dynamic> text) {
    final modulus =
        '00e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b72'
        '5152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ecbd'
        'a92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813cfe48'
        '75d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7';
    final nonce = '0CoJUm6Qyw8W8jud';
    final pubKey = '010001';
    final jsonText = jsonEncode(text);
    // print(jsonText);
    final secKey = _createSecretKey(16);
    final t1 = _aesEncrypt(jsonText, nonce, 'AES-CBC');
    final t2 = base64.encode(t1);
    // print(t2);
    final t3 = _aesEncrypt(t2, secKey, 'AES-CBC');
    final t4 = base64.encode(t3);
    // print(t4);
    final encText = t4;
    final encSecKey = _rsaEncrypt(secKey, pubKey, modulus);
    return {
      'params': encText,
      'encSecKey': encSecKey,
    };
  }

  Uint8List _aesEncrypt2(String text, String secKey, String algo) {
    final key = utf8.encode(secKey);
    final encrypter = ECBBlockCipher(AESEngine())
      ..init(true, KeyParameter(Uint8List.fromList(key)));
    final paddedText = _pad2(utf8.encode(text), encrypter.blockSize);
    final encrypted = Uint8List(paddedText.length);
    var offset = 0;
    while (offset < paddedText.length) {
      offset += encrypter.processBlock(paddedText, offset, encrypted, offset);
    }
    return encrypted;
  }

  Uint8List _pad2(Uint8List data, int blockSize) {
    final padLength = blockSize - (data.length % blockSize);
    return Uint8List.fromList(data + List.filled(padLength, padLength));
  }

  String _bytesToHex(Uint8List bytes) {
    final buffer = StringBuffer();
    for (var byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Map<String, dynamic> eapi(String url, dynamic object) {
    const eapiKey = 'e82ckenh8dichen8';
    final text = object is Map ? jsonEncode(object) : object;
    final message = 'nobody' + url + 'use' + text + 'md5forencrypt';
    final digest = md5.convert(utf8.encode(message)).toString();
    final data = '$url-36cd479b6b5-$text-36cd479b6b5-$digest';
    final encrypted = _aesEncrypt2(data, eapiKey, 'AES-ECB');
    final hexString = _bytesToHex(encrypted).toUpperCase();
    return {
      'params': hexString,
    };
  }

  // Future<void> neShowToplist( int? offset) async {
  Future<Map<String, dynamic>> neShowToplist(int? offset) async {
    if (offset != null && offset > 0) {
      // callback({'result': []});
      return {"result": []};
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
    // callback({'result': result});
    return {"result": result};
  }

  Future<Map<String, dynamic>> showPlaylist(String url) async {
    const order = 'hot';
    final offset = int.parse(getParameterByName('offset', url));
    final filterId = getParameterByName('filter_id', url);

    if (filterId == 'toplist') {
      // await neShowToplist(
      //     offset != null ? int.tryParse(offset) : null, callback);
      return neShowToplist(offset);
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
    int total = 1;
    final t = document.getElementsByClassName('u-page')[0].children;
    for (var i = 0; i < t.length; i++) {
      try {
        if (t[i].className == 'zpgi') {
          total = max(total, int.parse(t[i].text));
        }
      } catch (e) {
        // print(e);
      }
    }

    return {"result": result, "total": total, "per_page": 35};
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
    // await neEnsureCookie((_) async {
    final response = await dio_post_with_cookie_and_csrf(targetUrl, data);
    // final resData = response.data;
    final resData = jsonDecode(response.data);
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
    // });
    // return {'info': {}, 'tracks': []};
  }

  static List<List<dynamic>> _splitArray(List<dynamic> array, int size) {
    final count = (array.length / size).ceil();
    final result = <List<dynamic>>[];
    for (var i = 0; i < count; i++) {
      final start = i * size;
      final end = (i + 1) * size;
      result.add(array.sublist(start, end > array.length ? array.length : end));
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _ngParsePlaylistTracks(
      List<dynamic> trackIds) async {
    const targetUrl = 'https://music.163.com/weapi/v3/song/detail';
    Map<String, dynamic> t = {'c': "", 'ids': ""};
    trackIds.forEach((element) {
      t['c'] = t['c'] + '{"id":${element['id']}},';
      t['ids'] = t['ids'] + '${element['id']},';
    });
    t['c'] = '[' + t['c'].substring(0, t['c'].length - 1) + ']';
    t['ids'] = '[' + t['ids'].substring(0, t['ids'].length - 1) + ']';
    final data = weapi(t);
    final datastr = FormData.fromMap(data);
    final response = await Dio().post(targetUrl,
        data: data,
        options: Options(contentType: 'application/x-www-form-urlencoded'));
    final tracks =
        (jsonDecode(response.data)['songs'] as List).map((trackJson) {
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
    try {
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

      final response = await dio_post_with_cookie_and_csrf(targetUrl, data);
      final resData = jsonDecode(response.data)['data'][0];
      final url = resData['url'];
      final br = resData['br'];
      if (url != null) {
        sound['url'] = url;
        sound['bitrate'] = '${(br / 1000).toStringAsFixed(0)}kbps';
        sound['platform'] = 'netease';
        success(sound, track);
      } else {
        failure();
      }
    } catch (e) {
      failure();
    }
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
    // final data = response.data;
    final data = jsonDecode(response.data);
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
    final response = await dio_get_with_cookie_and_csrf(targetUrl);
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
    final data = jsonDecode(response.data);
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
        return neGetPlaylist(url);
        break;
      case 'nealbum':
        // await neAlbum(url, fn);
        return neAlbum(url);
        break;
      case 'neartist':
        // await neArtist(url, fn);
        return neArtist(url);
        break;
      default:
        return {};
    }
  }

  Future<Map<String, dynamic>> getPlaylistFilters() {
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
    final playlists =
        (jsonDecode(response.data)['playlist'] as List).where((item) {
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
  Future<Map<String, dynamic>> getUserFavoritePlaylist(String url) async {
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

    final response =
        await dio_post_with_cookie_and_csrf(targetUrl, encryptReqData);
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
    const url = 'https://music.163.com/weapi/w/nuser/account/get';

    // final encryptReqData = weapi({});
    dynamic encryptReqData = {
      // 'csrf_token': await get_csrf(),
      'csrf_token': "af3c2b3649aac37f7dd3a32ce1818ffc",
    };
    // print(encryptReqData);
    // print(jsonEncode(encryptReqData));
    encryptReqData = weapi(encryptReqData);
    print(encryptReqData);
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
