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

// Future<void> outputAllSettingsToFile([bool toJsonString = false]) async {
Future<Map<String, dynamic>> outputAllSettingsToFile(
    [bool toJsonString = false]) async {
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
        try {
          settings[key] = jsonDecode(prefs.getString(key) ?? '{}');
        } catch (e) {
          settings[key] = prefs.getString(key);
        }
    }
  }
  if (toJsonString) {
    settings.remove('githubOauthAccessKey');
    return settings;
  }
  // 申请所有文件访问权限
  if (await Permission.storage.request().isGranted) {
    try {
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
  return {};
}

Future<void> importSettingsFromFile(
    // [bool fromjson = false, String jsonString = '']) async {
    [bool fromjson = false,
    Map<String, dynamic> jsonString = const {}]) async {
  Future<void> _sets(Map<String, dynamic> settings) async {
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
        case 'settings':
          continue;
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
  }

  if (fromjson) {
    // final settings = jsonDecode(jsonString) as Map<String, dynamic>;
    final settings = jsonString;
    await _sets(settings);
    return;
  }
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

        await _sets(settings);
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

class login_webview extends StatefulWidget {
  final WebViewController controller;
  final String config_key;
  final String open_url;
  const login_webview(
      {super.key,
      required this.controller,
      required this.config_key,
      required this.open_url});
  @override
  _login_webviewState createState() => _login_webviewState();
}

class _login_webviewState extends State<login_webview> {
  void get__cookie() async {
    switch (widget.config_key) {
      case 'github':
        final url = await widget.controller.currentUrl();
        print(url);
        final code = url?.split('code=')[1];
        Github.handleCallback(code ?? '', context);
        break;
      default:
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
        builder: (context) => login_webview(
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
        builder: (context) => login_webview(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                SvgPicture.string(
                    '<svg width="800px" height="800px" viewBox="0 0 20 20" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"><title>github [#142]</title><desc>Created with Sketch.</desc><defs></defs><g id="Page-1" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd"><g id="Dribbble-Light-Preview" transform="translate(-140.000000, -7559.000000)" fill="#000000"><g id="icons" transform="translate(56.000000, 160.000000)"><path d="M94,7399 C99.523,7399 104,7403.59 104,7409.253 C104,7413.782 101.138,7417.624 97.167,7418.981 C96.66,7419.082 96.48,7418.762 96.48,7418.489 C96.48,7418.151 96.492,7417.047 96.492,7415.675 C96.492,7414.719 96.172,7414.095 95.813,7413.777 C98.04,7413.523 100.38,7412.656 100.38,7408.718 C100.38,7407.598 99.992,7406.684 99.35,7405.966 C99.454,7405.707 99.797,7404.664 99.252,7403.252 C99.252,7403.252 98.414,7402.977 96.505,7404.303 C95.706,7404.076 94.85,7403.962 94,7403.958 C93.15,7403.962 92.295,7404.076 91.497,7404.303 C89.586,7402.977 88.746,7403.252 88.746,7403.252 C88.203,7404.664 88.546,7405.707 88.649,7405.966 C88.01,7406.684 87.619,7407.598 87.619,7408.718 C87.619,7412.646 89.954,7413.526 92.175,7413.785 C91.889,7414.041 91.63,7414.493 91.54,7415.156 C90.97,7415.418 89.522,7415.871 88.63,7414.304 C88.63,7414.304 88.101,7413.319 87.097,7413.247 C87.097,7413.247 86.122,7413.234 87.029,7413.87 C87.029,7413.87 87.684,7414.185 88.139,7415.37 C88.139,7415.37 88.726,7417.2 91.508,7416.58 C91.513,7417.437 91.522,7418.245 91.522,7418.489 C91.522,7418.76 91.338,7419.077 90.839,7418.982 C86.865,7417.627 84,7413.783 84,7409.253 C84,7403.59 88.478,7399 94,7399" id="github-[#142]"></path></g></g></g></svg>'),
                Expanded(
                  child: FutureBuilder(
                    // future: check_bl_cookie(),
                    future: Github.updateStatus(),
                    builder:
                        (BuildContext context, AsyncSnapshot<int> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      } else {
                        if (snapshot.data == '') {
                          return const Text('cookie未设置或失效');
                        } else {
                          // return Text(const JsonEncoder.withIndent('  ')
                          //     .convert(snapshot.data));
                          return Text(Github.getStatusText());
                        }
                      }
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Github.openAuthUrl(context),
                  child: const Text('登录Github(建议使用魔法'),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => outputAllSettingsToFile(),
                  child: const Text('保存配置到文件'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (Github.status != 2) {
                      _msg('请先登录Github', 1.0);
                      return;
                    }
                    var playlists = await Github.listExistBackup();
                    print(playlists);

                    try {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('导出到Github Gist'),
                            content: Container(
                              width: double.maxFinite,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: playlists.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final playlist = playlists[index];
                                  return ListTile(
                                    title: Text(playlist['id']),
                                    subtitle: Text(playlist['description']),
                                    onTap: () async {
                                      try {
                                        Fluttertoast.showToast(
                                          msg: '正在导出',
                                        );
                                        final settings =
                                            await outputAllSettingsToFile(true);
                                        final jsfile =
                                            Github.json2gist(settings);
                                        await Github.backupMySettings2Gist(
                                          jsfile,
                                          playlist['id'],
                                          playlist['public'],
                                        );
                                        Fluttertoast.showToast(
                                          msg: '导出成功',
                                        );
                                        Navigator.of(context).pop();
                                      } catch (e) {
                                        Fluttertoast.showToast(
                                          msg: '导出失败$e',
                                        );
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () async {
                                  try {
                                    Fluttertoast.showToast(
                                      msg: '正在导出',
                                    );
                                    final settings =
                                        await outputAllSettingsToFile(true);
                                    final jsfile = Github.json2gist(settings);
                                    await Github.backupMySettings2Gist(
                                      jsfile,
                                      null,
                                      true,
                                    );
                                    Fluttertoast.showToast(
                                      msg: '导出成功',
                                    );
                                    Navigator.of(context).pop();
                                  } catch (e) {
                                    Fluttertoast.showToast(
                                      msg: '导出失败$e',
                                    );
                                  }
                                },
                                child: Text('创建公开备份'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  try {
                                    Fluttertoast.showToast(
                                      msg: '正在导出',
                                    );
                                    final settings =
                                        await outputAllSettingsToFile(true);
                                    final jsfile = Github.json2gist(settings);
                                    await Github.backupMySettings2Gist(
                                      jsfile,
                                      null,
                                      false,
                                    );
                                    Fluttertoast.showToast(
                                      msg: '导出成功',
                                    );
                                    Navigator.of(context).pop();
                                  } catch (e) {
                                    Fluttertoast.showToast(
                                      msg: '导出失败$e',
                                    );
                                  }
                                },
                                child: Text('创建私有备份'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text('取消'),
                              ),
                            ],
                          );
                        },
                      );
                    } catch (e) {
                      // print(e);
                      Fluttertoast.showToast(
                        msg: '添加失败${e}',
                      );
                    }
                  },
                  child: const Text('备份配置到Gist'),
                ),
              ],
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              ElevatedButton(
                onPressed: () => importSettingsFromFile(),
                child: const Text('从文件导入配置'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (Github.status != 2) {
                    _msg('请先登录Github', 1.0);
                    return;
                  }
                  var playlists = await Github.listExistBackup();
                  print(playlists);

                  try {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('从Github Gist导入'),
                          content: Container(
                            width: double.maxFinite,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: playlists.length,
                              itemBuilder: (BuildContext context, int index) {
                                final playlist = playlists[index];
                                return ListTile(
                                  title: Text(playlist['id']),
                                  subtitle: Text(playlist['description']),
                                  onTap: () async {
                                    try {
                                      Fluttertoast.showToast(
                                        msg: '正在导入',
                                      );

                                      final jsfile =
                                          await Github.importMySettingsFromGist(
                                        playlist['id'],
                                      );
                                      final settings =
                                          await Github.gist2json(jsfile);
                                      await importSettingsFromFile(
                                          true, settings);
                                      Fluttertoast.showToast(
                                        msg: '导出成功',
                                      );
                                      Navigator.of(context).pop();
                                    } catch (e) {
                                      Fluttertoast.showToast(
                                        msg: '导出失败$e',
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('取消'),
                            ),
                          ],
                        );
                      },
                    );
                  } catch (e) {
                    // print(e);
                    Fluttertoast.showToast(
                      msg: '添加失败${e}',
                    );
                  }
                },
                child: const Text('从Gist导入配置'),
              ),
            ]),
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

class Github {
  static const String OAUTH_URL = 'https://github.com/login/oauth';
  static const String API_URL = 'https://api.github.com';

  static const String clientId = 'e099a4803bb1e2e773a3';
  static const String clientSecret = '81fbfc45c65af8c0fbf2b4dae6f23f22e656cfb8';

  static Dio dio = Dio(BaseOptions(
    baseUrl: API_URL,
    headers: {'accept': 'application/json'},
  ));

  static int status = 0;
  static String username = '';

  static Future<void> handleCallback(String code, BuildContext context) async {
    final url = '$OAUTH_URL/access_token';
    final params = {
      'client_id': clientId,
      'client_secret': clientSecret,
      'code': code,
    };
    final response = await dio.post(
      url,
      queryParameters: params,
    );
    final accessToken = response.data['access_token'];
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('githubOauthAccessKey', accessToken);
    _msg('设置成功', context, 1.0);
  }

  static void openAuthUrl(BuildContext context) {
    status = 1;
    final url = '$OAUTH_URL/authorize?client_id=$clientId&scope=gist';
    // Open URL in browser
    // window.open(url, '_blank');
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
        ),
      )
      ..loadRequest(Uri.parse(url));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => login_webview(
            controller: controller, config_key: 'github', open_url: url),
      ),
    );
  }

  static int getStatus() => status;

  static String getStatusText() {
    switch (status) {
      case 0:
        return '未连接';
      case 1:
        return '连接中';
      case 2:
        return '$username已登录';
      default:
        return '???';
    }
  }

  static Future<int> updateStatus() async {
    // final accessToken = localStorage.getItem('githubOauthAccessKey');
    // final accessToken = null; // Replace with actual access token retrieval
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('githubOauthAccessKey');
    if (accessToken == null) {
      status = 0;
    } else {
      final response = await dio.get('/user',
          options: Options(headers: {
            'Authorization': 'token $accessToken',
          }));
      final data = response.data;
      if (data['login'] == null) {
        status = 1;
      } else {
        status = 2;
        username = data['login'];
      }
    }
    return status;
  }

  static void logout() {
    // localStorage.removeItem('githubOauthAccessKey');
    status = 0;
  }

  static Map<String, dynamic> json2gist(Map<String, dynamic> jsonObject) {
    final result = <String, dynamic>{};

    result['listen1_backup.json'] = {
      'content': json.encode(jsonObject),
    };

    final playlistIds = jsonObject['playerlists'];
    final songsCount = playlistIds.fold<int>(0, (count, playlistId) {
      final playlist = jsonObject[playlistId];
      final cover =
          '<img src="${playlist['info']['cover_img_url']}" width="140" height="140"><br/>';
      final title = playlist['info']['title'];
      var tableHeader = '\n| 音乐标题 | 歌手 | 专辑 |\n';
      tableHeader += '| --- | --- | --- |\n';
      final tableBody = playlist['tracks'].fold<String>('', (r, track) {
        return '$r | ${track['title']} | ${track['artist']} | ${track['album']} | \n';
      });
      final content =
          '<details>\n  <summary>$cover   $title</summary><p>\n$tableHeader$tableBody</p></details>';
      final filename = 'listen1_$playlistId.md';
      result[filename] = {
        'content': content,
      };
      return (count as int) + (playlist['tracks'].length as int);
    });
    final summary =
        '本歌单由[Listen1](https://listen1.github.io/listen1/)创建, 歌曲数：$songsCount，歌单数：${playlistIds.length}，点击查看更多';
    result['listen1_aha_playlist.md'] = {
      'content': summary,
    };

    return result;
  }

  // static Future<void> gist2json(Map<String, dynamic> gistFiles,
  static Future<Map<String, dynamic>> gist2json(
    Map<String, dynamic> gistFiles,
  ) async {
    if (!gistFiles['listen1_backup.json']['truncated']) {
      final jsonString = gistFiles['listen1_backup.json']['content'];
      // callback(json.decode(jsonString));
      return json.decode(jsonString);
    } else {
      final url = gistFiles['listen1_backup.json']['raw_url'];
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('githubOauthAccessKey');
      final response = await dio.get(url,
          options: Options(headers: {
            'Authorization': 'token $accessToken',
          }));
      // callback(response.data);
      return response.data;
    }
  }

  static Future<List<dynamic>> listExistBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('githubOauthAccessKey');
    final response = await dio.get('/gists',
        options: Options(headers: {
          'Authorization': 'token $accessToken',
        }));
    final result = response.data;
    return result.where((backupObject) {
      return backupObject['description'] != null &&
          backupObject['description'].startsWith('updated by Listen1');
    }).toList();
  }

  static Future<void> backupMySettings2Gist(
      Map<String, dynamic> files, String? gistId, bool isPublic) async {
    String method;
    String url;
    if (gistId != null) {
      method = 'patch';
      url = '/gists/$gistId';
    } else {
      method = 'post';
      url = '/gists';
    }
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('githubOauthAccessKey');
    await dio.request(
      url,
      options: Options(method: method, headers: {
        'Authorization': 'token $accessToken',
      }),
      data: {
        'description':
            'updated by Listen1(https://listen1.github.io/listen1/) at ${DateTime.now().toLocal()}',
        'public': isPublic,
        'files': files,
      },
    );
  }

  static Future<Map<String, dynamic>> importMySettingsFromGist(
      String gistId) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('githubOauthAccessKey');
    final response = await dio.get('/gists/$gistId',
        options: Options(headers: {
          'Authorization': 'token $accessToken',
        }));
    return response.data['files'];
  }
}
