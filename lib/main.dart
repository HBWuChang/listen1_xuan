import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
  PageController _pageController = PageController();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(index,
        duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void change_main_status(String id) {
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
    _animationController.dispose();
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
                          child: NavigationBar(
                            labelBehavior:
                                NavigationDestinationLabelBehavior.alwaysHide,
                            selectedIndex: _selectedIndex,
                            destinations: [
                              NavigationDestination(
                                  icon: Center(child: Text('BiliBili')),
                                  label: ''),
                              NavigationDestination(
                                  icon: Center(child: Text('Playlist 2')),
                                  label: ''),
                              NavigationDestination(
                                  icon: Center(child: Text('Playlist 3')),
                                  label: ''),
                            ],
                            onDestinationSelected: (index) {
                              _onItemTapped(index);
                            },
                          )),
                      // 长灰色细分割线
                      Divider(
                        height: 1,
                        color: Colors.grey[300],
                      ),
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _selectedIndex = index;
                            });
                          },
                          children: <Widget>[
                            Playlist(
                                source: "bilibili",
                                offset: 0,
                                filter: "",
                                onPlaylistTap: change_main_status),
                            Center(child: Text('Song List 2')),
                            Center(child: Text('Song List 3')),
                          ],
                        ),
                      ),
                    ],
                  )
                : PlaylistInfo(
                    listId: _playlist_id,
                    onPlaylistTap: change_main_status,
                  ),
            bottomNavigationBar: play));
  }
}
