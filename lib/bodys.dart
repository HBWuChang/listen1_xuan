import 'dart:math' as math;

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:listen1_xuan/constants/const.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/pages/lyric/lyric_page.dart';
import 'package:listen1_xuan/pages/playlist_info/playlist_info_args.dart';
import 'package:listen1_xuan/router/ro.dart';
import 'package:listen1_xuan/widgets/ext/ext_hero.dart';
import 'package:listen1_xuan/widgets/ext/ext_widget.dart';
import 'package:share_plus/share_plus.dart';
import 'controllers/controllers.dart';
import 'controllers/myPlaylist_controller.dart';
import 'controllers/play_controller.dart';
import 'controllers/websocket_client_controller.dart';
import 'controllers/search_controller.dart';
import 'examples/websocket_client_example.dart';
import 'package:flutter/material.dart'
    hide SearchController, CircularProgressIndicator;
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
import 'package:universal_io/io.dart' as universal_io;
import 'settings.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import '../widgets/progress_indicator_xuan.dart';

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
                          if (state.extendedImageLoadState ==
                              LoadState.loading) {
                            return globalLoadingAnimeOfExtendedImage;
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
                        if (playController.nowPlayingTrackId == track.id) {
                          if ((track.source_url ?? '').contains('bilibili')) {
                            Uri url = Uri.parse(track.source_url!);
                            url = url.replace(
                              queryParameters: {
                                ...url.queryParameters,
                                't': playController
                                    .music_player
                                    .state
                                    .position
                                    .inSeconds
                                    .toString(),
                              },
                            );
                            launchUrl(url);
                            return;
                          }
                        }
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
              if (isDesktop)
                FutureBuilder<String>(
                  future: get_local_cache(track.id),
                  builder: (context, snapshot) {
                    final localCachePath = snapshot.data ?? '';
                    if (localCachePath.isEmpty ||
                        Get.find<CacheController>().isOnlineCache(track.id)) {
                      return SizedBox.shrink();
                    }
                    return ListTile(
                      title: Text('在文件夹中打开缓存文件'),
                      subtitle: Text(
                        localCachePath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () async {
                        try {
                          if (isWindows) {
                            await universal_io.Process.run('explorer', [
                              '/select,',
                              localCachePath,
                            ], runInShell: true);
                          } else if (isMacOS) {
                            await universal_io.Process.run('open', [
                              '-R',
                              localCachePath,
                            ], runInShell: true);
                          }
                        } catch (e) {
                          showErrorSnackbar('打开失败', e.toString());
                        }
                      },
                    );
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
