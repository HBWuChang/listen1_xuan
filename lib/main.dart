import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:listen1_xuan/controllers/controllers.dart';
import 'package:listen1_xuan/controllers/search_controller.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/pages/lyric/lyric_page.dart';
import 'package:media_kit/media_kit.dart' show MediaKit;
import 'package:resizable_widget/resizable_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'controllers/HomeController.dart';
import 'controllers/upd_controller.dart';
import 'examples/websocket_server_example.dart';
import 'examples/websocket_client_example.dart';
import 'pages/download_page.dart';
import 'pages/nowPlaying_page.dart';
import 'pages/settings/settings_readme.dart';
import 'pages/settings/settings_supabase_login_page.dart';
import 'pages/settings/settings_supabase_password_login_page.dart';
import 'pages/settings/cache_naming_page.dart';
import 'pages/songReplace_page.dart';
import 'settings.dart';
import 'loweb.dart';
import 'bodys.dart';
import 'play.dart';
import 'global_settings_animations.dart';
import 'widgets.dart';
import 'widgets/smooth_sheet_toast.dart';
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
import 'package:shared_preferences/util/legacy_to_async_migration_util.dart';
part 'main_testBtn.dart';
part 'pages/main/main_widgets.dart';
part 'pages/main/main_utils.dart';

String supabaseUrl = 'https://jtvxrwybwvgpqobyhaoy.supabase.co';

String supabaseKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0dnhyd3lid3ZncHFvYnloYW95Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE5NjE5ODUsImV4cCI6MjA3NzUzNzk4NX0.lb4YhPlsyTinmoK85jv_15KCEv1QDr0JsUa1oI5P0Ko';

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
  const SharedPreferencesOptions sharedPreferencesOptions =
      SharedPreferencesOptions();
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await migrateLegacySharedPreferencesToSharedPreferencesAsyncIfNecessary(
    legacySharedPreferencesInstance: prefs,
    sharedPreferencesAsyncOptions: sharedPreferencesOptions,
    migrationCompletedKey: 'migrationCompleted',
  );
  SettingsController settingsController = Get.put(
    SettingsController(),
    permanent: true,
  );
  await settingsController.init();
  Get.put(RouteController(), permanent: true);
  DioController dioController = Get.put(DioController(), permanent: true);
  await dioController.loadConfig();
  settingsController.completeDioInit();
  CacheController cacheController = Get.put(CacheController(), permanent: true);
  Get.put(PlayController(), permanent: true);
  cacheController.loadLocalCacheList();
  Get.find<PlayController>().loadDatas();
  Get.put(MyPlayListController(), permanent: true);
  Get.find<MyPlayListController>().loadDatas();
  Get.put(AudioHandlerController(), permanent: true);
  Get.put(XLyricController(), permanent: true);
  Get.put(NowPlayingPageController(), permanent: true);
  Get.put(BroadcastWsController(), permanent: true);
  Get.put(ScanBroadcastController(), permanent: true);
  Get.put(WsDownloadController(), permanent: true);
  Get.put(Applinkscontroller(), permanent: true);
  Get.put(SupabaseAuthController(), permanent: true);
  Get.put(XSearchController(), permanent: true);
  Get.put(UpdController(), permanent: true);
  Get.put(HomeController(), permanent: true);
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
  // dioWithCookieManager.httpClientAdapter = IOHttpClientAdapter(
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

var main_showVolumeSlider;

late bool globalHorizon;
final List<String> platforms = ['我的', 'BiliBili', '网易云', 'QQ', '酷狗'];

HomeController get homeController => Get.find<HomeController>();

TextEditingController get input_text_Controller =>
    Get.find<XSearchController>().searchTextController;

class _MyHomePageState extends State<MyHomePage>
    with TrayListener, WindowListener, WidgetsBindingObserver {
  FocusNode _focusNode = FocusNode();
  FocusNode _focusNode2 = FocusNode();
  PlayController _playController = Get.find<PlayController>();
  OverlayEntry? _overlayEntry;
  Timer? _timer;
  bool volumeSliderVisible = false;
  @override
  void initState() {
    super.initState();
    if (isDesktop) WidgetsBinding.instance.addObserver(this);
    trayManager.addListener(this);
    homeController.updatePageControllers();
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

    smoothSheetToast = SmoothSheetToast();
    smoothSheetToast.init(navigatorKey.currentContext!);
  }

  @override
  void onWindowClose() {
    closeApp();
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

  void init_playlist_filters() async {
    for (var i = 1; i < HomeController.sources.length; i++) {
      var t = await MediaService.getPlaylistFilters(HomeController.sources[i]);
      t["success"]((data) {
        debugPrint(HomeController.sources[i]);
        debugPrint(data.toString());
        homeController.filter_details[i] = data;
      });
    }
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
    homeController.pageControllerHorizon.dispose(); // 销毁 PageController
    homeController.pageControllerPortrait.dispose();
    try {} catch (e) {
      // print(e);
    }
    super.dispose();
  }

  bool left_to_right_reverse = true;
  List<double> horPartPercentages =
      Get.find<SettingsController>().horPartPercentages;
  @override
  Widget build(BuildContext main_context) {
    homeController.main_context = main_context;
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
            homeController.selectedIndex.value = 2;
            debugPrint('当前为横屏模式');
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

            homeController.show_filter.value = true;
          } else {
            homeController.selectedIndex.value = 0;
            debugPrint('当前为竖屏模式');
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          }
          homeController.source.value =
              HomeController.sources[homeController.selectedIndex.value];
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
            homeController.updatePageControllers();
          }
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
                        child: globalHorizon
                            ? ResizableWidget(
                                isHorizontalSeparator: false,
                                isDisabledSmartHide: false,
                                separatorColor: AdaptiveTheme.of(
                                  Get.context!,
                                ).theme.colorScheme.secondaryContainer,
                                separatorSize: 2,
                                percentages: horPartPercentages,
                                minWidths: [180, 500],
                                onResized: (infoList) {
                                  Get.find<SettingsController>()
                                      .horPartPercentages = infoList
                                      .map((e) => e.percentage)
                                      .toList();
                                },
                                children: [
                                  // required
                                  isWindows || isMacOS
                                      ? DragToMoveArea(child: _leftBar)
                                      : _leftBar,

                                  _mainContent(),
                                ],
                              )
                            : _mainContent(),
                      ),
                      if (!globalHorizon)
                        SafeArea(top: false, child: SizedBox(height: 256.w))
                      else
                        SizedBox(height: 60),
                    ],
                  ),
                ),

                ///测试按钮
                if (kDebugMode) testBtn,

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
    Overlay.of(homeController.main_context).insert(_overlayEntry!);
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
