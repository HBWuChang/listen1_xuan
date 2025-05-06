import 'main.dart';
import 'package:flutter/material.dart';
import 'package:listen1_xuan/bl.dart';
import 'package:listen1_xuan/qq.dart';
import 'netease.dart';
import 'package:marquee/marquee.dart';
import 'loweb.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'play.dart';
import 'myplaylist.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'global_settings_animations.dart';

Future<dynamic> song_dialog(
  BuildContext context,
  Map<String, dynamic> track, {
  Function? change_main_status,
  bool is_my = false,
  Map<String, dynamic> nowplaylistinfo = const {},
  Function? deltrack,
  Offset? position,
}) async {
  final screenSize = MediaQuery.of(context).size;
  final dialogWidth = screenSize.width * 0.5;
  final dialogHeight = screenSize.height * 1;
  bool horizon = screenSize.height > screenSize.width ? false : true;
  print("horizon:$horizon");
  print("position:$position");
  return await showDialog(
    context: context,
    builder: (BuildContext context) {
      // 根据手指按下的位置动态调整弹窗位置和大小

      double left = position != null ? position.dx - dialogWidth / 2 : 0;
      double top = position != null ? position.dy - dialogHeight / 2 : 0;

      // 确保弹窗不会超出屏幕边界
      left = left < 0
          ? 0
          : (left + dialogWidth > screenSize.width
              ? screenSize.width - dialogWidth
              : left);
      top = top < 0
          ? 0
          : (top + dialogHeight > screenSize.height
              ? screenSize.height - dialogHeight
              : top);
      Widget dialog = AlertDialog(
        title: GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: track['title'] ?? '未知标题'));
            xuan_toast(msg: '标题已复制到剪切板');
          },
          child: SelectableText(
            track['title'] ?? '未知标题',
            style: TextStyle(fontSize: 16),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: track['title'] ?? '未知标题'));
                  xuan_toast(msg: '标题已复制到剪切板');
                },
                onLongPress: () {
                  Clipboard.setData(
                      ClipboardData(text: track['img_url'] ?? '未知封面'));
                  xuan_toast(msg: '封面链接已复制到剪切板');
                },
                child: track['img_url'] == null
                    ? Container()
                    : CachedNetworkImage(
                        imageUrl: track['img_url'],
                        errorWidget: (context, url, error) => Icon(Icons.error),
                      ),
              ),
              ListTile(
                title: Text('搜索此音乐'),
                onTap: () {
                  if (change_main_status != null) {
                    Navigator.of(context).pop();
                    change_main_status!("", search_text: track['title']);
                  }
                },
                onLongPress: () {
                  Clipboard.setData(
                      ClipboardData(text: track['artist'] ?? '未知艺术家'));
                  xuan_toast(msg: '作者已复制到剪切板');
                },
              ),
              ListTile(
                title: Text('作者：${track['artist'] ?? '未知艺术家'}'),
                onTap: () {
                  if (change_main_status != null) {
                    Navigator.of(context).pop();
                    change_main_status!(track['artist_id'] ?? '');
                  }
                },
                onLongPress: () {
                  Clipboard.setData(
                      ClipboardData(text: track['artist'] ?? '未知艺术家'));
                  xuan_toast(msg: '作者已复制到剪切板');
                },
              ),
              if (track['album'] != null)
                ListTile(
                  title: Text('专辑：${track['album']}'),
                  onTap: () {
                    Navigator.of(context).pop();
                    change_main_status!(track['album_id']);
                  },
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: track['album']));
                    xuan_toast(msg: '专辑已复制到剪切板');
                  },
                ),
              ListTile(
                title: Text('歌曲链接'),
                onTap: () {
                  launchUrl(Uri.parse(track['source_url']));
                },
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: track['source_url']));
                  xuan_toast(msg: '歌曲链接已复制到剪切板');
                },
              ),
              ListTile(
                title: Text('添加到当前播放列表'),
                onTap: () {
                  add_current_playing([track]);
                  xuan_toast(
                    msg: '已添加到当前播放列表',
                  );
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('添加到歌单'),
                onTap: () {
                  if (nowplaylistinfo.isNotEmpty) {
                    myplaylist.Add_to_my_playlist(
                      context,
                      [track],
                      nowplaylistinfo['title'],
                      nowplaylistinfo['cover_img_url'],
                    );
                  } else {
                    myplaylist.Add_to_my_playlist(
                      context,
                      [track],
                    );
                  }
                },
              ),
              ListTile(
                title: Text('添加到下载队列'),
                onTap: () async {
                  final ok = await add_to_download_tasks([track['id']]);
                  if (ok) {
                    xuan_toast(
                      msg: '已添加到下载队列',
                    );
                  } else {
                    xuan_toast(
                      msg: '添加失败',
                    );
                  }
                },
              ),
              ListTile(
                title: Text('删除本地缓存'),
                onTap: () async {
                  await clean_local_cache(false, track['id']);
                },
              ),
              if (is_my)
                ListTile(
                  title: Text('删除歌曲'),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('删除歌曲'),
                          content: Text('确定要删除这首歌曲吗？'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('取消'),
                            ),
                            TextButton(
                              onPressed: () async {
                                await myplaylist.removeTrackFromMyPlaylist(
                                    // widget.listId, track['id']);
                                    nowplaylistinfo['id'],
                                    track['id']);
                                Navigator.of(context).pop();
                                if (deltrack != null) {
                                  deltrack(track);
                                }
                              },
                              child: Text('确定'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      );

      return horizon
          ? Stack(
              children: [
                Positioned(
                    left: left,
                    top: top,
                    width: dialogWidth,
                    height: dialogHeight,
                    child: dialog),
              ],
            )
          : dialog;
    },
  );
}

class Playlist extends StatefulWidget {
  final String source;
  final int offset;
  // final String filter;
  final Map<String, dynamic> filter;
  final Function(String) onPlaylistTap;

  Playlist({
    required this.source,
    required this.offset,
    required this.filter,
    required this.onPlaylistTap,
    Key? key,
  }) : super(key: key);

  @override
  _PlaylistState createState() => _PlaylistState();
}

class _PlaylistState extends State<Playlist> {
  List<dynamic> _playlists = [];
  bool _loading = true;
  bool _loadingMore = false;
  int per_page = 20;
  bool hasmore = true;
  int _currentOffset = 0;
  final ScrollController _scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  void _loadData() async {
    Map<String, dynamic> result = await MediaService.showPlaylistArray(
        widget.source, widget.offset, widget.filter['id']);

    result['success']((data) {
      print(data); // 打印实际的数据
      try {
        setState(() {
          _playlists = data.toList();
          per_page = data.length;
          hasmore = true;
          _loading = false;
        });
      } catch (e) {
        print(e);
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreData();
    }
  }

  void _loadMoreData() async {
    if (_loadingMore) return;
    _currentOffset += per_page;
    if (!hasmore) return;
    try {
      setState(() {
        _loadingMore = true;
      });
      Map<String, dynamic> result = await MediaService.showPlaylistArray(
          widget.source, _currentOffset, widget.filter['id']);
      result['success']((data) {
        print(data); // 打印实际的数据
        if (data.length == 0) {
          hasmore = false;
          setState(() {
            _loadingMore = false;
          });
          return;
        }
        setState(() {
          _playlists.addAll(data);
          _loadingMore = false;
        });
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context_playlist) {
    return Scaffold(
      body: Center(
        child: _loading
            ? global_loading_anime
            : GridView.builder(
                controller: _scrollController,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width >
                          MediaQuery.of(context).size.height
                      ? 6
                      : 3, // 每行显示的列数
                  crossAxisSpacing: 5.0, // 列间距
                  mainAxisSpacing: 5.0, // 行间距
                  childAspectRatio: 0.8, // 子项宽高比
                ),
                itemCount: _playlists.length,
                itemBuilder: (BuildContext context, int index) {
                  final playlist = _playlists[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context_playlist).push(
                        MaterialPageRoute(
                          builder: (context) => PlaylistInfo(
                            listId: playlist['id'],
                            onPlaylistTap: widget.onPlaylistTap,
                            is_my: false,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: (MediaQuery.of(context).size.width -
                                      (MediaQuery.of(context).size.width >
                                              MediaQuery.of(context).size.height
                                          ? 200
                                          : 0)) /
                                  (MediaQuery.of(context).size.width >
                                          MediaQuery.of(context).size.height
                                      ? 6
                                      : 3) -
                              10,
                          height: (MediaQuery.of(context).size.width -
                                      (MediaQuery.of(context).size.width >
                                              MediaQuery.of(context).size.height
                                          ? 200
                                          : 0)) /
                                  (MediaQuery.of(context).size.width >
                                          MediaQuery.of(context).size.height
                                      ? 6
                                      : 3) -
                              10,
                          child: CachedNetworkImage(
                            imageUrl: playlist['cover_img_url'],
                            fit: BoxFit.cover,
                          ),
                        ),
                        Text(
                          playlist['title'],
                          style: TextStyle(fontSize: 12), // 可选：设置字体大小
                          maxLines: 2, // 可选：限制最大行数
                          overflow: TextOverflow.ellipsis, // 可选：超出部分显示省略号
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class MyPlaylist extends StatefulWidget {
  final Function(String, {bool is_my, String search_text}) onPlaylistTap;
  MyPlaylist({
    required this.onPlaylistTap,
  });
  @override
  _MyPlaylistState createState() => _MyPlaylistState();
}

class _MyPlaylistState extends State<MyPlaylist> {
  List<dynamic> _playlists_my = [];
  List<dynamic> _playlists_fav = [];
  List<dynamic> _playlists_bl = [];
  List<dynamic> _playlists_ne = [];
  List<dynamic> _playlists_qq = [];
  bool _isExpandedMy = true;
  bool _isExpandedFav = false;
  bool _isExpandedBl = false;
  bool _isExpandedNe = false;
  bool _isExpandedQq = false;
  bool _isFavDataLoaded = false;
  bool _isBlDataLoaded = false;
  bool _isNeDataLoaded = false;
  bool _isQqDataLoaded = false;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    My_loadData();
    My_playlist_loaddata = My_loadData;
  }

  void My_loadData() async {
    Map<String, dynamic> result_my = await myplaylist.show_myplaylist('my');
    try {
      setState(() {
        _playlists_my = result_my['result'];
        _loading = false;
      });
    } catch (e) {
      xuan_toast(
        msg: '我的歌单加载失败',
      );
    }
  }

  void _loadFavData() async {
    Map<String, dynamic> result_fav =
        await myplaylist.show_myplaylist('favorite');
    try {
      setState(() {
        _playlists_fav = result_fav['result'];
        _isFavDataLoaded = true;
      });
    } catch (e) {
      xuan_toast(
        msg: '收藏歌单加载失败',
      );
    }
  }

  void _loadBlData() async {
    try {
      var result_bl = await bilibili.Xuan_get_bl_playlist();
      setState(() {
        _playlists_bl = result_bl;
        _isBlDataLoaded = true;
      });
    } catch (e) {
      print(e);
    }
  }

  void _loadNeData() async {
    try {
      var _neuserinfo = await Netease().get_user();
      var uid = _neuserinfo['result']["user_id"];
      var result_ne = await netease.get_user_created_playlist(
          "/get_user_favorite_playlist?user_id=$uid");
      var result_ne2 = await netease.get_user_favorite_playlist(
          "/get_user_favorite_playlist?user_id=$uid");
      bool tflag1 = false;
      bool tflag2 = false;
      void check() {
        if (tflag1 && tflag2) {
          setState(() {
            _isNeDataLoaded = true;
          });
        }
      }

      result_ne['success']((data) {
        if (data["status"] != "fail")
          for (var i = 0; i < data['data']["playlists"].length; i++) {
            _playlists_ne.add({
              "info": {
                'cover_img_url': data['data']["playlists"][i]['cover_img_url'],
                'title': data['data']["playlists"][i]['title'],
                'id': data['data']["playlists"][i]['id'],
                'source_url': data['data']["playlists"][i]['source_url']
              }
            });
          }
        tflag1 = true;
        check();
      });
      result_ne2['success']((data) {
        if (data["status"] != "fail")
          for (var i = 0; i < data['data']["playlists"].length; i++) {
            _playlists_ne.add({
              "info": {
                'cover_img_url': data['data']["playlists"][i]['cover_img_url'],
                'title': data['data']["playlists"][i]['title'],
                'id': data['data']["playlists"][i]['id'],
                'source_url': data['data']["playlists"][i]['source_url']
              }
            });
          }
        tflag2 = true;
        check();
      });
    } catch (e) {
      xuan_toast(
        msg: '网易云音乐歌单加载失败',
      );
    }
  }

  void _loadQqData() async {
    try {
      var _neuserinfo = await QQ().get_user();
      var uid = _neuserinfo['data']["user_id"];
      var result_qq = await qq.get_user_created_playlist(
          "/get_user_favorite_playlist?user_id=$uid");
      var result_qq2 = await qq.get_user_favorite_playlist(
          "/get_user_favorite_playlist?user_id=$uid");
      bool tflag1 = false;
      bool tflag2 = false;
      void check() {
        if (tflag1 && tflag2) {
          setState(() {
            _isQqDataLoaded = true;
          });
        }
      }

      result_qq['success']((data) {
        if (data["status"] != "fail")
          for (var i = 0; i < data['data']["playlists"].length; i++) {
            _playlists_qq.add({
              "info": {
                'cover_img_url': data['data']["playlists"][i]['cover_img_url'],
                'title': data['data']["playlists"][i]['title'],
                'id': data['data']["playlists"][i]['id'],
                'source_url': data['data']["playlists"][i]['source_url']
              }
            });
          }
        tflag1 = true;
        check();
      });
      result_qq2['success']((data) {
        if (data["status"] != "fail")
          for (var i = 0; i < data['data']["playlists"].length; i++) {
            _playlists_qq.add({
              "info": {
                'cover_img_url': data['data']["playlists"][i]['cover_img_url'],
                'title': data['data']["playlists"][i]['title'],
                'id': data['data']["playlists"][i]['id'],
                'source_url': data['data']["playlists"][i]['source_url']
              }
            });
          }
        tflag2 = true;
        check();
      });
    } catch (e) {
      xuan_toast(
        msg: 'QQ音乐歌单加载失败',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: _loading
            ? global_loading_anime
            : SingleChildScrollView(
                child: Column(children: [
                  ExpansionPanelList(
                    materialGapSize: 0,
                    expansionCallback: (int index, bool isExpanded) {
                      setState(() {
                        if (index == 0) {
                          _isExpandedMy = !_isExpandedMy;
                        } else if (index == 1) {
                          _isExpandedFav = !_isExpandedFav;
                          if (_isExpandedFav && !_isFavDataLoaded) {
                            _loadFavData();
                          }
                        } else if (index == 2) {
                          _isExpandedBl = !_isExpandedBl;
                          if (_isExpandedBl && !_isBlDataLoaded) {
                            _loadBlData();
                          }
                        } else if (index == 3) {
                          _isExpandedNe = !_isExpandedNe;
                          if (_isExpandedNe && !_isNeDataLoaded) {
                            _loadNeData();
                          }
                        } else if (index == 4) {
                          _isExpandedQq = !_isExpandedQq;
                          if (_isExpandedQq && !_isQqDataLoaded) {
                            _loadQqData();
                          }
                        }
                      });
                    },
                    children: [
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: Icon(Icons.library_music),
                            title: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '我创建的歌单',
                                style: TextStyle(fontSize: 20.0),
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _isExpandedMy = !_isExpandedMy;
                              });
                            },
                          );
                        },
                        body: Column(
                          children: _playlists_my.map((playlist) {
                            return ListTile(
                              leading: playlist['info']['cover_img_url'] == ""
                                  ? Container(
                                      width: 50,
                                      height: 50,
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: playlist['info']
                                          ['cover_img_url'],
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                              title: FittedBox(
                                  alignment: Alignment.centerLeft,
                                  fit: BoxFit.scaleDown,
                                  child: Text(playlist['info']['title'])),
                              onTap: () async {
                                clean_top_context();
                                var ret = await Navigator.push(
                                  top_context.last,
                                  MaterialPageRoute(
                                    builder: (context) => PlaylistInfo(
                                      listId: playlist['info']['id'],
                                      onPlaylistTap: widget.onPlaylistTap,
                                      is_my: true,
                                    ),
                                  ),
                                );
                                if (ret != null) {
                                  if (ret["refresh"] == true) {
                                    My_loadData();
                                  }
                                }
                              },
                            );
                          }).toList(),
                        ),
                        isExpanded: _isExpandedMy,
                      ),
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: Icon(Icons.star),
                            title: FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '我收藏的歌单',
                                style: TextStyle(fontSize: 20.0),
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _isExpandedFav = !_isExpandedFav;
                                if (_isExpandedFav && !_isFavDataLoaded) {
                                  _loadFavData();
                                }
                              });
                            },
                          );
                        },
                        body: _isFavDataLoaded
                            ? Column(
                                children: _playlists_fav.map((playlist) {
                                  return ListTile(
                                    leading: CachedNetworkImage(
                                      imageUrl: playlist['info']
                                          ['cover_img_url'],
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                                    title: FittedBox(
                                        alignment: Alignment.centerLeft,
                                        fit: BoxFit.scaleDown,
                                        child: Text(playlist['info']['title'])),
                                    onTap: () async {
                                      clean_top_context();
                                      var ret = await Navigator.push(
                                        top_context.last,
                                        MaterialPageRoute(
                                          builder: (context) => PlaylistInfo(
                                            listId: playlist['info']['id'],
                                            onPlaylistTap: widget.onPlaylistTap,
                                          ),
                                        ),
                                      );
                                      if (ret != null) {
                                        if (ret["refresh"] == true) {
                                          My_loadData();
                                        }
                                      }
                                    },
                                  );
                                }).toList(),
                              )
                            : Center(child: global_loading_anime),
                        isExpanded: _isExpandedFav,
                      ),
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: SvgPicture.string(
                                '<svg width="18" height="18" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg" class="zhuzhan-icon"><path fill-rule="evenodd" clip-rule="evenodd" d="M3.73252 2.67094C3.33229 2.28484 3.33229 1.64373 3.73252 1.25764C4.11291 0.890684 4.71552 0.890684 5.09591 1.25764L7.21723 3.30403C7.27749 3.36218 7.32869 3.4261 7.37081 3.49407H10.5789C10.6211 3.4261 10.6723 3.36218 10.7325 3.30403L12.8538 1.25764C13.2342 0.890684 13.8368 0.890684 14.2172 1.25764C14.6175 1.64373 14.6175 2.28484 14.2172 2.67094L13.364 3.49407H14C16.2091 3.49407 18 5.28493 18 7.49407V12.9996C18 15.2087 16.2091 16.9996 14 16.9996H4C1.79086 16.9996 0 15.2087 0 12.9996V7.49406C0 5.28492 1.79086 3.49407 4 3.49407H4.58579L3.73252 2.67094ZM4 5.42343C2.89543 5.42343 2 6.31886 2 7.42343V13.0702C2 14.1748 2.89543 15.0702 4 15.0702H14C15.1046 15.0702 16 14.1748 16 13.0702V7.42343C16 6.31886 15.1046 5.42343 14 5.42343H4ZM5 9.31747C5 8.76519 5.44772 8.31747 6 8.31747C6.55228 8.31747 7 8.76519 7 9.31747V10.2115C7 10.7638 6.55228 11.2115 6 11.2115C5.44772 11.2115 5 10.7638 5 10.2115V9.31747ZM12 8.31747C11.4477 8.31747 11 8.76519 11 9.31747V10.2115C11 10.7638 11.4477 11.2115 12 11.2115C12.5523 11.2115 13 10.7638 13 10.2115V9.31747C13 8.76519 12.5523 8.31747 12 8.31747Z" fill="gray"></path></svg>'),
                            title: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '我的哔哩哔哩收藏',
                                style: TextStyle(fontSize: 20.0),
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _isExpandedBl = !_isExpandedBl;
                                if (_isExpandedBl && !_isBlDataLoaded) {
                                  _loadBlData();
                                }
                              });
                            },
                          );
                        },
                        body: _isBlDataLoaded
                            ? Column(
                                children: _playlists_bl.map((playlist) {
                                  return ListTile(
                                      leading: CachedNetworkImage(
                                        imageUrl: playlist['info']
                                            ['cover_img_url'],
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) =>
                                            Icon(Icons.help_outline), // 添加错误处理
                                      ),
                                      title: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child:
                                              Text(playlist['info']['title'])),
                                      onTap: () async {
                                        clean_top_context();
                                        var ret = await Navigator.push(
                                          top_context.last,
                                          MaterialPageRoute(
                                            builder: (context) => PlaylistInfo(
                                              listId: playlist['info']['id'],
                                              onPlaylistTap:
                                                  widget.onPlaylistTap,
                                            ),
                                          ),
                                        );
                                        if (ret != null) {
                                          if (ret["refresh"] == true) {
                                            My_loadData();
                                          }
                                        }
                                      });
                                }).toList(),
                              )
                            : Center(child: global_loading_anime),
                        isExpanded: _isExpandedBl,
                      ),
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: CachedNetworkImage(
                                imageUrl:
                                    "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/28469918905/0dfc/b6c0/d913/713572367ec9d917628e41266a39a67f.png",
                                width: 18,
                                height: 18),
                            title: FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '我的网易云歌单',
                                style: TextStyle(fontSize: 20.0),
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _isExpandedNe = !_isExpandedNe;
                                if (_isExpandedNe && !_isNeDataLoaded) {
                                  _loadNeData();
                                }
                              });
                            },
                          );
                        },
                        body: _isNeDataLoaded
                            ? Column(
                                children: _playlists_ne.map((playlist) {
                                  return ListTile(
                                    leading: CachedNetworkImage(
                                      imageUrl: playlist['info']
                                          ['cover_img_url'],
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                                    title: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(playlist['info']['title'])),
                                    onTap: () async {
                                      clean_top_context();
                                      var ret = await Navigator.push(
                                        top_context.last,
                                        MaterialPageRoute(
                                          builder: (context) => PlaylistInfo(
                                            listId: playlist['info']['id'],
                                            onPlaylistTap: widget.onPlaylistTap,
                                          ),
                                        ),
                                      );
                                      if (ret != null) {
                                        if (ret["refresh"] == true) {
                                          My_loadData();
                                        }
                                      }
                                    },
                                  );
                                }).toList(),
                              )
                            : Center(child: global_loading_anime),
                        isExpanded: _isExpandedNe,
                      ),
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: CachedNetworkImage(
                                imageUrl:
                                    "https://ts2.cn.mm.bing.net/th?id=ODLS.07d947f8-8fdd-4949-8b9a-be5283268438&w=32&h=32&qlt=90&pcl=fffffa&o=6&pid=1.2",
                                width: 18,
                                height: 18),
                            title: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '我的QQ歌单',
                                style: TextStyle(fontSize: 20.0),
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _isExpandedQq = !_isExpandedQq;
                                if (_isExpandedQq && !_isQqDataLoaded) {
                                  _loadQqData();
                                }
                              });
                            },
                          );
                        },
                        body: _isQqDataLoaded
                            ? Column(
                                children: _playlists_qq.map((playlist) {
                                  return ListTile(
                                    leading: CachedNetworkImage(
                                      imageUrl: playlist['info']
                                          ['cover_img_url'],
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) =>
                                          Container(), // 如果加载出错则返回空的Container
                                    ),
                                    title: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(playlist['info']['title'])),
                                    onTap: () async {
                                      clean_top_context();
                                      var ret = await Navigator.push(
                                        top_context.last,
                                        MaterialPageRoute(
                                          builder: (context) => PlaylistInfo(
                                            listId: playlist['info']['id'],
                                            onPlaylistTap: widget.onPlaylistTap,
                                          ),
                                        ),
                                      );
                                      if (ret != null) {
                                        if (ret["refresh"] == true) {
                                          My_loadData();
                                        }
                                      }
                                    },
                                  );
                                }).toList(),
                              )
                            : Center(child: global_loading_anime),
                        isExpanded: _isExpandedQq,
                      ),
                    ],
                  ),
                ]),
              ));
  }
}

class PlaylistInfo extends StatefulWidget {
  final String listId;
  final Function(String) onPlaylistTap;
  bool is_my = false;
  PlaylistInfo(
      {Key? key,
      required this.listId,
      required this.onPlaylistTap,
      this.is_my = false})
      : super(key: key);

  @override
  _PlaylistInfoState createState() => _PlaylistInfoState();
}

class _PlaylistInfoState extends State<PlaylistInfo> {
  Map<String, dynamic> _playlist = {};
  bool _loading = true;
  bool _loadfailed = false;
  bool _is_fav = false;
  TextEditingController _searchController = TextEditingController();
  double lastmove = 0;
  List<Map<String, dynamic>> _unfilteredTracks = [];
  List<Map<String, dynamic>> tracks = [];
  Map<String, dynamic> result = {};
  OverlayEntry? scroll_bar_overlayEntry;
  bool scroll_bar_Visible = false;
  double scroll_bar_pos = 0.5;
  Timer? scroll_bar_timer;
  StateSetter? scroll_bar_setState; // 添加这个变量
  bool last_move_is_up = false;
  bool on_drag_slider = false;
  final FocusNode _focusNode = FocusNode(); // 创建 FocusNode
  @override
  void initState() {
    super.initState();
    check_fav();
    _loadData();
    _searchController.addListener(_filterTracks);
    inner_scrollController.addListener(_onInnerScroll);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        set_inapp_hotkey(false);
      } else {
        set_inapp_hotkey(true);
      }
    });
  }

  void check_fav() async {
    final result = await myplaylist.isMyfavPlaylist(widget.listId);
    setState(() {
      _is_fav = result;
    });
  }

  void _loadData() async {
    var res = await MediaService.getPlaylist(widget.listId);
    res['success']((data) {
      result = data;
      setState(() {
        _playlist = data;
        tracks = List<Map<String, dynamic>>.from(data['tracks']);
        _unfilteredTracks = List<Map<String, dynamic>>.from(tracks);
        _loading = false;
        if (data['info']['title'] == null) {
          _loadfailed = true;
        }
      });
    });
  }

  void deltrack(Map<String, dynamic> track) {
    setState(() {
      // tracks.remove(track);
      _unfilteredTracks.remove(track);
      _filterTracks();
    });
  }

  void _filterTracks() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      tracks = _unfilteredTracks.where((track) {
        final title = track['title']?.toLowerCase() ?? '';
        final artist = track['artist']?.toLowerCase() ?? '';
        final album = track['album']?.toLowerCase() ?? '';
        return title.contains(query) ||
            artist.contains(query) ||
            album.contains(query);
      }).toList();
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (!widget.is_my) {
      xuan_toast(
        msg: '只有自己创建的歌单才能排序',
      );
      return;
    }
    if (_searchController.text.toLowerCase().isNotEmpty) {
      xuan_toast(
        msg: '搜索状态下无法排序',
      );
      return;
    }
    MediaService.insertTrackToMyPlaylist(
        widget.listId, tracks[oldIndex], tracks[newIndex], 'top');
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = tracks.removeAt(oldIndex);
      tracks.insert(newIndex, item);
    });
  }

  void _onInnerScroll() {
    if (!scroll_bar_Visible) {
      _show_scroll_bar(context);
    }
    _startAutoCloseTimer();
    scroll_bar_pos = inner_scrollController.position.pixels /
        inner_scrollController.position.maxScrollExtent;
    scroll_bar_pos = scroll_bar_pos > 1 ? 1 : scroll_bar_pos;
    scroll_bar_pos = scroll_bar_pos < 0 ? 0 : scroll_bar_pos;
    if (scroll_bar_setState != null && scroll_bar_Visible) {
      try {
        scroll_bar_setState!(() {});
      } catch (e) {
        scroll_bar_setState = null;
      }
    }
    // 获取滚动信息
    final move = inner_scrollController.position.pixels - lastmove;
    // 判断滚动方向
    bool now_move_is_up = move > 0;
    if (now_move_is_up != last_move_is_up && move > 20) {
      last_move_is_up = now_move_is_up;
      return;
    }
    last_move_is_up = now_move_is_up;
    if (!on_drag_slider) {
      if (move > 0) {
        if (outter_scrollController.position.maxScrollExtent !=
            outter_scrollController.offset) {
          outter_scrollController.jumpTo(
              (outter_scrollController.offset + move) >
                      outter_scrollController.position.maxScrollExtent
                  ? outter_scrollController.position.maxScrollExtent
                  : (outter_scrollController.offset + move));
        }
      } else {
        if (outter_scrollController.offset != 0) {
          outter_scrollController.jumpTo(
              (outter_scrollController.offset + move) < 0
                  ? 0
                  : (outter_scrollController.offset + move));
        }
      }
    }
    lastmove = inner_scrollController.position.pixels; // 记录当前滚动位置
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    inner_scrollController.dispose();
    super.dispose();
  }

  ScrollController outter_scrollController = ScrollController();
  ScrollController inner_scrollController = ScrollController();
  @override
  Widget build(BuildContext context_PlaylistInfo) {
    top_context.add(context_PlaylistInfo);
    return Scaffold(
        body: Center(
      child: _loading
          ? global_loading_anime
          : _loadfailed
              ? Text('加载失败')
              : CustomScrollView(
                  controller: outter_scrollController,
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 280.0,
                      pinned: true,
                      leading: IconButton(
                        icon: Icon(Icons.arrow_back),
                        onPressed: () {
                          Navigator.pop(context_PlaylistInfo);
                        },
                      ),
                      title: Container(
                        height: 48,
                        child: Marquee(
                          text: result['info']['title'],
                          style: TextStyle(fontSize: 16),
                          scrollAxis: Axis.horizontal,
                          blankSpace: 20.0,
                          velocity: 50.0,
                          pauseAfterRound: Duration(seconds: 1),
                          startPadding: 10.0,
                          accelerationDuration: Duration(seconds: 1),
                          accelerationCurve: Curves.linear,
                          decelerationDuration: Duration(milliseconds: 500),
                          decelerationCurve: Curves.easeOut,
                        ),
                      ),
                      titleSpacing: 0,
                      flexibleSpace: FlexibleSpaceBar(
                        collapseMode: CollapseMode.parallax,
                        background: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // SizedBox(height: 80), // 添加一个空的SizedBox来调整位置
                            CachedNetworkImage(
                              imageUrl: result['info']['cover_img_url'],
                              width: 150,
                              height: 150,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  global_loading_anime,
                              errorWidget: (context, url, error) =>
                                  Icon(Icons.error),
                            ),
                            SizedBox(height: 8.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      // 播放全部按钮点击事件
                                      List<Map<String, dynamic>> trackList =
                                          List<Map<String, dynamic>>.from(
                                              tracks);
                                      await set_current_playing(trackList);
                                      await set_player_settings(
                                          "nowplaying_track_id",
                                          tracks[0]['id']);
                                      await playsong(tracks[0]);
                                    },
                                    child: Text('播放全部（共${tracks.length}首）'),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: IconButton(
                                    onPressed: () async {
                                      List<Map<String, dynamic>> trackList =
                                          List<Map<String, dynamic>>.from(
                                              tracks);
                                      await add_current_playing(trackList);
                                      xuan_toast(
                                        msg: '已添加到当前播放列表',
                                      );
                                    },
                                    icon: Icon(Icons.add_box_outlined),
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: TextField(
                                    focusNode: _focusNode,
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: '搜索',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        IconButton(
                            icon: Icon(Icons.add),
                            onPressed: () async {
                              // 添加按钮点击事件
                              try {
                                // await myplaylist.saveMyPlaylist('my', result);
                                await myplaylist.Add_to_my_playlist(
                                    context_PlaylistInfo,
                                    tracks,
                                    result['info']['title'],
                                    result['info']['cover_img_url']);
                                Navigator.of(context_PlaylistInfo)
                                    .pop({"refresh": true});
                              } catch (e) {
                                // print(e);
                                xuan_toast(
                                  msg: '添加失败${e}',
                                );
                              }
                            }),
                        widget.is_my
                            ? IconButton(
                                icon: Icon(Icons.delete),
                                onPressed: () {
                                  // 删除按钮点击事件
                                  showDialog(
                                    context: context_PlaylistInfo,
                                    builder: (BuildContext context_dialog) {
                                      return AlertDialog(
                                        title: Text('删除歌单'),
                                        content: Text('确定要删除这个歌单吗？'),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context_dialog)
                                                  .pop();
                                            },
                                            child: Text('取消'),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              await myplaylist.removeMyPlaylist(
                                                  'my', widget.listId);
                                              Navigator.of(context_dialog)
                                                  .pop();
                                              Navigator.of(context_PlaylistInfo)
                                                  .pop({"refresh": true});
                                            },
                                            child: Text('确定'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              )
                            : IconButton(
                                icon: Icon(Icons.link),
                                onPressed: () {
                                  // 链接按钮点击事件
                                  // launchUrl(playlistInfo['source_url']);
                                  launchUrl(
                                      Uri.parse(result['info']['source_url']));
                                },
                              ),
                        widget.is_my
                            ? IconButton(
                                icon: Icon(Icons.edit),
                                onPressed: () async {
                                  await set_inapp_hotkey(false);
                                  // 编辑按钮点击事件
                                  await showDialog(
                                    context: context_PlaylistInfo,
                                    builder: (BuildContext context_dialog) {
                                      final TextEditingController
                                          _titleController =
                                          TextEditingController();
                                      final TextEditingController
                                          _coverImgUrlController =
                                          TextEditingController();
                                      _titleController.text =
                                          result['info']['title'];
                                      _coverImgUrlController.text =
                                          result['info']['cover_img_url'];
                                      return AlertDialog(
                                        title: Text('编辑歌单'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              controller: _titleController,
                                              decoration: InputDecoration(
                                                labelText: '歌单标题',
                                              ),
                                            ),
                                            TextField(
                                              controller:
                                                  _coverImgUrlController,
                                              decoration: InputDecoration(
                                                labelText: '封面图片链接',
                                              ),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context_dialog)
                                                  .pop();
                                            },
                                            child: Text('取消'),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              await myplaylist.editMyPlaylist(
                                                widget.listId,
                                                _titleController.text,
                                                _coverImgUrlController.text,
                                              );
                                              xuan_toast(
                                                msg: '编辑成功',
                                              );
                                              Navigator.of(context_dialog)
                                                  .pop();
                                              Navigator.of(context_PlaylistInfo)
                                                  .pop({"refresh": true});
                                            },
                                            child: Text('确定'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  await set_inapp_hotkey(true);
                                },
                              )
                            : IconButton(
                                // icon: Icon(Icons.star_border),
                                icon: _is_fav
                                    ? Icon(Icons.star)
                                    : Icon(Icons.star_border),
                                onPressed: () async {
                                  // 添加按钮点击事件
                                  if (_is_fav) {
                                    await myplaylist.removeMyPlaylist(
                                        'favorite', widget.listId);
                                    check_fav();
                                    xuan_toast(
                                      msg: '已取消收藏',
                                    );
                                  } else {
                                    await myplaylist.saveMyPlaylist(
                                        'favorite', result);
                                    check_fav();
                                    xuan_toast(
                                      msg: '已添加到我的收藏',
                                    );
                                  }
                                }),
                      ],
                    ),
                    SliverFillRemaining(
                      hasScrollBody: true,
                      child: ReorderableListView(
                        onReorder: _onReorder,
                        scrollController: inner_scrollController,
                        children: tracks.map((track) {
                          var _key = GlobalKey();
                          return ListTile(
                            key: _key,
                            title: Text(track['title'] ?? '未知标题'),
                            subtitle: Text(
                                '${track['artist'] ?? '未知艺术家'} - ${track['album'] ?? '未知专辑'}'),
                            trailing: IconButton(
                              icon: Icon(Icons.more_vert),
                              onPressed: () async {
                                var ret = await song_dialog(
                                    context_PlaylistInfo, track,
                                    change_main_status: widget.onPlaylistTap,
                                    is_my: widget.is_my,
                                    nowplaylistinfo: result['info'],
                                    deltrack: deltrack,
                                    position: Offset(
                                        MediaQuery.of(context).size.width,
                                        (_key.currentContext!.findRenderObject()
                                                as RenderBox)
                                            .localToGlobal(Offset.zero)
                                            .dy));

                                if (ret != null) {
                                  if (ret["pop"] == true) {
                                    Navigator.of(context_PlaylistInfo).pop();
                                  }
                                  if (ret["replace"] != null) {
                                    Navigator.of(context_PlaylistInfo).replace(
                                      oldRoute: ModalRoute.of(
                                          context_PlaylistInfo)!, // 获取当前路由
                                      newRoute: MaterialPageRoute(
                                        builder: (context) => PlaylistInfo(
                                          listId: ret["replace"],
                                          onPlaylistTap: widget.onPlaylistTap,
                                          is_my: false,
                                        ),
                                      ),
                                    );
                                  }
                                  if (ret["push"] != null) {
                                    Navigator.of(context_PlaylistInfo).push(
                                      MaterialPageRoute(
                                        builder: (context) => PlaylistInfo(
                                          listId: ret["push"],
                                          onPlaylistTap: widget.onPlaylistTap,
                                          is_my: false,
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                            onTap: () {
                              xuan_toast(
                                msg: '尝试播放：${track['title']}',
                              );
                              playsong(track);
                            },
                          );
                        }).toList(),
                      ),
                    )
                  ],
                ),
    ));
  }

  void _show_scroll_bar(BuildContext context) async {
    scroll_bar_pos = inner_scrollController.position.pixels /
        inner_scrollController.position.maxScrollExtent;
    scroll_bar_Visible = true;
    scroll_bar_overlayEntry = _createOverlayEntry();
    Overlay.of(context)!.insert(scroll_bar_overlayEntry!);
    _startAutoCloseTimer();
  }

  void _startAutoCloseTimer() {
    scroll_bar_timer?.cancel();
    scroll_bar_timer = Timer(Duration(seconds: 1), () {
      scroll_bar_overlayEntry?.remove();
      scroll_bar_overlayEntry = null;
      scroll_bar_Visible = false;
    });
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Positioned(
        top: 100,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              scroll_bar_overlayEntry?.remove();
              scroll_bar_overlayEntry = null;
              scroll_bar_Visible = false;
            },
            child: Container(
              height: MediaQuery.of(context).size.height - 200,
              width: 30,
              decoration: BoxDecoration(
                color: const Color.fromARGB(0, 120, 120, 120),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(0, 120, 120, 120),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: RotatedBox(
                quarterTurns: 1,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    scroll_bar_setState = setState;
                    return Slider(
                      value: scroll_bar_pos,
                      onChanged: (value) {
                        setState(() {
                          scroll_bar_pos = value;
                        });
                        inner_scrollController.jumpTo(value *
                            inner_scrollController.position.maxScrollExtent);
                        _startAutoCloseTimer(); // 重置计时器
                      },
                      onChangeStart: (value) => on_drag_slider = true,
                      onChangeEnd: (value) {
                        on_drag_slider = false;
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

class Searchlistinfo extends StatefulWidget {
  TextEditingController input_text_Controller;
  final Function(String) onPlaylistTap;
  Searchlistinfo({
    required this.input_text_Controller,
    required this.onPlaylistTap,
  });

  @override
  _SearchlistinfoState createState() => _SearchlistinfoState();
}

class _SearchlistinfoState extends State<Searchlistinfo> {
  Map<String, dynamic> _playlist = {};
  bool _loading = true;
  bool song_or_playlist = false;
  List<Map<String, dynamic>> _unfilteredTracks = [];
  List<Map<String, dynamic>> tracks = [];
  Map<String, dynamic> result = {};
  String source = 'netease';
  String lastsource = 'netease';
  int curpage = 1;
  final ScrollController _scrollController = ScrollController();
  String lastquery = "";
  final FocusNode _focusNode = FocusNode(); // 创建 FocusNode
  @override
  void initState() {
    super.initState();
    widget.input_text_Controller.addListener(_filterTracks);
    _scrollController.addListener(_onScroll);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        set_inapp_hotkey(false);
      } else {
        set_inapp_hotkey(true);
      }
    });
    _filterTracks();
    selectedOptionNotifier.addListener(_filterTracks);
  }

  void change_source() async {
    switch (selectedOptionNotifier.value) {
      case 'BiliBili':
        source = 'bilibili';
        break;
      case '网易云':
        source = 'netease';
        break;
      case 'QQ':
        source = 'qq';
        break;
      case '酷狗':
        source = 'kugou';
        break;
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreData();
    }
  }

  void _loadMoreData() async {
    if (_loading) return;
    curpage += 1;
    if (curpage >= result['total'] / (tracks.length / (curpage - 1))) return;
    change_source();
    var ret = await MediaService.search(source, {
      'keywords': widget.input_text_Controller.text,
      'curpage': curpage,
      'type': song_or_playlist ? 1 : 0
    });
    ret["success"]((data) {
      result = data;
      setState(() {
        tracks.addAll(List<Map<String, dynamic>>.from(data['result']));
        _loading = false;
      });
    });
  }

  void _filterTracks() async {
    String query = widget.input_text_Controller.text.toLowerCase();
    change_source();
    if (query == '' || (query == lastquery && lastsource == source)) {
      return;
    }
    lastquery = query;
    lastsource = source;

    try {
      setState(() {
        _loading = true;
      });
      var ret = await MediaService.search(source, {
        'keywords': query,
        'curpage': curpage,
        'type': song_or_playlist ? 1 : 0
      });
      ret["success"]((data) {
        result = data;
        setState(() {
          tracks = List<Map<String, dynamic>>.from(data['result']);
          _loading = false;
        });
      });
    } catch (e) {}
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    selectedOptionNotifier.removeListener(_filterTracks);
    super.dispose();
  }

  String selectedOption = '网易云';
  final ValueNotifier<String> selectedOptionNotifier =
      ValueNotifier<String>('Option 1');
  final List<String> _options = ['BiliBili', '网易云', "QQ", '酷狗'];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: TextField(
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: '请输入歌曲名，歌手或专辑',
                  border: InputBorder.none,
                ),
                controller: widget.input_text_Controller,
                autofocus: true,
              ),
            ),
            DropdownButton<String>(
              value: selectedOption,
              icon: Icon(Icons.arrow_downward),
              onChanged: (String? newValue) {
                setState(() {
                  selectedOption = newValue!;
                  selectedOptionNotifier.value = newValue;
                });
              },
              items: _options.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      body: Center(
        child: _loading
            ? global_loading_anime
            : CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: tracks.length,
                      itemBuilder: (context, index) {
                        var _key = GlobalKey();
                        final track = tracks[index];
                        return ListTile(
                          title: Text(track['title']),
                          subtitle:
                              Text('${track['artist']} - ${track['album']}'),
                          trailing: IconButton(
                            key: _key,
                            icon: Icon(Icons.more_vert),
                            onPressed: () {
                              song_dialog(context, track,
                                  change_main_status: widget.onPlaylistTap,
                                  position: Offset(
                                      MediaQuery.of(context).size.width,
                                      (_key.currentContext!.findRenderObject()
                                              as RenderBox)
                                          .localToGlobal(Offset.zero)
                                          .dy));
                            },
                          ),
                          onTap: () {
                            xuan_toast(
                              msg: '尝试播放：${track['title']}',
                            );
                            playsong(track);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
