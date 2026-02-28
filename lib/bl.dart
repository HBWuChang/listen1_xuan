import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;
import 'package:listen1_xuan/settings.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' show parse;
import 'controllers/DioController.dart';
import 'controllers/settings_controller.dart';
import 'funcs.dart';
import 'lowebutil.dart';
import 'package:listen1_xuan/models/Track.dart';

import 'models/PlayListInfo.dart';
import 'models/Playlist.dart';

final bilibili = Bilibili();

enum BLPlaylistType {
  playlist('biplaylist'),
  album('bialbum'),
  artist('biartist'),
  track('bitrack'),
  playlistxuan('biplaylistxuan');

  final String prefix;
  const BLPlaylistType(this.prefix);
}

class Bilibili {
  Future<List<PlayList>> Xuan_get_bl_playlist() async {
    var bilibiliData = {};
    var bilibiliData2 = [];
    String url = 'https://api.bilibili.com/x/v3/fav/folder/list4navigate';
    final settings = settings_getsettings();
    final cookie = settings['bl'];

    var headers = {'content-type': 'application/json'};
    try {
      final response = await dioWithCookieManager.get(
        url,
        options: Options(headers: headers),
      );
      bilibiliData = response.data;
      url = 'https://api.bilibili.com/x/v3/fav/folder/collected/list';
      String upMid = cookie.split('DedeUserID=')[1].split(';')[0];
      String turl = '$url?pn=1&ps=20&up_mid=$upMid&platform=web';
      var response2 = await dioWithCookieManager.get(
        turl,
        options: Options(headers: headers),
      );
      var res2 = response2.data;
      bilibiliData2.clear();
      res2['data']['list'].forEach((element) {
        bilibiliData2.add(element);
      });
      if (res2['data']['has_more']) {
        var pn = 2;
        do {
          turl = '$url?pn=$pn&ps=20&up_mid=$upMid&platform=web';
          response2 = await dioWithCookieManager.get(
            turl,
            options: Options(headers: headers),
          );
          res2 = response2.data;
          res2['data']['list'].forEach((element) {
            bilibiliData2.add(element);
          });
          pn++;
        } while (res2['data']['has_more']);
      }
      var retdata = [];
      bilibiliData["data"].forEach((item) {
        if (item["mediaListResponse"]["list"] != null) {
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
        }
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
      // return retdata.cast<PlayList>();
      return List.from([
        PlayList(
          info: PlayListInfo(
            id: 'biplaylistxuan_toview$upMid',
            title: '稍后再看',
            cover_img_url: '',
            source_url: 'https://www.bilibili.com/watchlater/list',
          ),
        ),
        ...(retdata.map((item) {
          return PlayList.fromJson(item);
        })),
      ]);
    } on DioException catch (e) {
      debugPrint('请求失败: ${e.message}');
      if (e.response != null) {
        debugPrint('响应数据: ${e.response?.data}');
        debugPrint('响应头: ${e.response?.headers}');
        debugPrint('请求信息: ${e.response?.requestOptions}');
      } else {
        debugPrint('请求未发送: ${e.requestOptions}');
        debugPrint('错误信息: ${e.message}');
      }
      showErrorSnackbar(
        'Bilibili获取歌单失败\n${e.message}',
        e.response?.data.toString() ?? '',
      );
      return [];
    } catch (e) {
      debugPrint('未知错误: $e');
      showErrorSnackbar('Bilibili获取歌单未知错误', e.toString());
      return [];
    }
  }

  static Future<Map<String, dynamic>> biGetPlaylistxuan(String url) async {
    final selectmid = getParameterByName('list_id', url)?.split('_').last;
    if (selectmid == null) {
      return {
        'success': (fn) {
          fn({'info': {}, 'tracks': []});
        },
      };
    }
    try {
      if (selectmid.substring(0, 2) == 'my') {
        var url = '';
        url =
            'https://api.bilibili.com/x/v3/fav/resource/list?ps=20&keyword&order=mtime&type=0&tid=0&platform=web&';
        var turl = '${url}pn=1&media_id=${selectmid.substring(2)}';
        final headers = {'content-type': 'application/json'};
        var medias = [];
        var response = await dioWithCookieManager.get(
          turl,
          options: Options(headers: headers),
        );
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
            response = await dioWithCookieManager.get(
              turl,
              options: Options(headers: headers),
            );
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

        // return {'info': info, 'tracks': tracks};
        return {
          'success': (fn) {
            fn({'info': info, 'tracks': tracks});
          },
        };
      } else if (selectmid.substring(0, 6) == 'toview') {
        final url = 'https://api.bilibili.com/x/v2/history/toview/web';
        final res = await dioWithCookieManager.get(
          url,
          options: Options(
            headers: {
              "User-Agent":
                  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36 Edg/142.0.0.0",
              "Connection": "keep-alive",
              "Accept": "*/*",
              "Accept-Encoding": "gzip, deflate, br, zstd",
              "sec-ch-ua-platform": "\"Windows\"",
              "sec-ch-ua":
                  "\"Chromium\";v=\"142\", \"Microsoft Edge\";v=\"142\", \"Not_A Brand\";v=\"99\"",
              "sec-ch-ua-mobile": "?0",
              "origin": "https://space.bilibili.com",
              "sec-fetch-site": "same-site",
              "sec-fetch-mode": "cors",
              "sec-fetch-dest": "empty",
              "referer": "https://www.bilibili.com/",
              "accept-language":
                  "zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6",
              "priority": "u=1, i",
            },
          ),
        );
        Map<String, dynamic> data = res.data['data'];
        final info = {
          'cover_img_url': '',
          'title': '稍后再看',
          'id': 'biplaylistxuan_$selectmid',
          'source_url': 'https://www.bilibili.com/watchlater/list',
        };
        List<dynamic> medias = data['list'];
        final tracks = medias.map((item) {
          return biConvertSongxuanToView(item);
        }).toList();
        // throw '测试阶段，稍后再看功能未完成';
        return {
          'success': (fn) {
            fn({'info': info, 'tracks': tracks});
          },
        };
      } else {
        var url = '';
        url =
            'https://api.bilibili.com/x/space/fav/season/list?pn=1&ps=20&season_id=';
        var turl = url + selectmid.toString();
        final headers = {'content-type': 'application/json'};
        var medias = [];
        var response = await dioWithCookieManager.get(
          turl,
          options: Options(headers: headers),
        );
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
        // return {'info': info, 'tracks': tracks};
        return {
          'success': (fn) {
            fn({'info': info, 'tracks': tracks});
          },
        };
      }
    } catch (e) {
      showErrorSnackbar('Bilibili获取歌单错误', e.toString());
      // return {'info': {}, 'tracks': []};
      return {
        'success': (fn) {
          fn({'info': {}, 'tracks': []});
        },
      };
    }
  }

  static Future<Map<String, dynamic>> _getsettings() async {
    return getx.Get.find<SettingsController>().settings;
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
      Response response = await Dio().get(
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

  static Map<String, String>? wbiKey;

  static String htmlDecode(String value) {
    var document = parse(value);
    return document.body?.text ?? '';
  }

  static Future<Map<String, String>> fetch_wbi_key() async {
    final response = await Dio().get(
      'https://api.bilibili.com/x/web-interface/nav',
    );
    final jsonContent = response.data;
    final imgUrl = jsonContent['data']['wbi_img']['img_url'];
    final subUrl = jsonContent['data']['wbi_img']['sub_url'];
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
        '${Uri.encodeComponent(key)}=${Uri.encodeComponent(params[key].toString().replaceAll(chrFilter, ''))}',
      );
    }
    final queryString = query.join('&');
    final wbiSign = md5.convert(utf8.encode(queryString + mixinKey)).toString();
    return '$queryString&w_rid=$wbiSign';
  }

  static Future<dynamic> wrap_wbi_request(
    String url,
    Map<String, dynamic> params, {
    ResponseType? responseType,
  }) async {
    final queryString = await encWbi(params);
    final targetUrl = '$url?$queryString';
    String cookie = '';
    Map<String, dynamic> settings = await _getsettings();
    if (settings.containsKey('bl') && settings['bl'] != '') {
      cookie = settings['bl'];
    } else {
      cookie = 'buvid3=0';
    }
    var t = await Dio().get(
      targetUrl,
      options: Options(
        headers: {
          "User-Agent":
              "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36",
          "Connection": "keep-alive",
          "Accept": "application/json, text/plain, */*",
          "Accept-Encoding": "gzip, deflate, br",
          "accept-language": "zh-CN",
          "referer": "https://www.bilibili.com/",
          "sec-fetch-dest": "empty",
          "sec-fetch-mode": "cors",
          "sec-fetch-site": "cross-site",
          'cookie': cookie,
        },
        validateStatus: (status) {
          // 允许 412 状态码不抛出异常
          return status != null && status < 500;
        },
        responseType: responseType,
      ),
    );
    return t;
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

  static Map<String, dynamic> biConvertSongxuanToView(
    Map<String, dynamic> songInfo,
  ) {
    return {
      'id': 'bitrack_v_${songInfo['bvid']}',
      'title': htmlDecode(songInfo['title']),
      'artist': htmlDecode(songInfo['owner']['name']),
      'artist_id': 'biartist_v_${songInfo['owner']['mid']}',
      'source': 'bilibili',
      'source_url': 'https://www.bilibili.com/${songInfo['bvid']}',
      'img_url': songInfo['cover'] ?? songInfo['pic'] ?? songInfo['cover43'],
    };
  }

  Future<Map<String, dynamic>> show_playlist(String url) async {
    int offset = int.parse(getParameterByName('offset', url) ?? '0');
    int page = (offset / 20).ceil() + 1;
    String targetUrl =
        'https://www.bilibili.com/audio/music-service-c/web/menu/hit?ps=20&pn=$page';

    return {
      'success': (Function fn) async {
        try {
          final res = await dioWithCookieManager.get(targetUrl);
          final data = res.data['data']["data"] as List;
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
        } catch (e) {
          debugPrint('Error fetching playlist: $e');
          fn([]);
        }
      },
    };
  }

  static Future<Map<String, dynamic>> bi_get_playlist(String url) async {
    final listId = getParameterByName('list_id', url)?.split('_').last;
    final targetUrl =
        'https://www.bilibili.com/audio/music-service-c/web/menu/info?sid=$listId';

    return {
      'success': (Function fn) {
        Dio().get(targetUrl).then((response) async {
          final data = response.data['data'];
          final info = {
            'cover_img_url': data['cover'],
            'title': data['title'],
            'id': 'biplaylist_$listId',
            'source_url': 'https://www.bilibili.com/audio/am$listId',
          };
          final target =
              'https://www.bilibili.com/audio/music-service-c/web/song/of-menu?pn=1&ps=100&sid=$listId';
          final res = await Dio().get(target);
          final tracks = res.data['data']['data'].map((item) {
            return bi_convert_song(item);
          }).toList();
          fn({'info': info, 'tracks': tracks});
        });
      },
    };
  }

  Future<Map<String, dynamic>> bi_album(String url) async {
    return {
      'success': (Function fn) => fn({'tracks': [], 'info': {}}),
    };
  }

  static Future<Map<String, dynamic>> bi_track(String url) async {
    final trackId = getParameterByName(
      'list_id',
      url,
    )?.split('_').last.split('-').first;
    final targetUrl =
        'https://api.bilibili.com/x/web-interface/view?bvid=$trackId';

    return {
      'success': (Function fn) {
        Dio().get(targetUrl).then((response) {
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

  static Map<String, dynamic> bi_convert_song3(
    Map<String, dynamic> songInfo,
    String bvid,
    Map<String, dynamic> author,
    String defaultImg,
  ) {
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

  static Future<Map<String, dynamic>> bi_artist(String url) async {
    final artistId = getParameterByName('list_id', url)?.split('_').last;
    return {
      'success': (Function fn) async {
        try {
          String targetUrl;
          final response = await wrap_wbi_request(
            'https://api.bilibili.com/x/space/wbi/acc/info',
            {'mid': artistId},
          );
          final info = {
            'cover_img_url': response.data['data']['face'],
            'title': response.data['data']['name'],
            'id': 'biartist_$artistId',
            'source_url': 'https://space.bilibili.com/$artistId/#/audio',
          };
          String cookie = '';
          Map<String, dynamic> settings = await _getsettings();
          if (settings.containsKey('bl') && settings['bl'] != '') {
            cookie = settings['bl'];
          } else {
            cookie = 'buvid3=0';
          }
          if (getParameterByName('list_id', url)?.split('_').length == 3) {
            final res = await wrap_wbi_request(
              'https://api.bilibili.com/x/space/wbi/arc/search',
              {
                'mid': artistId,
                'pn': 1,
                'ps': 25,
                'order': 'click',
                'index': 1,
              },
            );
            final tracks = res.data['data']['list']['vlist'].map((item) {
              return bi_convert_song2(item);
            }).toList();
            fn({'tracks': tracks, 'info': info});
          } else {
            targetUrl =
                'https://api.bilibili.com/audio/music-service-c/web/song/upper?pn=1&ps=0&order=2&uid=$artistId';
            final res = await Dio().get(
              targetUrl,
              options: Options(headers: {'cookie': cookie}),
            );
            final tracks = res.data['data']['data'].map((item) {
              return bi_convert_song(item);
            }).toList();
            fn({'tracks': tracks, 'info': info});
          }
        } catch (e) {
          print(e);
          fn({'tracks': [], 'info': {}});
        }
      },
    };
  }

  static Future<Map<String, dynamic>> parse_url(String url) async {
    final regex = RegExp(r'\/\/www.bilibili.com\/audio\/am([0-9]+)');
    final match = regex.firstMatch(url);
    Map<String, dynamic>? result;
    if (match != null) {
      final playlistId = match.group(1);
      result = {'type': 'playlist', 'id': 'biplaylist_$playlistId'};
    }
    return result ?? {};
  }

  Future<void> bootstrap_track(
    Track track,
    Function success,
    Function failure,
  ) async {
    final trackId = track.id;
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
        final response = await Dio().get(targetUrl);
        var cid = response.data['data']['pages'][0]['cid'];
        if (trackIdCheck.length > 1) {
          cid = trackIdCheck[1];
        }
        final targetUrl2 =
            'https://api.bilibili.com/x/player/playurl?fnval=16&bvid=$bvid&cid=$cid';
        final response2 = await Dio().get(targetUrl2);
        try {
          final audioList = response2.data['data']['dash']['audio'];
          if (audioList.isNotEmpty) {
            // 找到最大的 id 对应的元素
            final maxAudio = audioList.reduce(
              (a, b) => a['id'] > b['id'] ? a : b,
            );
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
        final response = await Dio().get(targetUrl);
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

  Future<Map<String, dynamic>> search(String url) async {
    return {
      'success': (fn) async {
        final keyword = getParameterByName('keywords', url);
        final curpage = getParameterByName('curpage', url);
        final targetUrl =
            'https://api.bilibili.com/x/web-interface/search/type?__refresh__=true&_extra=&context=&page=$curpage&page_size=42&platform=pc&highlight=1&single_column=0&keyword=${Uri.encodeComponent(keyword!)}&category_id=&search_type=video&dynamic_offset=0&preload=true&com2co=true';

        dioWithCookieManager
            .get(targetUrl)
            .then(
              (response) {
                final result = response.data['data']['result'].map((song) {
                  return bi_convert_song2(song);
                }).toList();
                final total = response.data['data']['numResults'];
                fn({'result': result, 'total': total});
              },
              onError: (e) {
                showDebugSnackbar('Bilibili搜索失败', e.toString());
                fn({'result': [], 'total': 0});
              },
            );
      },
    };
  }

  static Future<Map<String, dynamic>> lyric() async {
    return {
      'success': (Function fn) {
        fn({'lyric': ''});
      },
    };
  }

  Future<Map<String, dynamic>> get_playlist(String url) async {
    final listId = getParameterByName('list_id', url)?.split('_')[0];
    // switch (listId) {
    //   case 'biplaylist':
    if (listId == BLPlaylistType.playlist.prefix) return bi_get_playlist(url);
    // case 'biplaylistxuan':
    if (listId == BLPlaylistType.playlistxuan.prefix)
      return biGetPlaylistxuan(url);
    // case 'bialbum':
    if (listId == BLPlaylistType.album.prefix) return bi_album(url);
    // case 'biartist':
    if (listId == BLPlaylistType.artist.prefix) return bi_artist(url);
    // case 'bitrack':
    if (listId == BLPlaylistType.track.prefix) return bi_track(url);
    // default:
    return Future.value(null);
    // }
  }

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
