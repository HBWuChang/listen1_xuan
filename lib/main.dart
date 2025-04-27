import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:listen1_xuan/netease.dart';
import 'package:animations/animations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bl.dart';
import 'settings.dart';
import 'loweb.dart';
import 'bodys.dart';
import 'play.dart';
import 'animations.dart';
import 'dart:async';
import 'dart:isolate';
import 'package:flutter_isolate/flutter_isolate.dart';
import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:preload_page_view/preload_page_view.dart';
import 'package:flutter/foundation.dart';

final dio_with_cookie_manager = Dio();
List<BuildContext> top_context = List.empty(growable: true);

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
    Map<String, dynamic> download_tasks =
        jsonDecode(prefs.getString("download_tasks") ?? "{}");
    if (download_tasks.isEmpty) {
      return {
        "waiting": [],
        "downloading": [],
        "downloaded": [],
        "failed": [],
      };
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
      Map<String, dynamic> download_tasks = await get_download_tasks();
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 确保 Flutter 框架已初始化

  Map<String, dynamic> settings = await settings_getsettings();
  bool useHttpOverrides = false;
  if (settings["useHttpOverrides"] == null) {
    settings["useHttpOverrides"] = false;
    await settings_setsettings(settings);
  } else {
    useHttpOverrides = settings["useHttpOverrides"];
  }
  // 根据设置的值决定是否运行 HttpOverrides.global = MyHttpOverrides();
  if (useHttpOverrides) {
    HttpOverrides.global = MyHttpOverrides();
  }
  final appDocDir = await getApplicationDocumentsDirectory();
  final cookiePath = '${appDocDir.path}/.cookies/';

  // 创建 PersistCookieJar 实例
  final cookieJar =
      PersistCookieJar(storage: FileStorage(cookiePath), ignoreExpires: true);

  // 将 PersistCookieJar 添加到 Dio 的拦截器中
  dio_with_cookie_manager.interceptors.add(CookieManager(cookieJar));
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Listen1',
      theme: ThemeData(
          primarySwatch: Colors.indigo,
          useMaterial3: true,
          primaryColor: Colors.indigo,
          pageTransitionsTheme: const PageTransitionsTheme(builders: {
            TargetPlatform.android: SharedAxisPageTransitionsBuilder(
              transitionType: SharedAxisTransitionType.scaled,
            ),
            TargetPlatform.iOS: SharedAxisPageTransitionsBuilder(
              transitionType: SharedAxisTransitionType.scaled,
            ),
          })),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
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
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

List<String> sources = ['myplaylist', 'bilibili', 'netease', 'qq', 'kugou'];
List<bool> show_filters = [false, false, true, true, false];

bool clean_top_context() {
  while (top_context.length > 1) {
    try {
      if (Navigator.of(top_context.last).canPop()) {
        return true;
      } else {
        top_context.removeLast();
      }
    } catch (e) {
      top_context.removeLast();
    }
  }
  return false;
}

var main_showVolumeSlider;

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  final List<String> platforms = ['我的', 'BiliBili', '网易云', 'QQ', '酷狗'];
  bool _isSearchActive = false;
  TextEditingController input_text_Controller = TextEditingController();
  FocusNode _focusNode = FocusNode();
  FocusNode _focusNode2 = FocusNode();
  late AnimationController animationController;
  bool _Mainpage = true;
  String _playlist_id = "bilibili";
  late PreloadPageController _pageController; // 声明 PageController

  Key _playlistInfoKey = UniqueKey();
  OverlayEntry? _overlayEntry;
  Timer? _timer;
  double _currentVolume = 0.5;
  bool volumeSliderVisible = false;
  @override
  void initState() {
    super.initState();
    main_showVolumeSlider = showVolumeSlider;
    _pageController = PreloadPageController(
        initialPage: _selectedIndex); // 初始化 PageController
    download_receiveport.listen((message) {
      if (message is SendPort) {
        print('download_sendport初始化');
        download_sendport = message;
      }
    });
    FlutterIsolate.spawn(
        downloadtasks_background, download_receiveport.sendPort);

    animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
      animationBehavior: AnimationBehavior.preserve,
    );

    animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isSearchActive) {
        _focusNode2.requestFocus();
      }
    });
    animationController.forward(from: 0.0);
    init_playlist_filters();
  }

  void _onSearchBackTapped() {
    // _animationController.reverse(from: 1.0);
    setState(() {
      _isSearchActive = false;
      if (!_isSearchActive) {
        _focusNode.unfocus();
      }
    });
    animationController.forward(from: 0.0);
  }

  int _selectedIndex = 0;
  List<int> offsets = List.generate(sources.length, (i) => 0);
  bool main_is_my = false;
  String source = 'myplaylist';
  List<Map<String, dynamic>> filters =
      List.generate(sources.length, (i) => {'id': '', 'name': '全部'});
  bool show_filter = false;
  // bool show_more = false;
  List<Map<String, dynamic>> filter_details =
      List.generate(sources.length, (i) => {'recommend': [], 'all': []});
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

  var buttons_setstate;
  void _onItemTapped(int index, {bool re = false}) async {
    if (index == _selectedIndex) {
      return;
    }
    source = sources[index];
    show_filter = show_filters[index];
    try {
      buttons_setstate(() {
        _selectedIndex = index;
      });
      _pageController.animateToPage(
        // 通知 PageController 切换页面
        index,
        duration: Duration(milliseconds: 150),
        curve: Curves.easeInOut,
      );
    } catch (e) {
      print(e);
    }
  }

  void change_fliter(dynamic id, String name) {
    print('change_fliter{id: $id, name: $name}');
    setState(() {
      filters[sources.indexOf(source)] = {'id': id, 'name': name};
    });
  }

  void change_main_status(String id,
      {bool is_my = false, String search_text = ""}) {
    main_is_my = is_my;
    _playlistInfoKey = UniqueKey();
    if (id != "") {
      clean_top_context();
      Navigator.of(top_context.last).push(
        MaterialPageRoute(
          builder: (context) => PlaylistInfo(
            listId: id,
            onPlaylistTap: change_main_status,
            is_my: false,
          ),
        ),
      );
    } else {
      if (search_text != "") {
        input_text_Controller.text = search_text;
        clean_top_context();
        Navigator.of(top_context.last).push(
          PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
                top_context.add(context);
                return Searchlistinfo(
                  input_text_Controller: input_text_Controller,
                  onPlaylistTap: change_main_status,
                  animationController: animationController,
                );
              },
              transitionsBuilder: (context, animation, secondaryAnimation,
                      child) =>
                  search_Animation(
                      animation: animation,
                      secondaryAnimation: secondaryAnimation,
                      child: child,
                      axis: Axis.vertical)),
        );
      } else {
        setState(() {
          _Mainpage = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _timer?.cancel();
    _focusNode2.dispose();
    _pageController.dispose(); // 销毁 PageController
    try {
      animationController.dispose();
    } catch (e) {
      // print(e);
    }
    super.dispose();
  }

  late BuildContext _main_context;
  int last_pop_time = 0;
  bool left_to_right_reverse = true;
  AnimationStatus lastStatus = AnimationStatus.forward;
  @override
  Widget build(BuildContext main_context) {
    _main_context = main_context;
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          print("didPop: didPop,");
          if (clean_top_context()) {
            Navigator.of(top_context.last).pop(); // 触发嵌套 Navigator 的 pop
            top_context.removeLast();
            return;
          }
          if (_isSearchActive) {
            _onSearchBackTapped();
            return;
          }
          if (_Mainpage) {
            if (DateTime.now().millisecondsSinceEpoch - last_pop_time < 1000) {
              if (kDebugMode) {
                print("exit(0)");
              } else {
                exit(0);
              }
            } else {
              Fluttertoast.showToast(
                msg: "再按一次退出",
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 1,
                backgroundColor: Colors.black54,
                textColor: Colors.white,
                fontSize: 16.0,
              );
              last_pop_time = DateTime.now().millisecondsSinceEpoch;
            }
          } else {
            change_main_status("");
            if (_isSearchActive) {
              _onSearchBackTapped();
            }
          }
        },
        child: Scaffold(
          body: Navigator(
            initialRoute: '/',
            onGenerateRoute: (RouteSettings settings) {
              WidgetBuilder builder;
              switch (settings.name) {
                case '/':
                  // 在函数内部定义默认页面
                  builder = (context_in_1) {
                    top_context.add(context_in_1);
                    return Scaffold(
                        appBar: _Mainpage
                            ? AppBar(
                                title: AnimatedBuilder(
                                  animation: animationController,
                                  builder: (context_app_bar, child) {
                                    return SizeTransition(
                                      sizeFactor: animationController,
                                      axis: Axis.horizontal,
                                      axisAlignment: -1,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          if (!_isSearchActive) Text('Listen1'),
                                          if (!_isSearchActive)
                                            SizedBox(width: 10),
                                          if (_isSearchActive)
                                            IconButton(
                                              icon: Icon(Icons.arrow_back),
                                              onPressed: _onSearchBackTapped,
                                            ),
                                          Expanded(
                                            child: TextField(
                                              decoration: InputDecoration(
                                                hintText: '请输入歌曲名，歌手或专辑',
                                                border: InputBorder.none,
                                              ),
                                              controller: input_text_Controller,
                                              readOnly: true,
                                              onTap: () async {
                                                clean_top_context();
                                                await Navigator.of(
                                                        top_context.last)
                                                    .push(
                                                  PageRouteBuilder(
                                                    pageBuilder: (context,
                                                        animation,
                                                        secondaryAnimation) {
                                                      top_context.add(context);
                                                      return Searchlistinfo(
                                                        input_text_Controller:
                                                            input_text_Controller,
                                                        onPlaylistTap:
                                                            change_main_status,
                                                        animationController:
                                                            animationController,
                                                      );
                                                    },
                                                    transitionsBuilder: (context,
                                                            animation,
                                                            secondaryAnimation,
                                                            child) =>
                                                        search_Animation(
                                                            animation:
                                                                animation,
                                                            secondaryAnimation:
                                                                secondaryAnimation,
                                                            child: child,
                                                            axis:
                                                                Axis.vertical),
                                                    transitionDuration: Duration(
                                                        milliseconds:
                                                            300), // 延长动画时间到 1000ms
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.settings),
                                            onPressed: () {
                                              Navigator.push(
                                                main_context,
                                                PageRouteBuilder(
                                                  pageBuilder: (context,
                                                      animation,
                                                      secondaryAnimation) {
                                                    return SettingsPage();
                                                  },
                                                  transitionsBuilder: (context,
                                                          animation,
                                                          secondaryAnimation,
                                                          child) =>
                                                      SharedAxisTransition(
                                                    animation: animation,
                                                    secondaryAnimation:
                                                        secondaryAnimation,
                                                    transitionType:
                                                        SharedAxisTransitionType
                                                            .horizontal,
                                                    child: child,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              )
                            : null,
                        body: Column(
                          children: [
                            Container(
                                height: 45,
                                child: StatefulBuilder(
                                    builder: (context, setState) {
                                  buttons_setstate = setState;
                                  return Row(children: [
                                    Expanded(
                                        child: NavigationBar(
                                      labelBehavior:
                                          NavigationDestinationLabelBehavior
                                              .alwaysHide,
                                      selectedIndex: _selectedIndex,
                                      destinations: platforms.map((platform) {
                                        return NavigationDestination(
                                          icon: Center(child: Text(platform)),
                                          label: '',
                                        );
                                      }).toList(),
                                      onDestinationSelected: (index) {
                                        _onItemTapped(index, re: true);
                                      },
                                    )),
                                    if (show_filter)
                                      TextButton(
                                        child: Text(
                                            filters[sources.indexOf(source)]
                                                ['name']),
                                        onPressed: () {
                                          Map<String, dynamic> tfilter = {};
                                          tfilter["推荐"] =
                                              filter_details[_selectedIndex]
                                                  ["recommend"];
                                          for (var item
                                              in filter_details[_selectedIndex]
                                                  ["all"]) {
                                            tfilter[item["category"]] =
                                                item["filters"];
                                          }
                                          _showFilterSelection(
                                              context_in_1,
                                              tfilter,
                                              filters[sources.indexOf(source)]
                                                  ['id'],
                                              change_fliter);
                                        },
                                      ),
                                  ]);
                                })),
                            // 长灰色细分割线
                            Divider(
                              height: 1,
                              color: Colors.grey[300],
                            ),
                            Expanded(
                                child: PreloadPageView.builder(
                              physics: BouncingScrollPhysics(),
                              controller: _pageController, // 使用 PageController
                              itemCount: sources.length, // 页面数量
                              preloadPagesCount: sources.length,
                              onPageChanged: (index) {
                                source = sources[index];
                                show_filter = show_filters[index];
                                buttons_setstate(() {
                                  _selectedIndex = index;
                                });
                              },
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  // 第一个页面：我的歌单
                                  return MyPlaylist(
                                    onPlaylistTap: change_main_status,
                                  );
                                } else {
                                  // 其他页面：动态生成
                                  return Playlist(
                                    source: sources[index],
                                    offset: offsets[index],
                                    filter: filters[index],
                                    onPlaylistTap: change_main_status,
                                    key: Key(filters[index].toString()),
                                  );
                                }
                              },
                            ))
                          ],
                        ));
                  };
                  break;

                default:
                  builder = (context_in_1) => Scaffold(
                        appBar: AppBar(title: Text('Default Page')),
                        body: Center(child: Text('This is the default page')),
                      );
                  break;
              }
              return MaterialPageRoute(builder: builder);
            },
          ),
          bottomNavigationBar: Play(onPlaylistTap: change_main_status),
        ));
  }

  void showVolumeSlider() async {
    try {
      _currentVolume = await get_player_settings("volume");
    } catch (e) {
      _currentVolume = 50;
    }
    _currentVolume = _currentVolume / 100;
    volumeSliderVisible = true;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(_main_context)!.insert(_overlayEntry!);
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
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return Slider(
                      value: _currentVolume,
                      onChanged: (value) {
                        setState(() {
                          _currentVolume = value;
                        });
                        // print(value);
                        set_player_settings("volume", value * 100);
                        music_player.setVolume(value);
                        _startAutoCloseTimer(); // 重置计时器
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showFilterSelection(BuildContext context, Map<String, dynamic> filter,
    dynamic now_id, Function change_fliter) {
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
                            fontSize: 16, fontWeight: FontWeight.bold),
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
                                  filterItem['id'], filterItem['name']);
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
