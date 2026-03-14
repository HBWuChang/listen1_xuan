import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:listen1_xuan/const.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:share_plus/share_plus.dart';
import 'controllers/controllers.dart';
import 'controllers/myPlaylist_controller.dart';
import 'controllers/play_controller.dart';
import 'controllers/websocket_client_controller.dart';
import 'controllers/search_controller.dart';
import 'examples/websocket_client_example.dart';
import 'package:flutter/material.dart' hide SearchController;
import 'package:listen1_xuan/bl.dart';
import 'package:listen1_xuan/qq.dart';
import 'models/PlayListInfo.dart';
import 'models/Playlist.dart';
import 'netease.dart';
import 'package:marquee/marquee.dart';
import 'loweb.dart';
import 'play.dart';
import 'myplaylist.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'global_settings_animations.dart';
import 'package:get/get.dart';
import 'package:extended_image/extended_image.dart';
import 'package:expandable/expandable.dart';
import 'settings.dart';
import 'package:listen1_xuan/models/Track.dart';

part './pages/PlaylistPage.dart';
part './pages/SearchListInfoPage.dart';
part './pages/MyPlaylistPage.dart';

Future<dynamic> song_dialog(
  BuildContext context,
  Track track, {
  bool is_my = false,
  PlayListInfo? nowplaylistinfo,
  Function? deltrack,
  Offset? position,
}) async {
  final screenSize = MediaQuery.of(context).size;
  final dialogWidth = screenSize.width * 0.5;
  final dialogHeight = screenSize.height * 1;
  bool horizon = screenSize.height > screenSize.width ? false : true;
  XSearchController xSearchController = Get.find<XSearchController>();
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
        title: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: track.title ?? '未知标题'));
                  showSuccessSnackbar('标题已复制到剪切板', null);
                },
                child: SelectableText(
                  track.title ?? '未知标题',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),

            IconButton(
              icon: Icon(Icons.play_circle_fill_rounded),
              onPressed: () {
                playsong(track, isByClick: true);
              },
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: track.title ?? '未知标题'));
                  showSuccessSnackbar('标题已复制到剪切板', null);
                },
                onLongPress: () {
                  // Clipboard.setData(
                  //     ClipboardData(text: track['img_url'] ?? '未知封面'));
                  // xuan_toast(msg: '封面链接已复制到剪切板');
                  g_launchURL(Uri.parse(track.img_url ?? ''));
                },
                child: track.img_url == null
                    ? Container()
                    : ExtendedImage.network(
                        track.img_url!,
                        fit: BoxFit.cover,
                        cache: true,
                        cacheMaxAge: const Duration(days: 365 * 4),
                        loadStateChanged: (state) {
                          if (state.extendedImageLoadState ==
                              LoadState.failed) {
                            return Icon(Icons.error);
                          }
                        },
                      ),
              ),
              Obx(
                () => Get.find<WebSocketClientController>().isConnected
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: ListTile(
                              title: Text('发送到被控端'),
                              onTap: () {
                                WebSocketClientHelper.sendTrack(track);
                                Navigator.of(context).pop();
                                WebSocketClientHelper.showControlPanel();
                              },
                            ),
                          ),
                          Flexible(
                            child: ListTile(
                              title: Text('发送到被控端下一首'),
                              onTap: () {
                                WebSocketClientHelper.sendNextTrack(track);
                                showSuccessSnackbar('已发送', null);
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                        ],
                      )
                    : SizedBox.shrink(),
              ),

              ListTile(
                title: Text('搜索此音乐'),
                onTap: () {
                  Navigator.of(context).pop();
                  xSearchController.toListByIDOrSearch(
                    "",
                    search_text: track.title!,
                  );
                },
                onLongPress: () {
                  Clipboard.setData(
                    ClipboardData(text: track.artist ?? '未知艺术家'),
                  );
                  showSuccessSnackbar('作者已复制到剪切板', null);
                },
              ),
              ListTile(
                title: Text('作者：${track.artist ?? '未知艺术家'}'),
                onTap: () {
                  Navigator.of(context).pop();
                  xSearchController.toListByIDOrSearch(track.artist_id ?? '');
                },
                onLongPress: () {
                  Clipboard.setData(
                    ClipboardData(text: track.artist ?? '未知艺术家'),
                  );
                  showSuccessSnackbar('作者已复制到剪切板', null);
                },
              ),
              if (track.id.startsWith('bitrack_'))
                ListTile(
                  title: Text('查看可能的分集'),
                  onTap: () {
                    Navigator.of(context).pop();
                    xSearchController.toListByIDOrSearch(track.id);
                  },
                ),
              if (track.album != null)
                ListTile(
                  title: Text('专辑：${track.album}'),
                  onTap: () {
                    Navigator.of(context).pop();
                    xSearchController.toListByIDOrSearch(track.album_id!);
                  },
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: track.album!));
                    showSuccessSnackbar('专辑已复制到剪切板', null);
                  },
                ),
              ListTile(
                title: Text('添加到歌单'),
                onTap: () {
                  if (nowplaylistinfo != null) {
                    myplaylist.Add_to_my_playlist(
                      context,
                      [track],
                      nowplaylistinfo.title,
                      nowplaylistinfo.cover_img_url,
                    );
                  } else {
                    myplaylist.Add_to_my_playlist(context, [track]);
                  }
                },
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ListTile(
                      title: Text('添加到当前播放列表'),
                      onTap: () {
                        add_current_playing([track]);
                        showSuccessSnackbar('已添加到当前播放列表', null);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: Text('下一首播放'),
                      onTap: () {
                        Get.find<PlayController>().nextTrack = track;
                        showSuccessSnackbar('已添加到下一首播放', null);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: ListTile(
                      title: Text('歌曲链接'),
                      onTap: () {
                        launchUrl(Uri.parse(track.source_url ?? ''));
                      },
                      onLongPress: () {
                        SharePlus.instance.share(
                          ShareParams(text: '${track.source_url ?? ''}'),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: Text('分享链接'),
                      onTap: () {
                        String appLink = Get.find<Applinkscontroller>()
                            .getShareAppLink(track);
                        SharePlus.instance.share(ShareParams(text: appLink));
                      },
                      onLongPress: null,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: ListTile(
                      title: Text('作为替换源'),
                      onTap: () {
                        try {
                          Get.find<PlayController>()
                                  .songReplaceSourceTrack
                                  .value =
                              track;
                          Navigator.of(context).pop();
                          showInfoSnackbar(
                            '已选择 ${track.title} 作为歌曲信息及歌词来源',
                            null,
                          );
                          Get.find<PlayController>().songReplaceAdding.value =
                              false;
                          if (!Get.find<RouteController>()
                              .inSongReplacePage
                              .value) {
                            Get.toNamed(RouteName.songReplacePage, id: 1);
                          }
                        } catch (e) {
                          showErrorSnackbar('操作失败', e.toString());
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: Text('作为音频源'),
                      onTap: () {
                        try {
                          Get.find<PlayController>()
                                  .songReplaceTargetTrack
                                  .value =
                              track;
                          Navigator.of(context).pop();
                          showInfoSnackbar('已选择 ${track.title} 作为音频数据来源', null);
                          Get.find<PlayController>().songReplaceAdding.value =
                              false;
                          if (!Get.find<RouteController>()
                              .inSongReplacePage
                              .value) {
                            Get.toNamed(RouteName.songReplacePage, id: 1);
                          }
                        } catch (e) {
                          showErrorSnackbar('操作失败', e.toString());
                        }
                      },
                    ),
                  ),
                ],
              ),

              // ListTile(
              //   title: Text('添加到下载队列'),
              //   onTap: () async {
              //     final ok = await add_to_download_tasks([track.id]);
              //     if (ok) {
              //       xuan_toast(msg: '已添加到下载队列');
              //     } else {
              //       xuan_toast(msg: '添加失败');
              //     }
              //   },
              // ),
              ListTile(
                title: Text('删除本地缓存'),
                onTap: () async {
                  if (!await showConfirmDialog(
                    '删除本地缓存？',
                    '此操作不可恢复',
                    confirmLevel: ConfirmLevel.danger,
                  )) {
                    return;
                  }
                  await clean_local_cache(false, track.id);
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
                              onPressed: () {
                                myplaylist.removeTrackFromMyPlaylist(
                                  nowplaylistinfo!.id,
                                  track.id,
                                );
                                Navigator.of(context).pop();
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
                  child: dialog,
                ),
              ],
            )
          : dialog;
    },
  );
}

class PlaylistInfo extends StatefulWidget {
  final String listId;
  bool is_my = false;
  PlaylistInfo({Key? key, required this.listId, this.is_my = false})
    : super(key: key);

  @override
  _PlaylistInfoState createState() => _PlaylistInfoState();
}

class _PlaylistInfoState extends State<PlaylistInfo> {
  bool _loading = true;
  bool _loadfailed = false;
  bool _is_fav = false;
  TextEditingController _searchController = TextEditingController();
  double lastmove = 0;
  List<Track> _unfilteredTracks = [];
  List<Track> tracks = [];
  late PlayList result;
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
      try {
        result = PlayList.fromJson(data);
      } catch (e) {
        // print(e);
        logger.e('歌单数据解析失败', error: e);
        result = PlayList.fromJson({
          'info': {'id': widget.listId},
        });
      }
      if (mounted) {
        setState(() {
          tracks = result.tracks ?? [];
          _unfilteredTracks = tracks;
          _loading = false;
          if (result.info.title == null) {
            _loadfailed = true;
          }
        });
      }
    });
  }

  void deltrack(Track track) {
    setState(() {
      _unfilteredTracks.remove(track);
      _filterTracks();
    });
  }

  void _filterTracks() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      tracks = _unfilteredTracks.where((track) {
        final title = track.title?.toLowerCase() ?? '';
        final artist = track.artist?.toLowerCase() ?? '';
        final album = track.album?.toLowerCase() ?? '';
        return title.contains(query) ||
            artist.contains(query) ||
            album.contains(query);
      }).toList();
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (!widget.is_my) {
      showErrorSnackbar('只有自己创建的歌单才能排序', null);
      return;
    }
    if (_searchController.text.toLowerCase().isNotEmpty) {
      showErrorSnackbar('搜索状态下无法排序', null);
      return;
    }
    MediaService.insertTrackToMyPlaylist(
      widget.listId,
      tracks[oldIndex],
      tracks[newIndex],
      'top',
    );
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
    scroll_bar_pos =
        inner_scrollController.position.pixels /
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
                : (outter_scrollController.offset + move),
          );
        }
      } else {
        if (outter_scrollController.offset != 0) {
          outter_scrollController.jumpTo(
            (outter_scrollController.offset + move) < 0
                ? 0
                : (outter_scrollController.offset + move),
          );
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
    return Scaffold(
      body: Center(
        child: _loading
            ? globalLoadingAnime
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
                        Get.back(id: 1);
                      },
                    ),
                    title: Container(
                      height: 48,
                      child: Marquee(
                        text: result.info.title!,
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
                          ExtendedImage.network(
                            result.info.cover_img_url!,
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                            cache: true,
                            loadStateChanged: (state) {
                              if (state.extendedImageLoadState ==
                                  LoadState.failed) {
                                return Icon(Icons.error);
                              }
                            },
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
                                    List<Track> trackList = List<Track>.from(
                                      tracks,
                                    );
                                    set_current_playing(trackList);

                                    playsong(tracks[0], isByClick: true);
                                  },
                                  child: Text('播放全部（共${tracks.length}首）'),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: IconButton(
                                  onPressed: () async {
                                    List<Track> trackList = List<Track>.from(
                                      tracks,
                                    );
                                    add_current_playing(trackList);
                                    showSuccessSnackbar('已添加到当前播放列表', null);
                                  },
                                  icon: Icon(Icons.add_box_outlined),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: TextField(
                                  focusNode: _focusNode,
                                  controller: _searchController,
                                  decoration: InputDecoration(hintText: '搜索'),
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
                              result.info.title!,
                              result.info.cover_img_url!,
                            );
                            Get.back(result: {"refresh": true}, id: 1);
                          } catch (e) {
                            // print(e);
                            showErrorSnackbar('添加失败', e.toString());
                          }
                        },
                      ),
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
                                            Navigator.of(context_dialog).pop();
                                          },
                                          child: Text('取消'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            myplaylist.removeMyPlaylist(
                                              'my',
                                              widget.listId,
                                            );
                                            Navigator.of(context_dialog).pop();
                                            Get.back(
                                              result: {"refresh": true},
                                              id: 1,
                                            );
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
                                launchUrl(Uri.parse(result.info.source_url!));
                              },
                            ),
                      widget.is_my
                          ? IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () async {
                                set_inapp_hotkey(false);
                                // 编辑按钮点击事件
                                await showDialog(
                                  context: context_PlaylistInfo,
                                  builder: (BuildContext context_dialog) {
                                    final TextEditingController
                                    _titleController = TextEditingController();
                                    final TextEditingController
                                    _coverImgUrlController =
                                        TextEditingController();
                                    _titleController.text = result.info.title!;
                                    _coverImgUrlController.text =
                                        result.info.cover_img_url!;
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
                                            Navigator.of(context_dialog).pop();
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
                                            showSuccessSnackbar('编辑成功', null);
                                            Navigator.of(context_dialog).pop();
                                            Get.back(
                                              result: {"refresh": true},
                                              id: 1,
                                            );
                                          },
                                          child: Text('确定'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                set_inapp_hotkey(true);
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
                                  myplaylist.removeMyPlaylist(
                                    'favorite',
                                    widget.listId,
                                  );
                                  check_fav();
                                  showInfoSnackbar('已取消收藏', null);
                                } else {
                                  myplaylist.saveMyPlaylist('favorite', result);
                                  check_fav();
                                  showSuccessSnackbar('已添加到我的收藏', null);
                                }
                              },
                            ),
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
                          title: Text(track.title ?? '未知标题'),
                          subtitle: Text(
                            '${track.artist ?? '未知艺术家'} - ${track.album ?? '未知专辑'}',
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.more_vert),
                            onPressed: () async {
                              var ret = await song_dialog(
                                context_PlaylistInfo,
                                track,
                                is_my: widget.is_my,
                                nowplaylistinfo: result.info,
                                deltrack: deltrack,
                                position: Offset(
                                  MediaQuery.of(context).size.width,
                                  (_key.currentContext!.findRenderObject()
                                          as RenderBox)
                                      .localToGlobal(Offset.zero)
                                      .dy,
                                ),
                              );

                              if (ret != null) {
                                if (ret["pop"] == true) {
                                  Get.back(id: 1);
                                }
                                if (ret["push"] != null) {
                                  Get.toNamed(
                                    ret["push"],
                                    arguments: {'listId': ret["push"]},
                                    id: 1,
                                  );
                                }
                              }
                            },
                          ),
                          onTap: () {
                            playsong(track, isByClick: true);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _show_scroll_bar(BuildContext context) async {
    scroll_bar_pos =
        inner_scrollController.position.pixels /
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
                        inner_scrollController.jumpTo(
                          value *
                              inner_scrollController.position.maxScrollExtent,
                        );
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
