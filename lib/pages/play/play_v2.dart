part of '../../play.dart';

Widget get playV2 => LayoutBuilder(
  builder: (context, boxConstraints) {
    _playController.playVMaxHeight = boxConstraints.maxHeight;

    final expandAnimationStage2Rate =
        _playController.playVMaxHeight - _playController.sheetMidHeight;

    return SizedBox(
      height: _playController.playVMaxHeight,

      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 1.sh,
            child: Obx(
              () => Visibility(
                visible: _playController.showPlayVInlineLyricVisible.value,
                child: SheetOffsetClip(child: LyricVBackPage()),
              ),
            ),
          ),
          Positioned.fill(
            child: SheetViewport(
              child: Sheet(
                controller: _playController.sheetController,
                initialOffset: SheetOffset(
                  _playController.sheetMinHeight /
                      _playController.playVMaxHeight,
                ),
                snapGrid: SheetSnapGrid(
                  snaps: [
                    SheetOffset(
                      _playController.sheetMinHeight /
                          _playController.playVMaxHeight,
                    ),
                    SheetOffset(
                      _playController.sheetMidHeight /
                          _playController.playVMaxHeight,
                    ),
                    SheetOffset(1.0),
                  ],
                ),
                child: Obx(
                  () => AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: _playController.playVMaxHeight,
                    clipBehavior: Clip.none,
                    decoration: BoxDecoration(
                      color: _playController.showPlayVInlineLyricOp.value
                          ? AdaptiveTheme.of(
                              Get.context!,
                            ).theme.cardColor.withAlpha(0)
                          : AdaptiveTheme.of(Get.context!).theme.cardColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
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
                              ((currentOffset - minOffset) /
                                      (maxOffset - minOffset))
                                  .clamp(0.0, 1.0);
                          _playController.sheetExpandRatio.value = ratio;
                        }
                        return false;
                      },
                      child: Builder(
                        builder: (context) {
                          // 获取 Sheet 位置驱动的动画
                          final sheetController =
                              _playController.sheetController;
                          final expandAnimationStage1 =
                              SheetOffsetDrivenAnimation(
                                controller: sheetController,
                                initialValue: 0,
                                startOffset: _playController.sheetMinOffset,
                                endOffset: _playController.sheetMidOffset,
                              );
                          final expandAnimationStage2 =
                              SheetOffsetDrivenAnimation(
                                controller: sheetController,
                                initialValue: 0,
                                startOffset: _playController.sheetMidOffset,
                                endOffset: _playController.playVMaxOffset,
                              );
                          expandAnimationStage2.addListener(() {
                            if (expandAnimationStage2.value >= 0.5) {
                              _playController
                                      .showPlayVInlineLyricVisible
                                      .value =
                                  true;
                            } else {
                              _playController.showPlayVInlineLyricOp.value =
                                  false;
                            }
                          });
                          return
                          // 封面和信息区域 - 使用 Stack 和 AnimatedPositioned 实现位置过渡
                          AnimatedBuilder(
                            animation: expandAnimationStage1,
                            builder: (context, child) {
                              final expandProgress = expandAnimationStage1.value
                                  .clamp(0.0, 1.0);

                              // 使用 LayoutBuilder 获取可用宽度并计算所有尺寸和位置
                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  final availableWidth = constraints.maxWidth;

                                  // ==================== 阶段1动画参数配置 ====================

                                  // 曲线定义
                                  final sizeCurve = Curves.easeOutCubic;
                                  final coverPositionCurve = Curves.easeInCubic;
                                  final infoPositionCurve =
                                      Curves.easeInOutCubic;
                                  final infoTopCurve = Curves.easeOutCubic;
                                  final controlPositionCurve = Curves.ease;
                                  final controlOpacityCurve = Curves.easeInQuad;

                                  // 封面尺寸
                                  final coverMinSize = 168.w;
                                  final coverMaxSize = 348.w; // 168.w + 180.w
                                  final sizeProgress = sizeCurve.transform(
                                    expandProgress,
                                  );
                                  final coverSize =
                                      coverMinSize +
                                      (coverMaxSize - coverMinSize) *
                                          sizeProgress;

                                  // 字体大小
                                  final titleMinSize = 16.0 * 3.sp;
                                  final titleMaxSize =
                                      20.0 * 3.sp; // 16.0 + 4.0
                                  final titleSize =
                                      titleMinSize +
                                      (titleMaxSize - titleMinSize) *
                                          expandProgress;

                                  final artistMinSize = 14.0 * 3.sp;
                                  final artistMaxSize =
                                      16.0 * 3.sp; // 14.0 + 2.0
                                  final artistSize =
                                      artistMinSize +
                                      (artistMaxSize - artistMinSize) *
                                          expandProgress;

                                  // 控制按钮透明度
                                  final opacityProgress = controlOpacityCurve
                                      .transform(expandProgress);
                                  final controlOpacity =
                                      (1.0 - opacityProgress * 3).clamp(
                                        0.0,
                                        1.0,
                                      );

                                  // 封面位置
                                  final collapsedCoverLeft = 44.w;
                                  final expandedCoverLeft =
                                      (availableWidth - coverSize) / 2;
                                  final coverProgress = coverPositionCurve
                                      .transform(expandProgress);
                                  final coverLeft =
                                      collapsedCoverLeft +
                                      (expandedCoverLeft - collapsedCoverLeft) *
                                          coverProgress;
                                  final handleMinHeight = 44.w;
                                  final handleMaxHeight =
                                      expandAnimationStage2Rate;

                                  final handleHeight =
                                      handleMinHeight +
                                      (handleMaxHeight - handleMinHeight) *
                                          expandAnimationStage2.value;
                                  // 信息区域位置
                                  final collapsedInfoLeft =
                                      collapsedCoverLeft + coverSize + 12.w;
                                  final expandedInfoLeft = 16.w;
                                  final infoProgress = infoPositionCurve
                                      .transform(expandProgress);
                                  final infoLeft =
                                      collapsedInfoLeft * (1.0 - infoProgress) +
                                      expandedInfoLeft * infoProgress;

                                  // 信息区域垂直位置
                                  final collapsedInfoTop = 0.0;
                                  final expandedInfoTop =
                                      coverSize + 16.w + 24.w + handleHeight;
                                  final infoTopProgress = infoTopCurve
                                      .transform(expandProgress);
                                  final infoTop =
                                      collapsedInfoTop *
                                          (1.0 - infoTopProgress) +
                                      expandedInfoTop * infoTopProgress +
                                      handleMinHeight;

                                  // 控制按钮位置
                                  final shrinkControlTop =
                                      (coverSize - controlButtonSize) / 2 +
                                      handleMinHeight;
                                  final expandedControlTop =
                                      expandedInfoTop + 200.w;
                                  final controlTopProgress =
                                      controlPositionCurve.transform(
                                        expandProgress,
                                      );
                                  final controlTop =
                                      shrinkControlTop *
                                          (1.0 - controlTopProgress) +
                                      expandedControlTop * controlTopProgress;

                                  // 控制按钮宽度
                                  final collapsedControlRight = 16.0.w;
                                  final collapsedControlWidth =
                                      controlButtonSize * 2 + 16.w;
                                  final expandedControlWidth = 1200.w;
                                  final controlEased = Curves.ease.transform(
                                    expandProgress,
                                  );
                                  final controlWidth =
                                      collapsedControlWidth +
                                      (expandedControlWidth -
                                              collapsedControlWidth) *
                                          controlEased;

                                  final collapsedControlLeft =
                                      availableWidth -
                                      collapsedControlRight -
                                      collapsedControlWidth;
                                  final expandedControlLeft =
                                      (availableWidth - controlWidth) / 2;
                                  final controlLeft =
                                      collapsedControlLeft *
                                          (1 - controlEased) +
                                      expandedControlLeft * controlEased;

                                  final collapsedInfoRight =
                                      collapsedControlWidth;
                                  final expandedInfoRight = 16.w;
                                  final infoRight =
                                      collapsedInfoRight *
                                          (1.0 - infoProgress) +
                                      expandedInfoRight * infoProgress;

                                  // 进度条位置
                                  final sliderTop =
                                      infoTop + 200.w + controlButtonSize;

                                  // 封面圆角
                                  final coverBorderRadius =
                                      8 +
                                      8 *
                                          Curves.easeInOutCubic.transform(
                                            expandProgress,
                                          );

                                  // 总高度计算
                                  final totalHeight =
                                      (expandProgress < 0.5
                                          ? coverSize
                                          : coverSize +
                                                expandedInfoTop +
                                                80.w * expandProgress) +
                                      handleHeight;

                                  // ==================== 阶段1动画参数配置结束 ====================

                                  return
                                  // 主内容区域
                                  SizedBox(
                                    width: availableWidth,
                                    height: totalHeight,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned.fill(
                                          child: ClipPath(
                                            clipper: InvertedRectClipper(
                                              borderRadius: BorderRadius.all(
                                                Radius.circular(16),
                                              ),
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Get.theme.shadowColor
                                                        .withOpacity(0.2),
                                                    blurRadius: 5,
                                                    offset: Offset(0, -5),
                                                    spreadRadius: 2.5,
                                                  ),
                                                ],
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(16),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        sheetHandle,

                                        // 封面 - 在第二阶段动画中逐渐隐藏
                                        AnimatedBuilder(
                                          animation: expandAnimationStage2,
                                          builder: (context, child) {
                                            final stage2Progress =
                                                expandAnimationStage2.value
                                                    .clamp(0.0, 1.0);

                                            // ==================== 阶段2封面透明度配置 ====================
                                            final coverOpacityCurve =
                                                Curves.linear;
                                            final coverOpacity =
                                                (1.0 -
                                                        coverOpacityCurve
                                                            .transform(
                                                              stage2Progress,
                                                            ))
                                                    .clamp(0.0, 1.0);
                                            // ==================== 阶段2封面透明度配置结束 ====================

                                            return Positioned(
                                              left: coverLeft,
                                              top: handleMinHeight,
                                              child: Opacity(
                                                opacity: coverOpacity,
                                                child: buildCoverImage(
                                                  coverSize,
                                                  borderRadius:
                                                      coverBorderRadius,
                                                ),
                                              ),
                                            );
                                          },
                                        ),

                                        // 歌曲信息
                                        Positioned(
                                          left: infoLeft,
                                          right: infoRight,
                                          top: infoTop,
                                          child: buildSongInfo(
                                            titleSize: titleSize,
                                            artistSize: artistSize,
                                            isCollapsed: expandProgress < 0.5,
                                          ),
                                        ),

                                        // 控制按钮
                                        Positioned(
                                          left: controlLeft,
                                          top: controlTop,
                                          width: controlWidth,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              SizedBoxWithOverflow.processMaxSizeDir(
                                                maxSize: controlButtonSize,
                                                process: expandProgress,
                                                child: showVolumeSliderBtn,
                                              ),
                                              SizedBoxWithOverflow.processMaxSizeDir(
                                                maxSize: controlButtonSize,
                                                process: expandProgress,
                                                child: playModeButton,
                                              ),
                                              SizedBoxWithOverflow.processMaxSizeDir(
                                                maxSize: controlButtonSize,
                                                process: expandProgress,
                                                child: buildPreviousButton(),
                                              ),
                                              buildPlayPauseButton(
                                                expandProgress,
                                              ),
                                              SizedBoxWithOverflow.processMaxSizeDir(
                                                maxSize: controlButtonSize,
                                                process: expandProgress,
                                                child: buildNextButton(),
                                              ),
                                              buildPlaylistButton,
                                              SizedBoxWithOverflow.processMaxSizeDir(
                                                maxSize: controlButtonSize,
                                                process: expandProgress,
                                                child: songDialogBtn,
                                              ),
                                            ],
                                          ),
                                        ),

                                        // 进度条
                                        Positioned(
                                          top: sliderTop,
                                          left: 0,
                                          right: 0,
                                          child: positionSlider,
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
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 1.sh,
            child: Obx(
              () => Visibility(
                visible: _playController.showPlayVInlineLyricVisible.value,
                child: IgnorePointer(
                  ignoring: !_playController.showPlayVInlineLyricOp.value,
                  child: SheetOffsetClip(type2: true, child: LyricVPage()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  },
);
