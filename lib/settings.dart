import 'dart:convert';
import 'dart:ui';
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
import 'controllers/DioController.dart';
import 'controllers/cache_controller.dart';
import 'controllers/myPlaylist_controller.dart';
import 'controllers/play_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/supabase_auth_controller.dart';
import 'controllers/websocket_client_controller.dart';
import 'pages/settings/settings_supabase_login_page.dart';
import 'examples/equalizer_integration_example.dart';
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
import 'package:iconify_flutter_plus/icons/fa_solid.dart';
import 'package:path/path.dart' as p;
import 'utils/curve_utils.dart';
import 'widgets/curve_selector_dialog.dart';
part 'pages/settings/settings_utils.dart';
part 'pages/settings/settings_github.dart';
part 'pages/settings/settings_widgets.dart';
part 'pages/settings/settings_widgets_upd.dart';
part 'pages/settings/settings_widgets_settings.dart';

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

class _LoginWebviewState extends State<LoginWebview> {
  final List<StreamSubscription> _subscriptions = [];
  late String nowurl;
  Future<void> get__cookie() async {
    switch (widget.config_key) {
      case 'github':
        final url = isWindows ? nowurl : await widget.controller.currentUrl();
        if (url == null) {
          // _msg('获取cookie失败', 3.0);
          showErrorSnackbar('获取cookie失败', null);
          return;
        }
        print(url);
        if (!url.contains('code=')) {
          // _msg('获取code失败', 3.0);
          showErrorSnackbar('获取code失败', '请确认已跳转到Github授权成功页面再点击按钮');
          return;
        }
        final code = url?.split('code=')[1];
        await Github.handleCallback(code ?? '', context);
        break;
      default:
        if (isWindows) {
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
          if (isMacOS) {
            // TODO: MacOS 支持
            showErrorSnackbar('MacOS暂不支持此功能', null);
            return;
          }
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
    if (isWindows) initPlatformState();
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
      body: isWindows
          ? compositeView()
          : WebViewWidget(controller: widget.controller),
    );
  }
}

late String apkfile_name;
Future<void> init_apkfilepath() async {
  // 确保路径存在
  switch (SysInfo.kernelArchitecture.name) {
    case "ARM64":
      apkfile_name = await xuanGetdownloadDirectory(
        path: 'app-arm64-v8a-release.apk',
      );
    case "ARM":
      apkfile_name = await xuanGetdownloadDirectory(
        path: 'app-armeabi-v7a-release.apk',
      );
    case "X86_64":
      apkfile_name = await xuanGetdownloadDirectory(
        path: 'app-x86_64-release.apk',
      );
    default:
      apkfile_name = await xuanGetdownloadDirectory(path: 'app-release.apk');
  }
}

class _SettingsPageState extends State<SettingsPage> {
  var useHttpOverrides = false.obs;
  final FocusNode _focusNode = FocusNode();
  final FocusNode _focusNode2 = FocusNode();
  final FocusNode _focusNode3 = FocusNode();
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
                      await savePlatformToken(PlantformCodes.bl, value);
                      showSuccessSnackbar('设置成功', null);
                      Navigator.pop(context);
                      setState(() {});
                    },
                    onChanged: (value) async {
                      await savePlatformToken(PlantformCodes.bl, value);
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
    if (isWindows) {
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
    if (isWindows) {
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
                      // Supabase 登录面板
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: Icon(Icons.person),
                            title: const Text('Supabase 账号（现在没有任何用'),
                            trailing: IconButton(
                              onPressed: () async {
                                Get.find<SupabaseAuthController>()
                                    .refreshUserProfile();
                              },
                              icon: Icon(Icons.refresh),
                            ),
                          );
                        },
                        canTapOnHeader: true,
                        isExpanded: settingsController.settingsPageExpansion
                            .contains(0),
                        body: _buildSupabaseLoginPanel(),
                      ),
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
                            .contains(1),
                        body: _buildThirdPartyLoginPanel(
                          context,
                          open_bl_login,
                          open_netease_login,
                          open_qq_login,
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
                            .contains(2),
                        body: settingsWidget(context),
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
                            .contains(3),
                        body: Wrap(
                          alignment: WrapAlignment.center,
                          children: [...cacheSettingsTiles],
                        ),
                      ),
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: Icon(
                              isWindows
                                  ? Icons.keyboard_alt
                                  : isAndroid
                                  ? Icons.notifications
                                  : Icons.device_unknown,
                            ),
                            title: Text(
                              isWindows
                                  ? '热键、代理、ffmpeg及其它win设置'
                                  : isAndroid
                                  ? "通知设置"
                                  : "未知平台设置",
                            ),
                          );
                        },
                        canTapOnHeader: true,
                        isExpanded: settingsController.settingsPageExpansion
                            .contains(4),
                        body: isWindows
                            ? winSettingsTiles(
                                context,
                                _focusNode2,
                                _focusNode3,
                              )
                            : isAndroid
                            ? androidSettingsTiles
                            : SizedBox.shrink(),
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
                            .contains(5),
                        body: updSettingsTile(context),
                      ),
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: Iconify(
                              FaSolid.tshirt,
                              color: AdaptiveTheme.of(
                                Get.context!,
                              ).theme.iconTheme.color,
                              size: 18,
                            ),
                            title: Text('外观设置'),
                          );
                        },
                        canTapOnHeader: true,
                        isExpanded: settingsController.settingsPageExpansion
                            .contains(6),
                        body: themeSettingsTiles,
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
                            .contains(7),
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
                // buildEqualizerTile(context),

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
