import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:listen1_xuan/play.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'bl.dart';
import 'netease.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:marquee/marquee.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'qq.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:dio/dio.dart';

Future<void> outputAllSettingsToFile() async {
  // 申请所有文件访问权限
  if (await Permission.storage.request().isGranted) {
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> settings = {};
      final allkeys = prefs.getKeys();
      for (var key in allkeys) {
        switch (key) {
          case 'playerlists':
            settings[key] = prefs.getStringList(key);
            break;
          case 'auto_choose_source_list':
            settings[key] = prefs.getStringList(key);
            break;
          case 'favoriteplayerlists':
            settings[key] = prefs.getStringList(key);
            break;
          case 'settings':
            continue;
          default:
            settings[key] = jsonDecode(prefs.getString(key) ?? '{}');
        }
      }

      // 确保路径存在
      final downloadDir = Directory('/storage/emulated/0/Download/Listen1');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      final outputPath = '/storage/emulated/0/Download/Listen1/settings.json';
      final file = File(outputPath);
      // 将设置写入 JSON 文件
      await file.writeAsString(jsonEncode(settings));
      Fluttertoast.showToast(
        msg: 'Settings saved to $outputPath',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.blue,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: '保存设置时出错: $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  } else {
    Fluttertoast.showToast(
      msg: '存储权限未授予',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }
}

Future<void> importSettingsFromFile() async {
  // 申请所有文件访问权限
  if (await Permission.storage.request().isGranted) {
    try {
      // 弹出系统文件选择器选择文件
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final settings = jsonDecode(content) as Map<String, dynamic>;

        final prefs = await SharedPreferences.getInstance();
        for (var key in settings.keys) {
          switch (key) {
            case 'playerlists':
              // settings[key] = prefs.getStringList(key);
              prefs.setStringList(key, settings[key].cast<String>());
              break;
            case 'auto_choose_source_list':
              prefs.setStringList(key, settings[key].cast<String>());
              break;
            case 'favoriteplayerlists':
              prefs.setStringList(key, settings[key].cast<String>());

              break;
            default:
              // settings[key] = jsonDecode(prefs.getString(key) ?? '{}');
              prefs.setString(key, jsonEncode(settings[key]));
          }
        }

        Fluttertoast.showToast(
          msg: 'Settings imported successfully',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.blue,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      } else {
        Fluttertoast.showToast(
          msg: '未选择文件',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '导入设置时出错: $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  } else {
    Fluttertoast.showToast(
      msg: '存储权限未授予',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }
}

Future<void> setSaveCookie({
  required String url,
  required List<Cookie> cookies,
}) async {
  //Save cookies
  final tempDir = await getTemporaryDirectory();
  final tempPath = tempDir.path;
  await PersistCookieJar(
    ignoreExpires: true,
    // storage: FileStorage(appDocPath + "/.cookies/"),
    storage: FileStorage(tempPath + "/.cookies/"),
  ).saveFromResponse(Uri.parse(url), cookies);
}

Future<bool> saveToken(String name, String token) async {
  final prefs = await SharedPreferences.getInstance();
  prefs.setString(name, token);
  return true;
}

void _launchURL(Uri url) async {
  if (await canLaunchUrl(url)) {
    await launchUrl(url);
  } else {
    throw 'Could not launch $url';
  }
}

Future<Map<String, dynamic>> settings_getsettings() async {
  final prefs = await SharedPreferences.getInstance();
  String? jsonString = prefs.getString('settings');
  print("jsonString: $jsonString");
  if (jsonString == null) {
    return {};
  }
  return jsonDecode(jsonString);
}

Future<void> _saveToken(String platform, String token) async {
  Map<String, dynamic> settings = await settings_getsettings();
  final prefs = await SharedPreferences.getInstance();
  settings[platform] = token;
  // String jsonString = jsonEncode(tokenData);
  // await prefs.setString('$platform_token', jsonString);
  await prefs.setString('settings', jsonEncode(settings));
  switch (platform) {
    // case 'bl':
    //   await bilibili.set_bl_cookie(token);
    //   break;
    case 'ne':
      List<Cookie> cookies = [];
      for (var item in token.split(';')) {
        // var cookie = item.split('=');
        // 除去两端空格
        var cookie = item.trim().split('=');
        // cookies.add(Cookie(cookie[0], cookie[1]));
        var cookieName = cookie[0].trim();
        var cookieValue = Uri.encodeComponent(cookie[1].trim());
        cookies.add(Cookie(cookieName, cookieValue));
      }
      await setSaveCookie(url: 'https://music.163.com', cookies: cookies);
      break;
    default:
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class netease_login_webview extends StatefulWidget {
  final WebViewController controller;
  final String config_key;
  final String open_url;
  const netease_login_webview(
      {super.key,
      required this.controller,
      required this.config_key,
      required this.open_url});
  @override
  _netease_login_webviewState createState() => _netease_login_webviewState();
}

class _netease_login_webviewState extends State<netease_login_webview> {
  void get__cookie() async {
    final cookieManager = WebviewCookieManager();

    final gotCookies = await cookieManager.getCookies(widget.open_url);
    for (var item in gotCookies) {
      print(item);
    }
    String cookies = "";
    for (var item in gotCookies) {
      cookies += "${item.name}=${Uri.decodeComponent(item.value)};";
    }
    cookies = cookies.substring(0, cookies.length - 1);
    // await _saveToken('ne', cookies);
    await _saveToken(widget.config_key, cookies);
    _msg('设置成功$cookies', 3.0);
    // _msg('设置成功', 1.0);
    // Navigator.pop(context);
    // setState(() {});
  }

  void _msg(String msg, [double showtime = 3.0]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: Duration(milliseconds: (showtime * 1000).toInt()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: const Text('请登录后，点击右上角保存cooke按钮'),
        title: SizedBox(
            height: 30,
            child: Marquee(
              text: '请登录后，点击右上角保存cooke按钮',
              style: const TextStyle(fontSize: 20),
              scrollAxis: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              blankSpace: 20.0,
              velocity: 100.0,
              pauseAfterRound: const Duration(seconds: 1),
              startPadding: 10.0,
              accelerationDuration: const Duration(seconds: 1),
              accelerationCurve: Curves.linear,
              decelerationDuration: const Duration(milliseconds: 500),
              decelerationCurve: Curves.easeOut,
            )),

        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              get__cookie();
            },
          ),
        ],
      ),
      // body: WebViewWidget(controller: controller),
      body: WebViewWidget(controller: widget.controller),
    );
  }
}

class _SettingsPageState extends State<SettingsPage> {
  String _readmeContent = '';

  void open_bl_login() async {
    TextEditingController blCookieController = TextEditingController();
    Map<String, dynamic> settings = await settings_getsettings();
    if (settings.containsKey('bl')) {
      blCookieController.text = settings['bl'];
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // 设置背景颜色为透明
      isScrollControlled: true, // 允许全屏显示
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              color: Colors.white, // 设置内容区域的背景颜色
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.0),
                topRight: Radius.circular(16.0),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: () {
                      _launchURL(Uri.parse(
                          'https://mashir0-bilibili-qr-login.hf.space/'));
                    },
                    child: const Text('点击打开B站cookie获取页面'),
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '请输入B站cookie',
                    ),
                    onSubmitted: (String value) async {
                      await _saveToken('bl', value);
                      _msg('设置成功', 1.0);
                      Navigator.pop(context);
                      setState(() {});
                    },
                    onChanged: (value) async {
                      await _saveToken('bl', value);
                    },
                    controller: blCookieController,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void open_netease_login() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onHttpError: (HttpResponseError error) {},
          onWebResourceError: (WebResourceError error) {},
          // onNavigationRequest: (NavigationRequest request) {
          //   if (request.url.startsWith('https://www.youtube.com/')) {
          //     return NavigationDecision.prevent;
          //   }
          //   return NavigationDecision.navigate;
          // },
        ),
      )
      ..setUserAgent(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3')
      ..loadRequest(Uri.parse('https://music.163.com/'));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => netease_login_webview(
            controller: controller,
            config_key: 'ne',
            open_url: 'https://music.163.com/'),
      ),
    );
  }

  void open_qq_login() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onHttpError: (HttpResponseError error) {},
          onWebResourceError: (WebResourceError error) {},
          // onNavigationRequest: (NavigationRequest request) {
          //   if (request.url.startsWith('https://www.youtube.com/')) {
          //     return NavigationDecision.prevent;
          //   }
          //   return NavigationDecision.navigate;
          // },
        ),
      )
      ..setUserAgent(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3')
      ..loadRequest(Uri.parse('https://y.qq.com/'));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => netease_login_webview(
            controller: controller,
            config_key: 'qq',
            open_url: 'https://y.qq.com/'),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadReadme();
  }

  Future<void> _loadReadme() async {
    final treadmeContent = await Dio().get(
      'https://api.github.com/repos/HBWuChang/listen1_xuan/readme',
    );
    String decodeBase64(String data) {
      return utf8.decode(base64Decode(data));
    }

    // 使用base64对content进行解码
    setState(() {
      _readmeContent =
          decodeBase64(treadmeContent.data['content'].replaceAll("\n", ''));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                SvgPicture.string(
                    '<svg width="18" height="18" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg" class="zhuzhan-icon"><path fill-rule="evenodd" clip-rule="evenodd" d="M3.73252 2.67094C3.33229 2.28484 3.33229 1.64373 3.73252 1.25764C4.11291 0.890684 4.71552 0.890684 5.09591 1.25764L7.21723 3.30403C7.27749 3.36218 7.32869 3.4261 7.37081 3.49407H10.5789C10.6211 3.4261 10.6723 3.36218 10.7325 3.30403L12.8538 1.25764C13.2342 0.890684 13.8368 0.890684 14.2172 1.25764C14.6175 1.64373 14.6175 2.28484 14.2172 2.67094L13.364 3.49407H14C16.2091 3.49407 18 5.28493 18 7.49407V12.9996C18 15.2087 16.2091 16.9996 14 16.9996H4C1.79086 16.9996 0 15.2087 0 12.9996V7.49406C0 5.28492 1.79086 3.49407 4 3.49407H4.58579L3.73252 2.67094ZM4 5.42343C2.89543 5.42343 2 6.31886 2 7.42343V13.0702C2 14.1748 2.89543 15.0702 4 15.0702H14C15.1046 15.0702 16 14.1748 16 13.0702V7.42343C16 6.31886 15.1046 5.42343 14 5.42343H4ZM5 9.31747C5 8.76519 5.44772 8.31747 6 8.31747C6.55228 8.31747 7 8.76519 7 9.31747V10.2115C7 10.7638 6.55228 11.2115 6 11.2115C5.44772 11.2115 5 10.7638 5 10.2115V9.31747ZM12 8.31747C11.4477 8.31747 11 8.76519 11 9.31747V10.2115C11 10.7638 11.4477 11.2115 12 11.2115C12.5523 11.2115 13 10.7638 13 10.2115V9.31747C13 8.76519 12.5523 8.31747 12 8.31747Z" fill="gray"></path></svg>'),
                SizedBox(
                  width: 180,
                  child: FutureBuilder(
                    // future: check_bl_cookie(),
                    future: bilibili.check_bl_cookie(),
                    builder:
                        (BuildContext context, AsyncSnapshot<String> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      } else {
                        if (snapshot.data == '') {
                          return const Text('cookie未设置或失效');
                        } else {
                          return Text(snapshot.data ?? 'Loading...');
                        }
                      }
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () => open_bl_login(),
                  child: const Text('设置bilibili cookie'),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                CachedNetworkImage(
                    imageUrl:
                        "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/28469918905/0dfc/b6c0/d913/713572367ec9d917628e41266a39a67f.png",
                    width: 18,
                    height: 18),
                SizedBox(
                  width: 200,
                  child: FutureBuilder(
                    // future: check_bl_cookie(),
                    future: Netease().get_user(),
                    builder: (BuildContext context,
                        AsyncSnapshot<Map<String, dynamic>> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      } else {
                        if (snapshot.data == '') {
                          return const Text('cookie未设置或失效');
                        } else {
                          // return Text(const JsonEncoder.withIndent('  ')
                          //     .convert(snapshot.data));
                          return Text((snapshot.data?['result']?['nickname'] ??
                              '未知用户'));
                        }
                      }
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () => open_netease_login(),
                  child: const Text('登录网易云'),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                CachedNetworkImage(
                    imageUrl:
                        "https://ts2.cn.mm.bing.net/th?id=ODLS.07d947f8-8fdd-4949-8b9a-be5283268438&w=32&h=32&qlt=90&pcl=fffffa&o=6&pid=1.2",
                    width: 18,
                    height: 18),
                SizedBox(
                  width: 200,
                  child: FutureBuilder(
                    // future: check_bl_cookie(),
                    future: qq.get_user(),
                    builder: (BuildContext context,
                        AsyncSnapshot<Map<String, dynamic>> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      } else {
                        if (snapshot.data == '') {
                          return const Text('cookie未设置或失效');
                        } else {
                          // return Text(const JsonEncoder.withIndent('  ')
                          //     .convert(snapshot.data));
                          return Text(
                              (snapshot.data?['data']?['nickname'] ?? '未知用户'));
                        }
                      }
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () => open_qq_login(),
                  child: const Text('登录QQ音乐'),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: () => outputAllSettingsToFile(),
              child: const Text('保存配置到文件'),
            ),
            ElevatedButton(
              onPressed: () => importSettingsFromFile(),
              child: const Text('从文件导入配置'),
            ),
            ElevatedButton(
              onPressed: () => clean_local_cache(),
              child: const Text('清除未在配置文件中的歌曲缓存'),
            ),
            ElevatedButton(
              onPressed: () => clean_local_cache(true),
              child: const Text('清除所有歌曲缓存'),
            ),
            Expanded(
              child: Markdown(
                data: _readmeContent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _msg(String msg, [double showtime = 3.0]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: Duration(milliseconds: (showtime * 1000).toInt()),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: SettingsPage(),
  ));
}

void _msg(String msg, BuildContext context, [double showtime = 3.0]) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      duration: Duration(milliseconds: (showtime * 1000).toInt()),
    ),
  );
}
