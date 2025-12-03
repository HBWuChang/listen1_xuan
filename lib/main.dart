import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get_connect/http/src/utils/utils.dart';
import 'package:listen1_xuan/controllers/controllers.dart';
import 'package:listen1_xuan/controllers/search_controller.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/pages/lyric/lyric_page.dart';
import 'package:media_kit/media_kit.dart' show MediaKit;
import 'examples/websocket_server_example.dart';
import 'examples/websocket_client_example.dart';
import 'pages/download_page.dart';
import 'pages/nowPlaying_page.dart';
import 'pages/settings/settings_readme.dart';
import 'pages/settings/settings_supabase_login_page.dart';
import 'pages/settings/cache_naming_page.dart';
import 'settings.dart';
import 'loweb.dart';
import 'bodys.dart';
import 'play.dart';
import 'global_settings_animations.dart';
import 'widgets.dart';
import 'dart:async';
import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:preload_page_view/preload_page_view.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:flutter/gestures.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:windows_taskbar/windows_taskbar.dart';
import 'package:smtc_windows/smtc_windows.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'controllers/theme.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';

String supabaseUrl = 'https://jtvxrwybwvgpqobyhaoy.supabase.co';

String supabaseKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0dnhyd3lid3ZncHFvYnloYW95Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE5NjE5ODUsImV4cCI6MjA3NzUzNzk4NX0.lb4YhPlsyTinmoK85jv_15KCEv1QDr0JsUa1oI5P0Ko';

Dio get dioWithCookieManager => Get.find<DioController>().dioWithCookieManager;
Dio get dioWithProxyAdapter => Get.find<DioController>().dioWithProxyAdapter;

int last_dir = 0;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void enableThumbnailToolbar() async {
  int retryCount = 0;
  const maxRetries = 10; // 最多重试10次

  while (retryCount < maxRetries) {
    try {
      await WindowsTaskbar.setThumbnailToolbar([
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon(
            'assets/images/audio_service_skip_previous.ico',
          ),
          '上一首',
          () {
            globalSkipToPrevious();
          },
        ),
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon('assets/images/audio_service_pause.ico'),
          '播放/暂停',
          () {
            globalPlayOrPause();
          },
        ),
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon(
            'assets/images/audio_service_skip_next.ico',
          ),
          '下一首',
          () {
            globalSkipToNext();
          },
        ),
      ]);
      debugPrint('任务栏缩略图工具栏设置成功');
      break;
    } catch (e) {
      retryCount++;
      debugPrint('设置任务栏缩略图工具栏失败 (尝试 $retryCount/$maxRetries): $e');
      if (retryCount < maxRetries) {
        await Future.delayed(Duration(seconds: 3)); // 注意这里添加了 await
      } else {
        debugPrint('已达到最大重试次数，放弃设置任务栏缩略图工具栏');
      }
    }
  }
}

void main() async {
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  await WidgetsFlutterBinding.ensureInitialized(); // 确保 Flutter框架已初始化
  MediaKit.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent, // 设置导航栏背景色为透明
      systemNavigationBarDividerColor: Colors.transparent, // 设置导航栏分割线为透明
    ),
  );
  SettingsController settingsController = Get.put(
    SettingsController(),
    permanent: true,
  );
  await settingsController.loadSettings();
  Get.put(RouteController(), permanent: true);
  Get.put(DioController(), permanent: true);
  CacheController cacheController = Get.put(CacheController(), permanent: true);
  Get.put(PlayController(), permanent: true);
  cacheController.loadLocalCacheList();
  Get.find<PlayController>().loadDatas();
  Get.put(MyPlayListController(), permanent: true);
  Get.find<MyPlayListController>().loadDatas();
  Get.put(AudioHandlerController(), permanent: true);
  Get.put(LyricController(), permanent: true);
  Get.put(NowPlayingPageController(), permanent: true);
  Get.put(BroadcastWsController(), permanent: true);
  Get.put(ScanBroadcastController(), permanent: true);
  Get.put(WsDownloadController(), permanent: true);
  Get.put(Applinkscontroller(), permanent: true);
  Get.put(SupabaseAuthController(), permanent: true);
  Get.put(XSearchController(), permanent: true);
  init_apkfilepath();
  if (isWindows || isMacOS) {
    if (isWindows) {
      SMTCWindows.initialize();
    }
    // flutter_acrylic
    await Window.initialize();
    // Must add this line.
    await windowManager.ensureInitialized();
    await hotKeyManager.unregisterAll();
    late WindowOptions windowOptions;
    if (settingsController.rememberWindowsSizeAndPosition) {
      Rect bounds = settingsController.windowsWindowBounds;
      windowOptions = WindowOptions(
        size: Size(bounds.width, bounds.height),
        minimumSize: Size(400, 700),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
      );
    } else {
      windowOptions = WindowOptions(
        size: Size(1000, 700),
        minimumSize: Size(400, 700),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
      );
    }
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (settingsController.isWindowMaximized) {
        await windowManager.maximize();
      }
      await windowManager.show();
      createThemeController().didChangePlatformBrightnessOrManual();
    });
    windowManager.setPreventClose(true);
  }
  createThemeController();
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

  // 创建 PersistCookieJar 实例
  final cookieJar = PersistCookieJar(
    storage: FileStorage(_cookiePath),
    ignoreExpires: true,
  );

  // 将 PersistCookieJar 添加到 Dio 的拦截器中
  dioWithCookieManager.interceptors.add(CookieManager(cookieJar));
  if (settingsController.settingsPageExpansion.contains(0)) {
    settingsController.refreshLoginData();
  }
  // dio_with_cookie_manager.httpClientAdapter = IOHttpClientAdapter(
  //   createHttpClient: () {
  //     final client = HttpClient();
  //     client.findProxy = (uri) {
  //       return 'PROXY 192.168.1.15:9000';
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
              widget = FToastBuilder()(context, widget);
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
                child: widget,
              );
            },
            navigatorKey: navigatorKey,
            theme: theme,
            //TODO 预测性返回功能待完善

            // .copyWith(
            //   pageTransitionsTheme: const PageTransitionsTheme(
            //     builders: <TargetPlatform, PageTransitionsBuilder>{
            //       TargetPlatform.android:
            //           PredictiveBackPageTransitionsBuilder(),
            //     },
            //   ),
            // )
            darkTheme: darkTheme,
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.mouse, // 添加鼠标拖动
                PointerDeviceKind.touch,
                PointerDeviceKind.stylus,
                PointerDeviceKind.invertedStylus,
                PointerDeviceKind.trackpad,
              },
            ),
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

late bool globalHorizon;

class _MyHomePageState extends State<MyHomePage>
    with TrayListener, WindowListener, WidgetsBindingObserver {
  final List<String> platforms = ['我的', 'BiliBili', '网易云', 'QQ', '酷狗'];
  TextEditingController get input_text_Controller =>
      Get.find<XSearchController>().searchTextController;
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
    super.initState();
    if (isDesktop) WidgetsBinding.instance.addObserver(this);
    trayManager.addListener(this);
    updatePageControllers();
    main_showVolumeSlider = showVolumeSlider;
    if (isWindows || isMacOS) {
      _initTrayManager();
      init_hotkeys();
      windowManager.addListener(this);
    }
    init_playlist_filters();
    Get.find<Applinkscontroller>().xshow = xshow;

    fToast = FToast();
    // if you want to use context from globally instead of content we need to pass navigatorKey.currentContext!
    fToast.init(navigatorKey.currentContext!);
  }

  @override
  void onWindowClose() {
    closeApp();
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
      source.value = sources[currentIndex];
      show_filter.value = show_filters[currentIndex];
      _selectedIndex.value = currentIndex;
    });
    _pageControllerPortrait.addListener(() {
      int index = _pageControllerPortrait.page!.round();
      source.value = sources[index];
      show_filter.value = show_filters[index];
      _selectedIndex.value = index;
    });
  }

  void _initTrayManager() async {
    await trayManager.setIcon('assets/images/app_icon.ico');
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

  Future<void> xshow() async {
    await windowManager.show();
    windowManager.setSkipTaskbar(false);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setBackgroundColor(Colors.transparent);
    // await
    createThemeController().didChangePlatformBrightnessOrManual();
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
      closeApp();
    }
  }

  var _selectedIndex = 0.obs;
  List<int> offsets = List.generate(sources.length, (i) => 0);
  final source = 'myplaylist'.obs;
  RxList<Map<String, dynamic>> filters = List<Map<String, dynamic>>.generate(
    sources.length,
    (i) => {'id': '', 'name': '全部'},
  ).obs;
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

  void change_fliter(dynamic id, String name) {
    print('change_fliter{id: $id, name: $name}');
    filters[sources.indexOf(source.value)] = (Map<String, Object>.from({
      'id': id,
      'name': name,
    }));
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    Get.find<ThemeController>().didChangePlatformBrightnessOrManual();
  }

  @override
  void dispose() {
    if (isDesktop) {
      trayManager.removeListener(this);
      WidgetsBinding.instance.removeObserver(this);
      windowManager.removeListener(this);
    }
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

  late BuildContext _main_context;
  bool left_to_right_reverse = true;

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
          globalHorizon = orientation == Orientation.landscape;
          if (globalHorizon) {
            _selectedIndex.value = 2;
            debugPrint('当前为横屏模式');
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

            show_filter.value = true;
          } else {
            _selectedIndex.value = 0;
            debugPrint('当前为竖屏模式');
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          }
          source.value = sources[_selectedIndex.value];
          bool flag = false;
          if (orientation == Orientation.portrait) {
            // 竖屏逻辑
            if (last_dir == 2) {
              flag = true;
            }
            last_dir = 1;
          } else {
            // 横屏逻辑
            if (last_dir == 1) {
              flag = true;
            }
            last_dir = 2;
          }
          if (flag) {
            Get.offAllNamed('/', id: 1);
            updatePageControllers();
          }
          Widget leftBar = Container(
            color: AdaptiveTheme.of(main_context).theme.scaffoldBackgroundColor,
            width: 197,
            child: Column(
              children: [
                SizedBox(height: 10),
                isDesktop
                    ? Listener(
                        onPointerDown: (event) {
                          if (event.kind == PointerDeviceKind.mouse &&
                              event.buttons == kSecondaryMouseButton) {
                            if (isMacOS) {
                              closeApp();
                              return;
                            }
                            windowManager.hide();
                            windowManager.setSkipTaskbar(true);
                          }
                          if (event.kind == PointerDeviceKind.mouse &&
                              event.buttons == kMiddleMouseButton) {
                            closeApp();
                          }
                        },
                        child: Tooltip(
                          message: isWindows ? '右键以最小化,中键以关闭' : '右键以关闭',
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
                    Get.toNamed(RouteName.searchPage, id: 1);
                  },
                ),
                Expanded(child: MyPlaylist()),
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
                        Get.toNamed(RouteName.settingsPage, id: 1);
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
          Widget _play = Play(horizon: globalHorizon);
          Scaffold con() => Scaffold(
            extendBody: true,
            backgroundColor: createThemeController().playHBackgroundColor.value,
            body: Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (globalHorizon) ...[
                              isWindows || isMacOS
                                  ? DragToMoveArea(child: leftBar)
                                  : leftBar,
                              RotatedBox(
                                quarterTurns: -1,
                                child: Divider(
                                  height: 1,
                                  thickness: 2,
                                  color: AdaptiveTheme.of(
                                    Get.context!,
                                  ).theme.colorScheme.secondaryContainer,
                                ),
                              ),
                            ],
                            Expanded(
                              child: Listener(
                                onPointerDown: (event) {
                                  if (event.kind == PointerDeviceKind.mouse &&
                                      event.buttons == kSecondaryMouseButton) {
                                    router_pop();
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
                                    if (isWindows)
                                      Container(
                                        height: 25,
                                        color: AdaptiveTheme.of(
                                          main_context,
                                        ).theme.scaffoldBackgroundColor,
                                        child: DragToMoveArea(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              IconButton(
                                                tooltip: "返回",
                                                onPressed: () {
                                                  router_pop();
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
                                                        Icons
                                                            .close_fullscreen_rounded,
                                                        size: 13,
                                                      ),
                                                      onPressed: () {
                                                        windowManager.hide();
                                                        windowManager
                                                            .setSkipTaskbar(
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
                                                        windowManager
                                                            .minimize();
                                                        windowManager
                                                            .setSkipTaskbar(
                                                              false,
                                                            );
                                                      },
                                                    ),
                                                    IconButton(
                                                      tooltip: "关闭",
                                                      icon: Icon(
                                                        Icons.close,
                                                        size: 13,
                                                      ),
                                                      onPressed: () {
                                                        closeApp();
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
                                        initialRoute: RouteName.defaultPage,
                                        onGenerateRoute: (RouteSettings settings) {
                                          WidgetBuilder builder;
                                          switch (settings.name) {
                                            case RouteName.defaultPage:
                                              // 在函数内部定义默认页面
                                              if (globalHorizon) {
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
                                                                  child: Stack(
                                                                    children: [
                                                                      Positioned(
                                                                        top: 0,
                                                                        child: Container(
                                                                          height:
                                                                              40,
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
                                                                                    text: platform,
                                                                                  ),
                                                                                )
                                                                                .toList(),
                                                                            containerHeight:
                                                                                40,
                                                                            spacing:
                                                                                0,
                                                                          ),
                                                                        ),
                                                                      ),

                                                                      Positioned(
                                                                        top:
                                                                            isWindows ||
                                                                                isMacOS
                                                                            ? 5
                                                                            : -5,
                                                                        right:
                                                                            20,
                                                                        child: Obx(
                                                                          () => AnimatedOpacity(
                                                                            opacity:
                                                                                show_filter.value
                                                                                ? 1.0
                                                                                : 0.0,
                                                                            duration: const Duration(
                                                                              milliseconds: 300,
                                                                            ),
                                                                            child: TextButton(
                                                                              child: Obx(
                                                                                () => Text(
                                                                                  filters[sources.indexOf(
                                                                                    source.value,
                                                                                  )]['name'],
                                                                                ),
                                                                              ),
                                                                              onPressed: show_filter.value
                                                                                  ? () {
                                                                                      Map<
                                                                                        String,
                                                                                        dynamic
                                                                                      >
                                                                                      tfilter = {};
                                                                                      tfilter["推荐"] = filter_details[_selectedIndex.value]["recommend"];
                                                                                      for (var item in filter_details[_selectedIndex.value]["all"]) {
                                                                                        tfilter[item["category"]] = item["filters"];
                                                                                      }
                                                                                      _showFilterSelection(
                                                                                        context_in_1,
                                                                                        tfilter,
                                                                                        filters[sources.indexOf(
                                                                                          source.value,
                                                                                        )]['id'],
                                                                                        change_fliter,
                                                                                      );
                                                                                    }
                                                                                  : null,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: PreloadPageView.builder(
                                                            physics:
                                                                BouncingScrollPhysics(),
                                                            controller:
                                                                _pageControllerHorizon, // 使用 PageController
                                                            itemCount:
                                                                sources.length -
                                                                1, // 页面数量
                                                            preloadPagesCount:
                                                                sources.length -
                                                                1,

                                                            itemBuilder: (context, index) {
                                                              index = index + 1;
                                                              // 其他页面：动态生成
                                                              return Obx(() {
                                                                return Playlist(
                                                                  source:
                                                                      sources[index],
                                                                  offset:
                                                                      offsets[index],
                                                                  filter:
                                                                      filters[index],
                                                                  key: Key(
                                                                    filters[index]
                                                                        .toString(),
                                                                  ),
                                                                );
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                };
                                                break;
                                              } else {
                                                //竖屏
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
                                                                hintText:
                                                                    '请输入歌曲名，歌手或专辑',
                                                                border:
                                                                    InputBorder
                                                                        .none,
                                                              ),
                                                              controller:
                                                                  input_text_Controller,
                                                              readOnly: true,
                                                              onTap: () async {
                                                                Get.toNamed(
                                                                  RouteName
                                                                      .searchPage,
                                                                  id: 1,
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                          WebSocketHelper.buildReactiveButton(
                                                            tooltip:
                                                                "WebSocket服务器",
                                                            inMainPage: true,
                                                          ),
                                                          WebSocketClientHelper.buildReactiveButton(
                                                            tooltip:
                                                                "WebSocket客户端",
                                                            inMainPage: true,
                                                          ),
                                                          IconButton(
                                                            tooltip: "设置",
                                                            icon: Icon(
                                                              Icons.settings,
                                                            ),
                                                            onPressed: () {
                                                              Get.toNamed(
                                                                RouteName
                                                                    .settingsPage,
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
                                                          child: Row(
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
                                                                  containerHeight:
                                                                      45,
                                                                  spacing: 0,
                                                                ),
                                                              ),
                                                              Obx(
                                                                () => AnimatedSize(
                                                                  duration:
                                                                      const Duration(
                                                                        milliseconds:
                                                                            300,
                                                                      ),
                                                                  child:
                                                                      show_filter
                                                                          .value
                                                                      ? TextButton(
                                                                          child: Obx(
                                                                            () => Text(
                                                                              filters[sources.indexOf(
                                                                                source.value,
                                                                              )]['name'],
                                                                            ),
                                                                          ),
                                                                          onPressed:
                                                                              show_filter.value
                                                                              ? () {
                                                                                  Map<
                                                                                    String,
                                                                                    dynamic
                                                                                  >
                                                                                  tfilter = {};
                                                                                  tfilter["推荐"] = filter_details[_selectedIndex.value]["recommend"];
                                                                                  for (var item in filter_details[_selectedIndex.value]["all"]) {
                                                                                    tfilter[item["category"]] = item["filters"];
                                                                                  }
                                                                                  _showFilterSelection(
                                                                                    context_in_1,
                                                                                    tfilter,
                                                                                    filters[sources.indexOf(
                                                                                      source.value,
                                                                                    )]['id'],
                                                                                    change_fliter,
                                                                                  );
                                                                                }
                                                                              : null,
                                                                        )
                                                                      : SizedBox.shrink(),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        // 长灰色细分割线
                                                        Divider(
                                                          height: 1,
                                                          color:
                                                              Colors.grey[300],
                                                        ),
                                                        Expanded(
                                                          child: PreloadPageView.builder(
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
                                                                return MyPlaylist();
                                                              } else {
                                                                // 其他页面：动态生成
                                                                return Obx(() {
                                                                  return Playlist(
                                                                    source:
                                                                        sources[index],
                                                                    offset:
                                                                        offsets[index],
                                                                    filter:
                                                                        filters[index],
                                                                    key: Key(
                                                                      filters[index]
                                                                          .toString(),
                                                                    ),
                                                                  );
                                                                });
                                                              }
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                };
                                                break;
                                              }
                                            case RouteName.searchPage:
                                              var route = GetPageRoute(
                                                settings: settings,
                                                page: () => Searchlistinfo(),
                                                transition: Transition.upToDown,
                                                middlewares: [
                                                  ListenPopMiddleware(),
                                                ],
                                              );
                                              addAndCleanReapeatRoute(
                                                route,
                                                RouteName.searchPage,
                                              );
                                              return route;
                                            case RouteName.settingsPage:
                                              var route = GetPageRoute(
                                                settings: settings,
                                                page: () => SettingsPage(),
                                                middlewares: [
                                                  ListenPopMiddleware(),
                                                ],
                                              );
                                              addAndCleanReapeatRoute(
                                                route,
                                                RouteName.settingsPage,
                                              );
                                              return route;
                                            case RouteName.nowPlayingPage:
                                              var route = GetPageRoute(
                                                settings: settings,
                                                transition: Transition.downToUp,
                                                // Transition.noTransition,
                                                page: () => NowPlayingPage(),
                                                middlewares: [
                                                  ListenPopMiddleware(),
                                                ],
                                              );
                                              addAndCleanReapeatRoute(
                                                route,
                                                RouteName.nowPlayingPage,
                                              );
                                              return route;
                                            case RouteName.lyricPage:
                                              var route = GetPageRoute(
                                                settings: settings,
                                                transition: Transition.downToUp,
                                                page: () => LyricPage(),
                                                middlewares: [
                                                  ListenPopMiddleware(),
                                                ],
                                              );
                                              addAndCleanReapeatRoute(
                                                route,
                                                RouteName.lyricPage,
                                              );
                                              return route;
                                            case RouteName.settingsReadmePage:
                                              var route = GetPageRoute(
                                                settings: settings,
                                                transition: Transition
                                                    .rightToLeftWithFade,
                                                page: () =>
                                                    SettingsReadmePage(),
                                                middlewares: [
                                                  ListenPopMiddleware(),
                                                ],
                                              );
                                              addAndCleanReapeatRoute(
                                                route,
                                                RouteName.settingsReadmePage,
                                              );
                                              return route;
                                            case RouteName.downloadPage:
                                              var route = GetPageRoute(
                                                settings: settings,
                                                transition: Transition
                                                    .rightToLeftWithFade,
                                                page: () => DownloadPage(),
                                                middlewares: [
                                                  ListenPopMiddleware(),
                                                ],
                                              );
                                              addAndCleanReapeatRoute(
                                                route,
                                                RouteName.downloadPage,
                                              );
                                              return route;
                                            case RouteName.supabaseLoginPage:
                                              var route = GetPageRoute(
                                                settings: settings,
                                                transition: Transition
                                                    .rightToLeftWithFade,
                                                page: () => SupabaseLoginPage(),
                                                middlewares: [
                                                  ListenPopMiddleware(),
                                                ],
                                              );
                                              addAndCleanReapeatRoute(
                                                route,
                                                RouteName.supabaseLoginPage,
                                              );
                                              return route;
                                            case RouteName.cacheNamingPage:
                                              var route = GetPageRoute(
                                                settings: settings,
                                                transition: Transition
                                                    .rightToLeftWithFade,
                                                page: () => CacheNamingPage(),
                                                middlewares: [
                                                  ListenPopMiddleware(),
                                                ],
                                              );
                                              addAndCleanReapeatRoute(
                                                route,
                                                RouteName.cacheNamingPage,
                                              );
                                              return route;
                                            default:
                                              var route = GetPageRoute(
                                                settings: settings,
                                                page: () {
                                                  final args =
                                                      settings.arguments
                                                          as Map<
                                                            String,
                                                            dynamic
                                                          >? ??
                                                      {};
                                                  return PlaylistInfo(
                                                    listId: args['listId'],
                                                    is_my:
                                                        args['is_my'] ?? false,
                                                  );
                                                },
                                                middlewares: [
                                                  ListenPopMiddleware(),
                                                ],
                                              );
                                              addAndCleanReapeatRoute(
                                                route,
                                                settings.name!,
                                              );
                                              return route;
                                          }
                                          return MaterialPageRoute(
                                            builder: builder,
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
                      if (!globalHorizon)
                        SafeArea(top: false, child: SizedBox(height: 256.w))
                      else
                        SizedBox(height: 60),
                    ],
                  ),
                ),

                ///测试按钮
                // Positioned.fill(
                //   child: SafeArea(
                //     top: false,
                //     child: Align(
                //       alignment: Alignment.bottomRight,
                //       child: Padding(
                //         padding: EdgeInsets.only(
                //           bottom: globalHorizon ? 76 : 300.w,
                //           right: globalHorizon ? 16 : 40.w,
                //         ),
                //         child: Row(
                //           mainAxisSize: MainAxisSize.min,
                //           children: [
                //             FloatingActionButton(
                //               onPressed: () async {
                //                 // final securityTest = SecurityTestExample();
                //                 // await securityTest.runAllTests();
                //               },
                //               child: Icon(Icons.bug_report),
                //             ),
                //             FloatingActionButton(
                //               onPressed: () async {
                //                 logger.i(
                //                   Platform.executable
                //                 );logger.i(
                //                   Platform.resolvedExecutable
                //                 );logger.i(
                //                   Platform.script
                //                 );
                //                 showErrorSnackbar('', '${Platform.executable}\n${Platform.resolvedExecutable}\n${Platform.script}');
                //               },
                //               child: Icon(Icons.bug_report),
                //             ),
                //           ],
                //         ),
                //       ),
                //     ),
                //   ),
                // ),

                ///WebSocketClientControlPanel悬浮按钮
                Positioned.fill(
                  child: SafeArea(
                    top: false,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: globalHorizon ? 76 : 300.w,
                          right: globalHorizon ? 16 : 40.w,
                        ),
                        child: WebSocketClientControlPanel.floatingActionButton,
                      ),
                    ),
                  ),
                ),

                /// 播放控制栏
                Positioned.fill(
                  child: globalHorizon
                      ? Align(alignment: Alignment.bottomCenter, child: _play)
                      : SafeArea(top: false, child: _play),

                  // 竖屏状态下添加额外的占位空间
                ),
              ],
            ),
            // floatingActionButton:
            // FloatingActionButton(
            //   onPressed: () {
            //     Get.find<Applinkscontroller>().processAppLink();
            //   },
            // ),
            // WebSocketClientControlPanel.floatingActionButton,
          );

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              router_pop();
            },
            child: isDesktop && globalHorizon ? Obx(() => con()) : con(),
          );
        },
      ),
    );
  }

  bool _windowManagerOnce = false;
  @override
  void onWindowFocus() {
    // 确保只调用一次
    if (!_windowManagerOnce) {
      _windowManagerOnce = true;
      if (isWindows) {
        enableThumbnailToolbar();
      }
      // if (isDesktop) {
      //   Get.find<ThemeController>().didChangePlatformBrightnessOrManual();
      // }
      setState(() {});
      // 做些什么
    }
  }

  @override
  void onWindowResized() {
    Get.find<SettingsController>().saveWindowsSizeAndPosition();
  }

  @override
  void onWindowMaximize() {
    Get.find<SettingsController>().onWindowMaximize();
  }

  @override
  void onWindowUnmaximize() {
    Get.find<SettingsController>().onWindowUnmaximize();
  }

  void showVolumeSlider() async {
    if (volumeSliderVisible) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      volumeSliderVisible = false;
      return;
    }
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
                    min: 0.0,
                    max: 100.0,
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
