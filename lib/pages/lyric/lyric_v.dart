part of 'lyric_page.dart';

class LyricVPage extends StatefulWidget {
  @override
  _LyricVPageState createState() => _LyricVPageState();
}

class _LyricVPageState extends State<LyricVPage> with TickerProviderStateMixin {
  late LyricController lyricController;
  late PlayController playController;
  late SettingsController settingsController;

  // 歌词UI样式
  var lyricUI = UINetease();

  // 背景颜色动画
  late AnimationController _backgroundController;
  late Animation<Color?> _backgroundAnimation;

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

    _backgroundController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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

    // 根据主题设置背景动画
    _backgroundAnimation = ColorTween(
      begin: theme.scaffoldBackgroundColor.withOpacity(0.3),
      end: theme.scaffoldBackgroundColor.withOpacity(isDark ? 0.8 : 0.9),
    ).animate(_backgroundController);

    return WillPopScope(
      onWillPop: () async {
        playController.sheetController.animateTo(
          playController.sheetMidOffset,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedBuilder(
          animation: _backgroundAnimation,
          builder: (context, child) {
            return Container(
              color: _backgroundAnimation.value,
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
                    child: Column(
                      children: [
                        Expanded(child: _buildLyricContent()),
                        _buildTranslationToggle(context),
                        SizedBox(height: 500.w),
                      ],
                    ),
                  ),
                  // 翻译开关按钮
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBackgroundCover(BuildContext context) {
    return Obx(() {
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExtendedImage.network(
                currentSong.img_url ?? '',
                fit: BoxFit.cover,
                cache: true,
                cacheMaxAge: const Duration(days: 365 * 4),
                loadStateChanged: (state) {
                  if (state.extendedImageLoadState == LoadState.failed) {
                    return Container(
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
                    );
                  }
                },
              ),
              // 高斯模糊效果
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  color: Theme.of(
                    context,
                  ).scaffoldBackgroundColor.withOpacity(0.2),
                ),
              ),
            ],
          ),
        ),
      );
    });
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
          stream: AudioService.position,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;

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
                        '跳转到: ${_formatDuration(Duration(milliseconds: progress))}',
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
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
