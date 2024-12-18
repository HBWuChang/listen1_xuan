import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'loweb.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'play.dart';
import 'myplaylist.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';

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
    setState(() {
      _playlists = result['result'];
      if (result.containsKey('total')) {
        total = result['total'];
        per_page = result['per_page'];
      }
      _loading = false;
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
    if (_currentOffset >= total * per_page) return;
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
                          width: 100, // 设置图片宽度
                          height: 100, // 设置图片高度
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
  bool _isExpandedMy = true;
  bool _isExpandedFav = true;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    Map<String, dynamic> result_my = await myplaylist.showMyPlaylist('my');
    Map<String, dynamic> result_fav =
        await myplaylist.showMyPlaylist('favorite');
    setState(() {
      _playlists_my = result_my['result'];
      _playlists_fav = result_fav['result'];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        _loading
            ? CircularProgressIndicator()
            : SingleChildScrollView(
                child: ExpansionPanelList(
                  expansionCallback: (int index, bool isExpanded) {
                    setState(() {
                      if (index == 0) {
                        _isExpandedMy = !_isExpandedMy;
                      } else if (index == 1) {
                        _isExpandedFav = !_isExpandedFav;
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
                              widget.onPlaylistTap(playlist['info']['id'], true);
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
                            });
                          },
                        );
                      },
                      body: Column(
                        children: _playlists_fav.map((playlist) {
                          return ListTile(
                            leading: CachedNetworkImage(
                              imageUrl: playlist['info']['cover_img_url'],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                            title: Text(playlist['info']['title']),
                            onTap: () {
                              widget.onPlaylistTap(playlist['info']['id']);
                            },
                          );
                        }).toList(),
                      ),
                      isExpanded: _isExpandedFav,
                    ),
                  ],
                ),
              ),
      ]),
    );
  }
}

class PlaylistInfo extends StatefulWidget {
  final String listId;
  final Function(String) onPlaylistTap;
  bool is_my = false;
  PlaylistInfo(
      {required this.listId, required this.onPlaylistTap, this.is_my = false});

  @override
  _PlaylistInfoState createState() => _PlaylistInfoState();
}

class _PlaylistInfoState extends State<PlaylistInfo> {
  Map<String, dynamic> _playlist = {};
  bool _loading = true;
  bool _is_fav = false;

  @override
  void initState() {
    super.initState();
    check_fav();
  }

  void check_fav() async {
    final result = await myplaylist.isMyfavPlaylist(widget.listId);
    setState(() {
      _is_fav = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FutureBuilder(
          future: MediaService.getPlaylist(widget.listId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator();
            }
            // try {
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            if (!snapshot.hasData || snapshot.data['tracks'].isEmpty) {
              return Text('No data available');
            }
            // } catch (e) {
            //   return Text('Error: ${e}');
            // }
            final playlistInfo = snapshot.data['info'];
            // {info: {cover_img_url: http://i0.hdslb.com/bfs/music/0fa5b14f421dcc686f2adb11faaa64b5f6ca86d2.jpg, title: 【日语】那些令人中毒循环的歌, id: biplaylist_48955, source_url: https://www.bilibili.com/audio/am48955}, tracks: [{id: bitrack_15228, title: 极乐净土, artist: 祈Inory, artist_id: biartist_234782, source: bilibili, source_url: https://www.bilibili.com/audio/au15228, img_url: http://i0.hdslb.com/bfs/music/015f137f9053008496df50518cd506cec62ff6b7.jpg, lyric_url: http://i0.hdslb.com/bfs/music/150529756415228.lrc},
            final tracks = snapshot.data['tracks'];
            return CustomScrollView(
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
                      text: playlistInfo['title'],
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
                        SizedBox(height: 80), // 添加一个空的SizedBox来调整位置
                        CachedNetworkImage(
                          imageUrl: playlistInfo['cover_img_url'],
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
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                // 播放全部按钮点击事件
                                List<Map<String, dynamic>> trackList = List<Map<String, dynamic>>.from(tracks);
                                await set_current_playing(trackList);
                                await playsong(tracks[0]);
                              },
                              child: Text('播放全部（共${tracks.length}首）'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                // 搜索按钮点击事件
                              },
                              child: Text('搜索'),
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
                            await myplaylist.saveMyPlaylist(
                              'my',
                              snapshot.data,
                            );
                            Fluttertoast.showToast(
                              msg: '已添加到我的歌单',
                            );
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
                                          await myplaylist.removeMyPlaylist(
                                              'my', widget.listId);
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
                              launchUrl(Uri.parse(playlistInfo['source_url']));
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
                                  final TextEditingController _titleController =
                                      TextEditingController();
                                  final TextEditingController _coverImgUrlController =
                                      TextEditingController();
                                  _titleController.text = playlistInfo['title'];
                                  _coverImgUrlController.text =
                                      playlistInfo['cover_img_url'];
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
                                          controller: _coverImgUrlController,
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
                                          await myplaylist.editMyPlaylist(
                                            widget.listId,
                                            _titleController.text,
                                            _coverImgUrlController.text,
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
                        :
                    IconButton(
                        // icon: Icon(Icons.star_border),
                        icon: _is_fav
                            ? Icon(Icons.star)
                            : Icon(Icons.star_border),
                        onPressed: () async {
                          // 添加按钮点击事件
                          try {
                            await myplaylist.saveMyPlaylist(
                              'favorite',
                              snapshot.data,
                            );
                            check_fav();
                            Fluttertoast.showToast(
                              msg: '已添加到我的收藏',
                            );
                          } catch (e) {
                            // print(e);
                            Fluttertoast.showToast(
                              msg: '添加失败${e}',
                            );
                          }
                        }),
                  ],
                ),
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
                            // 更多按钮点击事件
                          },
                        ),
                        onTap: () {
                          // 歌曲点击事件
                          // bootstrapTrack(track);
                          // MediaService.bootstrapTrack(track, playerSuccessCallback, playerFailCallback);
                          Fluttertoast.showToast(
                            msg: '尝试播放：${track['title']}',
                          );
                          MediaService.bootstrapTrack(
                              track, playerSuccessCallback, playerFailCallback);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
