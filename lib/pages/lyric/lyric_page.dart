import 'dart:convert';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_connect/http/src/utils/utils.dart';
import 'dart:ui' as ui;

import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/main.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';
import '../../controllers/lyric_controller.dart';
import '../../controllers/play_controller.dart';
import '../../controllers/settings_controller.dart';
import 'package:extended_image/extended_image.dart';

import '../../global_settings_animations.dart';
import '../../models/XLyricStyle.dart';
import '../../settings.dart';
import 'custom_side_sheet_type.dart';
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
    // WidgetsBinding.instance.addPostFrameCallback(
    //   (_) => lyricController.loadLyric(),
    // );

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
                    child: _buildLyricContent(context),
                  ),
                  // 翻译开关按钮
                  _buildTranslationToggle(context),
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        size: 28,
                      ),
                      onPressed: () {
                        Get.back(id: 1);
                      },
                    ),
                  ),
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
              settingsController.disableOpacityInLyricPage
                  ? 0
                  : settingsController.lyricBackgroundBlurRadius,
            ),
          ),
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
