part of '../../main.dart';

Widget get _leftBar => Scaffold(
  body: Column(
    children: [
      10.sbh,
      isDesktop
          ? Listener(
              onPointerDown: (event) {
                if (event.kind == PointerDeviceKind.mouse &&
                    event.buttons == kSecondaryMouseButton) {
                  windowManager.hide();
                  windowManager.setSkipTaskbar(true);
                }
                if (event.kind == PointerDeviceKind.mouse &&
                    event.buttons == kMiddleMouseButton) {
                  closeApp();
                }
              },
              child: Tooltip(
                message: '右键以最小化,中键以关闭',
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Listen1', style: TextStyle(fontSize: 24)),
                    );
                  },
                ).sbwh(double.infinity, 34),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Listen1', style: TextStyle(fontSize: 24)),
                );
              },
            ).sbwh(double.infinity, 34),
      LayoutBuilder(
        builder: (context, constraints) {
          XSearchController searchController = Get.find<XSearchController>();
          bool useFocusNode = !searchController.showSearchArea.value;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            searchController.leftBarWidth.value = constraints.maxWidth;
          });
          if (constraints.maxWidth > 200) {
            if (searchController.showSearchArea.value) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                searchController.showSearchArea.value = false;
              });
            }
          } else {
            if (!searchController.showSearchArea.value) {
              useFocusNode = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                searchController.showSearchArea.value = true;
              });
            }
          }
          final inputFontSize = (constraints.maxWidth / 6)
              .clamp(12.0, 16.0)
              .toDouble();
          return TextField(
            focusNode: useFocusNode ? searchController.focusNode : null,
            decoration: InputDecoration(
              labelText: '请输入歌曲名，歌手或专辑',
              labelStyle: TextStyle(fontSize: inputFontSize),
              border: InputBorder.none,
            ),
            style: TextStyle(fontSize: inputFontSize),
            controller: input_text_Controller,
            readOnly: searchController.showSearchArea.value,
            onSubmitted: (_) => searchController.onSubmitted(),
            onTap: searchController.showSearchArea.value
                ? () async {
                    Get.toNamed(RouteName.searchPage, id: 1);
                  }
                : null,
          );
        },
      ).sbh(56),
      Expanded(child: MyPlaylist()),

      // SizedBox(),
      PriorityResponsiveActionRow(
        hidePriority: const [2, 1, 0, 3],
        children: [
          ThemeToggleButton(iconSize: 24.0, padding: EdgeInsets.all(0)),
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

final heroineController = HeroineController();

final innerKey = Get.nestedKey(1);
/// 歌单分类（筛选）按钮。
///
/// 注意：任何状态下都不要返回 [SizedBox.shrink] 之类没有内容的子组件。
/// 该按钮的显隐完全交给外层动画（横屏用 [AnimatedOpacity]、竖屏用 [AnimatedSize]）控制，
/// 而「隐藏」和 `empty` 状态是同一时刻发生的；一旦子组件在这里先变成零尺寸，
/// 淡出动画就没有内容可淡，视觉上就成了「瞬间消失」。
Widget get filterButton => Builder(
  builder: (context) => TextButton(
    onPressed: homeController.canFilterClick
        ? () {
            _showFilterSelection(context);
          }
        : null,
    child: Obx(
      () => switch (homeController.playlistFiltersLoadingStatus) {
        PlaylistFiltersLoadingStatus.loading => globalLoadingAnime,
        PlaylistFiltersLoadingStatus.failed => Icon(
          Icons.error,
          color: Colors.red,
        ),
        // loaded / empty / notLoaded 都显示当前分类名（默认「全部」）。
        _ => Text(
          homeController.currentProvider.nowSelectedPlaylistFilter.value.name,
        ),
      },
    ),
  ),
);
Listener _mainContent() => Listener(
  onPointerDown: (event) {
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons == kSecondaryMouseButton) {
      routerPop();
    }
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons == kMiddleMouseButton) {
      switch (Get.find<SettingsController>().hideOrMinimize) {
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
  child: Scaffold(
    body: Column(
      children: [
        if (isWindows)
          DragToMoveArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: "返回",
                  onPressed: () {
                    routerPop();
                  },
                  icon: Icon(Icons.arrow_back_ios_new, size: 13),
                ),
                Obx(
                  () => Container(
                    width:
                        Get.find<SettingsController>()
                                .windowsCloseBtnCloseOrHideApp ==
                            false
                        ? 80
                        : 120,
                    child: Row(
                      children: [
                        if (Get.find<SettingsController>()
                                .windowsCloseBtnCloseOrHideApp !=
                            false)
                          IconButton(
                            tooltip: "隐藏到托盘",
                            icon: Icon(
                              Icons.close_fullscreen_rounded,
                              size: 13,
                            ),
                            onPressed: () {
                              windowManager.hide();
                              windowManager.setSkipTaskbar(true);
                            },
                          ),
                        IconButton(
                          tooltip: "最小化",
                          icon: Icon(Icons.minimize, size: 13),
                          onPressed: () {
                            windowManager.minimize();
                            windowManager.setSkipTaskbar(false);
                          },
                        ),
                        IconButton(
                          tooltip:
                              (Get.find<SettingsController>()
                                      .windowsCloseBtnCloseOrHideApp !=
                                  false)
                              ? "关闭"
                              : "隐藏到托盘",
                          icon: Icon(Icons.close, size: 13),
                          onPressed: _clickCloseBtn,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ).sbh(25),
        Expanded(
          child: Navigator(
            key: innerKey,
            initialRoute: RouteName.defaultPage,
            observers: [heroineController],
            onGenerateRoute: (RouteSettings settings) {
              WidgetBuilder builder;
              switch (settings.name) {
                case RouteName.defaultPage:
                  // 在函数内部定义默认页面
                  if (globalHorizon) {
                    builder = (context_in_1) {
                      return Scaffold(
                        body: OverHeroineScope(
                          child: Column(
                            children: [
                              OverHeroine(
                                keepDir: KeepDir.bottom,
                                child: Container(
                                  height: 40,
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        top: 0,
                                        right: 100,
                                        left: 0,
                                        child: Container(
                                          height: 40,
                                          child: AnimatedTabBarWidget(
                                            pageController: homeController
                                                .pageControllerHorizon,
                                            tabLabels:
                                                supportShowPlaylistProvidersH
                                                    .map(
                                                      (platform) => TextSpan(
                                                        text: platform
                                                            .shortDisplayName,
                                                      ),
                                                    )
                                                    .toList(),
                                            containerHeight: 40,
                                            spacing: 0,
                                          ),
                                        ),
                                      ),

                                      Positioned(
                                        top: isWindows || isMacOS ? 5 : -5,
                                        right: 20,
                                        child: Obx(
                                          // filterButton 隐藏时仍会保留内容，
                                          // 这样淡出才有东西可以淡（见 filterButton 注释）。
                                          () => AnimatedOpacity(
                                            opacity: homeController.showFilter
                                                ? 1.0
                                                : 0.0,
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            child: filterButton,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: PreloadPageView.builder(
                                  physics: BouncingScrollPhysics(),
                                  controller: homeController
                                      .pageControllerHorizon, // 使用 PageController
                                  itemCount: supportShowPlaylistProvidersH
                                      .length, // 页面数量
                                  preloadPagesCount:
                                      supportShowPlaylistProvidersH.length,

                                  itemBuilder: (context, index) {
                                    // 其他页面：动态生成
                                    return Obx(() {
                                      return PlaylistPage(
                                        source:
                                            supportShowPlaylistProvidersH[index],
                                        key: ValueKey(
                                          '${supportShowPlaylistProvidersH[index].name}${supportShowPlaylistProvidersH[index].nowSelectedPlaylistFilter.value.id}',
                                        ),
                                      );
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Listen1'),
                              10.sbw,
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: '请输入歌曲名，歌手或专辑',
                                    border: InputBorder.none,
                                  ),
                                  controller: input_text_Controller,
                                  readOnly: true,
                                  onTap: () async {
                                    Get.toNamed(RouteName.searchPage, id: 1);
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
                                  Get.toNamed(RouteName.settingsPage, id: 1);
                                },
                              ),
                            ],
                          ),
                        ),
                        body: OverHeroineScope(
                          child: Column(
                            children: [
                              SizedBox(
                                height: 45,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: AnimatedTabBarWidget(
                                        pageController: homeController
                                            .pageControllerPortrait,
                                        tabLabels: supportShowPlaylistProviders
                                            .map(
                                              (provider) => TextSpan(
                                                text: provider.shortDisplayName,
                                              ),
                                            )
                                            .toList(),
                                        containerHeight: 45,
                                        spacing: 0,
                                      ),
                                    ),
                                    Obx(
                                      () => AnimatedSize(
                                        // 不要加 key：状态一变 key 就变，
                                        // State 会被重建，尺寸动画会退化成瞬间跳变。
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        // 贴住右边缘，收起/展开时像是从右侧滑出。
                                        alignment: Alignment.centerRight,
                                        // 必须能在隐藏时真的收成 0 宽度，否则占位不会变化。
                                        child: homeController.showFilter
                                            ? filterButton
                                            : const SizedBox.shrink(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 长灰色细分割线
                              OverHeroine(
                                keepDir: KeepDir.bottom,
                                child: Divider(
                                  height: 1,
                                  color: Colors.grey[300],
                                ),
                              ),
                              Expanded(
                                child: PreloadPageView.builder(
                                  physics: BouncingScrollPhysics(),
                                  controller: homeController
                                      .pageControllerPortrait, // 使用 PageController
                                  itemCount: supportShowPlaylistProviders
                                      .length, // 页面数量
                                  preloadPagesCount:
                                      supportShowPlaylistProviders.length,

                                  itemBuilder: (context, index) {
                                    final provider =
                                        supportShowPlaylistProviders[index];
                                    if (provider.isLocal) {
                                      return MyPlaylist();
                                    } else {
                                      return PlaylistPage(
                                        source: provider,
                                        key: Key(provider.name),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    };
                    break;
                  }
                case RouteName.searchPage:
                  var route = ThemedGetPageRoute(
                    settings: settings,
                    page: () => Searchlistinfo(),
                    transition: Transition.upToDown,
                    middlewares: [ListenPopMiddleware()],
                  );
                  addAndCleanReapeatRoute(route, RouteName.searchPage);
                  return route;
                case RouteName.settingsPage:
                  var route = ThemedGetPageRoute(
                    settings: settings,
                    page: () => SettingsPage(),
                    middlewares: [ListenPopMiddleware()],
                  );
                  addAndCleanReapeatRoute(route, RouteName.settingsPage);
                  return route;
                case RouteName.nowPlayingPage:
                  var route = ThemedGetPageRoute(
                    settings: settings,
                    transition: Transition.downToUp,
                    // Transition.noTransition,
                    page: () => NowPlayingPage(),
                    middlewares: [ListenPopMiddleware()],
                  );
                  addAndCleanReapeatRoute(route, RouteName.nowPlayingPage);
                  return route;
                case RouteName.lyricPage:
                  var route = ThemedGetPageRoute(
                    settings: settings,
                    transition: Transition.downToUp,
                    page: () => LyricPage(),
                    middlewares: [ListenPopMiddleware()],
                  );
                  addAndCleanReapeatRoute(route, RouteName.lyricPage);
                  return route;
                case RouteName.settingsReadmePage:
                  var route = ThemedGetPageRoute(
                    settings: settings,
                    transition: Transition.rightToLeftWithFade,
                    page: () => SettingsReadmePage(),
                    middlewares: [ListenPopMiddleware()],
                  );
                  addAndCleanReapeatRoute(route, RouteName.settingsReadmePage);
                  return route;
                case RouteName.downloadPage:
                  var route = ThemedGetPageRoute(
                    settings: settings,
                    transition: Transition.rightToLeftWithFade,
                    page: () => DownloadPage(),
                    middlewares: [ListenPopMiddleware()],
                  );
                  addAndCleanReapeatRoute(route, RouteName.downloadPage);
                  return route;
                case RouteName.supabaseLoginPage:
                  var route = ThemedGetPageRoute(
                    settings: settings,
                    transition: Transition.rightToLeftWithFade,
                    page: () => SupabaseLoginPage(),
                    middlewares: [ListenPopMiddleware()],
                  );
                  addAndCleanReapeatRoute(route, RouteName.supabaseLoginPage);
                  return route;
                case RouteName.supabasePasswordLoginPage:
                  var route = ThemedGetPageRoute(
                    settings: settings,
                    transition: Transition.rightToLeftWithFade,
                    page: () => SupabasePasswordLoginPage(),
                    middlewares: [ListenPopMiddleware()],
                  );
                  addAndCleanReapeatRoute(
                    route,
                    RouteName.supabasePasswordLoginPage,
                  );
                  return route;
                case RouteName.cacheNamingPage:
                  var route = ThemedGetPageRoute(
                    settings: settings,
                    transition: Transition.rightToLeftWithFade,
                    page: () => CacheNamingPage(),
                    middlewares: [ListenPopMiddleware()],
                  );
                  addAndCleanReapeatRoute(route, RouteName.cacheNamingPage);
                  return route;
                case RouteName.equalizerPage:
                  var route = ThemedGetPageRoute(
                    settings: settings,
                    transition: Transition.rightToLeftWithFade,
                    page: () => AndroidEqualizerPage(),
                    middlewares: [ListenPopMiddleware()],
                  );
                  addAndCleanReapeatRoute(route, RouteName.equalizerPage);
                  return route;
                case RouteName.songReplacePage:
                  var route = ThemedGetPageRoute(
                    settings: settings,
                    page: () => SongReplacePage(),
                    middlewares: [ListenPopMiddleware()],
                  );
                  addAndCleanReapeatRoute(route, RouteName.songReplacePage);
                  return route;
                default:
                  final args = settings.arguments is PlaylistInfoArgs
                      ? settings.arguments as PlaylistInfoArgs
                      : null;
                  if (args == null) throw 'unknown route $settings';
                  var route = ThemedGetPageRoute(
                    settings: settings,
                    binding: PlaylistInfoBinding(args: args),
                    page: () => PlaylistInfoPage(args: args),
                    middlewares: [ListenPopMiddleware()],
                  );
                  addAndCleanReapeatRoute(route, settings.name!);
                  return route;
              }
              return MaterialPageRoute(
                builder: (context) => PopScope(
                  // The default route must stay in the nested navigator. This
                  // passive scope also keeps Android back dispatch in Flutter
                  // so the root scope can forward it to routerPop().
                  canPop: false,
                  child: builder(context),
                ),
              );
            },
          ),
        ),
      ],
    ),
  ),
);
