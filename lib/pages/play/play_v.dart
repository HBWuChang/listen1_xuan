part of '../../play.dart';

Widget get playV0 => Center(
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // Show media item title
      StreamBuilder<MediaItem?>(
        stream: Get.find<AudioHandlerController>().audioHandler.mediaItem,
        builder: (context, snapshot) {
          final mediaItem = snapshot.data;
          // return Text(mediaItem?.title ?? '');
          if (mediaItem == null) {
            return Container(width: 168.w, height: 168.w);
          }
          return GestureDetector(
            onTap: () {
              // 点击封面打开歌词页面
              _openLyricPage();
            },
            child: Container(
              width: 168.w,
              height: 168.w,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ExtendedImage.network(
                  mediaItem.artUri.toString(),
                  fit: BoxFit.cover,
                  cache: true,
                  loadStateChanged: (state) {
                    if (state.extendedImageLoadState == LoadState.failed) {
                      return Icon(Icons.music_note, size: 168.w);
                    }
                  },
                ),
              ),
            ),
          );
        },
      ),
      Container(
        width: 864.w,
        height: 150.w,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -20.w,
              left: 0,
              right: 0,
              child: Container(
                height: 120.w,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 5,
                      child: StreamBuilder<MediaItem?>(
                        stream: Get.find<AudioHandlerController>()
                            .audioHandler
                            .mediaItem,
                        builder: (context, snapshot) {
                          final mediaItem = snapshot.data;
                          return Text(
                            '${mediaItem?.title ?? 'null'}  -  ${mediaItem?.artist ?? 'null'}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                    Container(
                      width: 200.w,
                      child: StreamBuilder<MediaState>(
                        stream: _mediaStateStream,
                        builder: (context, snapshot) {
                          final mediaItem = snapshot.data;

                          return Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                (formatDuration(
                                      mediaItem?.position ?? Duration.zero,
                                    ) +
                                    ' / ' +
                                    formatDuration(
                                      mediaItem?.mediaItem?.duration ??
                                          Duration.zero,
                                    )),
                                style: TextStyle(fontSize: 60.0.sp),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Obx(
                      () => SizedBox(
                        width: 120.w,
                        height: 120.w,
                        child: Stack(
                          children: [
                            Center(
                              child: IconButton(
                                tooltip: '正在播放列表',
                                icon: Icon(Icons.playlist_play_rounded),
                                onPressed: () async {
                                  Get.toNamed(RouteName.nowPlayingPage, id: 1);
                                },
                              ),
                            ),
                            Positioned(
                              top: 0,
                              child: Text(
                                '${_playController.current_playing.length}',
                                style: TextStyle(fontSize: 32.sp),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Obx(() {
                      return IconButton(
                        icon: switch (playmode.value) {
                          0 => Icon(Icons.repeat, size: 60.w),
                          1 => Icon(Icons.shuffle, size: 60.w),
                          2 => Icon(Icons.repeat_one, size: 60.w),
                          _ => Icon(Icons.error), // 默认情况
                        },
                        onPressed: () {
                          global_change_play_mode();
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -30.w,
              right: 0,
              left: 0,
              child: StreamBuilder<MediaState>(
                stream: _mediaStateStream,
                builder: (context, snapshot) {
                  final mediaState = snapshot.data;
                  return Container(
                    height: 120.w,
                    child: Slider(
                      value:
                          (mediaState?.position.inMilliseconds.toDouble() ??
                                  0.0) >
                              (mediaState?.mediaItem?.duration?.inMilliseconds
                                      .toDouble() ??
                                  1.0)
                          ? (mediaState?.mediaItem?.duration?.inMilliseconds
                                    .toDouble() ??
                                1.0)
                          : (mediaState?.position.inMilliseconds.toDouble() ??
                                0.0),
                      max:
                          mediaState?.mediaItem?.duration?.inMilliseconds
                              .toDouble() ??
                          1.0,
                      onChanged: (value) {
                        global_seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      Container(
        width: 150.w,
        height: 150.w,
        child: Obx(
          () => Center(
            child: _playController.isplaying.value
                ? _button(Icons.pause, () {
                    global_pause();
                  })
                : _button(Icons.play_arrow, () {
                    global_play();
                  }),
          ),
        ),
      ),
    ],
  ),
);
// 256.w
Widget get playV => LayoutBuilder(
  builder: (context, boxConstraints) {
    _playController.playVMaxHeight = boxConstraints.maxHeight;
    return SizedBox(
      height: _playController.playVMaxHeight,
      child: SheetViewport(
        child: Sheet(
          controller: _playController.sheetController,
          initialOffset: SheetOffset(
            _playController.sheetMinHeight / _playController.playVMaxHeight,
          ),
          snapGrid: SheetSnapGrid(
            snaps: [
              SheetOffset(
                _playController.sheetMinHeight / _playController.playVMaxHeight,
              ),
              SheetOffset(
                _playController.sheetMidHeight / _playController.playVMaxHeight,
              ),
              SheetOffset(1.0),
            ],
          ),
          child: Container(
            height: _playController.playVMaxHeight,
            decoration: BoxDecoration(
              color: AdaptiveTheme.of(Get.context!).theme.cardColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Get.theme.shadowColor.withOpacity(0.2),
                  blurRadius: 5,
                  offset: Offset(0, -5),
                  spreadRadius: 2.5,
                ),
              ],
            ),
            child: NotificationListener<SheetNotification>(
              onNotification: (notification) {
                if (notification is SheetUpdateNotification) {
                  final minOffset =
                      _playController.sheetMinHeight /
                      _playController.sheetMidHeight;
                  final maxOffset = 1.0;
                  final currentOffset = notification.metrics.offset;
                  final ratio =
                      ((currentOffset - minOffset) / (maxOffset - minOffset))
                          .clamp(0.0, 1.0);
                  _playController.sheetExpandRatio.value = ratio;
                }
                return false;
              },
              child: Builder(
                builder: (context) {
                  // 获取 Sheet 位置驱动的动画
                  final sheetController = _playController.sheetController;
                  final expandAnimation = SheetOffsetDrivenAnimation(
                    controller: sheetController,
                    initialValue: 0,
                    startOffset: _playController.sheetMinOffset,
                    endOffset: _playController.sheetMidOffset,
                  );

                  return SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 100.w,
                    ),
                    child: Column(
                      children: [
                        // 拖拽指示器
                        Container(
                          height: 32,
                          alignment: Alignment.center,
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Get.theme.dividerColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        SizedBox(height: 16.w),

                        // 封面 - 尺寸随展开程度变化
                        AnimatedBuilder(
                          animation: expandAnimation,
                          builder: (context, child) {
                            final expandProgress = expandAnimation.value.clamp(
                              0.0,
                              1.0,
                            );
                            // 从 120.w 变化到 300.w
                            final coverSize = 120.w + (180.w * expandProgress);

                            return StreamBuilder<MediaItem?>(
                              stream: Get.find<AudioHandlerController>()
                                  .audioHandler
                                  .mediaItem,
                              builder: (context, snapshot) {
                                final mediaItem = snapshot.data;
                                if (mediaItem == null) {
                                  return Container(
                                    width: coverSize,
                                    height: coverSize,
                                    decoration: BoxDecoration(
                                      color: Get.theme.cardColor,
                                      borderRadius: BorderRadius.circular(
                                        8 + 8 * expandProgress,
                                      ),
                                    ),
                                  );
                                }
                                return GestureDetector(
                                  onTap: () => _openLyricPage(),
                                  child: Container(
                                    width: coverSize,
                                    height: coverSize,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        8 + 8 * expandProgress,
                                      ),
                                      child: ExtendedImage.network(
                                        mediaItem.artUri.toString(),
                                        fit: BoxFit.cover,
                                        cache: true,
                                        loadStateChanged: (state) {
                                          if (state.extendedImageLoadState ==
                                              LoadState.failed) {
                                            return Icon(
                                              Icons.music_note,
                                              size: coverSize,
                                            );
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),

                        // 歌曲信息 - 布局随展开程度变化
                        AnimatedBuilder(
                          animation: expandAnimation,
                          builder: (context, child) {
                            final expandProgress = expandAnimation.value.clamp(
                              0.0,
                              1.0,
                            );
                            // 间距从 16 变化到 40
                            final spacing = 16.w + (24.w * expandProgress);
                            // 字体大小变化
                            final titleSize = 16.0 + (4.0 * expandProgress);
                            final artistSize = 14.0 + (2.0 * expandProgress);

                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w + (16.w * expandProgress),
                                vertical: spacing,
                              ),
                              child: StreamBuilder<MediaItem?>(
                                stream: Get.find<AudioHandlerController>()
                                    .audioHandler
                                    .mediaItem,
                                builder: (context, snapshot) {
                                  final mediaItem = snapshot.data;
                                  return Column(
                                    children: [
                                      Text(
                                        mediaItem?.title ?? '未播放',
                                        style: TextStyle(
                                          fontSize: titleSize,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: expandProgress > 0.5 ? 2 : 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(
                                        height: 4 + (4 * expandProgress),
                                      ),
                                      Text(
                                        mediaItem?.artist ?? '',
                                        style: TextStyle(
                                          fontSize: artistSize,
                                          color: Get
                                              .theme
                                              .textTheme
                                              .bodySmall
                                              ?.color,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );
                          },
                        ),

                        // 控制按钮区域 - 高度和透明度渐进变化
                        AnimatedBuilder(
                          animation: expandAnimation,
                          builder: (context, child) {
                            final expandProgress = expandAnimation.value.clamp(
                              0.0,
                              1.0,
                            );
                            // 当展开程度 > 0.3 时才开始显示额外控制按钮
                            final controlOpacity =
                                ((expandProgress - 0.3) / 0.7).clamp(0.0, 1.0);
                            final baseHeight = 120.0.w;
                            final actualHeight = baseHeight * controlOpacity;

                            return SizedBox(
                              height: actualHeight,
                              child: ClipRect(
                                child: OverflowBox(
                                  maxHeight: baseHeight,
                                  child: Opacity(
                                    opacity: controlOpacity,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 32.w,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          // 播放模式
                                          Obx(() {
                                            return IconButton(
                                              icon: switch (playmode.value) {
                                                0 => Icon(
                                                  Icons.repeat,
                                                  size: 32.w,
                                                ),
                                                1 => Icon(
                                                  Icons.shuffle,
                                                  size: 32.w,
                                                ),
                                                2 => Icon(
                                                  Icons.repeat_one,
                                                  size: 32.w,
                                                ),
                                                _ => Icon(
                                                  Icons.error,
                                                  size: 32.w,
                                                ),
                                              },
                                              onPressed: () =>
                                                  global_change_play_mode(),
                                            );
                                          }),

                                          // 上一曲
                                          IconButton(
                                            icon: Icon(
                                              Icons.skip_previous,
                                              size: 40.w,
                                            ),
                                            onPressed: () {
                                              // TODO: 实现上一曲功能
                                            },
                                          ),

                                          // 播放/暂停 - 中心按钮
                                          Container(
                                            width: 64.w,
                                            height: 64.w,
                                            decoration: BoxDecoration(
                                              color: Get.theme.primaryColor,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Obx(
                                              () => IconButton(
                                                icon: Icon(
                                                  _playController
                                                          .isplaying
                                                          .value
                                                      ? Icons.pause
                                                      : Icons.play_arrow,
                                                  color: Colors.white,
                                                  size: 36.w,
                                                ),
                                                onPressed: () {
                                                  if (_playController
                                                      .isplaying
                                                      .value) {
                                                    global_pause();
                                                  } else {
                                                    global_play();
                                                  }
                                                },
                                              ),
                                            ),
                                          ),

                                          // 下一曲
                                          IconButton(
                                            icon: Icon(
                                              Icons.skip_next,
                                              size: 40.w,
                                            ),
                                            onPressed: () {
                                              // TODO: 实现下一曲功能
                                            },
                                          ),

                                          // 播放列表
                                          Obx(
                                            () => Stack(
                                              children: [
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.playlist_play_rounded,
                                                    size: 32.w,
                                                  ),
                                                  onPressed: () {
                                                    Get.toNamed(
                                                      RouteName.nowPlayingPage,
                                                      id: 1,
                                                    );
                                                  },
                                                ),
                                                if (_playController
                                                    .current_playing
                                                    .isNotEmpty)
                                                  Positioned(
                                                    top: 0,
                                                    right: 0,
                                                    child: Container(
                                                      padding: EdgeInsets.all(
                                                        4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Get
                                                            .theme
                                                            .primaryColor,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Text(
                                                        '${_playController.current_playing.length}',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // 简化控制区 - 收起时显示
                        AnimatedBuilder(
                          animation: expandAnimation,
                          builder: (context, child) {
                            final expandProgress = expandAnimation.value.clamp(
                              0.0,
                              1.0,
                            );
                            // 当展开程度 < 0.3 时显示简化控制
                            final simpleOpacity = (1.0 - (expandProgress / 0.3))
                                .clamp(0.0, 1.0);

                            if (simpleOpacity <= 0.0) return SizedBox.shrink();

                            return Opacity(
                              opacity: simpleOpacity,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Obx(
                                      () => IconButton(
                                        icon: Icon(
                                          _playController.isplaying.value
                                              ? Icons.pause
                                              : Icons.play_arrow,
                                          size: 36.w,
                                        ),
                                        onPressed: () {
                                          if (_playController.isplaying.value) {
                                            global_pause();
                                          } else {
                                            global_play();
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  },
);
