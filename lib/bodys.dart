import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'loweb.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'play.dart';

class Playlist extends StatefulWidget {
  final String source;
  final int offset;
  final String filter;
  final Function(String) onPlaylistTap;

  Playlist({required this.source, required this.offset, required this.filter, required this.onPlaylistTap});

  @override
  _PlaylistState createState() => _PlaylistState();
}

class _PlaylistState extends State<Playlist> {
  List<Map<String, dynamic>> _playlists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    Map<String, dynamic> result = await MediaService.showPlaylistArray(
        widget.source, widget.offset, widget.filter);
    print(result);
    setState(() {
      _playlists = result['result'];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _loading
            ? CircularProgressIndicator()
            : GridView.builder(
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
                      // 处理点击事件
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) => PlaylistInfo(
                      //       listId: playlist['id'],
                      //     ),
                      //   ),
                      // );
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

// bi_get_playlist
class PlaylistInfo extends StatefulWidget {
  final String listId;
  final Function(String) onPlaylistTap;

  PlaylistInfo({required this.listId, required this.onPlaylistTap});

  @override
  _PlaylistInfoState createState() => _PlaylistInfoState();
}

class _PlaylistInfoState extends State<PlaylistInfo> {
  Map<String, dynamic> _playlist = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
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
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              if (!snapshot.hasData || snapshot.data['tracks'].isEmpty) {
                return Text('No data available');
              }
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
                                onPressed: () {
                                  // 播放全部按钮点击事件
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
                        onPressed: () {
                          // 添加按钮点击事件
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.link),
                        onPressed: () {
                          // 链接按钮点击事件
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.favorite_border),
                        onPressed: () {
                          // 收藏按钮点击事件
                        },
                      ),
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
                            MediaService.bootstrapTrack(track,playerSuccessCallback, playerFailCallback);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),);
  }
}
