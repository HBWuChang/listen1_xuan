part of 'lyric_page.dart';

class LyricVPage extends StatefulWidget {
  @override
  _LyricVPageState createState() => _LyricVPageState();
}

class _LyricVPageState extends State<LyricVPage>
    with TickerProviderStateMixin, LyricFormattingMixin {
  @override
  void initState() {
    super.initState();

    // 初始化控制器
    // WidgetsBinding.instance.addPostFrameCallback(
    //   (_) => lyricController.loadLyric(),
    // );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        playController.sheetController.animateTo(
          playController.sheetMidOffset,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        return false;
      },
      child: Column(
        children: [
          Expanded(child: _buildLyricContent(context)),
          _buildTranslationToggle(context),
          IgnorePointer(child: SizedBox(height: 500.w)),
        ],
      ),
    );
  }

  Widget _buildTranslationToggle(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsetsGeometry.all(16.w),
        child: traBtn(context, settingsController, lyricController),
      ),
    );
  }
}

Widget traBtn(
  BuildContext context,
  SettingsController settingsController,
  XLyricController lyricController,
) => Material(
  color: Colors.transparent,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Obx(
        () =>
            isEmpty(lyricController.sLyricTra.value) ||
                !lyricController.hasLyric.value
            ? SizedBox.shrink()
            : IconButton(
                onPressed: lyricController.toggleTranslation,
                padding: EdgeInsets.zero,
                icon: Obx(
                  () => Text(
                    '译',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: settingsController.showLyricTranslation.value
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
      ),
      IconButton(
        onPressed: lyricController.toggledisableOpacity,
        onLongPress: () {
          Get.find<SettingsController>().disableOpacityInLyricPage = false;
          showLyricBackgroundBlurRadiusInputDialog(
            disableBackgroundShadow: true,
          );
        },
        padding: EdgeInsets.zero,
        icon: Obx(
          () => Icon(
            Icons.opacity_rounded,
            color: settingsController.disableOpacityInLyricPage
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
      ),
      Obx(
        () => !Get.find<PlayController>().currentTrack.id.startsWith('bi')
            ? SizedBox.shrink()
            : IconButton(
                onPressed: lyricController.findBilibiliLyric,
                padding: EdgeInsets.zero,
                icon: Icon(Icons.manage_search_rounded),
              ),
      ),
      _ExpandableMoreMenu(lyricController: lyricController),
    ],
  ),
);

class _ExpandableMoreMenu extends StatefulWidget {
  final XLyricController lyricController;

  const _ExpandableMoreMenu({Key? key, required this.lyricController})
    : super(key: key);

  @override
  __ExpandableMoreMenuState createState() => __ExpandableMoreMenuState();
}

class __ExpandableMoreMenuState extends State<_ExpandableMoreMenu> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isExpanded = true),
      onExit: (_) => setState(() => _isExpanded = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isExpanded) ...[
                  IconButton(
                    onPressed: () => showLyricStyleSettings(Get.context!),
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.text_format_rounded),
                  ),
                  IconButton(
                    onPressed: () {
                      WoltModalSheet.show(
                        context: Get.context!,
                        modalBarrierColor: Colors.transparent,
                        modalTypeBuilder: (modalSheetContext) =>
                            WoltModalType.bottomSheet(),
                        pageListBuilder: (modalSheetContext) {
                          return [
                            WoltModalSheetPage(
                              hasTopBarLayer: false,
                              isTopBarLayerAlwaysVisible: false,
                              enableDrag: true,
                              child: LyricDelayAdjuster(
                                lyricController: widget.lyricController,
                              ),
                            ),
                          ];
                        },
                        useRootNavigator: true,
                      );
                    },
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.av_timer_rounded),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            padding: EdgeInsets.zero,
            icon: Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
    );
  }
}

class LyricVBackPage extends StatefulWidget {
  @override
  _LyricVBackPageState createState() => _LyricVBackPageState();
}

class _LyricVBackPageState extends State<LyricVBackPage>
    with TickerProviderStateMixin, LyricBlurredBackgroundMixin {
  SettingsController settingsController = Get.find<SettingsController>();

  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return IgnorePointer(
      child: Stack(
        children: [
          // 背景封面和高斯模糊
          _buildBackgroundCover(context),
          // 前景内容
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor.withOpacity(
                isDark ? 0.15 : 0.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double lyricBorderRadius = Get.find<SettingsController>().lyricBorderRadius;

  Widget _buildBackgroundCover(BuildContext context) {
    return Obx(() {
      PlayController playController = Get.find<PlayController>();
      final currentSong = playController.currentTrack.id.isNotEmpty
          ? playController.currentTrack
          : null;

      if (currentSong == null) {
        return ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(lyricBorderRadius),
            topRight: Radius.circular(lyricBorderRadius),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.3),
                  Theme.of(context).scaffoldBackgroundColor,
                ],
              ),
            ),
          ),
        );
      }

      return ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(lyricBorderRadius),
          topRight: Radius.circular(lyricBorderRadius),
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Get.theme.scaffoldBackgroundColor,
          child: Obx(
            () => buildBlurredImage(
              currentSong.img_url ?? '',
              settingsController.disableOpacityInLyricPage
                  ? 0
                  : settingsController.lyricBackgroundBlurRadius,
            ),
          ),
        ),
      );
    });
  }
}

class SheetOffsetClip extends StatelessWidget {
  final Widget child;
  final bool type2;

  SheetOffsetClip({required this.child, this.type2 = false});
  double lyricBorderRadius = Get.find<SettingsController>().lyricBorderRadius;

  @override
  Widget build(BuildContext context) {
    final PlayController playController = Get.find<PlayController>();
    final SheetController sheetController = playController.sheetController;
    final SheetOffsetDrivenAnimation ani = type2
        ? SheetOffsetDrivenAnimation(
            controller: sheetController,
            initialValue: 0,
            startOffset: playController.sheetMidOffset,
            endOffset: playController.playVMaxOffset,
          )
        : SheetOffsetDrivenAnimation(
            controller: sheetController,
            initialValue: 0,
            startOffset: playController.sheetMinOffset,
            endOffset: playController.playVMaxOffset,
          );

    final double maxOffset = playController.playVMaxHeight;
    final double minOffset = type2
        ? playController.sheetMidHeight
        : playController.sheetMinHeight;
    final double radius = lyricBorderRadius;
    return AnimatedBuilder(
      animation: ani,
      builder: (context, _) {
        return ClipPath(
          clipper: type2
              ? MyClipper2(
                  height: (maxOffset - minOffset) * (1 - ani.value),
                  midHeight: minOffset * (1 - ani.value),
                  radius: radius,
                )
              : MyClipper(
                  height: (maxOffset - minOffset) * (1 - ani.value),
                  radius: radius,
                ),
          child: ani.value < 0.01
              ? Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: AdaptiveTheme.of(Get.context!).theme.cardColor,
                )
              : child,
        );
      },
    );
  }
}

// 7. 自定义 Clipper 类
// CustomClipper<Path> 告诉 Flutter 我们要裁剪的形状是一个 "Path"
class MyClipper extends CustomClipper<Path> {
  final double height;
  final double radius;

  MyClipper({required this.height, required this.radius});

  @override
  Path getClip(Size size) {
    // getClip 方法返回一个 Path 对象
    // 只有在这个 Path 内部的区域才会被显示

    // 创建一个新路径
    final path = Path();

    // // 如果 "A" 被移除了 (例如，位置设为 null 或移出屏幕)
    // // 我们可以返回一个空路径，这样 B 就完全不可见了
    // // if (position == null) {
    // //   return path; // 返回空路径，Stack变透明
    // // }

    // // 添加一个圆形路径，圆心在 "A" 的位置，半径为 _clipRadius
    // path.addOval(Rect.fromCircle(center: height, radius: radius));
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, height, 1.sw, 1.sh - height),
        Radius.circular(radius),
      ),
    );
    return path;
  }

  // 8. 决定是否需要重新裁剪
  // 当 "A" 的位置 (position) 改变时，我们需要重新计算裁剪区域
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    if (oldClipper is MyClipper) {
      return oldClipper.height != height || oldClipper.radius != radius;
    }
    return true; // 如果类型不同，总是重新裁剪
  }
}

// 7. 自定义 Clipper 类
// CustomClipper<Path> 告诉 Flutter 我们要裁剪的形状是一个 "Path"
class MyClipper2 extends CustomClipper<Path> {
  final double height;
  final double midHeight;
  final double radius;

  MyClipper2({
    required this.height,
    required this.midHeight,
    required this.radius,
  });

  @override
  Path getClip(Size size) {
    // getClip 方法返回一个 Path 对象
    // 只有在这个 Path 内部的区域才会被显示

    // 创建一个新路径
    final path = Path();

    // // 如果 "A" 被移除了 (例如，位置设为 null 或移出屏幕)
    // // 我们可以返回一个空路径，这样 B 就完全不可见了
    // // if (position == null) {
    // //   return path; // 返回空路径，Stack变透明
    // // }

    // // 添加一个圆形路径，圆心在 "A" 的位置，半径为 _clipRadius
    // path.addOval(Rect.fromCircle(center: height, radius: radius));
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, height, 1.sw, 1.sh - height - midHeight),
        Radius.circular(radius),
      ),
    );
    return path;
  }

  // 8. 决定是否需要重新裁剪
  // 当 "A" 的位置 (position) 改变时，我们需要重新计算裁剪区域
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    if (oldClipper is MyClipper) {
      return oldClipper.height != height || oldClipper.radius != radius;
    }
    return true; // 如果类型不同，总是重新裁剪
  }
}

/// 歌词延迟调整器
class LyricDelayAdjuster extends StatelessWidget {
  final XLyricController lyricController;

  const LyricDelayAdjuster({Key? key, required this.lyricController})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 当前歌曲延迟调整
          Obx(
            () => _DelaySliderItem(
              label: Text.rich(
                TextSpan(
                  text: '当前歌曲延迟',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    TextSpan(
                      text: '\n仅"歌曲替换列表"中的"源歌曲"可用',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              delayValue: lyricController.nowPlayingLyricDelay,
              theme: theme,
              enabled:
                  lyricController.hasLyric.value &&
                  Get.find<PlayController>().nowPlayingTrackHasReplaceTrack,
            ),
          ),

          SizedBox(height: 12),
          // 全局延迟调整
          _DelaySliderItem(
            label: Text(
              '全局歌词延迟',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            delayValue: lyricController.globalLyricDelay,
            theme: theme,
            enabled: true,
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// 延迟滑块项
class _DelaySliderItem extends StatefulWidget {
  final Widget label;
  final RxDouble delayValue;
  final ThemeData theme;
  final bool enabled;

  const _DelaySliderItem({
    Key? key,
    required this.label,
    required this.delayValue,
    required this.theme,
    required this.enabled,
  }) : super(key: key);

  @override
  State<_DelaySliderItem> createState() => _DelaySliderItemState();
}

class _DelaySliderItemState extends State<_DelaySliderItem> {
  // 滑块的临时偏移值（范围 -2.5 到 2.5）
  double _tempOffset = 0.0;
  // 拖动开始时的原始值
  double _startValue = 0.0;

  void _onChangeStart(double value) {
    _startValue = widget.delayValue.value;
    _tempOffset = 0.0;
  }

  void _onChanged(double value) {
    // 实时更新控制器的值
    widget.delayValue.value = _startValue + value;
    setState(() {
      _tempOffset = value;
    });
  }

  void _onChangeEnd(double value) {
    // 调整结束，滑块归中
    setState(() {
      _tempOffset = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final actualValue = widget.delayValue.value;
      final totalDelay = actualValue;

      return Opacity(
        opacity: widget.enabled ? 1.0 : 0.5,
        child: AbsorbPointer(
          absorbing: !widget.enabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标签和当前值显示
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  widget.label,
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${totalDelay >= 0 ? '+' : ''}${totalDelay.toStringAsFixed(2)}s',
                      style: widget.theme.textTheme.bodyMedium?.copyWith(
                        color: widget.theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              // 滑块
              Row(
                children: [
                  // 左侧标签（-2.5s）
                  Text(
                    '-2.5s',
                    style: widget.theme.textTheme.bodySmall?.copyWith(
                      color: widget.theme.textTheme.bodySmall?.color
                          ?.withOpacity(0.6),
                    ),
                  ),
                  // 滑块
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        overlayShape: RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                        activeTrackColor: widget.theme.colorScheme.primary,
                        inactiveTrackColor: widget.theme.colorScheme.primary
                            .withOpacity(0.3),
                        thumbColor: widget.theme.colorScheme.primary,
                        overlayColor: widget.theme.colorScheme.primary
                            .withOpacity(0.2),
                        disabledThumbColor: widget.theme.disabledColor,
                        disabledActiveTrackColor: widget.theme.disabledColor
                            .withOpacity(0.3),
                        disabledInactiveTrackColor: widget.theme.disabledColor
                            .withOpacity(0.1),
                      ),
                      child: Slider(
                        value: _tempOffset,
                        min: -2.5,
                        max: 2.5,
                        divisions: 500, // 0.01秒精度
                        onChangeStart: _onChangeStart,
                        onChanged: widget.enabled ? _onChanged : null,
                        onChangeEnd: _onChangeEnd,
                      ),
                    ),
                  ),
                  // 右侧标签（+2.5s）
                  Text(
                    '+2.5s',
                    style: widget.theme.textTheme.bodySmall?.copyWith(
                      color: widget.theme.textTheme.bodySmall?.color
                          ?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              // 中心指示器
              Center(
                child: Container(
                  width: 2,
                  height: 8,
                  margin: EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: _tempOffset.abs() < 0.05
                        ? widget.theme.colorScheme.primary
                        : widget.theme.dividerColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
