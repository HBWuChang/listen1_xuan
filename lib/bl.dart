import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
    }
    else
    {
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
