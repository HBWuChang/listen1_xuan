import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:listen1_xuan/controllers/controllers.dart';
import 'package:listen1_xuan/main.dart';
import 'package:listen1_xuan/play.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'bl.dart';
import 'controllers/cache_controller.dart';
import 'controllers/myPlaylist_controller.dart';
import 'controllers/play_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/websocket_client_controller.dart';
import 'examples/websocket_client_example.dart';
import 'examples/websocket_server_example.dart';
import 'funcs.dart';
import 'models/websocket_message.dart';
import 'netease.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:marquee/marquee.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'pages/download_page.dart';
import 'qq.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'package:archive/archive.dart';
import 'package:install_plugin/install_plugin.dart';
import 'package:system_info3/system_info3.dart';
import 'global_settings_animations.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:get/get.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:extended_image/extended_image.dart';
import 'controllers/theme.dart';
import 'package:iconify_flutter_plus/iconify_flutter_plus.dart';
import 'package:iconify_flutter_plus/icons/octicon.dart';
import 'package:iconify_flutter_plus/icons/ri.dart';
import 'package:iconify_flutter_plus/icons/mdi.dart';
part 'pages/settings/settings_utils.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class LoginWebview extends StatefulWidget {
  final dynamic controller;
  final String config_key;
  final String open_url;
  const LoginWebview({
    super.key,
    required this.controller,
    required this.config_key,
    required this.open_url,
  });
  @override
  _LoginWebviewState createState() => _LoginWebviewState();
}

final navigatorKey = GlobalKey<NavigatorState>();

class _LoginWebviewState extends State<LoginWebview> {
  final List<StreamSubscription> _subscriptions = [];
  late String nowurl;
  Future<void> get__cookie() async {
    switch (widget.config_key) {
      case 'github':
        final url = is_windows ? nowurl : await widget.controller.currentUrl();
        if (url == null) {
          // _msg('获取cookie失败', 3.0);
          showErrorSnackbar('获取cookie失败', null);
          return;
        }
        print(url);
        final code = url?.split('code=')[1];
        await Github.handleCallback(code ?? '', context);
        break;
      default:
        if (is_windows) {
          var t = jsonDecode(await widget.controller.getCookies())["cookies"];

          print(t);
          String cookies = "";
          for (var item in t) {
            cookies += "${item['name']}=${Uri.decodeComponent(item['value'])};";
          }
          cookies = cookies.substring(0, cookies.length - 1);
          await savePlatformToken(widget.config_key, cookies);
          // _msg('设置成功$cookies', 3.0);
          showSuccessSnackbar('设置成功', null);
        } else {
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
          await savePlatformToken(widget.config_key, cookies);
          // _msg('设置成功$cookies', 3.0);
          showSuccessSnackbar('设置成功', null);
        }
    }
  }

  @override
  void initState() {
    super.initState();
    if (is_windows) initPlatformState();
  }

  Future<void> initPlatformState() async {
    try {
      await widget.controller.initialize();
      _subscriptions.add(
        widget.controller.url.listen((url) {
          nowurl = url;
        }),
      );
      await widget.controller.setBackgroundColor(Colors.transparent);
      await widget.controller.setPopupWindowPolicy(
        WebviewPopupWindowPolicy.deny,
      );
      await widget.controller.loadUrl(widget.open_url);

      if (!mounted) return;
      setState(() {});
    } on PlatformException catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Error'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Code: ${e.code}'),
                Text('Message: ${e.message}'),
              ],
            ),
            actions: [
              TextButton(
                child: Text('Continue'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      });
    }
  }

  Widget compositeView() {
    if (!widget.controller.value.isInitialized) {
      return const Text(
        'Not Initialized',
        style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w900),
      );
    } else {
      return Card(
        color: Colors.transparent,
        elevation: 0,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: Stack(
          children: [
            Webview(
              widget.controller,
              permissionRequested: _onPermissionRequested,
            ),
            StreamBuilder<LoadingState>(
              stream: widget.controller.loadingState,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data == LoadingState.loading) {
                  return LinearProgressIndicator();
                } else {
                  return SizedBox();
                }
              },
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _subscriptions.forEach((s) => s.cancel());
    super.dispose();
  }

  Future<WebviewPermissionDecision> _onPermissionRequested(
    String url,
    WebviewPermissionKind kind,
    bool isUserInitiated,
  ) async {
    final decision = await showDialog<WebviewPermissionDecision>(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('WebView permission requested'),
        content: Text('WebView has requested permission \'$kind\''),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.deny),
            child: const Text('Deny'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.allow),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    return decision ?? WebviewPermissionDecision.none;
  }

  final _saving = false.obs;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: const Text('请登录后，点击右上角保存cooke按钮'),
        title: SizedBox(
          height: 30,
          child: Marquee(
            text: '请登录后，点击右上角保存cookie按钮',
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
          ),
        ),

        actions: [
          Obx(
            () => IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saving.value
                  ? null
                  : () async {
                      _saving.value = true;
                      await get__cookie();
                      Get.find<SettingsController>().refreshLoginData();
                      _saving.value = false;
                    },
            ),
          ),
        ],
      ),
      body: is_windows
          ? compositeView()
          : WebViewWidget(controller: widget.controller),
    );
  }
}

class _SettingsPageState extends State<SettingsPage> {
  var useHttpOverrides = false.obs;
  final FocusNode _focusNode = FocusNode();
  final FocusNode _focusNode2 = FocusNode();
  final FocusNode _focusNode3 = FocusNode();
  late String apkfile_name;
  @override
  void dispose() {
    _focusNode.dispose(); // 释放 FocusNode
    _focusNode2.dispose(); // 释放 FocusNode
    _focusNode3.dispose(); // 释放 FocusNode
    super.dispose();
  }

  void open_bl_login() async {
    TextEditingController blCookieController = TextEditingController();
    Map<String, dynamic> settings = settings_getsettings();
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
                      g_launchURL(
                        Uri.parse(
                          'https://mashir0-bilibili-qr-login.hf.space/',
                        ),
                      );
                    },
                    child: const Text('点击打开B站cookie获取页面'),
                  ),
                  TextField(
                    focusNode: _focusNode,
                    decoration: const InputDecoration(labelText: '请输入B站cookie'),
                    onSubmitted: (String value) async {
                      await savePlatformToken('bl', value);
                      // _msg('设置成功', 1.0);
                      showSuccessSnackbar('设置成功', null);
                      Navigator.pop(context);
                      setState(() {});
                    },
                    onChanged: (value) async {
                      await savePlatformToken('bl', value);
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
    var controller;
    if (is_windows) {
      controller = WebviewController();
    } else {
      controller = WebViewController()
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
        ..setUserAgent(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3',
        )
        ..loadRequest(Uri.parse('https://music.163.com/'));
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoginWebview(
          controller: controller,
          config_key: 'ne',
          open_url: 'https://music.163.com/',
        ),
      ),
    );
  }

  void open_qq_login() async {
    var controller;
    if (is_windows) {
      controller = WebviewController();
    } else {
      controller = WebViewController()
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
        ..setUserAgent(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3',
        )
        ..loadRequest(Uri.parse('https://y.qq.com/'));
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoginWebview(
          controller: controller,
          config_key: 'qq',
          open_url: 'https://y.qq.com/',
        ),
      ),
    );
  }

  void get_useHttpOverrides() async {
    Map<String, dynamic> settings = settings_getsettings();
    if (settings["useHttpOverrides"] != null) {
      useHttpOverrides.value = settings["useHttpOverrides"];
    }
  }

  void set_useHttpOverrides(bool value) async {
    Get.find<SettingsController>().setSettings({'useHttpOverrides': value});
    showWarningSnackbar('重启应用后生效', null);
  }

  @override
  void initState() {
    super.initState();
    get_useHttpOverrides();
    init_apkfilepath();
    // 监听焦点变化
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        set_inapp_hotkey(false);
      } else {
        set_inapp_hotkey(true);
      }
    });
    _focusNode2.addListener(() {
      if (_focusNode2.hasFocus) {
        set_inapp_hotkey(false);
      } else {
        set_inapp_hotkey(true);
      }
    });
    _focusNode3.addListener(() {
      if (_focusNode3.hasFocus) {
        set_inapp_hotkey(false);
      } else {
        set_inapp_hotkey(true);
      }
    });
  }

  Future<void> init_apkfilepath() async {
    // 确保路径存在
    switch (SysInfo.kernelArchitecture.name) {
      case "ARM64":
        apkfile_name = await xuan_getdownloadDirectory(
          path: 'app-arm64-v8a-release.apk',
        );
      case "ARM":
        apkfile_name = await xuan_getdownloadDirectory(
          path: 'app-armeabi-v7a-release.apk',
        );
      case "X86_64":
        apkfile_name = await xuan_getdownloadDirectory(
          path: 'app-x86_64-release.apk',
        );
      default:
        apkfile_name = await xuan_getdownloadDirectory(path: 'app-release.apk');
    }
  }

  SettingsController settingsController = Get.find<SettingsController>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            actions: [
              WebSocketHelper.buildReactiveButton(tooltip: "WebSocket服务器"),
              WebSocketClientHelper.buildReactiveButton(
                tooltip: "WebSocket客户端",
              ),
            ],
            expandedHeight: 120.0,
            flexibleSpace: FlexibleSpaceBar(title: const Text('Settings')),
          ),
          SliverToBoxAdapter(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Obx(
                  () => ExpansionPanelList(
                    expansionCallback: (int index, bool isExpanded) {
                      if (isExpanded) {
                        settingsController.settingsPageExpansion.add(index);
                      } else {
                        settingsController.settingsPageExpansion.remove(index);
                      }
                    },
                    children: [
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: Icon(Icons.login),
                            title: const Text('第三方平台登录'),
                            trailing: IconButton(
                              onPressed: () async {
                                settingsController.refreshLoginData();
                              },
                              icon: Icon(Icons.refresh),
                            ),
                          );
                        },
                        canTapOnHeader: true,
                        isExpanded: settingsController.settingsPageExpansion
                            .contains(0),
                        body: Column(
                          children: <Widget>[
                            IntrinsicHeight(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Iconify(
                                        Ri.bilibili_fill,
                                        color: AdaptiveTheme.of(
                                          Get.context!,
                                        ).theme.iconTheme.color,
                                      ),

                                      ExtendedImage.network(
                                        "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/28469918905/0dfc/b6c0/d913/713572367ec9d917628e41266a39a67f.png",
                                        width: 18,
                                        height: 18,
                                        cache: true,
                                      ),

                                      ExtendedImage.network(
                                        "https://ts2.cn.mm.bing.net/th?id=ODLS.07d947f8-8fdd-4949-8b9a-be5283268438&w=32&h=32&qlt=90&pcl=fffffa&o=6&pid=1.2",
                                        cache: true,
                                        width: 18,
                                        height: 18,
                                      ),

                                      Iconify(
                                        Mdi.github,
                                        color: AdaptiveTheme.of(
                                          Get.context!,
                                        ).theme.iconTheme.color,
                                      ),
                                    ].map((e) => Expanded(child: Center(child: e))).toList(),
                                  ),
                                  Flexible(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Obx(() {
                                          bool isLoading = settingsController
                                              .loginDataLoading
                                              .contains(PlantformCodes.bl);
                                          final data = settingsController
                                              .loginData[PlantformCodes.bl];
                                          if (isLoading) {
                                            return globalLoadingAnime;
                                          } else {
                                            if (data == '') {
                                              return const Text('cookie未设置或失效');
                                            } else {
                                              return Text(data ?? 'Loading...');
                                            }
                                          }
                                        }),
                                        Obx(() {
                                          bool isLoading = settingsController
                                              .loginDataLoading
                                              .contains(PlantformCodes.ne);
                                          final data = settingsController
                                              .loginData[PlantformCodes.ne];
                                          if (isLoading) {
                                            return globalLoadingAnime;
                                          } else {
                                            if (data == '') {
                                              return const Text('cookie未设置或失效');
                                            } else {
                                              return Text(
                                                data?['result']?['nickname'] ??
                                                    '未知用户',
                                              );
                                            }
                                          }
                                        }),
                                        Obx(() {
                                          bool isLoading = settingsController
                                              .loginDataLoading
                                              .contains(PlantformCodes.qq);
                                          final data = settingsController
                                              .loginData[PlantformCodes.qq];
                                          if (isLoading) {
                                            return globalLoadingAnime;
                                          } else {
                                            if (data == '') {
                                              return const Text('cookie未设置或失效');
                                            } else {
                                              return Text(
                                                data?['data']?['nickname'] ??
                                                    '未知用户',
                                              );
                                            }
                                          }
                                        }),
                                        Obx(() {
                                          bool isLoading = settingsController
                                              .loginDataLoading
                                              .contains(PlantformCodes.github);
                                          final data = settingsController
                                              .loginData[PlantformCodes.github];
                                          if (isLoading) {
                                            return globalLoadingAnime;
                                          } else {
                                            if (data == '') {
                                              return const Text('cookie未设置或失效');
                                            } else {
                                              return Text(
                                                Github.getStatusText(),
                                              );
                                            }
                                          }
                                        }),
                                      ].map((e) => Expanded(child: Center(child: e))).toList(),
                                    ),
                                  ),
                                  Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children:
                                        [
                                              ElevatedButton(
                                                onPressed: () =>
                                                    open_bl_login(),
                                                child: const Text(
                                                  '设置bilibili cookie',
                                                ),
                                              ),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    open_netease_login(),
                                                child: const Text('登录网易云'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    open_qq_login(),
                                                child: const Text('登录QQ音乐'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    Github.openAuthUrl(context),
                                                child: const Text(
                                                  '登录Github(建议使用魔法',
                                                ),
                                              ),
                                            ]
                                            .map(
                                              (e) => Expanded(
                                                child: Center(child: e),
                                              ),
                                            )
                                            .map(
                                              (e) => Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 4.0,
                                                ),
                                                child: e,
                                              ),
                                            )
                                            .toList(),
                                  ),
                                ],
                              ),
                            ),

                            Obx(() {
                              WebSocketClientController wscc =
                                  Get.find<WebSocketClientController>();
                              return ElevatedButton(
                                onPressed: !wscc.isConnected
                                    ? null
                                    : () {
                                        wscc.sendGetCookieMessage();
                                      },
                                child: Text('从WebSocket服务器获取登录信息'),
                              );
                            }),
                          ].map((e) => Padding(padding: EdgeInsets.all(8.0), child: e)).toList(),
                        ),
                      ),
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: Icon(Icons.save),
                            title: const Text('歌单/配置文件'),
                          );
                        },
                        canTapOnHeader: true,
                        isExpanded: settingsController.settingsPageExpansion
                            .contains(1),
                        body: Padding(
                          padding: EdgeInsets.all(10),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          outputAllSettingsToFile(false),
                                      icon: Icon(Icons.save),
                                      label: Text('保存配置到文件'),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => importSettingsFromFile(),
                                      icon: Icon(Icons.upload),
                                      label: Text('导入配置文件'),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: outputPlaylistToGithubGist,
                                      icon: Icon(Icons.playlist_play),
                                      label: Text('导出歌单到Github Gist'),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        if (Github.status != 2) {
                                          // _msg('请先登录Github', 1.0);
                                          showWarningSnackbar(
                                            '请先登录Github Gist',
                                            null,
                                          );
                                          return;
                                        }
                                        var playlists =
                                            await Github.listExistBackup();
                                        print(playlists);

                                        try {
                                          showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                title: Text('从Github Gist导入歌单'),
                                                content: Container(
                                                  width: double.maxFinite,
                                                  child: ListView.builder(
                                                    shrinkWrap: true,
                                                    itemCount: playlists.length,
                                                    itemBuilder:
                                                        (
                                                          BuildContext context,
                                                          int index,
                                                        ) {
                                                          final playlist =
                                                              playlists[index];
                                                          return ListTile(
                                                            title: Text(
                                                              playlist['id'],
                                                            ),
                                                            subtitle: Text(
                                                              playlist['description'],
                                                            ),
                                                            onTap: () async {
                                                              try {
                                                                showInfoSnackbar(
                                                                  '正在导入',
                                                                  null,
                                                                );

                                                                final jsfile =
                                                                    await Github.importMySettingsFromGist(
                                                                      playlist['id'],
                                                                    );
                                                                final settings =
                                                                    await Github.gist2json(
                                                                      jsfile,
                                                                    );
                                                                await importSettingsFromFile(
                                                                  true,
                                                                  settings,
                                                                );
                                                                Navigator.of(
                                                                  context,
                                                                ).pop();
                                                                showSuccessSnackbar(
                                                                  '导入成功',
                                                                  null,
                                                                );
                                                              } catch (e) {
                                                                showErrorSnackbar(
                                                                  '导入失败',
                                                                  e.toString(),
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
                                                      Navigator.of(
                                                        context,
                                                      ).pop();
                                                    },
                                                    child: Text('取消'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        } catch (e) {
                                          showErrorSnackbar(
                                            '添加失败',
                                            e.toString(),
                                          );
                                        }
                                      },

                                      icon: Icon(Icons.playlist_add),
                                      label: Text('从Github Gist导入歌单'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: Iconify(
                              Octicon.cache_16,
                              color: AdaptiveTheme.of(
                                Get.context!,
                              ).theme.iconTheme.color,
                            ),
                            title: Text('缓存'),
                          );
                        },
                        canTapOnHeader: true,
                        isExpanded: settingsController.settingsPageExpansion
                            .contains(2),
                        body: Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            ...[
                              Obx(() {
                                WebSocketClientController wscc =
                                    Get.find<WebSocketClientController>();
                                return ElevatedButton(
                                  onPressed: !wscc.isConnected
                                      ? null
                                      : () {
                                          Get.toNamed(
                                            RouteName.downloadPage,
                                            id: 1,
                                          );
                                        },
                                  child: Text('从WebSocket服务器获取缓存文件'),
                                );
                              }),
                              ElevatedButton(
                                onPressed: () => clean_local_cache(),
                                child: const Text('清除未在配置文件中的歌曲缓存'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  final result = await showConfirmDialog(
                                    '确认清除所有歌曲缓存？此操作不可恢复',
                                    '清除所有缓存',
                                    confirmLevel: ConfirmLevel.danger,
                                  );
                                  if (!result) return;
                                  clean_local_cache(true);
                                },
                                child: const Text('清除所有歌曲缓存'),
                              ),
                            ].map(
                              (e) => Padding(
                                padding: EdgeInsets.all(8.0),
                                child: e,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: Icon(
                              is_windows
                                  ? Icons.keyboard_alt
                                  : Icons.notifications,
                            ),
                            title: Text(
                              is_windows ? '热键、代理、ffmpeg及其它win设置' : "通知设置",
                            ),
                          );
                        },
                        canTapOnHeader: true,
                        isExpanded: settingsController.settingsPageExpansion
                            .contains(3),
                        body: is_windows
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children:
                                    [
                                          Wrap(
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            alignment:
                                                WrapAlignment.spaceAround,

                                            children: create_hotkey_btns(
                                              context,
                                            ),
                                          ),
                                          FutureBuilder(
                                            // future: check_bl_cookie(),
                                            future: get_windows_proxy_addr(),
                                            builder:
                                                (
                                                  BuildContext context,
                                                  AsyncSnapshot<String>
                                                  snapshot,
                                                ) {
                                                  if (snapshot
                                                          .connectionState ==
                                                      ConnectionState.waiting) {
                                                    return globalLoadingAnime;
                                                  } else {
                                                    return TextField(
                                                      focusNode: _focusNode2,
                                                      controller:
                                                          TextEditingController(
                                                            text: snapshot.data,
                                                          ),
                                                      decoration: InputDecoration(
                                                        labelText:
                                                            'Windows代理地址,仅适用于Github,例如：localhost:7890,留空表示不使用,回车以保存',
                                                      ),
                                                      onSubmitted: (value) async {
                                                        Get.find<
                                                              SettingsController
                                                            >()
                                                            .setSettings({
                                                              'proxy': value,
                                                            });
                                                        showInfoSnackbar(
                                                          '设置成功$value，重启应用生效',
                                                          null,
                                                        );
                                                      },
                                                    );
                                                  }
                                                },
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  focusNode: _focusNode3,
                                                  controller:
                                                      TextEditingController(
                                                        text:
                                                            Get.find<
                                                                  PlayController
                                                                >()
                                                                .getPlayerSettings(
                                                                  'ffmpegPath',
                                                                ),
                                                      ),
                                                  decoration: InputDecoration(
                                                    labelText:
                                                        'FFmpeg路径,例如：C:\\ffmpeg\\bin\\ffmpeg.exe,留空表示使用默认,回车以保存',
                                                  ),
                                                  onSubmitted: (value) async {
                                                    var msg = '正在检查ffmpeg'.obs;
                                                    Get.find<CacheController>()
                                                            .ffmpegPathWindows =
                                                        value;
                                                    try {
                                                      showLoadingDialog(msg);
                                                      var isOk =
                                                          await Get.find<
                                                                CacheController
                                                              >()
                                                              .isFFmpegOk();
                                                      if (!isOk)
                                                        throw Exception(
                                                          'FFmpeg不可用',
                                                        );
                                                      Get.back();
                                                      showSuccessSnackbar(
                                                        '设置成功',
                                                        Get.find<
                                                              CacheController
                                                            >()
                                                            .checkFfmpegVersion,
                                                      );
                                                    } catch (e) {
                                                      Get.back();
                                                      showErrorSnackbar(
                                                        '错误',
                                                        e.toString(),
                                                      );
                                                    }
                                                  },
                                                ),
                                              ),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  var msg = '正在下载FFmpeg'.obs;
                                                  showLoadingDialog(msg);
                                                  try {
                                                    final res1 = (await Dio().get(
                                                      'https://h3.040905.xyz/default/https/api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest',
                                                    )).data;
                                                    debugPrint(
                                                      'FFmpeg最新版本信息: $res1',
                                                    );
                                                    List assets =
                                                        res1["assets"];
                                                    if (assets.isEmpty) {
                                                      throw Exception(
                                                        '没有可用的FFmpeg版本',
                                                      );
                                                    }
                                                    String downloadUrl = '';
                                                    for (var asset in assets) {
                                                      // ffmpeg-master-latest-win64-lgpl-shared.zip
                                                      if (asset['name']
                                                              .contains(
                                                                'ffmpeg',
                                                              ) &&
                                                          asset['name']
                                                              .contains(
                                                                'win64',
                                                              ) &&
                                                          asset['name']
                                                              .contains(
                                                                'lgpl',
                                                              ) &&
                                                          !asset['name']
                                                              .contains(
                                                                'shared',
                                                              )) {
                                                        downloadUrl =
                                                            asset['browser_download_url'];
                                                        break;
                                                      }
                                                    }
                                                    if (downloadUrl.isEmpty) {
                                                      throw Exception(
                                                        '没有可用的FFmpeg版本',
                                                      );
                                                    }
                                                    downloadUrl = downloadUrl
                                                        .replaceAll(
                                                          'https://',
                                                          'https://h3.040905.xyz/default/https/',
                                                        );
                                                    debugPrint(
                                                      'FFmpeg下载链接: $downloadUrl',
                                                    );
                                                    final tempPath =
                                                        (await xuan_getdownloadDirectory())
                                                            .path;
                                                    String filePath =
                                                        '$tempPath/ffmpeg.zip ';
                                                    await Dio().download(
                                                      downloadUrl,
                                                      filePath,
                                                      onReceiveProgress:
                                                          (received, total) {
                                                            if (total > 0) {
                                                              msg.value =
                                                                  '下载进度: ${(received / 1024 / 1024).toStringAsFixed(2)}MB/${(total / 1024 / 1024).toStringAsFixed(2)}MB';
                                                            }
                                                          },
                                                    );
                                                    msg.value =
                                                        '下载完成，正在解压FFmpeg';
                                                    final bytes = File(
                                                      filePath,
                                                    ).readAsBytesSync();
                                                    final archive = ZipDecoder()
                                                        .decodeBytes(bytes);
                                                    for (final file
                                                        in archive) {
                                                      var filename = file.name;
                                                      if (filename.contains(
                                                        'ffmpeg.exe',
                                                      )) {
                                                        filename = 'ffmpeg.exe';
                                                        final data =
                                                            file.content
                                                                as List<int>;
                                                        File(
                                                            '$tempPath/$filename',
                                                          )
                                                          ..createSync(
                                                            recursive: true,
                                                          )
                                                          ..writeAsBytesSync(
                                                            data,
                                                          );
                                                        break;
                                                      }
                                                    }
                                                    Get.find<CacheController>()
                                                            .ffmpegPathWindows =
                                                        '$tempPath/ffmpeg.exe';
                                                    msg.value = '正在删除压缩包';
                                                    await File(
                                                      filePath,
                                                    ).delete();
                                                    Get.back();
                                                    setState(() {});
                                                    showSuccessSnackbar(
                                                      '下载成功',
                                                      'FFmpeg已设置',
                                                    );
                                                  } catch (e) {
                                                    Get.back();
                                                    showErrorSnackbar(
                                                      '下载失败',
                                                      e.toString(),
                                                    );
                                                  }
                                                },
                                                child: Text('从GitHub下载FFmpeg'),
                                              ),
                                            ],
                                          ),
                                          Obx(
                                            () => SwitchListTile(
                                              title: const Text(
                                                '在右侧页面中键时隐藏/最小化主页面',
                                              ),
                                              value:
                                                  Get.find<SettingsController>()
                                                      .hideOrMinimize,
                                              onChanged: (bool value) {
                                                Get.find<SettingsController>()
                                                        .hideOrMinimize =
                                                    value;
                                                // _msg('设置成功', 1.0);
                                                showSuccessSnackbar(
                                                  '设置成功',
                                                  null,
                                                );
                                              },
                                            ),
                                          ),
                                        ]
                                        .map(
                                          (e) => Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 4.0,
                                            ),
                                            child: e,
                                          ),
                                        )
                                        .toList(),
                              )
                            : Column(
                                children: [
                                  Obx(
                                    () => SwitchListTile(
                                      title: const Text('尝试在通知中显示歌词'),
                                      value: Get.find<SettingsController>()
                                          .tryShowLyricInNotification,
                                      onChanged: (bool value) {
                                        Get.find<SettingsController>()
                                                .tryShowLyricInNotification =
                                            value;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: Icon(Icons.system_update),
                            title: Text('更新版本'),
                          );
                        },
                        canTapOnHeader: true,
                        isExpanded: settingsController.settingsPageExpansion
                            .contains(4),
                        body: Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            ...[
                              ElevatedButton(
                                onPressed: () async {
                                  var dia_context;

                                  if (is_windows) {
                                    try {
                                      final tempPath =
                                          (await xuan_getdownloadDirectory())
                                              .path;

                                      final filePath = '$tempPath\\canary.zip';
                                      final url_list =
                                          'https://api.github.com/repos/HBWuChang/listen1_xuan/actions/artifacts';
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      final token = prefs.getString(
                                        'githubOauthAccessKey',
                                      );
                                      if (token == null) {
                                        showWarningSnackbar('请先登录Github', null);
                                        return;
                                      }
                                      final response =
                                          await dio_with_ProxyAdapter.get(
                                            url_list,
                                            options: Options(
                                              headers: {
                                                'accept':
                                                    'application/vnd.github.v3+json',
                                                'authorization':
                                                    'Bearer ' + token,
                                                'x-github-api-version':
                                                    '2022-11-28',
                                              },
                                            ),
                                          );
                                      late var art;

                                      for (var i
                                          in response.data["artifacts"]) {
                                        if (i['name'].indexOf("windows") >= 0) {
                                          art = i;
                                          break;
                                        }
                                      }
                                      bool flag = true;
                                      if (await File(filePath).exists()) {
                                        // 获取sha256值
                                        var sha256 = await Process.run(
                                          'certutil',
                                          ['-hashfile', filePath, 'SHA256'],
                                        );
                                        var sha256_str = sha256.stdout
                                            .toString()
                                            .split('\n')[1]
                                            .trim();
                                        print('sha256: $sha256_str');
                                        String r_sha256 = art["digest"]
                                            .replaceAll("sha256:", "")
                                            .trim();
                                        if (sha256_str == r_sha256) {
                                          flag = false;
                                        }
                                      }
                                      if (flag) {
                                        final download_url =
                                            art["archive_download_url"];
                                        final created_at = art["created_at"];
                                        double total = art["size_in_bytes"]
                                            .toDouble();
                                        double received = 0;
                                        final StreamController<double>
                                        progressStreamController =
                                            StreamController<double>();
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (BuildContext context) {
                                            dia_context = context;
                                            return PopScope(
                                              canPop: false,
                                              onPopInvokedWithResult:
                                                  (didPop, result) => {},
                                              child: StatefulBuilder(
                                                builder:
                                                    (
                                                      BuildContext context,
                                                      StateSetter setState,
                                                    ) {
                                                      return AlertDialog(
                                                        title: Text(
                                                          '下载进度: ${created_at}',
                                                        ),
                                                        content: StreamBuilder<double>(
                                                          stream:
                                                              progressStreamController
                                                                  .stream,
                                                          builder: (context, snapshot) {
                                                            double progress =
                                                                snapshot.data ??
                                                                0;
                                                            return Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                LinearProgressIndicator(
                                                                  value:
                                                                      progress,
                                                                ),
                                                                SizedBox(
                                                                  height: 20,
                                                                ),
                                                                Text(
                                                                  '${(progress * total / 1024 / 1024).toStringAsFixed(2)}MB/${(total / 1024 / 1024).toStringAsFixed(2)}MB',
                                                                ),
                                                              ],
                                                            );
                                                          },
                                                        ),
                                                      );
                                                    },
                                              ),
                                            );
                                          },
                                        );
                                        await dio_with_ProxyAdapter.download(
                                          download_url,
                                          filePath,
                                          options: Options(
                                            headers: {
                                              'accept':
                                                  'application/vnd.github.v3+json',
                                              'authorization':
                                                  'Bearer ' + token,
                                              'x-github-api-version':
                                                  '2022-11-28',
                                            },
                                          ),
                                          onReceiveProgress:
                                              (receivedBytes, totalBytes) {
                                                received = receivedBytes
                                                    .toDouble();
                                                double progress =
                                                    received / total;
                                                progressStreamController.add(
                                                  progress,
                                                );
                                              },
                                        );
                                        try {
                                          Navigator.of(
                                            dia_context,
                                          ).pop(); // 关闭进度条对话框
                                        } catch (e) {
                                          print('关闭进度条对话框失败: $e');
                                        }
                                      }
                                      showSuccessSnackbar('下载成功', null);
                                      // 解压 ZIP 文件
                                      final bytes = File(
                                        filePath,
                                      ).readAsBytesSync();
                                      final archive = ZipDecoder().decodeBytes(
                                        bytes,
                                      );
                                      // 删除canary文件夹
                                      final canaryDir = Directory(
                                        '$tempPath\\canary',
                                      );
                                      if (await canaryDir.exists()) {
                                        await canaryDir.delete(recursive: true);
                                      }
                                      for (final file in archive) {
                                        final filename = file.name;
                                        if (file.isFile) {
                                          final data =
                                              file.content as List<int>;
                                          File('$tempPath\\canary\\$filename')
                                            ..createSync(recursive: true)
                                            ..writeAsBytesSync(data);
                                        } else {
                                          Directory(
                                            '$filePath\\canary\\$filename',
                                          ).create(recursive: true);
                                        }
                                      }
                                      String executablePath =
                                          Platform.resolvedExecutable;
                                      String executableDir = File(
                                        executablePath,
                                      ).parent.path;
                                      print(executableDir);
                                      createAndRunBatFile(
                                        tempPath,
                                        executableDir,
                                      );
                                    } catch (e) {
                                      try {
                                        Navigator.of(
                                          dia_context,
                                        ).pop(); // 关闭进度条对话框
                                      } catch (e) {
                                        print('关闭进度条对话框失败: $e');
                                      }
                                      showErrorSnackbar('下载失败', e.toString());
                                    }
                                  } else {
                                    try {
                                      if (await Permission.manageExternalStorage
                                              .request()
                                              .isGranted ||
                                          await Permission.storage
                                              .request()
                                              .isGranted) {
                                        final tempPath =
                                            (await xuan_getdownloadDirectory())
                                                .path;

                                        final apkFile = File(apkfile_name);
                                        print('apkFile: $apkFile');
                                        if (await apkFile.exists()) {
                                          try {
                                            InstallPlugin.installApk(
                                                  apkfile_name,
                                                )
                                                .then((result) {
                                                  print('install apk $result');
                                                })
                                                .catchError((error) {
                                                  print(
                                                    'install apk error: $error',
                                                  );
                                                });
                                            return;
                                          } catch (e) {
                                            print('安装APK失败: $e');
                                            return;
                                          }
                                        }
                                        final filePath = '$tempPath/canary.zip';

                                        final url_list =
                                            'https://api.github.com/repos/HBWuChang/listen1_xuan/actions/artifacts';
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        final token = prefs.getString(
                                          'githubOauthAccessKey',
                                        );
                                        if (token == null) {
                                          showWarningSnackbar('请先登录Github', null);
                                          return;
                                        }
                                        final response =
                                            await dio_with_ProxyAdapter.get(
                                              url_list,
                                              options: Options(
                                                headers: {
                                                  'accept':
                                                      'application/vnd.github.v3+json',
                                                  'authorization':
                                                      'Bearer ' + token,
                                                  'x-github-api-version':
                                                      '2022-11-28',
                                                },
                                              ),
                                            );
                                        print(
                                          'Kernel architecture: ${SysInfo.kernelArchitecture.name}',
                                        );
                                        late var art;

                                        switch (SysInfo
                                            .kernelArchitecture
                                            .name) {
                                          case "ARM64":
                                            for (var i
                                                in response.data["artifacts"]) {
                                              if (i['name'].indexOf("arm64") >
                                                  0) {
                                                art = i;
                                                break;
                                              }
                                            }
                                          case "ARM":
                                            for (var i
                                                in response.data["artifacts"]) {
                                              if (i['name'].indexOf("armeabi") >
                                                  0) {
                                                art = i;
                                                break;
                                              }
                                            }
                                          case "X86_64":
                                            for (var i
                                                in response.data["artifacts"]) {
                                              if (i['name'].indexOf("x86_64") >
                                                  0) {
                                                art = i;
                                                break;
                                              }
                                            }
                                          default:
                                            art = response.data["artifacts"][0];
                                        }
                                        final download_url =
                                            art["archive_download_url"];
                                        final created_at = art["created_at"];
                                        double total = art["size_in_bytes"]
                                            .toDouble();
                                        double received = 0;
                                        final StreamController<double>
                                        progressStreamController =
                                            StreamController<double>();
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (BuildContext context) {
                                            dia_context = context;
                                            return PopScope(
                                              canPop: false,
                                              onPopInvokedWithResult:
                                                  (didPop, result) => {},
                                              child: StatefulBuilder(
                                                builder:
                                                    (
                                                      BuildContext context,
                                                      StateSetter setState,
                                                    ) {
                                                      return AlertDialog(
                                                        title: Text(
                                                          '下载进度: ${created_at}',
                                                        ),
                                                        content: StreamBuilder<double>(
                                                          stream:
                                                              progressStreamController
                                                                  .stream,
                                                          builder: (context, snapshot) {
                                                            double progress =
                                                                snapshot.data ??
                                                                0;
                                                            return Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                LinearProgressIndicator(
                                                                  value:
                                                                      progress,
                                                                ),
                                                                SizedBox(
                                                                  height: 20,
                                                                ),
                                                                Text(
                                                                  '${(progress * total / 1024 / 1024).toStringAsFixed(2)}MB/${(total / 1024 / 1024).toStringAsFixed(2)}MB',
                                                                ),
                                                              ],
                                                            );
                                                          },
                                                        ),
                                                      );
                                                    },
                                              ),
                                            );
                                          },
                                        );
                                        // 首先获取302重定向的实际下载链接
                                        final redirectResponse =
                                            await dio_with_ProxyAdapter.get(
                                              download_url,
                                              options: Options(
                                                followRedirects: false,
                                                validateStatus: (status) =>
                                                    status! < 400,
                                                headers: {
                                                  'accept':
                                                      'application/vnd.github.v3+json',
                                                  'authorization':
                                                      'Bearer ' + token,
                                                  'x-github-api-version':
                                                      '2022-11-28',
                                                },
                                              ),
                                            );
                                        String actualDownloadUrl = download_url;
                                        if (redirectResponse.statusCode ==
                                            302) {
                                          actualDownloadUrl =
                                              redirectResponse.headers.value(
                                                'location',
                                              ) ??
                                              download_url;
                                        }

                                        // 使用实际下载链接进行下载，不添加GitHub API请求头
                                        await dio_with_ProxyAdapter.download(
                                          // await Dio().download(
                                          actualDownloadUrl,
                                          filePath,
                                          onReceiveProgress:
                                              (receivedBytes, totalBytes) {
                                                received = receivedBytes
                                                    .toDouble();
                                                double progress =
                                                    received / total;
                                                progressStreamController.add(
                                                  progress,
                                                );
                                              },
                                        );

                                        try {
                                          Navigator.of(
                                            dia_context,
                                          ).pop(); // 关闭进度条对话框
                                        } catch (e) {
                                          print('关闭进度条对话框失败: $e');
                                        }
                                        // 解压 ZIP 文件
                                        final bytes = File(
                                          filePath,
                                        ).readAsBytesSync();
                                        final archive = ZipDecoder()
                                            .decodeBytes(bytes);

                                        for (final file in archive) {
                                          final filename = file.name;
                                          if (file.isFile) {
                                            final data =
                                                file.content as List<int>;
                                            File('$tempPath/$filename')
                                              ..createSync(recursive: true)
                                              ..writeAsBytesSync(data);
                                          } else {
                                            Directory(
                                              '$filePath/$filename',
                                            ).create(recursive: true);
                                          }
                                        }
                                        if (await apkFile.exists()) {
                                          try {
                                            InstallPlugin.installApk(
                                                  apkfile_name,
                                                )
                                                .then((result) {
                                                  print('install apk $result');
                                                })
                                                .catchError((error) {
                                                  print(
                                                    'install apk error: $error',
                                                  );
                                                });
                                          } catch (e) {
                                            print('安装APK失败: $e');
                                          }
                                        } else {
                                          showErrorSnackbar('APK 文件未找到', null);
                                        }
                                        showSuccessSnackbar('下载成功', null);
                                      } else {
                                        throw Exception("没有权限访问存储空间");
                                      }
                                    } catch (e) {
                                      try {
                                        Navigator.of(
                                          dia_context,
                                        ).pop(); // 关闭进度条对话框
                                      } catch (e) {
                                        print('关闭进度条对话框失败: $e');
                                      }
                                      showErrorSnackbar('下载失败', e.toString());
                                    }
                                  }
                                },
                                child: const Text('下载最新测试版'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  g_launchURL(
                                    Uri.parse(
                                      'https://github.com/HBWuChang/listen1_xuan/releases',
                                    ),
                                  );
                                },
                                child: Text('打开GitHub Release页面'),
                              ),
                              if (!is_windows)
                                ElevatedButton(
                                  onPressed: () async {
                                    if (await Permission.manageExternalStorage
                                            .request()
                                            .isGranted ||
                                        await Permission.storage
                                            .request()
                                            .isGranted) {
                                      final tempDir =
                                          await getApplicationDocumentsDirectory();
                                      var tempPath = tempDir.path;
                                      var filePath = '$tempPath/canary.zip';

                                      var file = File(filePath);
                                      if (await file.exists()) {
                                        await file.delete();
                                      }
                                      file = File(
                                        '$tempPath/app-arm64-v8a-release.apk',
                                      );
                                      if (await file.exists()) {
                                        await file.delete();
                                      }
                                      file = File(
                                        '$tempPath/app-armeabi-v7a-release.apk',
                                      );
                                      if (await file.exists()) {
                                        await file.delete();
                                      }
                                      file = File(
                                        '$tempPath/app-x86_64-release.apk',
                                      );
                                      if (await file.exists()) {
                                        await file.delete();
                                      }
                                      file = File('$tempPath/app-release.apk');
                                      if (await file.exists()) {
                                        await file.delete();
                                      }
                                      tempPath =
                                          '/storage/emulated/0/Download/Listen1';
                                      filePath = '$tempPath/canary.zip';

                                      file = File(filePath);
                                      if (await file.exists()) {
                                        await file.delete();
                                      }
                                      file = File(
                                        '$tempPath/app-arm64-v8a-release.apk',
                                      );
                                      if (await file.exists()) {
                                        await file.delete();
                                      }
                                      file = File(
                                        '$tempPath/app-armeabi-v7a-release.apk',
                                      );
                                      if (await file.exists()) {
                                        await file.delete();
                                      }
                                      file = File(
                                        '$tempPath/app-x86_64-release.apk',
                                      );
                                      if (await file.exists()) {
                                        await file.delete();
                                      }
                                      file = File('$tempPath/app-release.apk');
                                      if (await file.exists()) {
                                        await file.delete();
                                      }

                                      showSuccessSnackbar('清理成功', null);
                                    } else {
                                      showErrorSnackbar(
                                        '没有权限访问存储空间',
                                        null,
                                      );
                                    }
                                  },
                                  child: const Text('清除安装包缓存'),
                                ),
                            ].map(
                              (e) => Padding(
                                padding: EdgeInsets.all(8.0),
                                child: e,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: Icon(Icons.miscellaneous_services),
                            title: Text('杂项'),
                          );
                        },
                        canTapOnHeader: true,
                        isExpanded: settingsController.settingsPageExpansion
                            .contains(5),
                        body: Column(
                          children: [
                            Obx(
                              () => SwitchListTile(
                                title: const Text('禁用ssl证书验证'),
                                value: useHttpOverrides.value,
                                onChanged: (bool value) {
                                  set_useHttpOverrides(value);
                                  useHttpOverrides.value = value;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.color_lens),
                  title: Text('主题设置'),
                  trailing: ThemeToggleButton(
                    iconSize: 24.0, // 可选：自定义图标大小
                    padding: EdgeInsets.all(0), // 可选：自定义内边距
                  ),
                  onTap: () {
                    Get.dialog(ThemeSettingsDialog(), barrierDismissible: true);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.book),
                  title: Text('查看README'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {
                    Get.toNamed(RouteName.settingsReadmePage, id: 1);
                  },
                ),
                SizedBox(height: 0.3.sh),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Github {
  static const String OAUTH_URL = 'https://github.com/login/oauth';
  static const String API_URL = 'https://api.github.com';

  static const String clientId = 'e099a4803bb1e2e773a3';
  static const String clientSecret = '81fbfc45c65af8c0fbf2b4dae6f23f22e656cfb8';

  static int status = 0;
  static String username = '';
  static bool usedefault = false;

  static Future<void> handleCallback(String code, BuildContext context) async {
    // _msg('正在向Github请求信息', context, 1.0);
    showInfoSnackbar('正在向Github请求信息', '');
    String res = "";
    try {
      final url = '$OAUTH_URL/access_token';
      final params = {
        'client_id': clientId,
        'client_secret': clientSecret,
        'code': code,
      };
      var response;
      try {
        // throw Exception('使用代理适配器请求失败，尝试使用默认Dio请求');
        response = await dio_with_ProxyAdapter.post(
          url,
          queryParameters: params,
          options: Options(headers: {'Accept': 'application/json'}),
        );
        res = response.data.toString();
      } catch (e) {
        // _msg('代理适配请求失败,尝试使用默认Dio请求...', context, 1.0);
        showInfoSnackbar('代理适配请求失败,尝试使用默认Dio请求...', null);
        response = await Dio().post(
          url,
          queryParameters: params,
          options: Options(headers: {'Accept': 'application/json'}),
        );
        res = response.data.toString();
      }
      final accessToken = response.data['access_token'];
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('githubOauthAccessKey', accessToken);

      showInfoSnackbar('设置成功', null);
    } catch (e) {
      Clipboard.setData(ClipboardData(text: e.toString() + res));
      showInfoSnackbar('设置失败，错误信息已复制到剪切板$e\n网络请求返回值：$res', null);
    }
  }

  static void openAuthUrl(BuildContext context) {
    status = 1;
    final url =
        '$OAUTH_URL/authorize?client_id=$clientId&scope=gist,public_repo';

    var controller;
    if (is_windows) {
      controller = WebviewController();
    } else {
      controller = WebViewController()
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
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoginWebview(
          controller: controller,
          config_key: 'github',
          open_url: url,
        ),
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
      var response;
      try {
        response = await dio_with_ProxyAdapter.get(
          '$API_URL/user',
          options: Options(
            headers: {
              'Authorization': 'token $accessToken',
              'Accept': 'application/json',
            },
          ),
        );
      } catch (e) {
        usedefault = true;
        response = await Dio().get(
          '$API_URL/user',
          options: Options(
            headers: {
              'Authorization': 'token $accessToken',
              'Accept': 'application/json',
            },
          ),
        );
      }

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

    result['listen1_backup.json'] = {'content': json.encode(jsonObject)};

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
      result[filename] = {'content': content};
      return (count as int) + (playlist['tracks'].length as int);
    });
    final summary =
        '本歌单由[listen1_xuan](https://github.com/HBWuChang/listen1_xuan)创建, 歌曲数：$songsCount，歌单数：${playlistIds.length}，点击查看更多';
    result['listen1_aha_playlist.md'] = {'content': summary};

    return result;
  }

  static Future<Map<String, dynamic>> gist2json(
    Map<String, dynamic> gistFiles,
  ) async {
    if (!gistFiles['listen1_backup.json']['truncated']) {
      final jsonString = gistFiles['listen1_backup.json']['content'];
      return json.decode(jsonString);
    } else {
      final url = gistFiles['listen1_backup.json']['raw_url'];
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('githubOauthAccessKey');
      final response = await (usedefault ? Dio() : dio_with_ProxyAdapter).get(
        url,
        options: Options(
          headers: {
            'Authorization': 'token $accessToken',
            'Accept': 'application/json',
          },
        ),
      );
      return json.decode(response.data);
    }
  }

  static Future<List<dynamic>> listExistBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('githubOauthAccessKey');
    final response = await (usedefault ? Dio() : dio_with_ProxyAdapter).get(
      '$API_URL/gists',
      options: Options(
        headers: {
          'Authorization': 'token $accessToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      ),
    );
    final result = response.data;
    return result.where((backupObject) {
      return backupObject['description'] != null &&
          backupObject['description'].startsWith('updated by Listen1');
    }).toList();
  }

  static Future<void> backupMySettings2Gist(
    Map<String, dynamic> files,
    String? gistId,
    bool isPublic,
  ) async {
    String method;
    String url;
    if (gistId != null) {
      method = 'patch';
      url = '$API_URL/gists/$gistId';
    } else {
      method = 'post';
      url = '$API_URL/gists';
    }
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('githubOauthAccessKey');
    await (usedefault ? Dio() : dio_with_ProxyAdapter).request(
      url,
      options: Options(
        method: method,
        headers: {
          'Authorization': 'token $accessToken',
          'Accept': 'application/json',
        },
      ),
      data: {
        'description':
            'updated by Listen1_xuan(https://github.com/HBWuChang/listen1_xuan) at ${DateTime.now().toLocal()}',
        'public': isPublic,
        'files': files,
      },
    );
  }

  static Future<Map<String, dynamic>> importMySettingsFromGist(
    String gistId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('githubOauthAccessKey');
    final response = await (usedefault ? Dio() : dio_with_ProxyAdapter).get(
      '$API_URL/gists/$gistId',
      options: Options(
        headers: {
          'Authorization': 'token $accessToken',
          'Accept': 'application/json',
        },
      ),
    );
    return response.data['files'];
  }
}
