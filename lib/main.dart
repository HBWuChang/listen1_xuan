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

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Listen1',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
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
  bool _isSearchActive = false;
  TextEditingController input_text_Controller = TextEditingController();
  FocusNode _focusNode = FocusNode();
  FocusNode _focusNode2 = FocusNode();
  late AnimationController _animationController;
  bool _Mainpage = true;
  String _playlist_id = "bilibili";

  @override
  void initState() {
    super.initState();
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
    }
    if (source == 'myplaylist') {
      setState(() {
        _selectedIndex = index;
      });
      return;
    }
    // 检查 mounted 属性
    if (!mounted) return;
    filter_detail = await MediaService.getPlaylistFilters(source);
    // 再次检查 mounted 属性
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void change_fliter(String id, String name) {
    print('change_fliter{id: $id, name: $name}');
    setState(() {
      filter = {'id': id, 'name': name};
    });
  }

  void change_main_status(String id, [bool is_my = false]) {
    main_is_my = is_my;
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
                }
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
                                  focusNode: _isSearchActive
                                      ? _focusNode2
                                      : _focusNode,
                                ),
                              ),
                              if (!_isSearchActive)
                                IconButton(
                                  icon: Icon(Icons.settings),
                                  onPressed: () {
                                    // Navigate to settings
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) {
                                        return SettingsPage();
                                      }),
                                    );
                                  },
                                ),
                            ],
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          ),
                        );
                      },
                    ),
                  )
                : null,
            body: _Mainpage
                ? Column(
                    children: [
                      Container(
                          height: 45,
                          child: Row(children: [
                            Expanded(
                                child: NavigationBar(
                              labelBehavior:
                                  NavigationDestinationLabelBehavior.alwaysHide,
                              selectedIndex: _selectedIndex,
                              destinations: [
                                NavigationDestination(
                                    icon: Center(child: Text('我的')), label: ''),
                                NavigationDestination(
                                    icon: Center(child: Text('BiliBili')),
                                    label: ''),
                                NavigationDestination(
                                    icon: Center(child: Text('网易云')),
                                    label: ''),
                              ],
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
                                    tfilter[item["category"]] = item["filters"];
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
                          child: source != "myplaylist"
                              ? Playlist(
                                  key: ValueKey(filter),
                                  source: source,
                                  offset: offset,
                                  filter: filter,
                                  onPlaylistTap: change_main_status)
                              : MyPlaylist(onPlaylistTap: change_main_status))
                    ],
                  )
                : PlaylistInfo(
                    listId: _playlist_id,
                    onPlaylistTap: change_main_status,
                    is_my: main_is_my,
                  ),
            bottomNavigationBar: play));
  }
}

void _showFilterSelection(BuildContext context, Map<String, dynamic> filter,
    String now_id, Function change_fliter) {
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
