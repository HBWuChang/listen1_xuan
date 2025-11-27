import 'package:dio/dio.dart';
import 'package:listen1_xuan/controllers/play_controller.dart' show Track;
import 'package:listen1_xuan/loweb.dart';
import 'package:listen1_xuan/main.dart';
import 'package:listen1_xuan/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' show parse;
import 'lowebutil.dart';
import 'package:marquee/marquee.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import 'dart:typed_data';
import 'global_settings_animations.dart';
import 'package:listen1_xuan/models/Track.dart';

final qq = QQ();

class QQ {
  static String htmlDecode(String value) {
    var document = parse(value);
    return document.body?.text ?? '';
  }

  Future<dynamic> dio_get_with_cookie_and_csrf(String url) async {
    final dio = Dio();
    try {
      final sets = settings_getsettings();
      final qq_cookie = sets['qq'];
      final res = await dio.get(url,
          options: Options(headers: {
            'cookie': qq_cookie,
            'referer': 'https://y.qq.com/',
            'origin': 'https://y.qq.com',
            'priority': 'u=1, i',
            'sec-ch-ua-platform': '"Windows"',
            'user-agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0',
            'accept': 'application/json, text/plain, */*',
            'sec-ch-ua':
                '"Microsoft Edge";v="131", "Chromium";v="131", "Not_A Brand";v="24"'
          }));

      return res;
    } catch (e) {
      return await Dio().get(url);
    }
  }

  Future<dynamic> dio_post_with_cookie_and_csrf(
      String url, dynamic data) async {
    print("dio_post_with_cookie_and_csrf");
    return await dioWithCookieManager.post(
      url,
      data: data,
    );
  }

  Future<Map<String, dynamic>> qq_show_toplist([int offset = 0]) async {
    if (offset > 0) {
      return {
        'success': (fn) => fn([]),
      };
    }
    var url =
        'https://c.y.qq.com/v8/fcg-bin/fcg_myqq_toplist.fcg?g_tk=5381&inCharset=utf-8&outCharset=utf-8&notice=0&format=json&uin=0&needNewCode=1&platform=h5';
    return {
      'success': (fn) async {
        var response = await dio_get_with_cookie_and_csrf(url);
        var result = <Map<String, dynamic>>[];
        jsonDecode(response.data)['data']['topList'].forEach((item) {
          var playlist = {
            'cover_img_url': item['picUrl'],
            'id': 'qqtoplist_${item['id']}',
            'source_url': 'https://y.qq.com/n/yqq/toplist/${item['id']}.html',
            'title': item['topTitle'],
          };
          result.add(playlist);
        });
        return fn(result);
      },
    };
  }

  Future<Map<String, dynamic>> show_playlist(String url) async {
    var offset = int.parse(getParameterByName('offset', url) ?? '0');
    var filterId = getParameterByName('filter_id', url) ?? '';
    if (filterId == 'toplist') {
      return qq_show_toplist(offset);
    }
    if (filterId == '') {
      filterId = '10000000';
    }

    var target_url =
        'https://c.y.qq.com/splcloud/fcgi-bin/fcg_get_diss_by_tag.fcg' +
            '?picmid=1&rnd=${Random().nextDouble()}&g_tk=732560869' +
            '&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8' +
            '&notice=0&platform=yqq.json&needNewCode=0' +
            '&categoryId=${filterId}&sortId=5&sin=${offset}&ein=${29 + offset}';
    return {
      'success': (fn) async {
        var response = await dio_get_with_cookie_and_csrf(target_url);
        var data = jsonDecode(response.data);
        var playlists = data['data']['list'].map((item) => {
              'cover_img_url': item['imgurl'],
              'title': htmlDecode(item['dissname']),
              'id': 'qqplaylist_${item['dissid']}',
              'source_url':
                  'https://y.qq.com/n/ryqq/playlist/${item['dissid']}',
            });
        return fn(playlists);
      },
    };
  }

  String qq_get_image_url(dynamic qqimgid, String img_type) {
    if (qqimgid == null || qqimgid == 0) {
      return '';
    }
    var category = '';
    if (img_type == 'artist') {
      category = 'T001R300x300M000';
    }
    if (img_type == 'album') {
      category = 'T002R300x300M000';
    }
    var s = category + qqimgid;
    var url = 'https://y.gtimg.cn/music/photo_new/${s}.jpg';
    return url;
  }

  bool qq_is_playable(Map<String, dynamic> song) {
    try {
      // var switch_flag = song['switch'].toString().split('');
      // 转为二进制
      var switch_flag = song['switch'].toRadixString(2).split('');
      switch_flag.removeLast();
      switch_flag = switch_flag.reversed.toList();
      var play_flag = switch_flag[0];
      var try_flag = switch_flag[13];
      return play_flag == '1' || (play_flag == '1' && try_flag == '1');
    } catch (e) {
      return false;
    }
  }

  Map<String, dynamic> qq_convert_song(Map<String, dynamic> song) {
    var d = {
      'id': 'qqtrack_${song['songmid']}',
      'title': htmlDecode(song['songname']),
      'artist': htmlDecode(song['singer'][0]['name']),
      'artist_id': 'qqartist_${song['singer'][0]['mid']}',
      'album': htmlDecode(song['albumname']),
      'album_id': 'qqalbum_${song['albummid']}',
      'img_url': qq_get_image_url(song['albummid'], 'album'),
      'source': 'qq',
      'source_url':
          'https://y.qq.com/#type=song&mid=${song['songmid']}&tpl=yqq_song_detail',
      'url': !qq_is_playable(song) ? '' : null,
    };
    return d;
  }

  Map<String, dynamic> qq_convert_song2(Map<String, dynamic> song) {
    var d = {
      'id': 'qqtrack_${song['mid']}',
      'title': htmlDecode(song['name']),
      'artist': htmlDecode(song['singer'][0]['name']),
      'artist_id': 'qqartist_${song['singer'][0]['mid']}',
      'album': htmlDecode(song['album']['name']),
      'album_id': 'qqalbum_${song['album']['mid']}',
      'img_url': qq_get_image_url(song['album']['mid'], 'album'),
      'source': 'qq',
      'source_url':
          'https://y.qq.com/#type=song&mid=${song['mid']}&tpl=yqq_song_detail',
      'url': '',
    };
    return d;
  }

  String get_toplist_url(String id, String period, int limit) {
    return 'https://u.y.qq.com/cgi-bin/musicu.fcg?format=json&inCharset=utf8&outCharset=utf-8&platform=yqq.json&needNewCode=0&data=${Uri.encodeComponent(jsonEncode({
          'comm': {
            'cv': 1602,
            'ct': 20,
          },
          'toplist': {
            'module': 'musicToplist.ToplistInfoServer',
            'method': 'GetDetail',
            'param': {
              'topid': id,
              'num': limit,
              'period': period,
            },
          },
        }))}';
  }

  Future<String> get_periods(String topid) async {
    var periodUrl = 'https://c.y.qq.com/node/pc/wk_v15/top.html';
    var regExps = {
      'periodList': RegExp(
          r'<i class="play_cover__btn c_tx_link js_icon_play" data-listkey=".+?" data-listname=".+?" data-tid=".+?" data-date=".+?" .+?</i>'),
      'period': RegExp(
          r'data-listname="(.+?)" data-tid=".*?/(.+?)" data-date="(.+?)" .+?</i>'),
    };
    var periods = {};
    // var response = await Dio().get(periodUrl);
    var response = await dio_get_with_cookie_and_csrf(periodUrl);
    var html = response.data;
    var pl = regExps['periodList']?.allMatches(html) ?? [];
    if (pl.isEmpty) {
      return '';
    }
    pl.forEach((p) {
      var pr = p.group(0) != null
          ? regExps['period']?.firstMatch(p.group(0)!)
          : null;
      if (pr == null) {
        return;
      }
      periods[pr.group(2)] = {
        'name': pr.group(1),
        'id': pr.group(2),
        'period': pr.group(3),
      };
    });
    var info = periods[topid];
    return info != null ? info['period'] : '';
  }

  Future<Map<String, dynamic>> qq_toplist(String url) async {
    var list_id = int.parse(getParameterByName('list_id', url).split('_').last);
    return {
      'success': (fn) async {
        var listPeriod = await get_periods(list_id.toString());
        var limit = 100;
        var target_url = get_toplist_url(list_id.toString(), listPeriod, limit);
        var response = await dio_get_with_cookie_and_csrf(target_url);
        var tracks = jsonDecode(response.data)['toplist']['data']
                ['songInfoList']
            .map((song) {
          var d = {
            'id': 'qqtrack_${song['mid']}',
            'title': htmlDecode(song['name']),
            'artist': htmlDecode(song['singer'][0]['name']),
            'artist_id': 'qqartist_${song['singer'][0]['mid']}',
            'album': htmlDecode(song['album']['name']),
            'album_id': 'qqalbum_${song['album']['mid']}',
            'img_url': qq_get_image_url(song['album']['mid'], 'album'),
            'source': 'qq',
            'source_url':
                'https://y.qq.com/#type=song&mid=${song['mid']}&tpl=yqq_song_detail',
          };
          return d;
        }).toList();
        var info = {
          'cover_img_url': response.data['toplist']['data']['data']
              ['frontPicUrl'],
          'title': response.data['toplist']['data']['data']['title'],
          'id': 'qqtoplist_${list_id}',
          'source_url': 'https://y.qq.com/n/yqq/toplist/${list_id}.html',
        };
        return fn({'tracks': tracks, 'info': info});
      },
    };
  }

  Future<Map<String, dynamic>> qq_get_playlist(String url) async {
    var list_id = getParameterByName('list_id', url).split('_').last;
    return {
      'success': (fn) async {
        var target_url =
            'https://i.y.qq.com/qzone-music/fcg-bin/fcg_ucc_getcdinfo_' +
                'byids_cp.fcg?type=1&json=1&utf8=1&onlysong=0' +
                '&nosign=1&disstid=${list_id}&g_tk=5381&loginUin=0&hostUin=0' +
                '&format=json&inCharset=GB2312&outCharset=utf-8&notice=0' +
                '&platform=yqq&needNewCode=0';
        var response = await dio_get_with_cookie_and_csrf(target_url);
        var data = response.data;
        var info = {
          'cover_img_url': data['cdlist'][0]['logo'],
          'title': data['cdlist'][0]['dissname'],
          'id': 'qqplaylist_${list_id}',
          'source_url': 'https://y.qq.com/n/ryqq/playlist/${list_id}',
        };
        var tracks = data['cdlist'][0]['songlist']
            .map((item) => qq_convert_song(item))
            .toList();
        // 去除重复track['id']
        var track_ids = [];
        var error_ids = [];
        for (var i = 0; i < tracks.length; i++) {
          if (track_ids.contains(tracks[i]['id'])) {
            error_ids.add(tracks[i]['id']);
          } else {
            track_ids.add(tracks[i]['id']);
          }
        }
        var t_list = [];
        for (var i = 0; i < tracks.length; i++) {
          if (!error_ids.contains(tracks[i]['id'])) {
            t_list.add(tracks[i]);
          }
        }
        tracks = t_list;
        return fn({'tracks': tracks, 'info': info});
      },
    };
  }

  Future<Map<String, dynamic>> qq_album(String url) async {
    var album_id = getParameterByName('list_id', url).split('_').last;
    return {
      'success': (fn) async {
        var target_url =
            'https://i.y.qq.com/v8/fcg-bin/fcg_v8_album_info_cp.fcg' +
                '?platform=h5page&albummid=${album_id}&g_tk=938407465' +
                '&uin=0&format=json&inCharset=utf-8&outCharset=utf-8' +
                '&notice=0&platform=h5&needNewCode=1&_=1459961045571';
        var response = await dio_get_with_cookie_and_csrf(target_url);
        var data = jsonDecode(response.data);
        var info = {
          'cover_img_url': qq_get_image_url(album_id, 'album'),
          'title': data['data']['name'],
          'id': 'qqalbum_${album_id}',
          'source_url': 'https://y.qq.com/#type=album&mid=${album_id}',
        };
        var tracks =
            data['data']['list'].map((item) => qq_convert_song(item)).toList();
        // 去除重复track['id']
        var track_ids = [];
        var error_ids = [];
        for (var i = 0; i < tracks.length; i++) {
          if (track_ids.contains(tracks[i]['id'])) {
            error_ids.add(tracks[i]['id']);
          } else {
            track_ids.add(tracks[i]['id']);
          }
        }
        var t_list = [];
        for (var i = 0; i < tracks.length; i++) {
          if (!error_ids.contains(tracks[i]['id'])) {
            t_list.add(tracks[i]);
          }
        }
        tracks = t_list;
        return fn({'tracks': tracks, 'info': info});
      },
    };
  }

  Future<Map<String, dynamic>> qq_artist(String url) async {
    var artist_id = getParameterByName('list_id', url).split('_').last;
    return {
      'success': (fn) async {
        var target_url =
            'https://u.y.qq.com/cgi-bin/musicu.fcg?format=json&loginUin=0&hostUin=0inCharset=utf8&outCharset=utf-8&platform=yqq.json&needNewCode=0&data=${Uri.encodeComponent(jsonEncode({
              'comm': {
                'ct': 24,
                'cv': 0,
              },
              'singer': {
                'method': 'get_singer_detail_info',
                'param': {
                  'sort': 5,
                  'singermid': artist_id,
                  'sin': 0,
                  'num': 50,
                },
                'module': 'music.web_singer_info_svr',
              },
            }))}';
        var response = await dio_get_with_cookie_and_csrf(target_url);
        var data = jsonDecode(response.data);
        var info = {
          'cover_img_url': qq_get_image_url(artist_id, 'artist'),
          'title': data['singer']['data']['singer_info']['name'],
          'id': 'qqartist_${artist_id}',
          'source_url': 'https://y.qq.com/#type=singer&mid=${artist_id}',
        };
        var tracks = data['singer']['data']['songlist']
            .map((item) => qq_convert_song2(item))
            .toList();
        return fn({'tracks': tracks, 'info': info});
      },
    };
  }

  Future<Map<String, dynamic>> search(String url) async {
    var keyword = getParameterByName('keywords', url);
    var curpage = getParameterByName('curpage', url);
    var searchType = getParameterByName('type', url);
    var target_url = 'https://u.y.qq.com/cgi-bin/musicu.fcg';
    var searchTypeMapping = {
      '0': 0,
      '1': 3,
    };
    return {
      'success': (fn) async {
        var limit = 50;
        var page = curpage;
        var query = {
          'comm': {
            'ct': '19',
            'cv': '1859',
            'uin': '0',
          },
          'req': {
            'method': 'DoSearchForQQMusicDesktop',
            'module': 'music.search.SearchCgiService',
            'param': {
              'grp': 1,
              'num_per_page': limit,
              'page_num': int.parse(page),
              'query': keyword,
              'search_type': searchTypeMapping[searchType],
            },
          },
        };
        var response = await dio_post_with_cookie_and_csrf(target_url, query);
        var data = jsonDecode(response.data);
        var result = [];
        var total = 0;
        if (searchType == '0') {
          for (var item in data['req']['data']['body']['song']['list']) {
            result.add(qq_convert_song2(item));
          }
          total = data['req']['data']['meta']['sum'];
        } else if (searchType == '1') {
          result =
              data['req']['data']['body']['songlist']['list'].map((info) => ({
                    'id': 'qqplaylist_${info['dissid']}',
                    'title': htmlDecode(info['dissname']),
                    'source': 'qq',
                    'source_url':
                        'https://y.qq.com/n/ryqq/playlist/${info['dissid']}',
                    'img_url': info['imgurl'],
                    'url': 'qqplaylist_${info['dissid']}',
                    'author': UnicodeToAscii(info['creator']['name']),
                    'count': info['song_count'],
                  })).toList();
          total = data['req']['data']['meta']['sum'];
        }
        return fn({'result': result, 'total': total, 'type': searchType});
      },
    };
  }

  // static UnicodeToAscii(str) {
  //   const result = str.replace(/&#(\d+);/g, () =>
  //     // eslint-disable-next-line prefer-rest-params
  //     String.fromCharCode(arguments[1])
  //   );
  //   return result;
  // }
  String UnicodeToAscii(String str) {
    return str.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      return String.fromCharCode(int.parse(match.group(1)!));
    });
  }

  Future<void> bootstrap_track(
      Track track, Function success, Function failure) async {
    Map<String, dynamic> settings = settings_getsettings();
    String qqcookie = settings['qq'] ?? '';
    // print(qqcookie);

    var sound = {};
    var songId = track.id.substring('qqtrack_'.length);
    var target_url = 'https://u.y.qq.com/cgi-bin/musicu.fcg';
    // var guid = '10000';
    // $guid = mt_rand() % 10000000000;
    var guid = Random().nextDouble().toStringAsFixed(10).substring(2);
    var songmidList = [songId];
    var uin = qqcookie
        .split(';')
        .firstWhere((element) => element.startsWith('uin='),
            orElse: () => 'uin=0')
        .split('=')[1];
    var fileType = '128';
    var fileConfig = {
      'm4a': {
        's': 'C400',
        'e': '.m4a',
        'bitrate': 'M4A',
      },
      '128': {
        's': 'M500',
        'e': '.mp3',
        'bitrate': '128kbps',
      },
      '320': {
        's': 'M800',
        'e': '.mp3',
        'bitrate': '320kbps',
      },
      'ape': {
        's': 'A000',
        'e': '.ape',
        'bitrate': 'APE',
      },
      'flac': {
        's': 'F000',
        'e': '.flac',
        'bitrate': 'FLAC',
      },
    };
    var fileInfo = fileConfig[fileType];
    var file = songmidList.length == 1 && fileInfo != null
        ? '${fileInfo['s']}${songId}${songId}${fileInfo['e']}'
        : null;
    var reqData = {
      'req_1': {
        'module': 'vkey.GetVkeyServer',
        'method': 'CgiGetVkey',
        'param': {
          'filename': file != null ? [file] : [],
          'guid': guid,
          'songmid': songmidList,
          'songtype': [0],
          'uin': uin,
          'loginflag': 1,
          'platform': '20',
        },
      },
      'loginUin': uin,
      'comm': {
        'uin': uin,
        'format': 'json',
        'ct': 24,
        'cv': 0,
      },
    };
    var response = await dio_post_with_cookie_and_csrf(target_url, reqData);
    var data = jsonDecode(response.data);
    var purl = data['req_1']['data']['midurlinfo'][0]['purl'];
    if (purl == '') {
      failure(track);
      return;
    }
    var url = data['req_1']['data']['sip'][0] + purl;
    sound['url'] = url;
    var prefix = purl.substring(0, 4);
    var found = fileConfig.values.where((i) => i['s'] == prefix);
    sound['bitrate'] = found.isNotEmpty ? found.first['bitrate'] : '';
    sound['platform'] = 'qq';
    success(sound, track);
  }

  // static str2ab(str) {
  //   // string to array buffer.
  //   const buf = new ArrayBuffer(str.length);
  //   const bufView = new Uint8Array(buf);
  //   for (let i = 0, strLen = str.length; i < strLen; i += 1) {
  //     bufView[i] = str.charCodeAt(i);
  //   }
  //   return buf;
  // }
  Uint8List str2ab(String str) {
    var buf = Uint8List(str.length);
    for (var i = 0; i < str.length; i++) {
      buf[i] = str.codeUnitAt(i);
    }
    return buf;
  }

  // static lyric(url) {
  //   // eslint-disable-line no-unused-vars
  //   const track_id = getParameterByName('track_id', url).split('_').pop();
  //   // use chrome extension to modify referer.
  //   const target_url =
  //     'https://i.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?' +
  //     `songmid=${track_id}&g_tk=5381&format=json&inCharset=utf8&outCharset=utf-8&nobase64=1`;
  //   return {
  //     success: (fn) => {
  //       axios.get(target_url).then((response) => {
  //         const { data } = response;
  //         const lrc = data.lyric || '';
  //         const tlrc = data.trans.replace(/\/\//g, '') || '';
  //         return fn({
  //           lyric: lrc,
  //           tlyric: tlrc,
  //         });
  //       });
  //     },
  //   };
  // }
  // Future<Map<String, dynamic>> lyric(String url) async {
  //   var track_id = getParameterByName('track_id', url).split('_').last;
  //   var target_url = 'https://i.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?' +
  //       'songmid=${track_id}&g_tk=5381&format=json&inCharset=utf8&outCharset=utf-8&nobase64=1';
  //   var response = await dio_get_with_cookie_and_csrf(target_url);
  //   var data = response.data;
  //   var lrc = data['lyric'] ?? '';
  //   var tlrc = data['trans'].replaceAll(RegExp(r'//'), '') ?? '';
  //   return {'lyric': lrc, 'tlyric': tlrc};
  // }
  Future<Map<String, dynamic>> lyric(String url) async {
    var track_id = getParameterByName('track_id', url).split('_').last;
    var target_url = 'https://i.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?' +
        'songmid=${track_id}&g_tk=5381&format=json&inCharset=utf8&outCharset=utf-8&nobase64=1';
    return {
      "success": (fn) async {
        final response = await dio_get_with_cookie_and_csrf(target_url);
        final data = jsonDecode(response.data);
        final lrc = data['lyric'] ?? '';
        var tlrc = data['trans'].replaceAll(RegExp(r'//'), '') ?? '';
        fn({'lyric': lrc, 'tlyric': tlrc});
      }
    };
  }
// static parse_url(url) {
//     return {
//       success: (fn) => {
//         let result;

//         let match = /\/\/y.qq.com\/n\/yqq\/playlist\/([0-9]+)/.exec(url);
//         if (match != null) {
//           const playlist_id = match[1];
//           result = {
//             type: 'playlist',
//             id: `qqplaylist_${playlist_id}`,
//           };
//         }
//         match = /\/\/y.qq.com\/n\/yqq\/playsquare\/([0-9]+)/.exec(url);
//         if (match != null) {
//           const playlist_id = match[1];
//           result = {
//             type: 'playlist',
//             id: `qqplaylist_${playlist_id}`,
//           };
//         }
//         match =
//           /\/\/y.qq.com\/n\/m\/detail\/taoge\/index.html\?id=([0-9]+)/.exec(
//             url
//           );
//         if (match != null) {
//           const playlist_id = match[1];
//           result = {
//             type: 'playlist',
//             id: `qqplaylist_${playlist_id}`,
//           };
//         }

//         // c.y.qq.com/base/fcgi-bin/u?__=1MsbSLu
//         match = /\/\/c.y.qq.com\/base\/fcgi-bin\/u\?__=([0-9a-zA-Z]+)/.exec(
//           url
//         );
//         if (match != null) {
//           return axios
//             .get(url)
//             .then((response) => {
//               const { responseURL } = response.request;
//               const playlist_id = getParameterByName('id', responseURL);
//               result = {
//                 type: 'playlist',
//                 id: `qqplaylist_${playlist_id}`,
//               };
//               return fn(result);
//             })
//             .catch(() => fn(undefined));
//         }
//         return fn(result);
//       },
//     };
//   }
  // Future<Map<String, dynamic>> parse_url(String url) async {
  //   var result;
  //   var match = RegExp(r'//y.qq.com/n/yqq/playlist/([0-9]+)').firstMatch(url);
  //   if (match != null) {
  //     var playlist_id = match.group(1);
  //     result = {
  //       'type': 'playlist',
  //       'id': 'qqplaylist_${playlist_id}',
  //     };
  //   }
  //   match = RegExp(r'//y.qq.com/n/yqq/playsquare/([0-9]+)').firstMatch(url);
  //   if (match != null) {
  //     var playlist_id = match.group(1);
  //     result = {
  //       'type': 'playlist',
  //       'id': 'qqplaylist_${playlist_id}',
  //     };
  //   }
  //   match = RegExp(r'//y.qq.com/n/m/detail/taoge/index.html\?id=([0-9]+)')
  //       .firstMatch(url);
  //   if (match != null) {
  //     var playlist_id = match.group(1);
  //     result = {
  //       'type': 'playlist',
  //       'id': 'qqplaylist_${playlist_id}',
  //     };
  //   }
  //   match = RegExp(r'//c.y.qq.com/base/fcgi-bin/u\?__=([0-9a-zA-Z]+)')
  //       .firstMatch(url);
  //   if (match != null) {
  //     var response = await dio_get_with_cookie_and_csrf(url);
  //     var responseURL = response.requestOptions.uri.toString();
  //     var playlist_id = getParameterByName('id', responseURL);
  //     result = {
  //       'type': 'playlist',
  //       'id': 'qqplaylist_${playlist_id}',
  //     };
  //   }
  //   return result;
  // }

  // static get_playlist(url) {
  //   const list_id = getParameterByName('list_id', url).split('_')[0];
  //   switch (list_id) {
  //     case 'qqplaylist':
  //       return this.qq_get_playlist(url);
  //     case 'qqalbum':
  //       return this.qq_album(url);
  //     case 'qqartist':
  //       return this.qq_artist(url);
  //     case 'qqtoplist':
  //       return this.qq_toplist(url);
  //     default:
  //       return null;
  //   }
  // }
  Future<Map<String, dynamic>?> get_playlist(String url) async {
    var list_id = getParameterByName('list_id', url).split('_').first;
    switch (list_id) {
      case 'qqplaylist':
        return qq_get_playlist(url);
      case 'qqalbum':
        return qq_album(url);
      case 'qqartist':
        return qq_artist(url);
      case 'qqtoplist':
        return qq_toplist(url);
      default:
        return null;
    }
  }
  // static get_playlist_filters() {
  //   const target_url =
  //     'https://c.y.qq.com/splcloud/fcgi-bin/fcg_get_diss_tag_conf.fcg' +
  //     `?picmid=1&rnd=${Math.random()}&g_tk=732560869` +
  //     '&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8' +
  //     '&notice=0&platform=yqq.json&needNewCode=0';

  //   return {
  //     success: (fn) => {
  //       axios.get(target_url).then((response) => {
  //         const { data } = response;
  //         const all = [];
  //         data.data.categories.forEach((cate) => {
  //           const result = { category: cate.categoryGroupName, filters: [] };
  //           if (cate.usable === 1) {
  //             cate.items.forEach((item) => {
  //               result.filters.push({
  //                 id: item.categoryId,
  //                 name: this.htmlDecode(item.categoryName),
  //               });
  //             });
  //             all.push(result);
  //           }
  //         });
  //         const recommendLimit = 8;
  //         const recommend = [
  //           { id: '', name: '全部' },
  //           { id: 'toplist', name: '排行榜' },
  //           ...all[1].filters.slice(0, recommendLimit),
  //         ];

  //         return fn({
  //           recommend,
  //           all,
  //         });
  //       });
  //     },
  //   };
  // }
  // Future<Map<String, dynamic>> get_playlist_filters() async {
  //   var target_url =
  //       'https://c.y.qq.com/splcloud/fcgi-bin/fcg_get_diss_tag_conf.fcg' +
  //           '?picmid=1&rnd=${Random().nextDouble()}&g_tk=732560869' +
  //           '&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8' +
  //           '&notice=0&platform=yqq.json&needNewCode=0';
  //   var response = await dio_get_with_cookie_and_csrf(target_url);
  //   var data = jsonDecode(response.data);
  //   var all = [];
  //   data['data']['categories'].forEach((cate) {
  //     var result = {'category': cate['categoryGroupName'], 'filters': []};
  //     if (cate['usable'] == 1) {
  //       cate['items'].forEach((item) {
  //         result['filters'].add({
  //           'id': item['categoryId'],
  //           'name': htmlDecode(item['categoryName']),
  //         });
  //       });
  //       all.add(result);
  //     }
  //   });
  //   var recommendLimit = 8;
  //   var recommend = [
  //     {'id': '', 'name': '全部'},
  //     {'id': 'toplist', 'name': '排行榜'},
  //     ...all[1]['filters'].sublist(0, recommendLimit),
  //   ];
  //   return {'recommend': recommend, 'all': all};
  // }
  Future<Map<String, dynamic>> get_playlist_filters() async {
    var target_url =
        'https://c.y.qq.com/splcloud/fcgi-bin/fcg_get_diss_tag_conf.fcg' +
            '?picmid=1&rnd=${Random().nextDouble()}&g_tk=732560869' +
            '&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8' +
            '&notice=0&platform=yqq.json&needNewCode=0';
    return Future.value({
      "success": (fn) async {
        var response = await dio_get_with_cookie_and_csrf(target_url);
        var data = jsonDecode(response.data);
        var all = [];
        if (data['data'] == null || data['data']['categories'] == null) {
          fn({'recommend': [], 'all': []});
          return;
        }
        data['data']['categories'].forEach((cate) {
          var result = {'category': cate['categoryGroupName'], 'filters': []};
          if (cate['usable'] == 1) {
            cate['items'].forEach((item) {
              result['filters'].add({
                'id': item['categoryId'],
                'name': htmlDecode(item['categoryName']),
              });
            });
            all.add(result);
          }
        });
        var recommendLimit = 8;
        var recommend = [
          {'id': '', 'name': '全部'},
          {'id': 'toplist', 'name': '排行榜'},
          ...all[1]['filters'].sublist(0, recommendLimit),
        ];
        fn({'recommend': recommend, 'all': all});
      }
    });
  }
  // static get_user_by_uin(uin, callback) {
  //   const infoUrl = `https://u.y.qq.com/cgi-bin/musicu.fcg?format=json&&loginUin=${uin}&hostUin=0inCharset=utf8&outCharset=utf-8&platform=yqq.json&needNewCode=0&data=${encodeURIComponent(
  //     JSON.stringify({
  //       comm: { ct: 24, cv: 0 },
  //       vip: {
  //         module: 'userInfo.VipQueryServer',
  //         method: 'SRFVipQuery_V2',
  //         param: { uin_list: [uin] },
  //       },
  //       base: {
  //         module: 'userInfo.BaseUserInfoServer',
  //         method: 'get_user_baseinfo_v2',
  //         param: { vec_uin: [uin] },
  //       },
  //     })
  //   )}`;

  //   return axios.get(infoUrl).then((response) => {
  //     const { data } = response;
  //     const info = data.base.data.map_userinfo[uin];
  //     const result = {
  //       is_login: true,
  //       user_id: uin,
  //       user_name: uin,
  //       nickname: info.nick,
  //       avatar: info.headurl,
  //       platform: 'qq',
  //       data,
  //     };
  //     return callback({ status: 'success', data: result });
  //   });
  // }
  Future<Map<String, dynamic>> get_user_by_uin(String uin) async {
    try {
      var infoUrl =
          'https://u.y.qq.com/cgi-bin/musicu.fcg?format=json&&loginUin=${uin}&hostUin=0inCharset=utf8&outCharset=utf-8&platform=yqq.json&needNewCode=0&data=${Uri.encodeComponent(jsonEncode({
            'comm': {'ct': 24, 'cv': 0},
            'vip': {
              'module': 'userInfo.VipQueryServer',
              'method': 'SRFVipQuery_V2',
              'param': {
                'uin_list': [uin]
              },
            },
            'base': {
              'module': 'userInfo.BaseUserInfoServer',
              'method': 'get_user_baseinfo_v2',
              'param': {
                'vec_uin': [uin]
              },
            },
          }))}';
      var response = await dio_get_with_cookie_and_csrf(infoUrl);
      // var data = response.data;
      var data = jsonDecode(response.data);
      var info = data['base']['data']['map_userinfo'][uin];
      var result = {
        'is_login': true,
        'user_id': uin,
        'user_name': uin,
        'nickname': info['nick'],
        'avatar': info['headurl'],
        'platform': 'qq',
        'data': data,
      };
      // callback({'status': 'success', 'data': result});
      return {'status': 'success', 'data': result};
    } catch (e) {
      return {'status': 'fail', 'data': {}};
    }
  }

  // static get_user_created_playlist(url) {
  //   const user_id = getParameterByName('user_id', url);
  //   // TODO: load more than size
  //   const size = 100;

  //   const target_url = `https://c.y.qq.com/rsc/fcgi-bin/fcg_user_created_diss?cv=4747474&ct=24&format=json&inCharset=utf-8&outCharset=utf-8&notice=0&platform=yqq.json&needNewCode=1&uin=${user_id}&hostuin=${user_id}&sin=0&size=${size}`;

  //   return {
  //     success: (fn) => {
  //       axios.get(target_url).then((response) => {
  //         const playlists = [];
  //         response.data.data.disslist.forEach((item) => {
  //           let playlist = {};
  //           if (item.dir_show === 0) {
  //             if (item.tid === 0) {
  //               return;
  //             }
  //             if (item.diss_name === '我喜欢') {
  //               playlist = {
  //                 cover_img_url:
  //                   'https://y.gtimg.cn/mediastyle/y/img/cover_love_300.jpg',
  //                 id: `qqplaylist_${item.tid}`,
  //                 source_url: `https://y.qq.com/n/ryqq/playlist/${item.tid}`,
  //                 title: item.diss_name,
  //               };
  //               playlists.push(playlist);
  //             }
  //           } else {
  //             playlist = {
  //               cover_img_url: item.diss_cover,
  //               id: `qqplaylist_${item.tid}`,
  //               source_url: `https://y.qq.com/n/ryqq/playlist/${item.tid}`,
  //               title: item.diss_name,
  //             };
  //             playlists.push(playlist);
  //           }
  //         });
  //         return fn({
  //           status: 'success',
  //           data: {
  //             playlists,
  //           },
  //         });
  //       });
  //     },
  //   };
  // }
  // Future<Map<String, dynamic>> get_user_created_playlist(String url) async {
  //   var user_id = getParameterByName('user_id', url);
  //   var size = 100;
  //   var target_url =
  //       'https://c.y.qq.com/rsc/fcgi-bin/fcg_user_created_diss?cv=4747474&ct=24&format=json&inCharset=utf-8&outCharset=utf-8&notice=0&platform=yqq.json&needNewCode=1&uin=${user_id}&hostuin=${user_id}&sin=0&size=${size}';
  //   var response = await dio_get_with_cookie_and_csrf(target_url);
  //   var playlists = [];
  //   jsonDecode(response.data)['data']['disslist'].forEach((item) {
  //     var playlist = {};
  //     if (item['dir_show'] == 0) {
  //       if (item['tid'] == 0) {
  //         return;
  //       }
  //       if (item['diss_name'] == '我喜欢') {
  //         playlist = {
  //           'cover_img_url':
  //               'https://y.gtimg.cn/mediastyle/y/img/cover_love_300.jpg',
  //           'id': 'qqplaylist_${item['tid']}',
  //           'source_url': 'https://y.qq.com/n/ryqq/playlist/${item['tid']}',
  //           'title': item['diss_name'],
  //         };
  //         playlists.add(playlist);
  //       }
  //     } else {
  //       playlist = {
  //         'cover_img_url': item['diss_cover'],
  //         'id': 'qqplaylist_${item['tid']}',
  //         'source_url': 'https://y.qq.com/n/ryqq/playlist/${item['tid']}',
  //         'title': item['diss_name'],
  //       };
  //       playlists.add(playlist);
  //     }
  //   });
  //   return {
  //     'status': 'success',
  //     'data': {
  //       'playlists': playlists,
  //     },
  //   };
  // }
  Future<Map<String, dynamic>> get_user_created_playlist(String url) async {
    var user_id = getParameterByName('user_id', url);
    var size = 100;
    var target_url =
        'https://c.y.qq.com/rsc/fcgi-bin/fcg_user_created_diss?cv=4747474&ct=24&format=json&inCharset=utf-8&outCharset=utf-8&notice=0&platform=yqq.json&needNewCode=1&uin=${user_id}&hostuin=${user_id}&sin=0&size=${size}';
    return {
      "success": (fn) async {
        try {
          var response = await dio_get_with_cookie_and_csrf(target_url);
          var playlists = [];
          jsonDecode(response.data)['data']['disslist'].forEach((item) {
            var playlist = {};
            if (item['dir_show'] == 0) {
              if (item['tid'] == 0) {
                return;
              }
              if (item['diss_name'] == '我喜欢') {
                playlist = {
                  'cover_img_url':
                      'https://y.gtimg.cn/mediastyle/y/img/cover_love_300.jpg',
                  'id': 'qqplaylist_${item['tid']}',
                  'source_url':
                      'https://y.qq.com/n/ryqq/playlist/${item['tid']}',
                  'title': item['diss_name'],
                };
                playlists.add(playlist);
              }
            } else {
              playlist = {
                'cover_img_url': item['diss_cover'],
                'id': 'qqplaylist_${item['tid']}',
                'source_url': 'https://y.qq.com/n/ryqq/playlist/${item['tid']}',
                'title': item['diss_name'],
              };
              playlists.add(playlist);
            }
          });
          return fn({
            'status': 'success',
            'data': {
              'playlists': playlists,
            },
          });
        } catch (e) {
          return fn({
            'status': 'success',
            'data': {
              'playlists': [],
            },
          });
        }
      }
    };
  }

  // static get_user_favorite_playlist(url) {
  //   const user_id = getParameterByName('user_id', url);
  //   // TODO: load more than size
  //   const size = 100;
  //   // https://github.com/jsososo/QQMusicApi/blob/master/routes/user.js
  //   const target_url = `https://c.y.qq.com/fav/fcgi-bin/fcg_get_profile_order_asset.fcg`;
  //   const data = {
  //     ct: 20,
  //     cid: 205360956,
  //     userid: user_id,
  //     reqtype: 3,
  //     sin: 0,
  //     ein: size,
  //   };
  //   return {
  //     success: (fn) => {
  //       axios.get(target_url, { params: data }).then((response) => {
  //         const playlists = [];
  //         response.data.data.cdlist.forEach((item) => {
  //           let playlist = {};
  //           if (item.dir_show === 0) {
  //             return;
  //           }
  //           playlist = {
  //             cover_img_url: item.logo,
  //             id: `qqplaylist_${item.dissid}`,
  //             source_url: `https://y.qq.com/n/ryqq/playlist/${item.dissid}`,
  //             title: item.dissname,
  //           };
  //           playlists.push(playlist);
  //         });
  //         return fn({
  //           status: 'success',
  //           data: {
  //             playlists,
  //           },
  //         });
  //       });
  //     },
  //   };
  // }
  // Future<Map<String, dynamic>> get_user_favorite_playlist(String url) async {
  //   try {
  //     var user_id = getParameterByName('user_id', url);
  //     var size = 100;
  //     var target_url =
  //         'https://c.y.qq.com/fav/fcgi-bin/fcg_get_profile_order_asset.fcg';
  //     var data = {
  //       'ct': 20,
  //       'cid': 205360956,
  //       'userid': user_id,
  //       'reqtype': 3,
  //       'sin': 0,
  //       'ein': size,
  //     };
  //     // var response = await dio_get_with_cookie_and_csrf(target_url, queryParameters: data);
  //     target_url +=
  //         '?' + data.entries.map((e) => '${e.key}=${e.value}').join('&');
  //     var response = await dio_get_with_cookie_and_csrf(target_url);
  //     var playlists = [];
  //     response.data['data']['cdlist'].forEach((item) {
  //       var playlist = {};
  //       if (item['dir_show'] == 0) {
  //         return;
  //       }
  //       playlist = {
  //         'cover_img_url': item['logo'],
  //         'id': 'qqplaylist_${item['dissid']}',
  //         'source_url': 'https://y.qq.com/n/ryqq/playlist/${item['dissid']}',
  //         'title': item['dissname'],
  //       };
  //       playlists.add(playlist);
  //     });
  //     return {
  //       'status': 'success',
  //       'data': {
  //         'playlists': playlists,
  //       },
  //     };
  //   } catch (e) {
  //     return {'status': 'fail', 'data': {}};
  //   }
  // }
  Future<Map<String, dynamic>> get_user_favorite_playlist(String url) async {
    var user_id = getParameterByName('user_id', url);
    var size = 100;
    var target_url =
        'https://c.y.qq.com/fav/fcgi-bin/fcg_get_profile_order_asset.fcg';
    var data = {
      'ct': 20,
      'cid': 205360956,
      'userid': user_id,
      'reqtype': 3,
      'sin': 0,
      'ein': size,
    };
    return {
      "success": (fn) async {
        try {
          target_url +=
              '?' + data.entries.map((e) => '${e.key}=${e.value}').join('&');
          var response = await dio_get_with_cookie_and_csrf(target_url);
          var playlists = [];
          response.data['data']['cdlist'].forEach((item) {
            var playlist = {};
            if (item['dir_show'] == 0) {
              return;
            }
            playlist = {
              'cover_img_url': item['logo'],
              'id': 'qqplaylist_${item['dissid']}',
              'source_url':
                  'https://y.qq.com/n/ryqq/playlist/${item['dissid']}',
              'title': item['dissname'],
            };
            playlists.add(playlist);
          });
          return fn({
            'status': 'success',
            'data': {
              'playlists': playlists,
            },
          });
        } catch (e) {
          return fn({'status': 'fail', 'data': {}});
        }
      }
    };
  }
  //  static get_recommend_playlist() {
  //   const target_url = `https://u.y.qq.com/cgi-bin/musicu.fcg?format=json&&loginUin=0&hostUin=0inCharset=utf8&outCharset=utf-8&platform=yqq.json&needNewCode=0&data=${encodeURIComponent(
  //     JSON.stringify({
  //       comm: {
  //         ct: 24,
  //       },
  //       recomPlaylist: {
  //         method: 'get_hot_recommend',
  //         param: {
  //           async: 1,
  //           cmd: 2,
  //         },
  //         module: 'playlist.HotRecommendServer',
  //       },
  //     })
  //   )}`;

  //   return {
  //     success: (fn) => {
  //       axios.get(target_url).then((response) => {
  //         const playlists = [];
  //         response.data.recomPlaylist.data.v_hot.forEach((item) => {
  //           const playlist = {
  //             cover_img_url: item.cover,
  //             id: `qqplaylist_${item.content_id}`,
  //             source_url: `https://y.qq.com/n/ryqq/playlist/${item.content_id}`,
  //             title: item.title,
  //           };
  //           playlists.push(playlist);
  //         });
  //         return fn({
  //           status: 'success',
  //           data: {
  //             playlists,
  //           },
  //         });
  //       });
  //     },
  //   };
  // }
  // Future<Map<String, dynamic>> get_recommend_playlist() async {
  //   var target_url =
  //       'https://u.y.qq.com/cgi-bin/musicu.fcg?format=json&&loginUin=0&hostUin=0inCharset=utf8&outCharset=utf-8&platform=yqq.json&needNewCode=0&data=${Uri.encodeComponent(jsonEncode({
  //         'comm': {
  //           'ct': 24,
  //         },
  //         'recomPlaylist': {
  //           'method': 'get_hot_recommend',
  //           'param': {
  //             'async': 1,
  //             'cmd': 2,
  //           },
  //           'module': 'playlist.HotRecommendServer',
  //         },
  //       }))}';
  //   var response = await dio_get_with_cookie_and_csrf(target_url);
  //   var playlists = [];
  //   response.data['recomPlaylist']['data']['v_hot'].forEach((item) {
  //     var playlist = {
  //       'cover_img_url': item['cover'],
  //       'id': 'qqplaylist_${item['content_id']}',
  //       'source_url': 'https://y.qq.com/n/ryqq/playlist/${item['content_id']}',
  //       'title': item['title'],
  //     };
  //     playlists.add(playlist);
  //   });
  //   return {
  //     'status': 'success',
  //     'data': {
  //       'playlists': playlists,
  //     },
  //   };
  // }
  Future<Map<String, dynamic>> get_recommend_playlist() async {
    var target_url =
        'https://u.y.qq.com/cgi-bin/musicu.fcg?format=json&&loginUin=0&hostUin=0inCharset=utf8&outCharset=utf-8&platform=yqq.json&needNewCode=0&data=${Uri.encodeComponent(jsonEncode({
          'comm': {
            'ct': 24,
          },
          'recomPlaylist': {
            'method': 'get_hot_recommend',
            'param': {
              'async': 1,
              'cmd': 2,
            },
            'module': 'playlist.HotRecommendServer',
          },
        }))}';
    return {
      "success": (fn) async {
        var response = await dio_get_with_cookie_and_csrf(target_url);
        var playlists = [];
        response.data['recomPlaylist']['data']['v_hot'].forEach((item) {
          var playlist = {
            'cover_img_url': item['cover'],
            'id': 'qqplaylist_${item['content_id']}',
            'source_url':
                'https://y.qq.com/n/ryqq/playlist/${item['content_id']}',
            'title': item['title'],
          };
          playlists.add(playlist);
        });
        return fn({
          'status': 'success',
          'data': {
            'playlists': playlists,
          },
        });
      }
    };
  }

  // static get_user() {
  //   return {
  //     success: (fn) => {
  //       const domain = 'https://y.qq.com';
  //       cookieGet(
  //         {
  //           url: domain,
  //           name: 'uin',
  //         },
  //         (qqCookie) => {
  //           if (qqCookie === null) {
  //             return cookieGet(
  //               {
  //                 url: domain,
  //                 name: 'wxuin',
  //               },
  //               (wxCookie) => {
  //                 if (wxCookie == null) {
  //                   return fn({ status: 'fail', data: {} });
  //                 }
  //                 let { value: uin } = wxCookie;
  //                 uin = `1${uin.slice('o'.length)}`; // replace prefix o with 1
  //                 return this.get_user_by_uin(uin, fn);
  //               }
  //             );
  //           }
  //           const { value: uin } = qqCookie;
  //           return this.get_user_by_uin(uin, fn);
  //         }
  //       );
  //     },
  //   };
  // }
  Future<Map<String, dynamic>> get_user() async {
    final settings = settings_getsettings();
    if (settings['qq'] == null) {
      return {'status': 'fail', 'data': {}};
    }
    for (var cookie in settings['qq'].split(';')) {
      var cookieParts = cookie.split('=');
      if (cookieParts[0] == 'uin') {
        return get_user_by_uin(cookieParts[1]);
      }
      if (cookieParts[0] == 'wxuin') {
        var uin = '1${cookieParts[1].substring('o'.length)}';
        return get_user_by_uin(uin);
      }
    }
    return {'status': 'fail', 'data': {}};
  }
}
