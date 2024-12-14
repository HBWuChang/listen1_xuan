import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';

final bilibili = Bilibili();

class Bilibili {
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
  Future<Map<String, dynamic>> showPlaylist(String url) async {
    int offset = getParameterByName('offset', url) ?? 0;
    int page = (offset / 20).ceil() + 1;
    String targetUrl =
        'https://www.bilibili.com/audio/music-service-c/web/menu/hit?ps=20&pn=$page';

    try {
      Response response = await Dio().get(targetUrl);
      List<dynamic> data = response.data['data']['data'];
      List<Map<String, dynamic>> result = data.map((item) {
        return {
          'cover_img_url': item['cover'],
          'title': item['title'],
          'id': 'biplaylist_${item['menuId']}',
          'source_url': 'https://www.bilibili.com/audio/am${item['menuId']}',
        };
      }).toList();

      return {'result': result};
    } catch (e) {
      print(e);
      return {'result': []};
    }
  }

  int? getParameterByName(String name, String url) {
    Uri uri = Uri.parse(url);
    String? param = uri.queryParameters[name];
    return param != null ? int.tryParse(param) : null;
  }
}
