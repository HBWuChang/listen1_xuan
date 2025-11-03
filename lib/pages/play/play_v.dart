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
                    playModeButton,
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
                        // 封面和信息区域 - 使用 Stack 和 AnimatedPositioned 实现位置过渡
                        AnimatedBuilder(
                          animation: expandAnimation,
                          builder: (context, child) {
                            final expandProgress = expandAnimation.value.clamp(
                              0.0,
                              1.0,
                            );

                            // 封面尺寸从 120.w 变化到 300.w，使用 easeOutCubic 让尺寸变化更流畅
                            final sizeProgress = Curves.easeOutCubic.transform(
                              expandProgress,
                            );
                            final coverSize = 120.w + (180.w * sizeProgress);

                            // 字体大小变化，使用线性过渡
                            final titleSize = 16.0 + (4.0 * expandProgress);
                            final artistSize = 14.0 + (2.0 * expandProgress);

                            // 控制按钮透明度：收起时显示，展开时隐藏，使用更快的淡出
                            final opacityProgress = Curves.easeInQuad.transform(
                              expandProgress,
                            );
                            final controlOpacity = (1.0 - opacityProgress * 3)
                                .clamp(0.0, 1.0);

                            return StreamBuilder<MediaItem?>(
                              stream: Get.find<AudioHandlerController>()
                                  .audioHandler
                                  .mediaItem,
                              builder: (context, snapshot) {
                                final mediaItem = snapshot.data;

                                // 使用 LayoutBuilder 获取可用宽度
                                return LayoutBuilder(
                                  builder: (context, constraints) {
                                    final availableWidth = constraints.maxWidth;

                                    // 计算各元素在收起状态下的位置
                                    final collapsedCoverLeft = 16.0.w;
                                    final collapsedInfoLeft =
                                        collapsedCoverLeft + coverSize + 12.w;
                                    final collapsedControlRight = 16.0.w;

                                    // 计算各元素在展开状态下的位置
                                    final expandedCoverLeft =
                                        (availableWidth - coverSize) / 2;
                                    final expandedInfoTop =
                                        coverSize + 16.w + 24.w;

                                    // 使用 lerp 计算当前位置，应用缓动曲线
                                    // 使用 easeInCubic 曲线：开始慢，后期快
                                    final coverProgress = Curves.easeInCubic
                                        .transform(expandProgress);
                                    final coverLeft =
                                        collapsedCoverLeft +
                                        (expandedCoverLeft -
                                                collapsedCoverLeft) *
                                            coverProgress;

                                    // 信息区域使用不同的缓动曲线，实现更平滑的过渡
                                    final infoProgress = Curves.easeInOutCubic
                                        .transform(expandProgress);
                                    final infoLeft =
                                        collapsedInfoLeft *
                                            (1.0 - infoProgress) +
                                        16.w * infoProgress;
                                    final infoRight =
                                        (16.w + 120.w * controlOpacity) *
                                            (1.0 - infoProgress) +
                                        16.w * infoProgress;

                                    // 信息区域从水平居左变为垂直居中，使用 easeOut 让最终位置更快到达
                                    final infoTopProgress = Curves.easeOutCubic
                                        .transform(expandProgress);
                                    final infoTop =
                                        0.0 * (1.0 - infoTopProgress) +
                                        expandedInfoTop * infoTopProgress;

                                    // 控制按钮的垂直位置，保持在封面中心
                                    final controlTopProgress = Curves
                                        .easeInCubic
                                        .transform(expandProgress);
                                    final controlTop =
                                        ((coverSize - 48.w) / 2) *
                                            (1.0 - controlTopProgress) +
                                        (coverSize / 2) * controlTopProgress;

                                    // 计算总高度
                                    final totalHeight = expandProgress < 0.5
                                        ? coverSize
                                        : coverSize +
                                              expandedInfoTop +
                                              80.w * expandProgress;

                                    return SizedBox(
                                      height: totalHeight,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          // 封面 - 使用 AnimatedPositioned
                                          AnimatedPositioned(
                                            duration: Duration
                                                .zero, // 由 expandAnimation 驱动，所以这里设为 zero
                                            left: coverLeft,
                                            top: 0,
                                            child: buildCoverImage(
                                              mediaItem,
                                              coverSize,
                                              borderRadius:
                                                  8 +
                                                  8 *
                                                      Curves.easeInOutCubic
                                                          .transform(
                                                            expandProgress,
                                                          ),
                                            ),
                                          ),

                                          // 歌曲信息 - 使用 AnimatedPositioned
                                          AnimatedPositioned(
                                            duration: Duration.zero,
                                            left: infoLeft,
                                            right: infoRight,
                                            top: infoTop,
                                            child: buildSongInfo(
                                              mediaItem: mediaItem,
                                              titleSize: titleSize,
                                              artistSize: artistSize,
                                              isCollapsed: expandProgress < 0.5,
                                            ),
                                          ),

                                          // 右侧控制按钮 - 只在收起时显示
                                          if (controlOpacity > 0.01)
                                            AnimatedPositioned(
                                              duration: Duration.zero,
                                              right: collapsedControlRight,
                                              top: controlTop, // 使用计算的垂直位置
                                              child: Opacity(
                                                opacity: controlOpacity,
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (controlOpacity > 0.5)
                                                      buildPlayPauseButton,
                                                    if (controlOpacity > 0.5)
                                                      buildPlaylistButton(
                                                        size: 28.w,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
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
                                          playModeButton,

                                          // 上一曲
                                          buildPreviousButton(),

                                          // 播放/暂停 - 中心按钮
                                          buildPlayPauseButton,

                                          // 下一曲
                                          buildNextButton(),

                                          // 播放列表
                                          buildPlaylistButton(size: 32.w),
                                        ],
                                      ),
                                    ),
                                  ),
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
