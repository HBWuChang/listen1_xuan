import 'package:flutter/material.dart';
import 'package:listen1_xuan/bl.dart';
import 'netease.dart';
import 'package:listen1_xuan/settings.dart';
import 'package:marquee/marquee.dart';
import 'loweb.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'play.dart';
import 'myplaylist.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

Future<void> song_dialog(BuildContext context, Map<String, dynamic> track,
    Function? change_main_status,
    [bool is_my = false,
    Map<String, dynamic> nowplaylistinfo = const {},
    Function? deltrack]) async {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
          title: Text(track['title'] ?? '未知标题'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CachedNetworkImage(imageUrl: track['img_url']),
                ListTile(
                  title: Text('作者：${track['artist'] ?? '未知艺术家'}'),
                  onTap: () {
                    if (change_main_status != null) {
                      Navigator.of(context).pop();
                      change_main_status!(track['artist_id'] ?? '');
                    }
                  },
                ),
                if (track['album'] != null)
                  ListTile(
                    title: Text('专辑：${track['album']}'),
                    onTap: () {
                      Navigator.of(context).pop();
                      change_main_status!(track['album_id']);
                    },
                  ),
                ListTile(
                  title: Text('歌曲链接'),
                  onTap: () {
                    launchUrl(Uri.parse(track['source_url']));
                  },
                ),
                ListTile(
                  title: Text('添加到当前播放列表'),
                  onTap: () {
                    add_current_playing([track]);
                    Fluttertoast.showToast(
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
                                  // setState(() {
                                  //   tracks.remove(track);
                                  // });
                                  // return 'del';
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
          ));
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
  int total = 0;
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
    print(result);
    try {
      setState(() {
        _playlists = result['result'];
        if (result.containsKey('total')) {
          total = result['total'];
          per_page = result['per_page'];
        }
        _loading = false;
      });
    } catch (e) {
      print(e);
    }
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
    if (_currentOffset >= total * per_page) return;
    try {
      setState(() {
        _loadingMore = true;
      });
      Map<String, dynamic> result = await MediaService.showPlaylistArray(
          widget.source, _currentOffset, widget.filter['id']);
      print(result);
      setState(() {
        _playlists.addAll(result['result']);
        _loadingMore = false;
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _loading
            ? CircularProgressIndicator()
            : GridView.builder(
                controller: _scrollController,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // 每行显示的列数
                  crossAxisSpacing: 10.0, // 列间距
                  mainAxisSpacing: 10.0, // 行间距
                  childAspectRatio: 0.8, // 子项宽高比
                ),
                itemCount: _playlists.length,
                itemBuilder: (BuildContext context, int index) {
                  final playlist = _playlists[index];
                  return GestureDetector(
                    onTap: () {
                      widget.onPlaylistTap(playlist['id']);
                    },
                    child: Column(
                      children: [
                        Container(
                          width: MediaQuery.of(context).size.width / 3 - 20,
                          height: MediaQuery.of(context).size.width / 3 - 20,
                          child: CachedNetworkImage(
                            imageUrl: playlist['cover_img_url'],
                            fit: BoxFit.cover,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            height: 20, // 设置文字容器高度
                            child: Marquee(
                              text: playlist['title'],
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
  final Function(String, [bool]) onPlaylistTap;
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
  bool _isExpandedMy = true;
  bool _isExpandedFav = false;
  bool _isExpandedBl = false;
  bool _isExpandedNe = false;
  bool _isFavDataLoaded = false;
  bool _isBlDataLoaded = false;
  bool _isNeDataLoaded = false;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    Map<String, dynamic> result_my = await myplaylist.showMyPlaylist('my');
    try {
      setState(() {
        _playlists_my = result_my['result'];
        _loading = false;
      });
    } catch (e) {
      print(e);
    }
  }

  void _loadFavData() async {
    Map<String, dynamic> result_fav =
        await myplaylist.showMyPlaylist('favorite');
    try {
      setState(() {
        _playlists_fav = result_fav['result'];
        _isFavDataLoaded = true;
      });
    } catch (e) {
      print(e);
    }
  }

  void _loadBlData() async {
    var result_bl = await bilibili.Xuan_get_bl_playlist();
    try {
      setState(() {
        _playlists_bl = result_bl;
        _isBlDataLoaded = true;
      });
    } catch (e) {
      print(e);
    }
  }

  void _loadNeData() async {
    var _neuserinfo = await Netease().getUser();
    var uid = _neuserinfo['result']["user_id"];
    var result_ne = await netease
        .getUserCreatedPlaylist("/get_user_favorite_playlist?user_id=$uid");
    var result_ne2 = await netease
        .getUserFavoritePlaylist("/get_user_favorite_playlist?user_id=$uid");
    try {
      setState(() {
        for (var i = 0; i < result_ne['data']["playlists"].length; i++) {
          _playlists_ne.add({
            "info": {
              'cover_img_url': result_ne['data']["playlists"][i]
                  ['cover_img_url'],
              'title': result_ne['data']["playlists"][i]['title'],
              'id': result_ne['data']["playlists"][i]['id'],
              'source_url': result_ne['data']["playlists"][i]['source_url']
            }
          });
        }
        for (var i = 0; i < result_ne2['data']["playlists"].length; i++) {
          _playlists_ne.add({
            "info": {
              'cover_img_url': result_ne2['data']["playlists"][i]
                  ['cover_img_url'],
              'title': result_ne2['data']["playlists"][i]['title'],
              'id': result_ne2['data']["playlists"][i]['id'],
              'source_url': result_ne2['data']["playlists"][i]['source_url']
            }
          });
        }
        _isNeDataLoaded = true;
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: _loading
            ? CircularProgressIndicator()
            : SingleChildScrollView(
                child: Column(children: [
                  ExpansionPanelList(
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
                        }
                      });
                    },
                    children: [
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: Icon(Icons.library_music),
                            title: Text('我创建的歌单'),
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
                              leading: CachedNetworkImage(
                                imageUrl: playlist['info']['cover_img_url'],
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                              title: Text(playlist['info']['title']),
                              onTap: () {
                                widget.onPlaylistTap(
                                    playlist['info']['id'], true);
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
                            title: Text('我收藏的歌单'),
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
                                    title: Text(playlist['info']['title']),
                                    onTap: () {
                                      widget.onPlaylistTap(
                                          playlist['info']['id']);
                                    },
                                  );
                                }).toList(),
                              )
                            : Center(child: CircularProgressIndicator()),
                        isExpanded: _isExpandedFav,
                      ),
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: SvgPicture.string(
                                '<svg width="18" height="18" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg" class="zhuzhan-icon"><path fill-rule="evenodd" clip-rule="evenodd" d="M3.73252 2.67094C3.33229 2.28484 3.33229 1.64373 3.73252 1.25764C4.11291 0.890684 4.71552 0.890684 5.09591 1.25764L7.21723 3.30403C7.27749 3.36218 7.32869 3.4261 7.37081 3.49407H10.5789C10.6211 3.4261 10.6723 3.36218 10.7325 3.30403L12.8538 1.25764C13.2342 0.890684 13.8368 0.890684 14.2172 1.25764C14.6175 1.64373 14.6175 2.28484 14.2172 2.67094L13.364 3.49407H14C16.2091 3.49407 18 5.28493 18 7.49407V12.9996C18 15.2087 16.2091 16.9996 14 16.9996H4C1.79086 16.9996 0 15.2087 0 12.9996V7.49406C0 5.28492 1.79086 3.49407 4 3.49407H4.58579L3.73252 2.67094ZM4 5.42343C2.89543 5.42343 2 6.31886 2 7.42343V13.0702C2 14.1748 2.89543 15.0702 4 15.0702H14C15.1046 15.0702 16 14.1748 16 13.0702V7.42343C16 6.31886 15.1046 5.42343 14 5.42343H4ZM5 9.31747C5 8.76519 5.44772 8.31747 6 8.31747C6.55228 8.31747 7 8.76519 7 9.31747V10.2115C7 10.7638 6.55228 11.2115 6 11.2115C5.44772 11.2115 5 10.7638 5 10.2115V9.31747ZM12 8.31747C11.4477 8.31747 11 8.76519 11 9.31747V10.2115C11 10.7638 11.4477 11.2115 12 11.2115C12.5523 11.2115 13 10.7638 13 10.2115V9.31747C13 8.76519 12.5523 8.31747 12 8.31747Z" fill="currentColor"></path></svg>'),
                            title: Text('我的哔哩哔哩收藏'),
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
                                    ),
                                    title: Text(playlist['info']['title']),
                                    onTap: () {
                                      widget.onPlaylistTap(
                                          playlist['info']['id']);
                                    },
                                  );
                                }).toList(),
                              )
                            : Center(child: CircularProgressIndicator()),
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
                            title: Text('我的网易云歌单'),
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
                                    title: Text(playlist['info']['title']),
                                    onTap: () {
                                      widget.onPlaylistTap(
                                          playlist['info']['id']);
                                    },
                                  );
                                }).toList(),
                              )
                            : Center(child: CircularProgressIndicator()),
                        isExpanded: _isExpandedNe,
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
  List<Map<String, dynamic>> _unfilteredTracks = [];
  List<Map<String, dynamic>> tracks = [];
  Map<String, dynamic> result = {};
  @override
  void initState() {
    super.initState();
    check_fav();
    _loadData();
    _searchController.addListener(_filterTracks);
  }

  void check_fav() async {
    final result = await myplaylist.isMyfavPlaylist(widget.listId);
    setState(() {
      _is_fav = result;
    });
  }

  void _loadData() async {
    result = await MediaService.getPlaylist(widget.listId);
    tracks = List<Map<String, dynamic>>.from(result['tracks']);
    _unfilteredTracks = List<Map<String, dynamic>>.from(tracks);
    setState(() {
      _playlist = result;
      _loading = false;
      if (result['info']['title'] == null) {
        _loadfailed = true;
      }
    });
  }

  void deltrack(Map<String, dynamic> track) {
    setState(() {
      tracks.remove(track);
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
      Fluttertoast.showToast(
        msg: '只有自己创建的歌单才能排序',
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

  @override
  void dispose() {
    _searchController.dispose();
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
                  // change_main_status(""),
                  widget.onPlaylistTap(''),
                }
            },
        child: Scaffold(
          body: Center(
            child: _loading
                ? CircularProgressIndicator()
                : _loadfailed
                    ? Text('加载失败')
                    :
                    // final playlistInfo = snapshot.data['info'];
                    // {info: {cover_img_url: http://i0.hdslb.com/bfs/music/0fa5b14f421dcc686f2adb11faaa64b5f6ca86d2.jpg, title: 【日语】那些令人中毒循环的歌, id: biplaylist_48955, source_url: https://www.bilibili.com/audio/am48955}, tracks: [{id: bitrack_15228, title: 极乐净土, artist: 祈Inory, artist_id: biartist_234782, source: bilibili, source_url: https://www.bilibili.com/audio/au15228, img_url: http://i0.hdslb.com/bfs/music/015f137f9053008496df50518cd506cec62ff6b7.jpg, lyric_url: http://i0.hdslb.com/bfs/music/150529756415228.lrc},
                    // final tracks = snapshot.data['tracks'];
                    CustomScrollView(
                        slivers: [
                          SliverAppBar(
                            expandedHeight: 280.0,
                            pinned: true,
                            leading: IconButton(
                              icon: Icon(Icons.arrow_back),
                              onPressed: () {
                                widget.onPlaylistTap('');
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
                                decelerationDuration:
                                    Duration(milliseconds: 500),
                                decelerationCurve: Curves.easeOut,
                              ),
                            ),
                            titleSpacing: 0,
                            flexibleSpace: FlexibleSpaceBar(
                              collapseMode: CollapseMode.parallax,
                              background: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(height: 80), // 添加一个空的SizedBox来调整位置
                                  CachedNetworkImage(
                                    imageUrl: result['info']['cover_img_url'],
                                    width: 150,
                                    height: 150,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        CircularProgressIndicator(),
                                    errorWidget: (context, url, error) =>
                                        Icon(Icons.error),
                                  ),
                                  SizedBox(height: 8.0),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            // 播放全部按钮点击事件
                                            List<Map<String, dynamic>>
                                                trackList =
                                                List<Map<String, dynamic>>.from(
                                                    tracks);
                                            await set_current_playing(
                                                trackList);
                                            await set_player_settings(
                                                "nowplaying_track_id",
                                                tracks[0]['id']);
                                            await playsong(tracks[0]);
                                          },
                                          child:
                                              Text('播放全部（共${tracks.length}首）'),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: IconButton(
                                          onPressed: () async {
                                            List<Map<String, dynamic>>
                                                trackList =
                                                List<Map<String, dynamic>>.from(
                                                    tracks);
                                            await add_current_playing(
                                                trackList);
                                            Fluttertoast.showToast(
                                              msg: '已添加到当前播放列表',
                                            );
                                          },
                                          icon: Icon(Icons.add_box_outlined),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: TextField(
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
                                      myplaylist.Add_to_my_playlist(
                                          context,
                                          tracks,
                                          result['info']['title'],
                                          result['info']['cover_img_url']);
                                    } catch (e) {
                                      // print(e);
                                      Fluttertoast.showToast(
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
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: Text('删除歌单'),
                                              content: Text('确定要删除这个歌单吗？'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  },
                                                  child: Text('取消'),
                                                ),
                                                TextButton(
                                                  onPressed: () async {
                                                    await myplaylist
                                                        .removeMyPlaylist('my',
                                                            widget.listId);
                                                    Navigator.of(context).pop();
                                                    widget.onPlaylistTap('');
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
                                        launchUrl(Uri.parse(
                                            result['info']['source_url']));
                                      },
                                    ),
                              widget.is_my
                                  ? IconButton(
                                      icon: Icon(Icons.edit),
                                      onPressed: () {
                                        // 编辑按钮点击事件
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
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
                                                    controller:
                                                        _titleController,
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
                                                    Navigator.of(context).pop();
                                                  },
                                                  child: Text('取消'),
                                                ),
                                                TextButton(
                                                  onPressed: () async {
                                                    await myplaylist
                                                        .editMyPlaylist(
                                                      widget.listId,
                                                      _titleController.text,
                                                      _coverImgUrlController
                                                          .text,
                                                    );
                                                    Fluttertoast.showToast(
                                                      msg: '编辑成功',
                                                    );
                                                    Navigator.of(context).pop();
                                                    widget.onPlaylistTap('');
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
                                          Fluttertoast.showToast(
                                            msg: '已取消收藏',
                                          );
                                        } else {
                                          await myplaylist.saveMyPlaylist(
                                              'favorite', result);
                                          check_fav();
                                          Fluttertoast.showToast(
                                            msg: '已添加到我的收藏',
                                          );
                                        }
                                      }),
                            ],
                          ),
                          SliverToBoxAdapter(
                              child: Container(
                            height: MediaQuery.of(context).size.height - 280,
                            child: ReorderableListView(
                              onReorder: _onReorder,
                              children: tracks.map((track) {
                                return ListTile(
                                  key: ValueKey(track['id']),
                                  title: Text(track['title'] ?? '未知标题'),
                                  subtitle: Text(
                                      '${track['artist'] ?? '未知艺术家'} - ${track['album'] ?? '未知专辑'}'),
                                  trailing: IconButton(
                                    icon: Icon(Icons.more_vert),
                                    onPressed: () {
                                      song_dialog(
                                          context,
                                          track,
                                          widget.onPlaylistTap,
                                          widget.is_my,
                                          result['info'],
                                          deltrack);
                                    },
                                  ),
                                  onTap: () {
                                    Fluttertoast.showToast(
                                      msg: '尝试播放：${track['title']}',
                                    );
                                    MediaService.bootstrapTrack(
                                      track,
                                      playerSuccessCallback,
                                      playerFailCallback,
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                          )),
                        ],
                      ),
          ),
        ));
  }
}

class Searchlistinfo extends StatefulWidget {
  TextEditingController input_text_Controller;
  final ValueNotifier<String> selectedOptionNotifier;
  final Function(String) onPlaylistTap;
  Searchlistinfo(
      {required this.input_text_Controller,
      required this.selectedOptionNotifier,
      required this.onPlaylistTap});

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
  int curpage = 1;
  final ScrollController _scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    widget.input_text_Controller.addListener(_filterTracks);
    _scrollController.addListener(_onScroll);
    _filterTracks();
    widget.selectedOptionNotifier.addListener(_filterTracks);
  }

  void change_source() async {
    switch (widget.selectedOptionNotifier.value) {
      case 'BiliBili':
        source = 'bilibili';
        break;
      case '网易云':
        source = 'netease';
        break;
    }
  }

  void _onScroll() {
    // print(widget.selectedOption);
    // print(_scrollController.position.pixels);
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
    result = await MediaService.search(source, {
      'keywords': widget.input_text_Controller.text,
      'curpage': curpage,
      'type': song_or_playlist ? 1 : 0
    });
    setState(() {
      tracks.addAll(List<Map<String, dynamic>>.from(result['result']));
      // _loading = false;
    });
  }

  void _filterTracks() async {
    String query = widget.input_text_Controller.text.toLowerCase();
    if (query == '') {
      return;
    }
    change_source();

    try {
      setState(() {
        _loading = true;
      });
      result = await MediaService.search(source, {
        'keywords': query,
        'curpage': curpage,
        'type': song_or_playlist ? 1 : 0
      });
      setState(() {
        tracks = List<Map<String, dynamic>>.from(result['result']);
        _loading = false;
      });
    } catch (e) {
      // print(e);
    }
  }

  @override
  void dispose() {
    // widget.input_text_Controller.dispose();
    _scrollController.dispose();
    widget.selectedOptionNotifier.removeListener(_filterTracks);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _loading
            ? CircularProgressIndicator()
            : CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: tracks.length,
                      itemBuilder: (context, index) {
                        final track = tracks[index];
                        return ListTile(
                          title: Text(track['title']),
                          subtitle:
                              Text('${track['artist']} - ${track['album']}'),
                          trailing: IconButton(
                            icon: Icon(Icons.more_vert),
                            onPressed: () {
                              song_dialog(context, track, widget.onPlaylistTap);
                            },
                          ),
                          onTap: () {
                            Fluttertoast.showToast(
                              msg: '尝试播放：${track['title']}',
                            );
                            MediaService.bootstrapTrack(track,
                                playerSuccessCallback, playerFailCallback);
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
