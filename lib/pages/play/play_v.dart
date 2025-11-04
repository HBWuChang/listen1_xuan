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

    final expandAnimationStage2Rate =
        _playController.playVMaxHeight - _playController.sheetMidHeight;
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
                  final expandAnimationStage1 = SheetOffsetDrivenAnimation(
                    controller: sheetController,
                    initialValue: 0,
                    startOffset: _playController.sheetMinOffset,
                    endOffset: _playController.sheetMidOffset,
                  );
                  final expandAnimationStage2 = SheetOffsetDrivenAnimation(
                    controller: sheetController,
                    initialValue: 0,
                    startOffset: _playController.sheetMidOffset,
                    endOffset: _playController.playVMaxOffset,
                  );
                  return Column(
                    children: [
                      // 封面和信息区域 - 使用 Stack 和 AnimatedPositioned 实现位置过渡
                      AnimatedBuilder(
                        animation: expandAnimationStage1,
                        builder: (context, child) {
                          final expandProgress = expandAnimationStage1.value
                              .clamp(0.0, 1.0);

                          final sizeProgress = Curves.easeOutCubic.transform(
                            expandProgress,
                          );
                          final coverSize = 168.w + (180.w * sizeProgress);

                          // 字体大小变化，使用线性过渡
                          final titleSize =
                              (16.0 + (4.0 * expandProgress)) * 3.sp;
                          final artistSize =
                              (14.0 + (2.0 * expandProgress)) * 3.sp;

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
                                  final collapsedCoverLeft = 44.w;
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
                                      (expandedCoverLeft - collapsedCoverLeft) *
                                          coverProgress;

                                  // 信息区域使用不同的缓动曲线，实现更平滑的过渡
                                  final infoProgress = Curves.easeInOutCubic
                                      .transform(expandProgress);
                                  final infoLeft =
                                      collapsedInfoLeft * (1.0 - infoProgress) +
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
                                  final shrinkControlTop =
                                      (coverSize - controlButtonSize) / 2;
                                  final expandedControlTop =
                                      expandedInfoTop + 200.w;
                                  // 控制按钮的垂直位置，保持在封面中心
                                  final controlTopProgress = Curves.ease
                                      .transform(expandProgress);
                                  final controlTop =
                                      shrinkControlTop *
                                          (1.0 - controlTopProgress) +
                                      expandedControlTop * controlTopProgress;

                                  // 计算总高度
                                  final totalHeight = expandProgress < 0.5
                                      ? coverSize
                                      : coverSize +
                                            expandedInfoTop +
                                            80.w * expandProgress;

                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedBuilder(
                                        animation: expandAnimationStage2,
                                        builder: (context, child) {
                                          return SizedBox(
                                            height:
                                                44.w +
                                                (expandAnimationStage2Rate -
                                                        44.w) *
                                                    expandAnimationStage2.value,
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: Align(
                                                    alignment:
                                                        Alignment.topCenter,
                                                    child: sheetHandle,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                      SizedBox(
                                        width: availableWidth,
                                        height: totalHeight,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            // 封面 - 使用 AnimatedPositioned
                                            Positioned(
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
                                            Positioned(
                                              left: infoLeft,
                                              right: infoRight,
                                              top: infoTop,
                                              child: buildSongInfo(
                                                mediaItem: mediaItem,
                                                titleSize: titleSize,
                                                artistSize: artistSize,
                                                isCollapsed:
                                                    expandProgress < 0.5,
                                              ),
                                            ),

                                            // 统一控制按钮：合并“右侧控制按钮”和“控制按钮区域”。
                                            // 使用 Positioned + AnimatedBuilder 在收起/展开状态之间切换布局。
                                            AnimatedBuilder(
                                              animation: expandAnimationStage1,
                                              builder: (context, _) {
                                                final expandProgress =
                                                    expandAnimationStage1.value
                                                        .clamp(0.0, 1.0);
                                                final eased = Curves.ease
                                                    .transform(expandProgress);

                                                // widths for collapsed and expanded states
                                                final double collapsedWidth =
                                                    controlButtonSize * 2 +
                                                    16.w;
                                                final double expandedWidth =
                                                    1000.w;
                                                final double childWidth =
                                                    collapsedWidth +
                                                    (expandedWidth -
                                                            collapsedWidth) *
                                                        eased;

                                                // compute target left positions
                                                final double collapsedLeft =
                                                    availableWidth -
                                                    collapsedControlRight -
                                                    collapsedWidth;
                                                // infoRight is the 'right' constraint of info; info's right edge = availableWidth - infoRight
                                                final double expandedLeft =
                                                    (availableWidth -
                                                        childWidth) /
                                                    2; // small gap

                                                // interpolate left position from collapsed to expanded
                                                final double left =
                                                    collapsedLeft *
                                                        (1 - eased) +
                                                    expandedLeft * eased;
                                                final perSize =
                                                    controlButtonSize;

                                                return Positioned(
                                                  left: left,
                                                  top: controlTop,
                                                  width: childWidth,
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceEvenly,
                                                    children: [
                                                      // show compact items when nearly collapsed
                                                      SizedBoxWithOverflow.processMaxSizeDir(
                                                        maxSize: perSize,
                                                        process: expandProgress,
                                                        child: playModeButton,
                                                      ),
                                                      SizedBoxWithOverflow.processMaxSizeDir(
                                                        maxSize: perSize,
                                                        process: expandProgress,
                                                        child:
                                                            buildPreviousButton(),
                                                      ),

                                                      buildPlayPauseButton(
                                                        expandProgress,
                                                      ),
                                                      SizedBoxWithOverflow.processMaxSizeDir(
                                                        maxSize: perSize,
                                                        process: expandProgress,
                                                        child:
                                                            buildNextButton(),
                                                      ),
                                                      buildPlaylistButton,
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                            Positioned(
                                              top:
                                                  infoTop +
                                                  200.w +
                                                  controlButtonSize,
                                              left: 0,
                                              right: 0,
                                              child: positionSlider,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                      // 控制按钮已合并到上方的 Positioned + AnimatedBuilder 中
                    ],
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
