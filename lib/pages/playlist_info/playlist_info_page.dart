import 'dart:math' as math;

import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/bodys.dart';
import 'package:listen1_xuan/controllers/routeController.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/global_settings_animations.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:listen1_xuan/play.dart';
import 'package:listen1_xuan/provider/loweb.dart';
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
                onPressed: () => routerPop(),
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
                      () => Skeletonizer(
                        enabled: controller.loading.value,
                        child: ExtendedImage.network(
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
                                if (controller.tracks.isEmpty) {
                                  return;
                                }
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
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: controller.loading.value
                      ? globalLoadingAnime.center
                      : controller.loadFailed.value
                      ? _buildErrorView(context, controller)
                      : controller.useReorderableList.value
                      ? _buildReorderableList(context, controller)
                      : _buildNormalList(context, controller),
                ),
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
    return [
      IconButton(
        icon: Icon(Icons.add),
        onPressed: () async {
          try {
            await provider.myplaylist.Add_to_my_playlist(
              context,
              List<Track>.from(controller.tracks),
              controller.result.info.title,
              controller.result.info.cover_img_url,
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
                            provider.myplaylist.removeMyPlaylist(
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
                final sourceUrl = controller.result.info.source_url;
                if (sourceUrl == null || sourceUrl.isEmpty) {
                  showErrorSnackbar('没有可打开的链接', null);
                  return;
                }
                launchUrl(Uri.parse(sourceUrl));
              },
            ),
      controller.isMy
          ? IconButton(
              icon: Icon(Icons.edit),
              onPressed: () async {
                setInAppHotKeyEnable(false);
                await showDialog(
                  context: context,
                  builder: (BuildContext contextDialog) {
                    final TextEditingController titleCtrl =
                        TextEditingController(
                          text: controller.result.info.title,
                        );
                    final TextEditingController coverCtrl =
                        TextEditingController(
                          text: controller.result.info.cover_img_url,
                        );
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
                            provider.myplaylist.editMyPlaylist(
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
                setInAppHotKeyEnable(true);
              },
            )
          : Obx(
              () => IconButton(
                icon: controller.isFav.value
                    ? Icon(Icons.star)
                    : Icon(Icons.star_border),
                onPressed: () async {
                  if (controller.isFav.value) {
                    provider.myplaylist.removeMyPlaylist(
                      'favorite',
                      controller.listId,
                    );
                    controller.checkFav();
                    showInfoSnackbar('已取消收藏', null);
                  } else {
                    provider.myplaylist.saveMyPlaylist(
                      'favorite',
                      controller.result,
                    );
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

  Widget _buildErrorView(
    BuildContext context,
    PlaylistInfoController controller,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            const Text(
              '加载失败',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(
              controller.loadError.value,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => controller.loadData(),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
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
    await song_dialog(
      context,
      track,
      is_my: controller.isMy,
      nowplaylistinfo: controller.result.info,
      deltrack: controller.delTrack,
      position: Offset(MediaQuery.of(context).size.width, iconDy),
    );
  }
}
