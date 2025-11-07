part of 'lyric_page.dart';

class LyricVPage extends StatefulWidget {
  @override
  _LyricVPageState createState() => _LyricVPageState();
}

class _LyricVPageState extends State<LyricVPage>
    with TickerProviderStateMixin, LyricFormattingMixin {
  late LyricController lyricController;
  late PlayController playController;
  late SettingsController settingsController;

  // 歌词UI样式
  var lyricUI = UINetease();

  @override
  void initState() {
    super.initState();

    // 初始化控制器
    lyricController = Get.find<LyricController>();
    playController = Get.find<PlayController>();
    settingsController = Get.find<SettingsController>();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => lyricController.loadLyric(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 根据主题设置歌词UI样式
    lyricUI = _ThemedUINetease(
      defaultSize: 18,
      defaultExtSize: 14,
      otherMainSize: 16,
      lineGap: 25,
      inlineGap: 8,
      lyricAlign: LyricAlign.CENTER,
      highlightDirection: HighlightDirection.LTR,
      context: context,
    );

    return WillPopScope(
      onWillPop: () async {
        playController.sheetController.animateTo(
          playController.sheetMidOffset,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        return false;
      },
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(child: _buildLyricContent()),
              _buildTranslationToggle(context),
              IgnorePointer(child: SizedBox(height: 500.w)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLyricContent() {
    return Obx(() {
      // 监听翻译开关状态变化，确保UI能够响应
      settingsController.showLyricTranslation.value;

      if (lyricController.isLyricLoading.value) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              globalLoadingAnime,
              SizedBox(height: 16),
              Text('加载歌词中...'),
            ],
          ),
        );
      }

      if (!lyricController.hasLyric.value) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '暂无歌词',
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              SizedBox(height: 8),
            ],
          ),
        );
      }

      return Container(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: StreamBuilder<Duration>(
          stream: Get.find<PlayController>().music_player.positionStream,
          builder: (context, snapshot) {
            final position =
                snapshot.data ??
                Get.find<PlayController>().music_player.position;

            return LyricsReader(
              padding: EdgeInsets.symmetric(horizontal: 20),
              model: lyricController.lyricModel,
              position: position.inMilliseconds,
              lyricUi: lyricUI,
              playing: playController.isplaying.value,
              size: Size(double.infinity, MediaQuery.of(context).size.height),
              emptyBuilder: () => Center(
                child: Text('暂无歌词', style: lyricUI.getOtherMainTextStyle()),
              ),
              selectLineBuilder: (progress, confirm) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '跳转到: ${formatDuration(Duration(milliseconds: progress))}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Get.find<PlayController>()
                                .music_player
                                .seek(Duration(milliseconds: progress)),
                            child: Text('确定'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              onTap: () {
                // 点击歌词区域的处理
              },
            );
          },
        ),
      );
    });
  }

  Widget _buildTranslationToggle(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsetsGeometry.all(16.w),
        child: Obx(() {
          // 只有当有翻译歌词时才显示开关
          if (lyricController.translationLyric.value.isEmpty) {
            return SizedBox.shrink();
          }

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: () {
                  lyricController.toggleTranslation();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
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
                      SizedBox(width: 6),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        width: 36,
                        height: 20,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: settingsController.showLyricTranslation.value
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).disabledColor,
                        ),
                        child: AnimatedAlign(
                          duration: Duration(milliseconds: 200),
                          alignment:
                              settingsController.showLyricTranslation.value
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 16,
                            height: 16,
                            margin: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
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

  Widget _buildBackgroundCover(BuildContext context) {
    return Obx(() {
      PlayController playController = Get.find<PlayController>();
      final currentSong = playController.currentTrack.id.isNotEmpty
          ? playController.currentTrack
          : null;

      if (currentSong == null) {
        return ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
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
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Get.theme.scaffoldBackgroundColor,
          child: Obx(
            () => buildBlurredImage(
              currentSong.img_url ?? '',
              settingsController.lyricBackgroundBlurRadius,
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

  @override
  Widget build(BuildContext context) {
    final PlayController playController = Get.find<PlayController>();
    final SheetController sheetController = playController.sheetController;
    final SheetOffsetDrivenAnimation ani = SheetOffsetDrivenAnimation(
      controller: sheetController,
      initialValue: 0,
      startOffset: playController.sheetMidOffset,
      endOffset: playController.playVMaxOffset,
    );

    final double maxOffset = playController.playVMaxHeight;
    final double minOffset = playController.sheetMidHeight;
    final double radius = 20.w;
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
          child: child,
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
