import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:listen1_xuan/controllers/controllers.dart';
import 'package:listen1_xuan/controllers/settings_controller.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:flutter_audio_tagger/flutter_audio_tagger.dart';
import 'package:flutter_audio_tagger/tag.dart';
import 'package:listen1_xuan/pages/lyric_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'controllers/audioHandler_controller.dart';
import 'controllers/lyric_controller.dart';
import 'controllers/myPlaylist_controller.dart';
import 'controllers/nowplaying_controller.dart';
import 'controllers/play_controller.dart';
import 'examples/websocket_server_example.dart';
import 'examples/websocket_client_example.dart';
import 'pages/nowPlaying_page.dart';
import 'settings.dart';
import 'loweb.dart';
import 'bodys.dart';
import 'play.dart';
import 'global_settings_animations.dart';
import 'widgets.dart';
import 'dart:async';
import 'dart:isolate';
import 'package:flutter_isolate/flutter_isolate.dart';
import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:preload_page_view/preload_page_view.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:flutter/gestures.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';
import 'package:windows_taskbar/windows_taskbar.dart';
import 'package:smtc_windows/smtc_windows.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:metadata_god/metadata_god.dart';
import 'controllers/theme.dart';
import 'package:ffmpeg_kit_flutter_new_min/abstract_session.dart';
import 'package:ffmpeg_kit_flutter_new_min/arch_detect.dart';
import 'package:ffmpeg_kit_flutter_new_min/chapter.dart';
import 'package:ffmpeg_kit_flutter_new_min/extensions.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_session_complete_callback.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffprobe_session.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffprobe_session_complete_callback.dart';
import 'package:ffmpeg_kit_flutter_new_min/level.dart';
import 'package:ffmpeg_kit_flutter_new_min/log.dart';
import 'package:ffmpeg_kit_flutter_new_min/log_callback.dart';
import 'package:ffmpeg_kit_flutter_new_min/log_redirection_strategy.dart';
import 'package:ffmpeg_kit_flutter_new_min/media_information.dart';
import 'package:ffmpeg_kit_flutter_new_min/media_information_json_parser.dart';
import 'package:ffmpeg_kit_flutter_new_min/media_information_session.dart';
import 'package:ffmpeg_kit_flutter_new_min/media_information_session_complete_callback.dart';
import 'package:ffmpeg_kit_flutter_new_min/packages.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_min/session.dart';
import 'package:ffmpeg_kit_flutter_new_min/session_state.dart';
import 'package:ffmpeg_kit_flutter_new_min/signal.dart';
import 'package:ffmpeg_kit_flutter_new_min/statistics.dart';
import 'package:ffmpeg_kit_flutter_new_min/statistics_callback.dart';
import 'package:ffmpeg_kit_flutter_new_min/stream_information.dart';
import 'package:app_links/app_links.dart';

final dio_with_cookie_manager = Dio();
final dio_with_ProxyAdapter = Dio();

int disposedByClean = 0;

class ListenPopMiddleware extends GetMiddleware {
  @override
  void onPageDispose() {
    print("onPageDispose: ${Get.currentRoute}");
    if (disposedByClean > 0) {
      disposedByClean--;
    } else {
      top_routeWithName.removeLast();
    }
  }
}

int last_dir = 0;

class routeWithName {
  final Route route;
  final String name;
  routeWithName(this.route, this.name);
}

List<routeWithName> top_routeWithName = List.empty(growable: true);

void addAndCleanReapeatRoute(Route route, String name) {
  if (top_routeWithName.isNotEmpty) {
    // 清除重复的路由
    top_routeWithName.removeWhere((r) {
      if (r.route.settings.name == route.settings.name) {
        disposedByClean++;
        Get.removeRoute(r.route, id: 1);
        return true;
      }
      return false;
    });
  }
  top_routeWithName.add(routeWithName(route, name));
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

late SendPort download_sendport;
var download_receiveport = ReceivePort();

Future<bool> add_to_download_tasks(List<String> download_tasks) async {
  try {
    download_sendport.send(download_tasks);
    return true;
  } catch (e) {
    return false;
  }
}

@pragma('vm:entry-point')
void downloadtasks_background(SendPort mainPort) async {
  Future get_download_tasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> download_tasks = jsonDecode(
      prefs.getString("download_tasks") ?? "{}",
    );
    if (download_tasks.isEmpty) {
      return {"waiting": [], "downloading": [], "downloaded": [], "failed": []};
    }
    return download_tasks;
  }

  Future set_download_tasks(Map<String, dynamic> download_tasks) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("download_tasks", jsonEncode(download_tasks));
  }

  final receivePort = ReceivePort();
  mainPort.send(receivePort.sendPort);
  for (var i = 0; i < 20; i++) {
    print("background");
  }
  receivePort.listen((message) async {
    print("background receive: $message");
    if (message == "get_download_tasks") {
      await get_download_tasks();
    }
    // 若为List<String>
    if (message is List<String>) {
      Map<String, dynamic> download_tasks = await get_download_tasks();
      for (var item in message) {
        if (download_tasks["waiting"].contains(item) ||
            download_tasks["downloading"].contains(item) ||
            download_tasks["downloaded"].contains(item)) {
          continue;
        }
        if (download_tasks["failed"].contains(item)) {
          download_tasks["failed"].remove(item);
        }
        if (await get_local_cache(item) != '') {
          download_tasks["downloaded"].add(item);
          continue;
        }
        download_tasks["waiting"].add(item);
      }
      await set_download_tasks(download_tasks);
    }
  });
}

void enableThumbnailToolbar() async {
  while (true) {
    try {
      await WindowsTaskbar.setThumbnailToolbar([
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon(
            'assets/images/audio_service_skip_previous.ico',
          ),
          '上一首',
          () {
            global_skipToPrevious();
          },
        ),
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon('assets/images/audio_service_pause.ico'),
          '播放/暂停',
          () {
            global_play_or_pause();
          },
        ),
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon(
            'assets/images/audio_service_skip_next.ico',
          ),
          '下一首',
          () {
            global_skipToNext();
          },
        ),
      ]);
      break;
    } catch (e) {
      print("ThumbnailToolbar error: $e");
      Future.delayed(Duration(seconds: 3));
    }
  }
}

void main() async {
  await WidgetsFlutterBinding.ensureInitialized(); // 确保 Flutter框架已初始化
  if (is_windows) {
    MetadataGod.initialize();
  }
  SettingsController settingsController = Get.put(
    SettingsController(),
    permanent: true,
  );
  await settingsController.loadSettings();

  Get.put(PlayController(), permanent: true);
  Get.find<PlayController>().loadDatas();
  CacheController cacheController = Get.put(CacheController(), permanent: true);
  cacheController.loadLocalCacheList();
  await cacheController.moveOldData();
  Get.put(MyPlayListController(), permanent: true);
  Get.find<MyPlayListController>().loadDatas();
  Get.put(AudioHandlerController(), permanent: true);
  Get.put(LyricController(), permanent: true);
  Get.put(NowPlayingController(), permanent: true);
  Get.put(Applinkscontroller(), permanent: true);

  if (is_windows) {
    SMTCWindows.initialize();
    enableThumbnailToolbar();
    JustAudioMediaKit.ensureInitialized(
      linux: false, // default: true  - dependency: media_kit_libs_linux
      windows:
          true, // default: true  - dependency: media_kit_libs_windows_audio
    );
    // Must add this line.
    await windowManager.ensureInitialized();
    await hotKeyManager.unregisterAll();
    WindowOptions windowOptions = WindowOptions(
      size: Size(1000, 700),
      minimumSize: Size(400, 700),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
    });
    enableThumbnailToolbar();
  }

  // 初始化WebSocket控制器并加载配置
  WebSocketCardController wsController = Get.put(
    WebSocketCardController(),
    permanent: true,
  );
  wsController.loadWebSocketSettings();
  // 如果设置了自动启动，则启动WebSocket服务器
  wsController.autoStartServerIfNeeded();

  // 初始化WebSocket客户端控制器并加载配置
  WebSocketClientController wsClientController = Get.put(
    WebSocketClientController(),
    permanent: true,
  );
  wsClientController.loadWebSocketClientSettings();
  // 如果设置了自动连接，则连接WebSocket服务器
  wsClientController.autoConnectIfNeeded();

  Map<String, dynamic> settings = settings_getsettings();
  bool useHttpOverrides = false;
  if (settings["useHttpOverrides"] == null) {
    settings["useHttpOverrides"] = false;
    Get.find<SettingsController>().setSettings(settings);
  } else {
    useHttpOverrides = settings["useHttpOverrides"];
  }
  // 根据设置的值决定是否运行 HttpOverrides.global = MyHttpOverrides();
  if (useHttpOverrides) {
    HttpOverrides.global = MyHttpOverrides();
  }

  final appDocDir = await getApplicationDocumentsDirectory();
  final _cookiePath = cookiePath(appDocDir);
  final cookieDir = Directory(_cookiePath);
  if (!await cookieDir.exists()) {
    await cookieDir.create(recursive: true);
  }
  if (!is_windows) {
    dio_with_ProxyAdapter.httpClientAdapter = NativeAdapter(
      createCupertinoConfiguration: () =>
          URLSessionConfiguration.ephemeralSessionConfiguration()
            ..allowsCellularAccess = true
            ..allowsConstrainedNetworkAccess = true
            ..allowsExpensiveNetworkAccess = true,
    );
  } else {
    var proxyaddr = await get_windows_proxy_addr();
    if (proxyaddr != "") {
      dio_with_ProxyAdapter.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.findProxy = (uri) {
            return 'PROXY $proxyaddr';
          };
          return client;
        },
      );
    }
  }
  // 创建 PersistCookieJar 实例
  final cookieJar = PersistCookieJar(
    storage: FileStorage(_cookiePath),
    ignoreExpires: true,
  );

  // 将 PersistCookieJar 添加到 Dio 的拦截器中
  dio_with_cookie_manager.interceptors.add(CookieManager(cookieJar));
  // dio_with_cookie_manager.httpClientAdapter = IOHttpClientAdapter(
  //   createHttpClient: () {
  //     final client = HttpClient();
  //     client.findProxy = (uri) {
  //       return 'PROXY localhost:9000';
  //     };
  //     return client;
  //   },
  // );
  initDeepLinks();
  runApp(MyApp());
}

Future<void> initDeepLinks() async {
  AppLinks().uriLinkStream.listen((uri) {
    debugPrint('Received app link: $uri');
    Get.find<Applinkscontroller>().appLink.value = uri;
  });
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      createThemeController();
    });

    return ScreenUtilInit(
      designSize: const Size(1200, 2670),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return AdaptiveTheme(
          light: ThemeData.light(useMaterial3: true),
          dark: ThemeData.dark(useMaterial3: true),
          initial: AdaptiveThemeMode.system,
          builder: (theme, darkTheme) => GetMaterialApp(
            title: 'Listen1',
            builder: (context, widget) {
              // 先应用 BotToastInit（如果是 Windows）

              // 处理 MediaQuery 异常问题，特别是小米澎湃系统
              MediaQueryData mediaQuery = MediaQuery.of(context);
              double safeTop = mediaQuery.padding.top;

              // 如果出现异常值，使用默认值替代
              if (safeTop > 80 || safeTop < 0) {
                print(
                  'Detected abnormal top padding: $safeTop, using fallback.',
                );
                safeTop = 24.0; // 合理默认值
              }

              // 然后应用 MediaQuery 设置
              return MediaQuery(
                ///设置文字大小不随系统设置改变
                data: MediaQuery.of(context)
                    .copyWith(textScaleFactor: 1.0)
                    .copyWith(
                      padding: mediaQuery.padding.copyWith(top: safeTop),
                    ),
                child: widget!,
              );
            },

            theme: theme,
            darkTheme: darkTheme,
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [
              const Locale('zh', 'CN'), // 中文简体
              // 其他支持的语言
            ],
            locale: const Locale('zh', 'CN'), // 设置默认语言为中文
            home: MyHomePage(),
          ),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

List<String> sources = ['myplaylist', 'bilibili', 'netease', 'qq', 'kugou'];
List<bool> show_filters = [false, false, true, true, false];

var main_showVolumeSlider;

class _MyHomePageState extends State<MyHomePage> with TrayListener {
  final List<String> platforms = ['我的', 'BiliBili', '网易云', 'QQ', '酷狗'];
  TextEditingController input_text_Controller = TextEditingController();
  FocusNode _focusNode = FocusNode();
  FocusNode _focusNode2 = FocusNode();
  late PreloadPageController _pageControllerHorizon; // 声明 PageController
  late PreloadPageController _pageControllerPortrait; // 声明 PageController
  PlayController _playController = Get.find<PlayController>();
  OverlayEntry? _overlayEntry;
  Timer? _timer;
  bool volumeSliderVisible = false;
  @override
  void initState() {
    trayManager.addListener(this);
    super.initState();
    updatePageControllers();
    main_showVolumeSlider = showVolumeSlider;
    if (is_windows) {
      _init();
      init_hotkeys();
    }

    download_receiveport.listen((message) {
      if (message is SendPort) {
        print('download_sendport初始化');
        download_sendport = message;
      }
    });
    if (!is_windows)
      FlutterIsolate.spawn(
        downloadtasks_background,
        download_receiveport.sendPort,
      );

    init_playlist_filters();
    Get.find<Applinkscontroller>().xshow = xshow;
  }

  void updatePageControllers() {
    try {
      _pageControllerHorizon.dispose(); // 销毁旧的 PageController
    } catch (e) {}
    try {
      _pageControllerPortrait.dispose(); // 销毁旧的 PageController
    } catch (e) {}
    _pageControllerHorizon = PreloadPageController(initialPage: 1);
    _pageControllerPortrait = PreloadPageController(initialPage: 0);
    _pageControllerHorizon.addListener(() {
      int currentIndex = _pageControllerHorizon.page!.round();
      debugPrint(
        "currentIndex: $currentIndex, sources.length: ${sources.length}",
      );
      currentIndex = currentIndex + 1;
      source = sources[currentIndex];
      show_filter.value = show_filters[currentIndex];
      _selectedIndex.value = currentIndex;
    });
    _pageControllerPortrait.addListener(() {
      int index = _pageControllerPortrait.page!.round();
      source = sources[index];
      show_filter.value = show_filters[index];
      _selectedIndex.value = index;
    });
  }

  void _init() async {
    await trayManager.setIcon('assets/images/flutter_logo.ico');
    await trayManager.setToolTip('Listen1_xuan');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show_window', label: '显示窗口'),
          MenuItem(key: 'exit_app', label: '退出应用'),
        ],
      ),
    );
  }

  @override
  void onTrayIconMouseDown() {
    print('onTrayIconMouseDown');
    // do something, for example pop up the menu
    xshow();
  }

  void xshow() {
    windowManager.show();
    windowManager.setSkipTaskbar(false);
    windowManager.setAlwaysOnTop(true);
    windowManager.setAlwaysOnTop(false);
  }

  @override
  void onTrayIconRightMouseDown() {
    print('onTrayIconRightMouseDown');
    // do something, for example pop up the menu
    trayManager.popUpContextMenu(bringAppToFront: true);
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    print('onTrayMenuItemClick: ${menuItem.key}');
    if (menuItem.key == 'show_window') {
      xshow();
    } else if (menuItem.key == 'exit_app') {
      // do something
      exit(0);
    }
  }

  var _selectedIndex = 0.obs;
  List<int> offsets = List.generate(sources.length, (i) => 0);
  bool main_is_my = false;
  String source = 'myplaylist';
  List<Map<String, dynamic>> filters = List.generate(
    sources.length,
    (i) => {'id': '', 'name': '全部'},
  );
  var show_filter = false.obs;
  // bool show_more = false;
  List<Map<String, dynamic>> filter_details = List.generate(
    sources.length,
    (i) => {'recommend': [], 'all': []},
  );
  void init_playlist_filters() async {
    for (var i = 1; i < sources.length; i++) {
      var t = await MediaService.getPlaylistFilters(sources[i]);
      t["success"]((data) {
        debugPrint(sources[i]);
        debugPrint(data.toString());
        filter_details[i] = data;
      });
    }
  }

  var play_list_setstate;

  void change_fliter(dynamic id, String name) {
    print('change_fliter{id: $id, name: $name}');
    play_list_setstate(() {
      filters[sources.indexOf(source)] = {'id': id, 'name': name};
    });
  }

  void change_main_status(
    String id, {
    bool is_my = false,
    String search_text = "",
  }) {
    main_is_my = is_my;
    if (id != "") {
      Get.toNamed(id, arguments: {'listId': id, 'is_my': is_my}, id: 1);
    } else {
      if (search_text != "") {
        input_text_Controller.text = search_text;
        Get.toNamed(
          '/search',
          arguments: {
            'input_text_Controller': input_text_Controller,
            'onPlaylistTap': change_main_status,
          },
          id: 1,
        );
      }
    }
  }

  @override
  void dispose() {
    trayManager.removeListener(this);

    _focusNode.dispose();
    _timer?.cancel();
    _focusNode2.dispose();
    _pageControllerHorizon.dispose(); // 销毁 PageController
    _pageControllerPortrait.dispose();
    try {} catch (e) {
      // print(e);
    }
    super.dispose();
  }

  late bool global_horizon;

  late BuildContext _main_context;
  int last_pop_time = 0;
  bool left_to_right_reverse = true;
  void _pop() {
    print("didPop: didPop,");
    if (top_routeWithName.isNotEmpty) {
      Get.back(id: 1);
      return;
    }

    if (DateTime.now().millisecondsSinceEpoch - last_pop_time < 1000) {
      if (is_windows) {
        windowManager.minimize();
        windowManager.setSkipTaskbar(false);
        return;
      }
      if (kDebugMode) {
        print("exit(0)");
      } else {
        exit(0);
      }
    } else {
      xuan_toast(
        msg: is_windows ? "再按一次以最小化" : "再按一次退出",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      last_pop_time = DateTime.now().millisecondsSinceEpoch;
    }
  }

  @override
  Widget build(BuildContext main_context) {
    _main_context = main_context;
    // appLinks
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<Applinkscontroller>().processAppLink();
    });
    return Focus(
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        // 动态判断是否启用热键
        if (!enable_inapp_hotkey) {
          return KeyEventResult.ignored; // 将按键事件传递给下一个处理器
        }

        bool flag = false;
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          inappShortcuts.forEach((key, value) {
            if (event.logicalKey == key) {
              value();
              flag = true;
            }
          });
        }
        if (flag) return KeyEventResult.handled;
        return KeyEventResult.ignored;
      },
      child: OrientationBuilder(
        builder: (context, orientation) {
          global_horizon = orientation == Orientation.landscape;
          print("global_horizon: $global_horizon");
          if (global_horizon) {
            _selectedIndex.value = 2;
            debugPrint('当前为横屏模式');
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

            show_filter.value = true;
          } else {
            _selectedIndex.value = 0;
            debugPrint('当前为竖屏模式');
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          }
          bool flag = false;
          if (orientation == Orientation.portrait) {
            // 竖屏逻辑
            print("当前为竖屏模式");
            if (last_dir == 2) {
              flag = true;
            }
            last_dir = 1;
          } else {
            // 横屏逻辑
            print("当前为横屏模式");
            if (last_dir == 1) {
              flag = true;
            }
            last_dir = 2;
          }
          if (flag) {
            Get.offAllNamed('/', id: 1);
            updatePageControllers();
          }
          Widget sized_box = SizedBox(
            width: 197,
            child: Column(
              children: [
                SizedBox(height: 10),
                is_windows
                    ? Listener(
                        onPointerDown: (event) {
                          if (event.kind == PointerDeviceKind.mouse &&
                              event.buttons == kSecondaryMouseButton) {
                            windowManager.hide();
                            windowManager.setSkipTaskbar(true);
                          }
                          if (event.kind == PointerDeviceKind.mouse &&
                              event.buttons == kMiddleMouseButton) {
                            exit(0);
                          }
                        },
                        child: Tooltip(
                          message: '右键以最小化,中键以关闭',
                          child: Text(
                            'Listen1',
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      )
                    : Text('Listen1', style: TextStyle(fontSize: 24)),
                TextField(
                  decoration: InputDecoration(
                    labelText: '请输入歌曲名，歌手或专辑',
                    border: InputBorder.none,
                  ),
                  controller: input_text_Controller,
                  readOnly: true,
                  onTap: () async {
                    Get.toNamed(
                      '/search',
                      arguments: {
                        'input_text_Controller': input_text_Controller,
                        'onPlaylistTap': change_main_status,
                      },
                      id: 1,
                    );
                  },
                ),
                Expanded(child: MyPlaylist(onPlaylistTap: change_main_status)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ThemeToggleButton(
                      iconSize: 24.0, // 可选：自定义图标大小
                      padding: EdgeInsets.all(0), // 可选：自定义内边距
                    ),
                    WebSocketHelper.buildReactiveButton(
                      tooltip: "WebSocket服务器",
                      inMainPage: true,
                    ),
                    WebSocketClientHelper.buildReactiveButton(
                      tooltip: "WebSocket客户端",
                      inMainPage: true,
                    ),
                    IconButton(
                      tooltip: "设置",
                      icon: Icon(Icons.settings),
                      onPressed: () {
                        Get.toNamed('/settings', id: 1);
                      },
                    ),
                  ],
                ),
              ],
            ),
          );

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              _pop();
            },
            child: Scaffold(
              body: Row(
                children: [
                  if (global_horizon)
                    is_windows ? DragToMoveArea(child: sized_box) : sized_box,
                  if (global_horizon)
                    RotatedBox(
                      quarterTurns: -1,
                      child: Divider(
                        height: 1,
                        thickness: 2,
                        color: Colors.grey[300],
                      ),
                    ),
                  Expanded(
                    child: Listener(
                      onPointerDown: (event) {
                        if (event.kind == PointerDeviceKind.mouse &&
                            event.buttons == kSecondaryMouseButton) {
                          _pop();
                        }
                        if (event.kind == PointerDeviceKind.mouse &&
                            event.buttons == kMiddleMouseButton) {
                          switch (Get.find<SettingsController>()
                              .hideOrMinimize) {
                            case false:
                              windowManager.hide();
                              windowManager.setSkipTaskbar(true);
                              break;
                            case true:
                              windowManager.minimize();
                              windowManager.setSkipTaskbar(false);
                              break;
                          }
                        }
                      },
                      child: Column(
                        children: [
                          if (is_windows)
                            Container(
                              height: 25,
                              child: DragToMoveArea(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      tooltip: "返回",
                                      onPressed: () {
                                        _pop();
                                      },
                                      icon: Icon(
                                        Icons.arrow_back_ios_new,
                                        size: 13,
                                      ),
                                    ),
                                    Container(
                                      width: 120,
                                      child: Row(
                                        children: [
                                          IconButton(
                                            tooltip: "隐藏到托盘",
                                            icon: Icon(
                                              Icons.close_fullscreen_rounded,
                                              size: 13,
                                            ),
                                            onPressed: () {
                                              windowManager.hide();
                                              windowManager.setSkipTaskbar(
                                                true,
                                              );
                                            },
                                          ),
                                          IconButton(
                                            tooltip: "最小化",
                                            icon: Icon(
                                              Icons.minimize,
                                              size: 13,
                                            ),
                                            onPressed: () {
                                              windowManager.minimize();
                                              windowManager.setSkipTaskbar(
                                                false,
                                              );
                                            },
                                          ),
                                          IconButton(
                                            tooltip: "关闭",
                                            icon: Icon(Icons.close, size: 13),
                                            onPressed: () {
                                              exit(0);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Expanded(
                            child: Navigator(
                              key: Get.nestedKey(1),
                              initialRoute: '/',
                              onGenerateRoute: (RouteSettings settings) {
                                WidgetBuilder builder;
                                switch (settings.name) {
                                  case '/':
                                    // 在函数内部定义默认页面
                                    if (global_horizon) {
                                      builder = (context_in_1) {
                                        return Scaffold(
                                          body: Column(
                                            children: [
                                              Container(
                                                height: 40,
                                                child: Container(
                                                  width:
                                                      MediaQuery.of(
                                                        context,
                                                      ).size.width -
                                                      200,
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width:
                                                            MediaQuery.of(
                                                              context,
                                                            ).size.width -
                                                            200,
                                                        child: Obx(
                                                          () => Stack(
                                                            children: [
                                                              Positioned(
                                                                top: 0,
                                                                child: Container(
                                                                  height: 40,
                                                                  width:
                                                                      MediaQuery.of(
                                                                        context,
                                                                      ).size.width -
                                                                      300,
                                                                  child: AnimatedTabBarWidget(
                                                                    pageController:
                                                                        _pageControllerHorizon,
                                                                    tabLabels: platforms
                                                                        .sublist(
                                                                          1,
                                                                        )
                                                                        .map(
                                                                          (
                                                                            platform,
                                                                          ) => TextSpan(
                                                                            text:
                                                                                platform,
                                                                          ),
                                                                        )
                                                                        .toList(),
                                                                    containerHeight:
                                                                        40,
                                                                    spacing: 0,
                                                                  ),
                                                                ),
                                                              ),
                                                              if (show_filter
                                                                  .value)
                                                                Positioned(
                                                                  top:
                                                                      is_windows
                                                                      ? 5
                                                                      : -5,
                                                                  right: 20,
                                                                  child: TextButton(
                                                                    child: Text(
                                                                      filters[sources.indexOf(
                                                                        source,
                                                                      )]['name'],
                                                                    ),
                                                                    onPressed: () {
                                                                      Map<
                                                                        String,
                                                                        dynamic
                                                                      >
                                                                      tfilter =
                                                                          {};
                                                                      tfilter["推荐"] =
                                                                          filter_details[_selectedIndex
                                                                              .value]["recommend"];
                                                                      for (var item
                                                                          in filter_details[_selectedIndex
                                                                              .value]["all"]) {
                                                                        tfilter[item["category"]] =
                                                                            item["filters"];
                                                                      }
                                                                      _showFilterSelection(
                                                                        context_in_1,
                                                                        tfilter,
                                                                        filters[sources.indexOf(
                                                                          source,
                                                                        )]['id'],
                                                                        change_fliter,
                                                                      );
                                                                    },
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: StatefulBuilder(
                                                  builder: (context, setState) {
                                                    play_list_setstate =
                                                        setState;
                                                    return PreloadPageView.builder(
                                                      physics:
                                                          BouncingScrollPhysics(),
                                                      controller:
                                                          _pageControllerHorizon, // 使用 PageController
                                                      itemCount:
                                                          sources.length -
                                                          1, // 页面数量
                                                      preloadPagesCount:
                                                          sources.length - 1,

                                                      itemBuilder: (context, index) {
                                                        index = index + 1;
                                                        // 其他页面：动态生成
                                                        return Playlist(
                                                          source:
                                                              sources[index],
                                                          offset:
                                                              offsets[index],
                                                          filter:
                                                              filters[index],
                                                          onPlaylistTap:
                                                              change_main_status,
                                                          key: Key(
                                                            filters[index]
                                                                .toString(),
                                                          ),
                                                        );
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      };
                                      break;
                                    } else {
                                      builder = (context_in_1) {
                                        return Scaffold(
                                          appBar: AppBar(
                                            title: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text('Listen1'),
                                                SizedBox(width: 10),
                                                Expanded(
                                                  child: TextField(
                                                    decoration: InputDecoration(
                                                      hintText: '请输入歌曲名，歌手或专辑',
                                                      border: InputBorder.none,
                                                    ),
                                                    controller:
                                                        input_text_Controller,
                                                    readOnly: true,
                                                    onTap: () async {
                                                      Get.toNamed(
                                                        '/search',
                                                        id: 1,
                                                      );
                                                    },
                                                  ),
                                                ),
                                                WebSocketHelper.buildReactiveButton(
                                                  tooltip: "WebSocket服务器",
                                                  inMainPage: true,
                                                ),
                                                WebSocketClientHelper.buildReactiveButton(
                                                  tooltip: "WebSocket客户端",
                                                  inMainPage: true,
                                                ),
                                                IconButton(
                                                  tooltip: "设置",
                                                  icon: Icon(Icons.settings),
                                                  onPressed: () {
                                                    Get.toNamed(
                                                      '/settings',
                                                      id: 1,
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          body: Column(
                                            children: [
                                              Container(
                                                height: 45,
                                                child: Obx(
                                                  () => Row(
                                                    children: [
                                                      Expanded(
                                                        child: AnimatedTabBarWidget(
                                                          pageController:
                                                              _pageControllerPortrait,
                                                          tabLabels: platforms
                                                              .map(
                                                                (
                                                                  platform,
                                                                ) => TextSpan(
                                                                  text:
                                                                      platform,
                                                                ),
                                                              )
                                                              .toList(),
                                                          containerHeight: 45,
                                                          spacing: 0,
                                                        ),
                                                      ),
                                                      if (show_filter.value)
                                                        TextButton(
                                                          child: Text(
                                                            filters[sources
                                                                .indexOf(
                                                                  source,
                                                                )]['name'],
                                                          ),
                                                          onPressed: () {
                                                            Map<String, dynamic>
                                                            tfilter = {};
                                                            tfilter["推荐"] =
                                                                filter_details[_selectedIndex
                                                                    .value]["recommend"];
                                                            for (var item
                                                                in filter_details[_selectedIndex
                                                                    .value]["all"]) {
                                                              tfilter[item["category"]] =
                                                                  item["filters"];
                                                            }
                                                            _showFilterSelection(
                                                              context_in_1,
                                                              tfilter,
                                                              filters[sources
                                                                  .indexOf(
                                                                    source,
                                                                  )]['id'],
                                                              change_fliter,
                                                            );
                                                          },
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              // 长灰色细分割线
                                              Divider(
                                                height: 1,
                                                color: Colors.grey[300],
                                              ),
                                              Expanded(
                                                child: StatefulBuilder(
                                                  builder: (context, setState) {
                                                    play_list_setstate =
                                                        setState;
                                                    return PreloadPageView.builder(
                                                      physics:
                                                          BouncingScrollPhysics(),
                                                      controller:
                                                          _pageControllerPortrait, // 使用 PageController
                                                      itemCount: sources
                                                          .length, // 页面数量
                                                      preloadPagesCount:
                                                          sources.length,

                                                      itemBuilder: (context, index) {
                                                        if (index == 0) {
                                                          // 第一个页面：我的歌单
                                                          return MyPlaylist(
                                                            onPlaylistTap:
                                                                change_main_status,
                                                          );
                                                        } else {
                                                          // 其他页面：动态生成
                                                          return Playlist(
                                                            source:
                                                                sources[index],
                                                            offset:
                                                                offsets[index],
                                                            filter:
                                                                filters[index],
                                                            onPlaylistTap:
                                                                change_main_status,
                                                            key: Key(
                                                              filters[index]
                                                                  .toString(),
                                                            ),
                                                          );
                                                        }
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      };
                                      break;
                                    }
                                  case '/search':
                                    var route = GetPageRoute(
                                      settings: settings,
                                      page: () => Searchlistinfo(
                                        input_text_Controller:
                                            input_text_Controller,
                                        onPlaylistTap: change_main_status,
                                      ),
                                      transition: Transition.upToDown,
                                      middlewares: [ListenPopMiddleware()],
                                    );
                                    addAndCleanReapeatRoute(route, '/search');
                                    return route;
                                  case '/settings':
                                    var route = GetPageRoute(
                                      settings: settings,
                                      page: () => SettingsPage(),
                                      middlewares: [ListenPopMiddleware()],
                                    );
                                    addAndCleanReapeatRoute(route, '/settings');
                                    return route;
                                  case '/nowPlayingPage':
                                    var route = GetPageRoute(
                                      settings: settings,
                                      transition: Transition.downToUp,
                                      page: () => NowPlayingPage(),
                                      middlewares: [ListenPopMiddleware()],
                                    );
                                    addAndCleanReapeatRoute(
                                      route,
                                      '/nowPlayingPage',
                                    );
                                    return route;
                                  case '/lyric':
                                    var route = GetPageRoute(
                                      settings: settings,
                                      transition: Transition.downToUp,
                                      page: () => LyricPage(),
                                      middlewares: [ListenPopMiddleware()],
                                    );
                                    addAndCleanReapeatRoute(route, '/lyric');
                                    return route;
                                  default:
                                    var route = GetPageRoute(
                                      settings: settings,
                                      page: () {
                                        final args =
                                            settings.arguments
                                                as Map<String, dynamic>? ??
                                            {};
                                        return PlaylistInfo(
                                          listId: args['listId'],
                                          onPlaylistTap: change_main_status,
                                          is_my: args['is_my'] ?? false,
                                        );
                                      },
                                      middlewares: [ListenPopMiddleware()],
                                    );
                                    addAndCleanReapeatRoute(
                                      route,
                                      settings.name!,
                                    );
                                    return route;
                                }
                                return MaterialPageRoute(builder: builder);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Play(
                    onPlaylistTap: change_main_status,
                    horizon: global_horizon,
                  ),
                  // 竖屏状态下添加额外的占位空间
                  if (!global_horizon)
                    Obx(() {
                      SettingsController controller =
                          Get.find<SettingsController>();
                      return SizedBox(
                        height: controller.portraitBottomBarPadding.value,
                      );
                    }),
                ],
              ),
              floatingActionButton:
                  // FloatingActionButton(
                  //   onPressed: () {
                  //     Get.find<Applinkscontroller>().processAppLink();
                  //   },
                  // ),
                  Obx(() {
                    WebSocketClientController? controller;
                    try {
                      controller = Get.find<WebSocketClientController>();
                    } catch (e) {
                      return FloatingActionButton(
                        tooltip: "WebSocket客户端",

                        onPressed: () async {
                          await WebSocketClientHelper.showControlPanel();
                        },
                        child: Icon(Icons.cast_connected),
                      );
                    }

                    // 检查是否应该显示按钮
                    if (!controller.wsClientBtnShowFloating) {
                      return const SizedBox.shrink();
                    }

                    // 根据连接状态确定图标颜色和状态
                    Color iconColor;
                    String currentTooltip;

                    if (controller.isConnecting || controller.isDisconnecting) {
                      iconColor = Colors.amber;
                      currentTooltip = controller.isConnecting
                          ? "WebSocket客户端 (连接中...)"
                          : "WebSocket客户端 (断开中...)";
                    } else if (controller.isConnected) {
                      iconColor = Colors.blue;
                      currentTooltip = "WebSocket客户端 (已连接)";
                    } else if (controller.isReconnecting) {
                      iconColor = Colors.orange;
                      currentTooltip = "WebSocket客户端 (重连中...)";
                    } else {
                      iconColor = Colors.grey;
                      currentTooltip = "WebSocket客户端 (未连接)";
                    }
                    return FloatingActionButton(
                      tooltip: currentTooltip,
                      onPressed: () async {
                        await WebSocketClientHelper.showControlPanel();
                      },
                      child: Icon(Icons.cast_connected, color: iconColor),
                    );
                  }),
            ),
          );
        },
      ),
    );
  }

  void showVolumeSlider() async {
    volumeSliderVisible = true;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(_main_context).insert(_overlayEntry!);
    _startAutoCloseTimer();
  }

  void _startAutoCloseTimer() {
    _timer?.cancel();
    _timer = Timer(Duration(seconds: 3), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
      volumeSliderVisible = false;
    });
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height / 2 - 100,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _overlayEntry?.remove();
              _overlayEntry = null;
              volumeSliderVisible = false;
            },
            child: Container(
              height: 200,
              width: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface, // 使用当前主题的表面颜色
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(113, 120, 120, 120),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: RotatedBox(
                quarterTurns: -1,
                child: Obx(
                  () => Slider(
                    value: _playController.currentVolume,
                    onChanged: (value) {
                      _playController.currentVolume = value;
                      _startAutoCloseTimer();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showFilterSelection(
  BuildContext context,
  Map<String, dynamic> filter,
  dynamic now_id,
  Function change_fliter,
) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Container(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择过滤器',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Divider(),
            Expanded(
              child: ListView(
                children: filter.entries.map<Widget>((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: entry.value.map<Widget>((filterItem) {
                          return FilterChip(
                            label: Text(filterItem['name']),
                            onSelected: (bool selected) {
                              // 处理过滤器选择逻辑
                              change_fliter(
                                filterItem['id'],
                                filterItem['name'],
                              );
                              Navigator.pop(context);
                            },
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 16.0),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    },
  );
}
