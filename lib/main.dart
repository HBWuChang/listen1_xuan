import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:listen1_xuan/netease.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bl.dart';
import 'settings.dart';
import 'loweb.dart';
import 'bodys.dart';
import 'play.dart';
import 'dart:async';
import 'dart:isolate';
import 'package:flutter_isolate/flutter_isolate.dart';
import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

final dio_with_cookie_manager = Dio();

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
  final cookiePath = '${appDocDir.path}/cookies';

  // 创建 PersistCookieJar 实例
  final cookieJar = PersistCookieJar(storage: FileStorage(cookiePath));

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
      ),
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

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  final List<String> platforms = ['我的', 'BiliBili', '网易云', 'QQ', '酷狗'];
  bool _isSearchActive = false;
  TextEditingController input_text_Controller = TextEditingController();
  FocusNode _focusNode = FocusNode();
  FocusNode _focusNode2 = FocusNode();
  late AnimationController _animationController;
  bool _Mainpage = true;
  String _playlist_id = "bilibili";
  String selectedOption = '网易云';
  final List<String> _options = ['BiliBili', '网易云', "QQ", '酷狗'];
  final ValueNotifier<String> selectedOptionNotifier =
      ValueNotifier<String>('Option 1');
  Key _playlistInfoKey = UniqueKey();
  OverlayEntry? _overlayEntry;
  Timer? _timer;
  double _currentVolume = 0.5;
  bool volumeSliderVisible = false;
  @override
  void initState() {
    super.initState();
    download_receiveport.listen((message) {
      if (message is SendPort) {
        print('download_sendport初始化');
        download_sendport = message;
      }
    });
    FlutterIsolate.spawn(
        downloadtasks_background, download_receiveport.sendPort);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _isSearchActive = true;
          _animationController.forward(from: 0);
        });
      }
    });

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
      animationBehavior: AnimationBehavior.preserve,
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isSearchActive) {
        _focusNode2.requestFocus();
      }
    });
    _animationController.forward(from: 0.0);
  }

  void _onSearchBackTapped() {
    // _animationController.reverse(from: 1.0);
    setState(() {
      _isSearchActive = false;
      if (!_isSearchActive) {
        _focusNode.unfocus();
      }
    });
    _animationController.forward(from: 0.0);
  }

  int _selectedIndex = 0;
  int offset = 0;
  bool main_is_my = false;
  String source = 'myplaylist';
  Map<String, dynamic> filter = {'id': '', 'name': '全部'};
  bool show_filter = false;
  // bool show_more = false;
  Map<String, dynamic> filter_detail = {};
  void _onItemTapped(int index) async {
    switch (index) {
      case 0:
        source = 'myplaylist';
        offset = 0;
        filter = {'id': '', 'name': '全部'};
        show_filter = false;
        break;
      case 1:
        offset = 0;
        filter = {'id': '', 'name': '全部'};
        show_filter = false;
        source = 'bilibili';
        break;
      case 2:
        offset = 0;
        filter = {'id': '', 'name': '全部'};
        show_filter = true;
        source = 'netease';
        break;
      case 3:
        offset = 0;
        filter = {'id': '', 'name': '全部'};
        show_filter = true;
        source = 'qq';
        break;
      case 4:
        offset = 0;
        filter = {'id': '', 'name': '全部'};
        show_filter = false;
        source = 'kugou';
        break;
    }
    try {
      if (source == 'myplaylist') {
        setState(() {
          _selectedIndex = index;
        });
        return;
      }
      // 检查 mounted 属性
      if (!mounted) return;
      // filter_detail = await MediaService.getPlaylistFilters(source);
      // // 再次检查 mounted 属性
      // if (mounted) {
      //   setState(() {
      //     _selectedIndex = index;
      //   });
      // }
      var t = await MediaService.getPlaylistFilters(source);
      t["success"]((data) {
        filter_detail = data;
        if (mounted) {
          setState(() {
            _selectedIndex = index;
          });
        }
      });
    } catch (e) {
      print(e);
    }
  }

  void change_fliter(dynamic id, String name) {
    print('change_fliter{id: $id, name: $name}');
    setState(() {
      filter = {'id': id, 'name': name};
    });
  }

  void change_main_status(String id, [bool is_my = false]) {
    main_is_my = is_my;
    _playlistInfoKey = UniqueKey();
    if (id != "") {
      setState(() {
        _Mainpage = false;
        _playlist_id = id;
      });
    } else {
      setState(() {
        _Mainpage = true;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _timer?.cancel();
    _focusNode2.dispose();
    try {
      _animationController.dispose();
    } catch (e) {
      // print(e);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        // onWillPop: () async {
        //   if (!_Mainpage) {
        //     change_main_status("");
        //     return false; // 阻止默认的返回操作
        //   }
        //   return true; // 允许默认的返回操作
        // },
        canPop: false,
        onPopInvokedWithResult: (didPop, result) => {
              print("didPop: $didPop, result: $result"),
              if (!didPop)
                {
                  change_main_status(""),
                  if (_isSearchActive) {_onSearchBackTapped()}
                },
            },
        child: Scaffold(
          appBar: _Mainpage
              ? AppBar(
                  title: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return SizeTransition(
                        sizeFactor: _animationController,
                        axis: Axis.horizontal,
                        axisAlignment: -1,
                        child: Row(
                          children: [
                            if (!_isSearchActive) Text('Listen1'),
                            if (!_isSearchActive) SizedBox(width: 10),
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
                                autofocus: _isSearchActive,
                                focusNode:
                                    _isSearchActive ? _focusNode2 : _focusNode,
                              ),
                            ),
                            if (!_isSearchActive)
                              IconButton(
                                icon: Icon(Icons.settings),
                                onPressed: () {
                                  // Navigate to settings
                                  // download_sendport.send("get_download_tasks");
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) {
                                      return SettingsPage();
                                    }),
                                  );
                                },
                              ),
                            if (_isSearchActive)
                              DropdownButton<String>(
                                value: selectedOption,
                                icon: Icon(Icons.arrow_downward),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    selectedOption = newValue!;
                                    selectedOptionNotifier.value = newValue;
                                  });
                                },
                                items: _options.map<DropdownMenuItem<String>>(
                                    (String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                              ),
                          ],
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        ),
                      );
                    },
                  ),
                )
              : null,
          body: _isSearchActive
              ? Searchlistinfo(
                  input_text_Controller: input_text_Controller,
                  selectedOptionNotifier: selectedOptionNotifier,
                  onPlaylistTap: change_main_status)
              : _Mainpage
                  ? Column(
                      children: [
                        Container(
                            height: 45,
                            child: Row(children: [
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
                                  _onItemTapped(index);
                                },
                              )),
                              if (show_filter)
                                TextButton(
                                  child: Text(filter['name']),
                                  onPressed: () {
                                    Map<String, dynamic> tfilter = {};
                                    tfilter["推荐"] = filter_detail["recommend"];
                                    for (var item in filter_detail["all"]) {
                                      tfilter[item["category"]] =
                                          item["filters"];
                                    }
                                    _showFilterSelection(context, tfilter,
                                        filter['id'], change_fliter);
                                  },
                                ),
                            ])),
                        // 长灰色细分割线
                        Divider(
                          height: 1,
                          color: Colors.grey[300],
                        ),
                        Expanded(
                            child: GestureDetector(
                                onHorizontalDragEnd: (details) {
                                  if (details.primaryVelocity != null) {
                                    if (details.primaryVelocity! > 0) {
                                      if (_selectedIndex == 0) {
                                        return;
                                      }
                                      _onItemTapped(_selectedIndex - 1);
                                    } else if (details.primaryVelocity! < 0) {
                                      if (_selectedIndex ==
                                          platforms.length - 1) {
                                        return;
                                      }
                                      _onItemTapped(_selectedIndex + 1);
                                    }
                                  }
                                },
                                child: source != "myplaylist"
                                    ? Playlist(
                                        key: ValueKey(filter),
                                        source: source,
                                        offset: offset,
                                        filter: filter,
                                        onPlaylistTap: change_main_status)
                                    : MyPlaylist(
                                        onPlaylistTap: change_main_status)))
                      ],
                    )
                  : PlaylistInfo(
                      key: _playlistInfoKey,
                      listId: _playlist_id,
                      onPlaylistTap: change_main_status,
                      is_my: main_is_my,
                    ),
          // bottomNavigationBar: play));
          bottomNavigationBar: Play(onPlaylistTap: change_main_status),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              if (volumeSliderVisible) {
                _overlayEntry?.remove();
                _overlayEntry = null;
                volumeSliderVisible = false;
                return;
              }
              _showVolumeSlider(context);
            },
            child: Icon(Icons.volume_up),
          ),
        ));
  }

  void _showVolumeSlider(BuildContext context) async {
    try {
      _currentVolume = await get_player_settings("volume");
    } catch (e) {
      _currentVolume = 50;
    }
    _currentVolume = _currentVolume / 100;
    volumeSliderVisible = true;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context)!.insert(_overlayEntry!);
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
