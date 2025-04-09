import 'package:dio/dio.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:listen1_xuan/loweb.dart';
import 'package:listen1_xuan/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' show parse;
import 'lowebutil.dart';
import 'package:marquee/marquee.dart';
import 'main.dart';

final bilibili = Bilibili();

class Bilibili {
  Future<List<Map<String, dynamic>>> Xuan_get_bl_playlist() async {
    bool b1 = false;
    var bilibiliData = {};
    var bilibiliData2 = [];
    b1 = false;
    String url = 'https://api.bilibili.com/x/v3/fav/folder/list4navigate';
    final settings = await settings_getsettings();
    final cookie = settings['bl'];

    var headers = {
      'content-type': 'application/json',
      'cookie': cookie,
    };
    final dio = dio_with_cookie_manager;
    try {
      print(headers);
      final response = await dio_with_cookie_manager.get(url,
          options: Options(headers: headers));
      print(response.statusCode);
      print(response.data);
      bilibiliData = response.data;
      url = 'https://api.bilibili.com/x/v3/fav/folder/collected/list';
      String upMid = cookie.split('DedeUserID=')[1].split(';')[0];
      String turl = url + '?pn=1&ps=20&up_mid=' + upMid + '&platform=web';
      var response2 = await dio_with_cookie_manager.get(turl,
          options: Options(headers: headers));
      var res2 = response2.data;
      bilibiliData2.clear();
      res2['data']['list'].forEach((element) {
        bilibiliData2.add(element);
      });
      if (res2['data']['has_more']) {
        var pn = 2;
        do {
          turl = url + '?pn=$pn&ps=20&up_mid=' + upMid + '&platform=web';
          response2 = await dio.get(turl, options: Options(headers: headers));
          res2 = response2.data;
          res2['data']['list'].forEach((element) {
            bilibiliData2.add(element);
          });
          pn++;
        } while (res2['data']['has_more']);
      }
      var retdata = [];
      bilibiliData["data"].forEach((item) {
        if (item["mediaListResponse"]["list"] != null)
          item["mediaListResponse"]["list"].forEach((element) {
            retdata.add({
              'info': {
                'cover_img_url': element['cover'],
                'title': element['title'],
                'id': 'biplaylistxuan_my${element['id']}',
                'source_url':
                    'https://api.bilibili.com/x/v3/fav/resource/list?ps=20&keyword&order=mtime&type=0&tid=0&platform=web&pn=1&media_id=${element['id']}',
              },
            });
          });
      });
      for (var i = 0; i < bilibiliData2.length; i++) {
        var item = bilibiliData2[i];
        retdata.add({
          'info': {
            'cover_img_url': item['cover'],
            'title': item['title'],
            'id': 'biplaylistxuan_${item['id']}',
            'source_url':
                'https://api.bilibili.com/x/space/fav/season/list?pn=1&ps=20&season_id=${item['mid']}',
          },
        });
      }
      return retdata.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      print('请求失败: ${e.message}');
      if (e.response != null) {
        print('响应数据: ${e.response?.data}');
        print('响应头: ${e.response?.headers}');
        print('请求信息: ${e.response?.requestOptions}');
      } else {
        print('请求未发送: ${e.requestOptions}');
        print('错误信息: ${e.message}');
      }
      return [];
    } catch (e) {
      print('未知错误: $e');
      Fluttertoast.showToast(msg: '未知错误: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> biGetPlaylistxuan(String url) async {
    final selectmid = getParameterByName('list_id', url)?.split('_').last;
    if (selectmid == null) {
      return {'info': {}, 'tracks': []};
    }
    try {
      if (selectmid.substring(0, 2) == 'my') {
        final settings = await settings_getsettings();
        final cookie = settings['bl'];
        var url = '';
        url =
            'https://api.bilibili.com/x/v3/fav/resource/list?ps=20&keyword&order=mtime&type=0&tid=0&platform=web&';
        var turl = '${url}pn=1&media_id=${selectmid.substring(2)}';
        final headers = {
          'content-type': 'application/json',
          'cookie': cookie,
        };
        var medias = [];
        var response = await dio_with_cookie_manager.get(turl,
            options: Options(headers: headers));
        var res = response.data;
        final data = response.data['data'];
        final info = {
          'cover_img_url': data['info']['cover'],
          'title': data['info']['title'],
          'id': 'biplaylistxuan_$selectmid',
          'source_url':
              'https://api.bilibili.com/x/v3/fav/resource/list?ps=20&keyword&order=mtime&type=0&tid=0&platform=web&pn=1&media_id=${selectmid.substring(2)}',
        };
        res["data"]['medias'].forEach((element) {
          medias.add(element);
        });
        if (res["data"]['has_more']) {
          var pn = 2;
          do {
            turl = '${url}pn=$pn&media_id=${selectmid.substring(2)}';
            response = await dio_with_cookie_manager.get(turl,
                options: Options(headers: headers));
            res = response.data;
            res["data"]['medias'].forEach((element) {
              medias.add(element);
            });
            pn++;
          } while (res["data"]['has_more']);
        }
        final tracks = medias.map((item) {
          return biConvertSongxuan(item);
        }).toList();

        return {'info': info, 'tracks': tracks};
      } else {
        final settings = await settings_getsettings();
        final cookie = settings['bl'];
        var url = '';
        url =
            'https://api.bilibili.com/x/space/fav/season/list?pn=1&ps=20&season_id=';
        var turl = url + selectmid.toString();
        final headers = {
          'content-type': 'application/json',
          'cookie': cookie,
        };
        var medias = [];
        var response = await dio_with_cookie_manager.get(turl,
            options: Options(headers: headers));
        var res = response.data;
        final data = response.data['data'];
        final info = {
          'cover_img_url': data['info']['cover'],
          'title': data['info']['title'],
          'id': 'biplaylistxuan_$selectmid',
          'source_url':
              'https://api.bilibili.com/x/space/fav/season/list?pn=1&ps=20&season_id=${selectmid}',
        };
        res["data"]['medias'].forEach((element) {
          medias.add(element);
        });

        final tracks = medias.map((item) {
          return biConvertSongxuan(item);
        }).toList();

        // return {'info': {}, 'tracks': []};
        return {'info': info, 'tracks': tracks};
      }
    } catch (e) {
      print(e);
      return {'info': {}, 'tracks': []};
    }
  }

  Future<Map<String, dynamic>> _getsettings() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('settings');
    print("jsonString: $jsonString");
    if (jsonString == null) {
      return {};
    }
    return jsonDecode(jsonString);
  }

  Future<String> check_bl_cookie() async {
    try {
      String cookie = '';
      Map<String, dynamic> settings = await _getsettings();
      if (settings.containsKey('bl') && settings['bl'] != '') {
        cookie = settings['bl'];
      } else {
        return '';
      }
      Response response = await dio_with_cookie_manager.get(
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
        return response.data['data']['uname'];
      }
    } catch (e) {
      print(e);
    }
    return '';
  }

// static show_playlist(url) {
//     let offset = getParameterByName('offset', url);
//     if (offset === undefined) {
//       offset = 0;
//     }
//     const page = offset / 20 + 1;
//     const target_url = `https://www.bilibili.com/audio/music-service-c/web/menu/hit?ps=20&pn=${page}`;
//     return {
//       success: (fn) => {
//         axios.get(target_url).then((response) => {
//           const { data } = response.data.data;
//           const result = data.map((item) => ({
//             cover_img_url: item.cover,
//             title: item.title,
//             id: `biplaylist_${item.menuId}`,
//             source_url: `https://www.bilibili.com/audio/am${item.menuId}`,
//           }));
//           return fn({
//             result,
//           });
//         });
//       },
//     };
//   }
  static Map<String, String>? wbiKey;

  static String htmlDecode(String value) {
    var document = parse(value);
    return document.body?.text ?? '';
  }

  static Future<Map<String, String>> fetch_wbi_key() async {
    final response = await dio_with_cookie_manager
        .get('https://api.bilibili.com/x/web-interface/nav');
    final jsonContent = response.data;
    final imgUrl = jsonContent['data']['wbi_img']['img_url'];
    final subUrl = jsonContent['data']['wbi_img']['sub_url'];
    return {
      'img_key': imgUrl.substring(
          imgUrl.lastIndexOf('/') + 1, imgUrl.lastIndexOf('.')),
      'sub_key': subUrl.substring(
          subUrl.lastIndexOf('/') + 1, subUrl.lastIndexOf('.')),
    };
  }

  static void clearWbiKey() {
    wbiKey = null;
  }

  static Future<Map<String, String>> getWbiKey() async {
    if (wbiKey != null) {
      return Future.value(wbiKey);
    }
    final key = await fetch_wbi_key();
    wbiKey = key;
    return key;
  }

  static Future<String> encWbi(Map<String, dynamic> params) async {
    final key = await getWbiKey();
    final imgKey = key['img_key']!;
    final subKey = key['sub_key']!;
    final mixinKeyEncTab = [
      46,
      47,
      18,
      2,
      53,
      8,
      23,
      32,
      15,
      50,
      10,
      31,
      58,
      3,
      45,
      35,
      27,
      43,
      5,
      49,
      33,
      9,
      42,
      19,
      29,
      28,
      14,
      39,
      12,
      38,
      41,
      13,
      37,
      48,
      7,
      16,
      24,
      55,
      40,
      61,
      26,
      17,
      0,
      1,
      60,
      51,
      30,
      4,
      22,
      25,
      54,
      21,
      56,
      59,
      6,
      63,
      57,
      62,
      11,
      36,
      20,
      34,
      44,
      52,
    ];

    String getMixinKey(String original) {
      String temp = '';
      for (var n in mixinKeyEncTab) {
        temp += original[n];
      }
      return temp.substring(0, 32);
    }

    final mixinKey = getMixinKey(imgKey + subKey);
    final currTime = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    final chrFilter = RegExp(r"[!'()*]");
    final query = [];
    params['wts'] = currTime; // 添加 wts 字段
    final sortedKeys = params.keys.toList()..sort();
    for (var key in sortedKeys) {
      query.add(
          '${Uri.encodeComponent(key)}=${Uri.encodeComponent(params[key].toString().replaceAll(chrFilter, ''))}');
    }
    final queryString = query.join('&');
    final wbiSign = md5.convert(utf8.encode(queryString + mixinKey)).toString();
    return '$queryString&w_rid=$wbiSign';
  }

  static Future<Response> wrap_wbi_request(
      String url, Map<String, dynamic> params) async {
    try {
      final queryString = await encWbi(params);
      final targetUrl = '$url?$queryString';
      return await dio_with_cookie_manager.get(targetUrl);
      // return await dio_get_with_cookie_and_csrf(targetUrl);
    } catch (e) {
      clearWbiKey();
      try {
        final queryString = await encWbi(params);
        final targetUrl = '$url?$queryString';
        return await dio_with_cookie_manager.get(targetUrl);
      } catch (e) {
        return Future.error('Request failed');
      }
    }
  }

  static Map<String, dynamic> bi_convert_song(Map<String, dynamic> songInfo) {
    return {
      'id': 'bitrack_${songInfo['id']}',
      'title': songInfo['title'],
      'artist': songInfo['uname'],
      'artist_id': 'biartist_${songInfo['uid']}',
      'source': 'bilibili',
      'source_url': 'https://www.bilibili.com/audio/au${songInfo['id']}',
      'img_url': songInfo['cover'],
      'lyric_url': songInfo['lyric'],
    };
  }

  static Map<String, dynamic> bi_convert_song2(Map<String, dynamic> songInfo) {
    String imgUrl = songInfo['pic'];
    if (imgUrl.startsWith('//')) {
      imgUrl = 'https:$imgUrl';
    }
    return {
      'id': 'bitrack_v_${songInfo['bvid']}',
      'title': htmlDecode(songInfo['title']),
      'artist': htmlDecode(songInfo['author']),
      'artist_id': 'biartist_v_${songInfo['mid']}',
      'source': 'bilibili',
      'source_url': 'https://www.bilibili.com/${songInfo['bvid']}',
      'img_url': imgUrl,
    };
  }

  static Map<String, dynamic> biConvertSongxuan(Map<String, dynamic> songInfo) {
    return {
      'id': 'bitrack_v_${songInfo['bvid']}',
      'title': htmlDecode(songInfo['title']),
      'artist': htmlDecode(songInfo['upper']['name']),
      'artist_id': 'biartist_v_${songInfo['upper']['mid']}',
      'source': 'bilibili',
      'source_url': 'https://www.bilibili.com/${songInfo['bvid']}',
      'img_url': songInfo['cover'],
    };
  }

// static show_playlist(url) {
//     let offset = getParameterByName('offset', url);
//     if (offset === undefined) {
//       offset = 0;
//     }
//     const page = offset / 20 + 1;
//     const target_url = `https://www.bilibili.com/audio/music-service-c/web/menu/hit?ps=20&pn=${page}`;
//     return {
//       success: (fn) => {
//         axios.get(target_url).then((response) => {
//           const { data } = response.data.data;
//           const result = data.map((item) => ({
//             cover_img_url: item.cover,
//             title: item.title,
//             id: `biplaylist_${item.menuId}`,
//             source_url: `https://www.bilibili.com/audio/am${item.menuId}`,
//           }));
//           return fn({
//             result,
//           });
//         });
//       },
//     };
//   }
  Future<Map<String, dynamic>> show_playlist(String url) async {
    int offset = int.parse(getParameterByName('offset', url) ?? '0');
    int page = (offset / 20).ceil() + 1;
    String targetUrl =
        'https://www.bilibili.com/audio/music-service-c/web/menu/hit?ps=20&pn=$page';

    return {
      'success': (Function fn) {
        dio_with_cookie_manager.get(targetUrl).then((response) {
          final data = response.data['data']["data"] as List;
          final result = data.map((item) {
            return {
              'cover_img_url': item['cover'],
              'title': item['title'],
              'id': 'biplaylist_${item['menuId']}',
              'source_url':
                  'https://www.bilibili.com/audio/am${item['menuId']}',
            };
          }).toList();
          fn(result);
        });
      },
    };
  }

  // static bi_get_playlist(url) {
  //   const list_id = getParameterByName('list_id', url).split('_').pop();
  //   const target_url = `https://www.bilibili.com/audio/music-service-c/web/menu/info?sid=${list_id}`;
  //   return {
  //     success: (fn) => {
  //       axios.get(target_url).then((response) => {
  //         const { data } = response.data;
  //         const info = {
  //           cover_img_url: data.cover,
  //           title: data.title,
  //           id: `biplaylist_${list_id}`,
  //           source_url: `https://www.bilibili.com/audio/am${list_id}`,
  //         };
  //         const target = `https://www.bilibili.com/audio/music-service-c/web/song/of-menu?pn=1&ps=100&sid=${list_id}`;
  //         axios.get(target).then((res) => {
  //           const tracks = res.data.data.data.map((item) =>
  //             this.bi_convert_song(item)
  //           );
  //           return fn({
  //             info,
  //             tracks,
  //           });
  //         });
  //       });
  //     },
  //   };
  // }

  static Future<Map<String, dynamic>> bi_get_playlist(String url) async {
    final listId = getParameterByName('list_id', url)?.split('_').last;
    final targetUrl =
        'https://www.bilibili.com/audio/music-service-c/web/menu/info?sid=$listId';

    return {
      'success': (Function fn) {
        dio_with_cookie_manager.get(targetUrl).then((response) async {
          final data = response.data['data'];
          final info = {
            'cover_img_url': data['cover'],
            'title': data['title'],
            'id': 'biplaylist_$listId',
            'source_url': 'https://www.bilibili.com/audio/am$listId',
          };
          final target =
              'https://www.bilibili.com/audio/music-service-c/web/song/of-menu?pn=1&ps=100&sid=$listId';
          final res = await dio_with_cookie_manager.get(target);
          final tracks = res.data['data']['data'].map((item) {
            return bi_convert_song(item);
          }).toList();
          fn({'info': info, 'tracks': tracks});
        });
      },
    };
  }

//  static bi_album(url) {
//     return {
//       success: (fn) =>
//         fn({
//           tracks: [],
//           info: {},
//         }),
//       // bilibili havn't album
//       // const album_id = getParameterByName('list_id', url).split('_').pop();
//       // const target_url = '';
//       // axios.get(target_url).then((response) => {
//       //   const data = response.data;
//       //   const info = {};
//       //   const tracks = [];
//       //   return fn({
//       //     tracks,
//       //     info,
//       //   });
//       // });
//     };
//   }
  Future<Map<String, dynamic>> bi_album(String url) async {
    return {
      'success': (Function fn) => fn({
            'tracks': [],
            'info': {},
          }),
    };
  }

// static bi_track(url) {
//     const track_id = getParameterByName('list_id', url).split('_').pop();
//     return {
//       success: (fn) => {
//         const target_url = `https://api.bilibili.com/x/web-interface/view?bvid=${track_id}`;
//         axios.get(target_url).then((response) => {
//           const info = {
//             cover_img_url: response.data.data.pic,
//             title: response.data.data.title,
//             id: `bitrack_v_${track_id}`,
//             source_url: `https://www.bilibili.com/${track_id}`,
//           };
//           const author = response.data.data.owner;
//           const default_img = response.data.data.pic;
//           const tracks = response.data.data.pages.map((item) =>
//             this.bi_convert_song3(item, track_id, author, default_img)
//           );
//           return fn({
//             tracks,
//             info,
//           });
//         });
//       },
//     };
//   }
  static Future<Map<String, dynamic>> bi_track(String url) async {
    final trackId = getParameterByName('list_id', url)?.split('_').last;
    final targetUrl =
        'https://api.bilibili.com/x/web-interface/view?bvid=$trackId';

    return {
      'success': (Function fn) {
        dio_with_cookie_manager.get(targetUrl).then((response) {
          final info = {
            'cover_img_url': response.data['data']['pic'],
            'title': response.data['data']['title'],
            'id': 'bitrack_v_$trackId',
            'source_url': 'https://www.bilibili.com/$trackId',
          };
          final author = response.data['data']['owner'];
          final defaultImg = response.data['data']['pic'];
          final tracks = response.data['data']['pages'].map((item) {
            return bi_convert_song3(item, trackId!, author, defaultImg);
          }).toList();
          fn({'tracks': tracks, 'info': info});
        });
      },
    };
  }

  static Map<String, dynamic> bi_convert_song3(Map<String, dynamic> songInfo,
      String bvid, Map<String, dynamic> author, String defaultImg) {
    String imgUrl = songInfo['first_frame'] ?? defaultImg;
    if (imgUrl.startsWith('//')) {
      imgUrl = 'https:$imgUrl';
    }
    return {
      'id': 'bitrack_v_${bvid}-${songInfo['cid']}',
      'title': htmlDecode(songInfo['part']),
      'artist': htmlDecode(author['name']),
      'artist_id': 'biartist_v_${author['mid']}',
      'source': 'bilibili',
      'source_url': 'https://www.bilibili.com/$bvid/?p=${songInfo['page']}',
      'img_url': imgUrl,
    };
  }
// static bi_artist(url) {
//     const artist_id = getParameterByName('list_id', url).split('_').pop();

//     return {
//       success: (fn) => {
//         let target_url;
//         bilibili
//           .wrap_wbi_request('https://api.bilibili.com/x/space/wbi/acc/info', {
//             mid: artist_id,
//           })
//           .then((response) => {
//             const info = {
//               cover_img_url: response.data.data.face,
//               title: response.data.data.name,
//               id: `biartist_${artist_id}`,
//               source_url: `https://space.bilibili.com/${artist_id}/#/audio`,
//             };
//             if (getParameterByName('list_id', url).split('_').length === 3) {
//               return bilibili
//                 .wrap_wbi_request(
//                   'https://api.bilibili.com/x/space/wbi/arc/search',
//                   {
//                     mid: artist_id,
//                     pn: 1,
//                     ps: 25,
//                     order: 'click',
//                     index: 1,
//                   }
//                 )
//                 .then((res) => {
//                   const tracks = res.data.data.list.vlist.map((item) =>
//                     this.bi_convert_song2(item)
//                   );
//                   return fn({
//                     tracks,
//                     info,
//                   });
//                 });
//             }
//             target_url = `https://api.bilibili.com/audio/music-service-c/web/song/upper?pn=1&ps=0&order=2&uid=${artist_id}`;
//             return axios.get(target_url).then((res) => {
//               const tracks = res.data.data.data.map((item) =>
//                 this.bi_convert_song(item)
//               );
//               return fn({
//                 tracks,
//                 info,
//               });
//             });
//           });
//       },
//     };
//   }
  static Future<Map<String, dynamic>> bi_artist(String url) async {
    final artistId = getParameterByName('list_id', url)?.split('_').last;
    return {
      'success': (Function fn) async {
        String targetUrl;
        final response = await wrap_wbi_request(
            'https://api.bilibili.com/x/space/wbi/acc/info', {'mid': artistId});
        final info = {
          'cover_img_url': response.data['data']['face'],
          'title': response.data['data']['name'],
          'id': 'biartist_$artistId',
          'source_url': 'https://space.bilibili.com/$artistId/#/audio',
        };
        if (getParameterByName('list_id', url)?.split('_').length == 3) {
          final res = await wrap_wbi_request(
              'https://api.bilibili.com/x/space/wbi/arc/search', {
            'mid': artistId,
            'pn': 1,
            'ps': 25,
            'order': 'click',
            'index': 1
          });
          final tracks = res.data['data']['list']['vlist'].map((item) {
            return bi_convert_song2(item);
          }).toList();
          fn({'tracks': tracks, 'info': info});
        } else {
          targetUrl =
              'https://api.bilibili.com/audio/music-service-c/web/song/upper?pn=1&ps=0&order=2&uid=$artistId';
          final res = await dio_with_cookie_manager.get(targetUrl);
          final tracks = res.data['data']['data'].map((item) {
            return bi_convert_song(item);
          }).toList();
          fn({'tracks': tracks, 'info': info});
        }
      }
    };
  }

  static Future<Map<String, dynamic>> parse_url(String url) async {
    final regex = RegExp(r'\/\/www.bilibili.com\/audio\/am([0-9]+)');
    final match = regex.firstMatch(url);
    Map<String, dynamic>? result;
    if (match != null) {
      final playlistId = match.group(1);
      result = {
        'type': 'playlist',
        'id': 'biplaylist_$playlistId',
      };
    }
    return result ?? {};
  }

  Future<void> bootstrap_track(
      Map<String, dynamic> track, Function success, Function failure) async {
    final trackId = track['id'];
    if (trackId.startsWith('bitrack_v_')) {
      final sound = {};
      var bvid = trackId.substring('bitrack_v_'.length);

      final trackIdCheck = trackId.split('-');
      if (trackIdCheck.length > 1) {
        bvid = trackIdCheck[0].substring('bitrack_v_'.length);
      }
      final targetUrl =
          'https://api.bilibili.com/x/web-interface/view?bvid=$bvid';
      try {
        final response = await dio_with_cookie_manager.get(targetUrl);
        var cid = response.data['data']['pages'][0]['cid'];
        if (trackIdCheck.length > 1) {
          cid = trackIdCheck[1];
        }
        final targetUrl2 =
            'https://api.bilibili.com/x/player/playurl?fnval=16&bvid=$bvid&cid=$cid';
        final response2 = await dio_with_cookie_manager.get(targetUrl2);
        try {
          final audioList = response2.data['data']['dash']['audio'];
          if (audioList.isNotEmpty) {
            // 找到最大的 id 对应的元素
            final maxAudio =
                audioList.reduce((a, b) => a['id'] > b['id'] ? a : b);
            final url = maxAudio['baseUrl'];
            sound['url'] = url;
            sound['platform'] = 'bilibili';
            success(sound, track);
          } else {
            failure(track);
          }
        } catch (e) {
          if (response2.data['data']['durl'].length > 0) {
            final url = response2.data['data']['durl'][0]['url'];
            sound['url'] = url;
            sound['platform'] = 'bilibili';
            success(sound, track);
          } else {
            failure(track);
          }
        }
      } catch (e) {
        failure(track);
      }
    } else {
      final sound = {};
      final songId = trackId.substring('bitrack_'.length);
      final targetUrl =
          'https://www.bilibili.com/audio/music-service-c/web/url?sid=$songId';
      try {
        final response = await dio_with_cookie_manager.get(targetUrl);
        final data = response.data;
        if (data['code'] == 0) {
          sound['url'] = data['data']['cdns'][0];
          sound['platform'] = 'bilibili';
          success(sound, track);
        } else {
          failure(track);
        }
      } catch (e) {
        failure(track);
      }
    }
  }
// static search(url) {
//     return {
//       success: (fn) => {
//         const keyword = getParameterByName('keywords', url);
//         const curpage = getParameterByName('curpage', url);

//         const target_url = `https://api.bilibili.com/x/web-interface/search/type?__refresh__=true&_extra=&context=&page=${curpage}&page_size=42&platform=pc&highlight=1&single_column=0&keyword=${encodeURIComponent(
//           keyword
//         )}&category_id=&search_type=video&dynamic_offset=0&preload=true&com2co=true`;

//         const domain = `https://api.bilibili.com`;
//         const cookieName = 'buvid3';
//         const expire =
//           (new Date().getTime() + 1e3 * 60 * 60 * 24 * 365 * 100) / 1000;
//         cookieGet(
//           {
//             url: domain,
//             name: cookieName,
//           },
//           (cookie) => {
//             if (cookie == null) {
//               cookieSet(
//                 {
//                   url: domain,
//                   name: cookieName,
//                   value: '0',
//                   expirationDate: expire,
//                 },
//                 () => {
//                   axios.get(target_url).then((response) => {
//                     const result = response.data.data.result.map((song) =>
//                       this.bi_convert_song2(song)
//                     );
//                     const total = response.data.data.numResults;
//                     return fn({
//                       result,
//                       total,
//                     });
//                   });
//                 }
//               );
//             } else {
//               axios.get(target_url).then((response) => {
//                 const result = response.data.data.result.map((song) =>
//                   this.bi_convert_song2(song)
//                 );
//                 const total = response.data.data.numResults;
//                 return fn({
//                   result,
//                   total,
//                 });
//               });
//             }
//           }
//         );
//       },
//     };
//   }
  // Future<Map<String, dynamic>> search(String url) async {
  //   final keyword = getParameterByName('keywords', url);
  //   final curpage = getParameterByName('curpage', url);

  //   final targetUrl =
  //       'https://api.bilibili.com/x/web-interface/search/type?__refresh__=true&_extra=&context=&page=$curpage&page_size=42&platform=pc&highlight=1&single_column=0&keyword=${Uri.encodeComponent(keyword!)}&category_id=&search_type=video&dynamic_offset=0&preload=true&com2co=true';

  //   String cookie = '';
  //   Map<String, dynamic> settings = await _getsettings();
  //   if (settings.containsKey('bl') && settings['bl'] != '') {
  //     cookie = settings['bl'];
  //   } else {
  //     cookie = 'buvid3=0';
  //   }
  //   final response = await dio_with_cookie_manager.get(targetUrl,
  //       options: Options(headers: {
  //         'cookie': cookie,
  //       }));
  //   final result = response.data['data']['result'].map((song) {
  //     return bi_convert_song2(song);
  //   }).toList();
  //   final total = response.data['data']['numResults'];

  //   return {
  //     'result': result,
  //     'total': total,
  //   };
  // }
  Future<Map<String, dynamic>> search(String url) async {
    return {
      'success': (fn) async {
        final keyword = getParameterByName('keywords', url);
        final curpage = getParameterByName('curpage', url);
        final targetUrl =
            'https://api.bilibili.com/x/web-interface/search/type?__refresh__=true&_extra=&context=&page=$curpage&page_size=42&platform=pc&highlight=1&single_column=0&keyword=${Uri.encodeComponent(keyword!)}&category_id=&search_type=video&dynamic_offset=0&preload=true&com2co=true';

        String cookie = '';
        Map<String, dynamic> settings = await _getsettings();
        if (settings.containsKey('bl') && settings['bl'] != '') {
          cookie = settings['bl'];
        } else {
          cookie = 'buvid3=0';
        }
        dio_with_cookie_manager
            .get(targetUrl,
                options: Options(headers: {
                  'cookie': cookie,
                }))
            .then((response) {
          final result = response.data['data']['result'].map((song) {
            return bi_convert_song2(song);
          }).toList();
          final total = response.data['data']['numResults'];
          fn({
            'result': result,
            'total': total,
          });
        });
      },
    };
  }

  static Future<Map<String, dynamic>> lyric() async {
    return {
      'success': (Function fn) {
        fn({
          'lyric': '',
        });
      },
    };
  }

  Future<Map<String, dynamic>> get_playlist(String url) async {
    final listId = getParameterByName('list_id', url)?.split('_')[0];
    switch (listId) {
      case 'biplaylist':
        return bi_get_playlist(url);
      case 'biplaylistxuan':
        return biGetPlaylistxuan(url);
      case 'bialbum':
        return bi_album(url);
      case 'biartist':
        return bi_artist(url);
      case 'bitrack':
        return bi_track(url);
      default:
        return Future.value(null);
    }
  }

// static get_playlist_filters() {
//     return {
//       success: (fn) => fn({ recommend: [], all: [] }),
//     };
//   }
  Future<Map<String, dynamic>> get_playlist_filters() async {
    return {
      'success': (Function fn) {
        fn({'recommend': [], 'all': []});
      },
    };
  }

// static get_user() {
//     return {
//       success: (fn) => fn({ status: 'fail', data: {} }),
//     };
//   }
  static Future<Map<String, dynamic>> get_user() async {
    return {'status': 'fail', 'data': {}};
  }

  static String get_login_url() {
    return 'https://www.bilibili.com';
  }

  static void logout() {}
}
