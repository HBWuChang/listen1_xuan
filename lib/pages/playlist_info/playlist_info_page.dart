import 'dart:math' as math;

import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/bodys.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/global_settings_animations.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:listen1_xuan/myplaylist.dart';
import 'package:listen1_xuan/play.dart';
import 'package:listen1_xuan/router/ro.dart';
import 'package:listen1_xuan/widgets/ext/ext_hero.dart';
import 'package:listen1_xuan/widgets/ext/ext_widget.dart';
import 'package:marquee/marquee.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:url_launcher/url_launcher.dart';

import 'playlist_info_args.dart';
import 'playlist_info_controller.dart';

class PlaylistInfoPage extends StatelessWidget {
  final PlaylistInfoArgs args;

  const PlaylistInfoPage({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlaylistInfoController>(
      tag: args.controllerTag,
    );
    return Scaffold(
      body: Center(
        child: CustomScrollView(
          controller: controller.outerScrollController,
          scrollBehavior: ScrollConfiguration.of(
            context,
          ).copyWith(scrollbars: false),
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
              title: Obx(
                () => Skeletonizer(
                  enabled: controller.loading.value,
                  child: SizedBox(
                    height: 48,
                    child: Marquee(
                      text: controller.loadFailed.value
                          ? '加载失败'
                          : controller.result.info.title ?? "加载失败",
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
              ),
              titleSpacing: 0,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Obx(
                      () => ExtendedImage.network(
                        controller.result.info.cover_img_url ?? '',
                        width: 150,
                        height: 150,
                        fit: BoxFit.cover,
                        cache: true,
                        loadStateChanged: (state) {
                          if (state.extendedImageLoadState ==
                              LoadState.failed) {
                            return Icon(Icons.error);
                          }
                          if (state.extendedImageLoadState ==
                              LoadState.loading) {
                            return globalLoadingAnimeOfExtendedImage;
                          }
                          return null;
                        },
                      ),
                    ).hero4playlistItemImg(args.playListInfo),
                    8.sbh,
                    Obx(
                      () => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            flex: 5,
                            child: ElevatedButton(
                              onPressed: () async {
                                List<Track> trackList = List<Track>.from(
                                  controller.tracks,
                                );
                                set_current_playing(trackList);
                                playsong(controller.tracks[0], isByClick: true);
                              },
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '播放全部（共${controller.tracks.length}首）',
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: IconButton(
                              onPressed: () async {
                                List<Track> trackList = List<Track>.from(
                                  controller.tracks,
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
                              focusNode: controller.searchFocusNode,
                              controller: controller.searchController,
                              decoration: InputDecoration(hintText: '搜索'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: _buildActions(context, controller),
            ),
            Obx(
              () => SliverFillRemaining(
                hasScrollBody: true,
                child: controller.loading.value
                    ? globalLoadingAnime.center
                    : controller.useReorderableList.value
                    ? _buildReorderableList(context, controller)
                    : _buildNormalList(context, controller),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    PlaylistInfoController controller,
  ) {
    final result = controller.result;
    return [
      IconButton(
        icon: Icon(Icons.add),
        onPressed: () async {
          try {
            await myplaylist.Add_to_my_playlist(
              context,
              controller.tracks.toList(),
              result.info.title,
              result.info.cover_img_url,
            );
            Get.back(result: {"refresh": true}, id: 1);
          } catch (e) {
            showErrorSnackbar('添加失败', e.toString());
          }
        },
      ),
      controller.isMy
          ? IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext contextDialog) {
                    return AlertDialog(
                      title: Text('删除歌单'),
                      content: Text('确定要删除这个歌单吗？'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(contextDialog).pop();
                          },
                          child: Text('取消'),
                        ),
                        TextButton(
                          onPressed: () async {
                            myplaylist.removeMyPlaylist(
                              'my',
                              controller.listId,
                            );
                            Navigator.of(contextDialog).pop();
                            Get.back(result: {"refresh": true}, id: 1);
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
                launchUrl(Uri.parse(result.info.source_url!));
              },
            ),
      controller.isMy
          ? IconButton(
              icon: Icon(Icons.edit),
              onPressed: () async {
                set_inapp_hotkey(false);
                await showDialog(
                  context: context,
                  builder: (BuildContext contextDialog) {
                    final TextEditingController titleCtrl =
                        TextEditingController(text: result.info.title);
                    final TextEditingController coverCtrl =
                        TextEditingController(text: result.info.cover_img_url);
                    return AlertDialog(
                      title: Text('编辑歌单'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: titleCtrl,
                            decoration: InputDecoration(labelText: '歌单标题'),
                          ),
                          TextField(
                            controller: coverCtrl,
                            decoration: InputDecoration(labelText: '封面图片链接'),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(contextDialog).pop();
                          },
                          child: Text('取消'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await myplaylist.editMyPlaylist(
                              controller.listId,
                              titleCtrl.text,
                              coverCtrl.text,
                            );
                            showSuccessSnackbar('编辑成功', null);
                            Navigator.of(contextDialog).pop();
                            Get.back(result: {"refresh": true}, id: 1);
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
          : Obx(
              () => IconButton(
                icon: controller.isFav.value
                    ? Icon(Icons.star)
                    : Icon(Icons.star_border),
                onPressed: () async {
                  if (controller.isFav.value) {
                    myplaylist.removeMyPlaylist('favorite', controller.listId);
                    controller.checkFav();
                    showInfoSnackbar('已取消收藏', null);
                  } else {
                    myplaylist.saveMyPlaylist('favorite', controller.result);
                    controller.checkFav();
                    showSuccessSnackbar('已添加到我的收藏', null);
                  }
                },
              ),
            ),
      if (controller.isMy)
        Tooltip(
          message: '排序',
          child: IconButton(
            onPressed: () {
              controller.useReorderableList.value =
                  !controller.useReorderableList.value;
            },
            icon: Transform.rotate(
              angle: -math.pi / 2.0,
              child: Obx(
                () => Icon(
                  Icons.compare_arrows_rounded,
                  color: controller.useReorderableList.value
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _buildReorderableList(
    BuildContext context,
    PlaylistInfoController controller,
  ) {
    return AnimatedReorderableListView(
      onReorder: controller.onReorder,
      isSameItem: (trackA, trackB) => trackA.id == trackB.id,
      controller: controller.innerScrollController,
      items: controller.tracks.toList(),
      enterTransition: [SlideInDown()],
      exitTransition: [SlideInUp()],
      insertDuration: const Duration(milliseconds: 300),
      removeDuration: const Duration(milliseconds: 300),
      dragStartDelay: const Duration(milliseconds: 300),
      buildDefaultDragHandles: false,
      longPressDraggable: false,
      itemBuilder: (context, index) {
        final track = controller.tracks[index];
        final key = ValueKey(track.id);
        return ListTile(
          key: key,
          title: Text(track.title ?? '未知标题'),
          subtitle: Text(
            '${track.artist ?? '未知艺术家'} - ${track.album ?? '未知专辑'}',
          ),
          trailing: Builder(
            builder: (iconContext) => IconButton(
              icon: Icon(Icons.more_vert),
              onPressed: () async {
                await _onTrackMore(context, iconContext, track, controller);
              },
            ),
          ),
          onTap: () {
            playsong(track, isByClick: true);
          },
        );
      },
    );
  }

  Widget _buildNormalList(
    BuildContext context,
    PlaylistInfoController controller,
  ) {
    return SuperListView.builder(
      controller: controller.innerScrollController,
      itemCount: controller.tracks.length,
      itemBuilder: (context, index) {
        final track = controller.tracks[index];
        final key = ValueKey(track.id);
        return ListTile(
          key: key,
          title: Text(track.title ?? '未知标题'),
          subtitle: Text(
            '${track.artist} - ${track.album}${track.totalDurMsg != null ? ' | ${track.totalDurMsg}' : ''}',
          ),
          trailing: Builder(
            builder: (iconContext) => IconButton(
              icon: Icon(Icons.more_vert),
              onPressed: () async {
                await _onTrackMore(context, iconContext, track, controller);
              },
            ),
          ),
          onTap: () {
            playsong(track, isByClick: true);
          },
        );
      },
    );
  }

  Future<void> _onTrackMore(
    BuildContext context,
    BuildContext iconContext,
    Track track,
    PlaylistInfoController controller,
  ) async {
    final renderObject = iconContext.findRenderObject();
    final iconDy = renderObject is RenderBox
        ? renderObject.localToGlobal(Offset.zero).dy
        : 0.0;
    var ret = await song_dialog(
      context,
      track,
      is_my: controller.isMy,
      nowplaylistinfo: controller.result.info,
      deltrack: controller.delTrack,
      position: Offset(MediaQuery.of(context).size.width, iconDy),
    );
  }
}
