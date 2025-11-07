import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:flutter_lyric/lyrics_reader_widget.dart';
import 'dart:ui' as ui;

import 'package:flutter_lyric/lyric_ui/lyric_ui.dart';
import 'package:flutter_lyric/lyric_ui/ui_netease.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import '../../controllers/lyric_controller.dart';
import '../../controllers/play_controller.dart';
import '../../controllers/settings_controller.dart';
import 'package:extended_image/extended_image.dart';

import '../../global_settings_animations.dart';
part 'lyric_v.dart';
part 'lyric_shared.dart';

class LyricPage extends StatefulWidget {
  @override
  _LyricPageState createState() => _LyricPageState();
}

class _LyricPageState extends State<LyricPage>
    with TickerProviderStateMixin, LyricBlurredBackgroundMixin, LyricFormattingMixin {
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
        Get.back(id: 1);
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
                        _buildHeader(context),
                        Expanded(child: _buildLyricContent()),
                      ],
                    ),
                  ),
                  // 翻译开关按钮
                  _buildTranslationToggle(context),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: Theme.of(context).textTheme.bodyLarge?.color,
              size: 28,
            ),
            onPressed: () {
              Get.back(id: 1);
            },
          ),
          Expanded(
            child: Obx(() {
              final currentSong = playController.currentTrack.id.isNotEmpty
                  ? playController.currentTrack
                  : null;

              return Column(
                children: [
                  Text(
                    currentSong?.title ?? '未知歌曲',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    currentSong?.artist ?? '未知艺术家',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            }),
          ),
          SizedBox(width: 48), // 平衡左侧的IconButton
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
    return Obx(() {
      // 只有当有翻译歌词时才显示开关
      if (lyricController.translationLyric.value.isEmpty) {
        return SizedBox.shrink();
      }

      return Positioned(
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 80,
        child: Container(
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
                        alignment: settingsController.showLyricTranslation.value
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
        ),
      );
    });
  }
}

// 主题化的歌词UI类
class _ThemedUINetease extends UINetease {
  final BuildContext context;

  _ThemedUINetease({
    required this.context,
    double defaultSize = 18,
    double defaultExtSize = 14,
    double otherMainSize = 16,
    double lineGap = 25,
    double inlineGap = 8,
    LyricAlign lyricAlign = LyricAlign.CENTER,
    HighlightDirection highlightDirection = HighlightDirection.LTR,
  }) : super(
         defaultSize: defaultSize,
         defaultExtSize: defaultExtSize,
         otherMainSize: otherMainSize,
         lineGap: lineGap,
         inlineGap: inlineGap,
         lyricAlign: lyricAlign,
         highlightDirection: highlightDirection,
       );

  @override
  TextStyle getPlayingMainTextStyle() {
    final theme = Theme.of(context);
    return TextStyle(
      color: theme.colorScheme.primary,
      fontSize: defaultSize,
      fontWeight: FontWeight.w600,
    );
  }

  @override
  TextStyle getOtherMainTextStyle() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return TextStyle(
      color:
          theme.textTheme.bodyLarge?.color?.withOpacity(isDark ? 0.8 : 0.7) ??
          (isDark ? Colors.white70 : Colors.black54),
      fontSize: otherMainSize,
    );
  }

  @override
  TextStyle getPlayingExtTextStyle() {
    final theme = Theme.of(context);
    return TextStyle(
      color: theme.colorScheme.primary.withOpacity(0.7),
      fontSize: defaultExtSize,
    );
  }

  @override
  TextStyle getOtherExtTextStyle() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return TextStyle(
      color:
          theme.textTheme.bodyMedium?.color?.withOpacity(isDark ? 0.6 : 0.5) ??
          (isDark ? Colors.white60 : Colors.black45),
      fontSize: defaultExtSize,
    );
  }

  @override
  Color getLyricHightlightColor() {
    final theme = Theme.of(context);
    return theme.colorScheme.primaryFixed.withAlpha(200);
  }
}
