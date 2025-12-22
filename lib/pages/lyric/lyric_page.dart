import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'dart:ui' as ui;

import 'package:listen1_xuan/funcs.dart';
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
    with
        TickerProviderStateMixin,
        LyricBlurredBackgroundMixin,
        LyricFormattingMixin {
  late XLyricController lyricController;
  late PlayController playController;
  late SettingsController settingsController;

  // 背景颜色动画
  late AnimationController _backgroundController;
  late Animation<Color?> _backgroundAnimation;

  @override
  void initState() {
    super.initState();

    // 初始化控制器
    lyricController = Get.find<XLyricController>();
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

  // 创建主题化的歌词样式
  LyricStyle _createThemedLyricStyle(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LyricStyle(
      textStyle: TextStyle(
        fontSize: 16,
        color:
            theme.textTheme.bodyLarge?.color?.withOpacity(isDark ? 0.8 : 0.7) ??
            (isDark ? Colors.white70 : Colors.black54),
      ),
      activeStyle: TextStyle(
        fontSize: 18,
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
      translationStyle: TextStyle(
        fontSize: 14,
        color:
            theme.textTheme.bodyMedium?.color?.withOpacity(
              isDark ? 0.6 : 0.5,
            ) ??
            (isDark ? Colors.white60 : Colors.black45),
      ),
      translationActiveColor: theme.colorScheme.primary.withOpacity(0.7),
      lineTextAlign: TextAlign.center,
      lineGap: 25,
      translationLineGap: 8,
      contentAlignment: CrossAxisAlignment.center,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      selectionAnchorPosition: 0.48,
      fadeRange: FadeRange(top: 80, bottom: 80),
      selectedColor: theme.colorScheme.primary,
      selectedTranslationColor: theme.colorScheme.primary.withOpacity(0.7),
      scrollDuration: Duration(milliseconds: 240),
      scrollDurations: {
        500: Duration(milliseconds: 500),
        1000: Duration(milliseconds: 1000),
      },
      enableSwitchAnimation: false,
      selectionAutoResumeMode: SelectionAutoResumeMode.selecting,
      selectionAutoResumeDuration: Duration(milliseconds: 320),
      activeAutoResumeDuration: Duration(milliseconds: 3000),
      activeHighlightColor: theme.colorScheme.primaryFixed.withAlpha(200),
      switchEnterDuration: Duration(milliseconds: 300),
      switchExitDuration: Duration(milliseconds: 500),
      switchEnterCurve: Curves.easeOutBack,
      switchExitCurve: Curves.easeOutQuint,
      selectionAlignment: MainAxisAlignment.center,
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

  double lyricBorderRadius = Get.find<SettingsController>().lyricBorderRadius;
  Widget _buildBackgroundCover(BuildContext context) {
    return Obx(() {
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
        child: LyricView(
          controller: lyricController.lyricController,
          style: _createThemedLyricStyle(context),
        ),
      );
    });
  }

  Widget _buildTranslationToggle(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.only(
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 80,
        ),
        child: traBtn(context, settingsController, lyricController),
      ),
    );
  }
}
