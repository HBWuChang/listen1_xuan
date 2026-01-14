part of '../../main.dart';

Container _leftBar(TextEditingController input_text_Controller) => Container(
  color: AdaptiveTheme.of(Get.context!).theme.scaffoldBackgroundColor,
  width: 197,
  child: Column(
    children: [
      SizedBox(height: 10),
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
                child: Text('Listen1', style: TextStyle(fontSize: 24)),
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

Listener _mainContent() => Listener(
  onPointerDown: (event) {
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons == kSecondaryMouseButton) {
      router_pop();
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
  child: Column(
    children: [
      if (isWindows)
        Container(
          height: 25,
          color: AdaptiveTheme.of(Get.context!).theme.scaffoldBackgroundColor,
          child: DragToMoveArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: "返回",
                  onPressed: () {
                    router_pop();
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
                          onPressed: () {
                            showTriStateConfirmDialog(
                              title: '请选择默认操作',
                              message: '关闭应用还是隐藏到托盘？',
                              currentValue: Get.find<SettingsController>()
                                  .windowsCloseBtnCloseOrHideApp,
                              confirmText: '关闭应用',
                              rejectText: '隐藏到托盘',
                              autoRem: true,
                              onRemember: (value) {
                                // 用户勾选"记住选择"时保存设置
                                Get.find<SettingsController>()
                                        .windowsCloseBtnCloseOrHideApp =
                                    value;
                              },
                            ).then((value) async {
                              if (value == null) return;
                              if (value == true) {
                                closeApp();
                              } else {
                                windowManager.hide();
                                windowManager.setSkipTaskbar(true);
                              }
                            });
                          },
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
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 0,
                                  right: 100,
                                  left: 0,
                                  child: Container(
                                    height: 40,
                                    child: AnimatedTabBarWidget(
                                      pageController:
                                          homeController.pageControllerHorizon,
                                      tabLabels: platforms
                                          .sublist(1)
                                          .map(
                                            (platform) =>
                                                TextSpan(text: platform),
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
                                    () => AnimatedOpacity(
                                      opacity: homeController.show_filter.value
                                          ? 1.0
                                          : 0.0,
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      child: TextButton(
                                        child: Obx(
                                          () => Text(
                                            homeController
                                                .filters[HomeController.sources
                                                .indexOf(
                                                  homeController.source.value,
                                                )]['name'],
                                          ),
                                        ),
                                        onPressed:
                                            homeController.show_filter.value
                                            ? () {
                                                Map<String, dynamic> tfilter =
                                                    {};
                                                tfilter["推荐"] =
                                                    homeController
                                                        .filter_details[homeController
                                                        .selectedIndex
                                                        .value]["recommend"];
                                                for (var item
                                                    in homeController
                                                        .filter_details[homeController
                                                        .selectedIndex
                                                        .value]["all"]) {
                                                  tfilter[item["category"]] =
                                                      item["filters"];
                                                }
                                                _showFilterSelection(
                                                  context_in_1,
                                                  tfilter,
                                                  homeController
                                                      .filters[HomeController
                                                      .sources
                                                      .indexOf(
                                                        homeController
                                                            .source
                                                            .value,
                                                      )]['id'],
                                                  homeController.change_fliter,
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
                          Expanded(
                            child: PreloadPageView.builder(
                              physics: BouncingScrollPhysics(),
                              controller: homeController
                                  .pageControllerHorizon, // 使用 PageController
                              itemCount:
                                  HomeController.sources.length - 1, // 页面数量
                              preloadPagesCount:
                                  HomeController.sources.length - 1,

                              itemBuilder: (context, index) {
                                index = index + 1;
                                // 其他页面：动态生成
                                return Obx(() {
                                  return Playlist(
                                    source: HomeController.sources[index],
                                    offset: homeController.offsets[index],
                                    filter: homeController.filters[index],
                                    key: Key(
                                      homeController.filters[index].toString(),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Listen1'),
                            SizedBox(width: 10),
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
                      body: Column(
                        children: [
                          Container(
                            height: 45,
                            child: Row(
                              children: [
                                Expanded(
                                  child: AnimatedTabBarWidget(
                                    pageController:
                                        homeController.pageControllerPortrait,
                                    tabLabels: platforms
                                        .map(
                                          (platform) =>
                                              TextSpan(text: platform),
                                        )
                                        .toList(),
                                    containerHeight: 45,
                                    spacing: 0,
                                  ),
                                ),
                                Obx(
                                  () => AnimatedSize(
                                    duration: const Duration(milliseconds: 300),
                                    child: homeController.show_filter.value
                                        ? TextButton(
                                            child: Obx(
                                              () => Text(
                                                homeController
                                                    .filters[HomeController
                                                    .sources
                                                    .indexOf(
                                                      homeController
                                                          .source
                                                          .value,
                                                    )]['name'],
                                              ),
                                            ),
                                            onPressed:
                                                homeController.show_filter.value
                                                ? () {
                                                    Map<String, dynamic>
                                                    tfilter = {};
                                                    tfilter["推荐"] =
                                                        homeController
                                                            .filter_details[homeController
                                                            .selectedIndex
                                                            .value]["recommend"];
                                                    for (var item
                                                        in homeController
                                                            .filter_details[homeController
                                                            .selectedIndex
                                                            .value]["all"]) {
                                                      tfilter[item["category"]] =
                                                          item["filters"];
                                                    }
                                                    _showFilterSelection(
                                                      context_in_1,
                                                      tfilter,
                                                      homeController
                                                          .filters[HomeController
                                                          .sources
                                                          .indexOf(
                                                            homeController
                                                                .source
                                                                .value,
                                                          )]['id'],
                                                      homeController
                                                          .change_fliter,
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
                          Divider(height: 1, color: Colors.grey[300]),
                          Expanded(
                            child: PreloadPageView.builder(
                              physics: BouncingScrollPhysics(),
                              controller: homeController
                                  .pageControllerPortrait, // 使用 PageController
                              itemCount: HomeController.sources.length, // 页面数量
                              preloadPagesCount: HomeController.sources.length,

                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  // 第一个页面：我的歌单
                                  return MyPlaylist();
                                } else {
                                  // 其他页面：动态生成
                                  return Obx(() {
                                    return Playlist(
                                      source: HomeController.sources[index],
                                      offset: homeController.offsets[index],
                                      filter: homeController.filters[index],
                                      key: Key(
                                        homeController.filters[index]
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
                  middlewares: [ListenPopMiddleware()],
                );
                addAndCleanReapeatRoute(route, RouteName.searchPage);
                return route;
              case RouteName.settingsPage:
                var route = GetPageRoute(
                  settings: settings,
                  page: () => SettingsPage(),
                  middlewares: [ListenPopMiddleware()],
                );
                addAndCleanReapeatRoute(route, RouteName.settingsPage);
                return route;
              case RouteName.nowPlayingPage:
                var route = GetPageRoute(
                  settings: settings,
                  transition: Transition.downToUp,
                  // Transition.noTransition,
                  page: () => NowPlayingPage(),
                  middlewares: [ListenPopMiddleware()],
                );
                addAndCleanReapeatRoute(route, RouteName.nowPlayingPage);
                return route;
              case RouteName.lyricPage:
                var route = GetPageRoute(
                  settings: settings,
                  transition: Transition.downToUp,
                  page: () => LyricPage(),
                  middlewares: [ListenPopMiddleware()],
                );
                addAndCleanReapeatRoute(route, RouteName.lyricPage);
                return route;
              case RouteName.settingsReadmePage:
                var route = GetPageRoute(
                  settings: settings,
                  transition: Transition.rightToLeftWithFade,
                  page: () => SettingsReadmePage(),
                  middlewares: [ListenPopMiddleware()],
                );
                addAndCleanReapeatRoute(route, RouteName.settingsReadmePage);
                return route;
              case RouteName.downloadPage:
                var route = GetPageRoute(
                  settings: settings,
                  transition: Transition.rightToLeftWithFade,
                  page: () => DownloadPage(),
                  middlewares: [ListenPopMiddleware()],
                );
                addAndCleanReapeatRoute(route, RouteName.downloadPage);
                return route;
              case RouteName.supabaseLoginPage:
                var route = GetPageRoute(
                  settings: settings,
                  transition: Transition.rightToLeftWithFade,
                  page: () => SupabaseLoginPage(),
                  middlewares: [ListenPopMiddleware()],
                );
                addAndCleanReapeatRoute(route, RouteName.supabaseLoginPage);
                return route;
              case RouteName.supabasePasswordLoginPage:
                var route = GetPageRoute(
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
                var route = GetPageRoute(
                  settings: settings,
                  transition: Transition.rightToLeftWithFade,
                  page: () => CacheNamingPage(),
                  middlewares: [ListenPopMiddleware()],
                );
                addAndCleanReapeatRoute(route, RouteName.cacheNamingPage);
                return route;
              case RouteName.songReplacePage:
                var route = GetPageRoute(
                  settings: settings,
                  page: () => SongReplacePage(),
                  middlewares: [ListenPopMiddleware()],
                );
                addAndCleanReapeatRoute(route, RouteName.songReplacePage);
                return route;
              default:
                var route = GetPageRoute(
                  settings: settings,
                  page: () {
                    final args =
                        settings.arguments as Map<String, dynamic>? ?? {};
                    return PlaylistInfo(
                      listId: args['listId'],
                      is_my: args['is_my'] ?? false,
                    );
                  },
                  middlewares: [ListenPopMiddleware()],
                );
                addAndCleanReapeatRoute(route, settings.name!);
                return route;
            }
            return MaterialPageRoute(builder: builder);
          },
        ),
      ),
    ],
  ),
);
