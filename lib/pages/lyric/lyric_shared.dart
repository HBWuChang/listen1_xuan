part of 'lyric_page.dart';

/// 歌词页面共享功能的 Mixin
/// 提供模糊背景图片和失败时的渐变背景构建方法
mixin LyricBlurredBackgroundMixin<T extends StatefulWidget> on State<T> {
  // 缓存模糊后的图像，key 格式: "url_blurRadius"
  final Map<String, ui.Image> _blurredImageCache = {};
  // 正在处理中的任务，避免重复处理
  final Set<String> _processingKeys = {};

  /// 构建预模糊的图片，使用 RepaintBoundary 缓存渲染结果
  Widget buildBlurredImage(String imageUrl, double blurRadius) {
    // 如果模糊半径为0，直接显示原图，避免不必要的模糊计算
    if (blurRadius == 0) {
      return ExtendedImage.network(
        imageUrl,
        fit: BoxFit.cover,
        cache: true,
        cacheMaxAge: const Duration(days: 365 * 4),
        loadStateChanged: (state) {
          if (state.extendedImageLoadState == LoadState.failed) {
            return buildFallbackGradient();
          }
          return null;
        },
      );
    }

    // 使用 RepaintBoundary 缓存渲染结果，在 beforePaintImage 中使用预模糊的图像
    return RepaintBoundary(
      child: ExtendedImage.network(
        imageUrl,
        fit: BoxFit.cover,
        cache: true,
        cacheMaxAge: const Duration(days: 365 * 4),
        clearMemoryCacheWhenDispose: false,
        beforePaintImage: (canvas, rect, image, paint) {
          if (!rect.isEmpty) {
            final String cacheKey = '${imageUrl}_$blurRadius';

            // 检查是否有缓存的模糊图像
            if (!_blurredImageCache.containsKey(cacheKey)) {
              // 第一次绘制：异步生成模糊图像
              _generateBlurredImage(image, blurRadius, cacheKey);

              // 计算适配图像分辨率的模糊半径
              // 基准：假设 1000px 宽度时使用原始模糊半径
              final double scaleFactor = image.width / 1000.0;
              final double adaptiveBlurRadius = blurRadius * scaleFactor;

              // 在等待预模糊图像时，使用临时 canvas 模糊方法
              // 保存 canvas 状态
              canvas.save();

              // 应用高斯模糊滤镜到 canvas layer
              canvas.saveLayer(
                rect,
                Paint()
                  ..imageFilter = ui.ImageFilter.blur(
                    sigmaX: adaptiveBlurRadius,
                    sigmaY: adaptiveBlurRadius,
                    tileMode: TileMode.clamp,
                  ),
              );

              // 绘制图像
              _drawImageWithAspectRatio(canvas, rect, image, Paint());

              // 恢复 canvas 状态
              canvas.restore();
              canvas.restore();
            } else {
              // 使用缓存的模糊图像直接绘制（高性能）
              final blurredImage = _blurredImageCache[cacheKey]!;
              _drawImageWithAspectRatio(canvas, rect, blurredImage, paint);
            }
          }
          return true; // 返回 true 表示已经手动绘制，跳过默认绘制
        },
        loadStateChanged: (state) {
          if (state.extendedImageLoadState == LoadState.failed) {
            return buildFallbackGradient();
          }
          return null;
        },
      ),
    );
  }

  /// 异步生成模糊图像并缓存（混合方案：图像处理在主线程，使用异步避免阻塞）
  Future<void> _generateBlurredImage(
    ui.Image originalImage,
    double blurRadius,
    String cacheKey,
  ) async {
    // 如果已经在处理中，避免重复生成
    if (_processingKeys.contains(cacheKey)) return;
    _processingKeys.add(cacheKey);

    try {
      // 由于 UI 操作必须在主 isolate 中，我们使用异步延迟来避免阻塞 UI
      // 将处理分批进行，给 UI 线程喘息的机会
      await Future.delayed(Duration.zero);

      // 计算适配图像分辨率的模糊半径
      // 基准：假设 1000px 宽度时使用原始模糊半径
      final double scaleFactor = originalImage.width / 1.sw;
      final double adaptiveBlurRadius = blurRadius * scaleFactor;

      // 创建一个 PictureRecorder 来录制绘制操作
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 应用模糊滤镜并绘制图像
      final paint = Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: adaptiveBlurRadius,
          sigmaY: adaptiveBlurRadius,
          tileMode: TileMode.clamp,
        );

      canvas.saveLayer(
        Rect.fromLTWH(
          0,
          0,
          originalImage.width.toDouble(),
          originalImage.height.toDouble(),
        ),
        paint,
      );

      canvas.drawImage(originalImage, Offset.zero, Paint());
      canvas.restore();

      // 结束录制并生成图片
      final picture = recorder.endRecording();
      // 让出控制权，避免长时间占用
      await Future.delayed(Duration.zero);

      final blurredImage = await picture.toImage(
        originalImage.width,
        originalImage.height,
      );

      // 缓存模糊后的图像
      _blurredImageCache[cacheKey] = blurredImage;

      // 触发重绘以使用新的模糊图像
      if (mounted) {
        setState(() {});
      }

      // 释放资源
      picture.dispose();
    } catch (e) {
      // 模糊生成失败，不影响正常显示
      debugPrint('Failed to generate blurred image: $e');
    } finally {
      _processingKeys.remove(cacheKey);
    }
  }

  /// 保持宽高比绘制图像
  void _drawImageWithAspectRatio(
    Canvas canvas,
    Rect rect,
    ui.Image image,
    Paint paint,
  ) {
    // 计算保持宽高比的源区域
    final double imageAspectRatio = image.width / image.height;
    final double rectAspectRatio = rect.width / rect.height;

    Rect srcRect;
    if (imageAspectRatio > rectAspectRatio) {
      // 图像更宽，裁剪左右两侧
      final double srcWidth = image.height * rectAspectRatio;
      final double srcLeft = (image.width - srcWidth) / 2;
      srcRect = Rect.fromLTWH(srcLeft, 0, srcWidth, image.height.toDouble());
    } else {
      // 图像更高，裁剪上下两侧
      final double srcHeight = image.width / rectAspectRatio;
      final double srcTop = (image.height - srcHeight) / 2;
      srcRect = Rect.fromLTWH(0, srcTop, image.width.toDouble(), srcHeight);
    }

    // 直接绘制图像（无需模糊滤镜，因为图像本身已经是模糊的）
    canvas.drawImageRect(
      image,
      srcRect,
      rect,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  void dispose() {
    // 清理缓存的模糊图像
    for (var image in _blurredImageCache.values) {
      image.dispose();
    }
    _blurredImageCache.clear();
    super.dispose();
  }

  /// 构建失败时的渐变背景
  Widget buildFallbackGradient() {
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
}

/// 歌词格式化相关的共享功能 Mixin
mixin LyricFormattingMixin {
  /// 格式化时长为 MM:SS 格式
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }
}
SettingsController get settingsController => Get.find<SettingsController>();
XLyricController get lyricController => Get.find<XLyricController>();
PlayController get playController => Get.find<PlayController>();

void showLyricStyleSettings(BuildContext context) {
  WoltModalSheet.show<void>(
    context: context,
    modalTypeBuilder: (context) => globalHorizon
        ? CustomSideSheetType(
            width: 0.36.sw,
            edge: CustomSideSheetEdge.left,
            forceMaxHeight: false,
          )
        : WoltModalType.bottomSheet(),
    modalBarrierColor: Colors.transparent,
    pageListBuilder: (modalSheetContext) {
      return [
        WoltModalSheetPage(
          hasTopBarLayer: false,
          child: Obx(() {
            // 获取当前的样式模型
            final style = lyricController.lyricStyle.value;

            // 封装通用的滑动条构建方法
            Widget buildSlider(
              String label,
              double value,
              Function(double) onChanged,
            ) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$label: ${value.toStringAsFixed(1)}'),
                  Slider(
                    value: value.clamp(10.0, 50.0),
                    min: 10.0,
                    max: 50.0,
                    onChanged: (v) {
                      onChanged(v);
                      lyricController.lyricStyle.refresh();
                    },
                  ),
                ],
              );
            }

            // 封装通用的开关构建方法
            Widget buildSwitch(
              String label,
              bool value,
              Function(bool) onChanged,
            ) {
              return SwitchListTile(
                title: Text(label),
                value: value,
                onChanged: (v) {
                  onChanged(v);
                  lyricController.lyricStyle.refresh();
                },
                contentPadding: EdgeInsets.zero,
              );
            }

            // 封装通用的字重下拉框构建方法
            Widget buildWeightDropdown(
              String label,
              int? value,
              Function(int?) onChanged,
            ) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label),
                  DropdownButton<int?>(
                    value: value,
                    items: [null, 100, 200, 300, 400, 500, 600, 700, 800, 900]
                        .map((w) {
                          String text = w == null ? '默认' : 'w$w';
                          return DropdownMenuItem<int?>(
                            value: w,
                            child: Text(text),
                          );
                        })
                        .toList(),
                    onChanged: (v) {
                      onChanged(v);
                      lyricController.lyricStyle.refresh();
                    },
                  ),
                ],
              );
            }

            Widget buildLineTextAlignDropdown(
              String label,
              int? value,
              Function(int?) onChanged,
            ) {
              final alignOptions = <MapEntry<int?, String>>[
                const MapEntry<int?, String>(null, '默认'),
                const MapEntry<int?, String>(0, 'left'),
                const MapEntry<int?, String>(1, 'right'),
                const MapEntry<int?, String>(2, 'center'),
                const MapEntry<int?, String>(3, 'justify'),
                const MapEntry<int?, String>(4, 'start'),
                const MapEntry<int?, String>(5, 'end'),
              ];
              final availableValues = alignOptions.map((e) => e.key).toSet();
              final selectedValue =
                  availableValues.contains(value) ? value : null;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label),
                  DropdownButton<int?>(
                    value: selectedValue,
                    items: alignOptions
                        .map(
                          (item) => DropdownMenuItem<int?>(
                            value: item.key,
                            child: Text(item.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      onChanged(v);
                      lyricController.lyricStyle.refresh();
                    },
                  ),
                ],
              );
            }

            Widget buildContentAlignmentDropdown(
              String label,
              int? value,
              Function(int?) onChanged,
            ) {
              final alignOptions = <MapEntry<int?, String>>[
                const MapEntry<int?, String>(null, '默认'),
                const MapEntry<int?, String>(0, 'start'),
                const MapEntry<int?, String>(1, 'end'),
                const MapEntry<int?, String>(2, 'center'),
                const MapEntry<int?, String>(3, 'stretch'),
              ];
              final availableValues = alignOptions.map((e) => e.key).toSet();
              final selectedValue =
                  availableValues.contains(value) ? value : null;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label),
                  DropdownButton<int?>(
                    value: selectedValue,
                    items: alignOptions
                        .map(
                          (item) => DropdownMenuItem<int?>(
                            value: item.key,
                            child: Text(item.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      onChanged(v);
                      lyricController.lyricStyle.refresh();
                    },
                  ),
                ],
              );
            }

            return SizedBox(
              width: globalHorizon ? 0.33.w : null,
              height: globalHorizon ? null : 200,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Text(
                        '选中歌词',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      buildSlider(
                        '字体大小',
                        style.activeTextSize ?? 24.0,
                        (v) => style.activeTextSize = v,
                      ),
                      buildSwitch(
                        '使用屏幕宽度比例 (w)',
                        style.activeTextSizeUseW ?? false,
                        (v) => style.activeTextSizeUseW = v,
                      ),
                      buildWeightDropdown(
                        '字体粗细',
                        style.activeTextWeight,
                        (v) => style.activeTextWeight = v,
                      ),
                      const SizedBox(height: 16),

                      const Divider(),
                      const Text(
                        '普通歌词',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      buildSlider(
                        '字体大小',
                        style.textStyleFontSize ?? 16.0,
                        (v) => style.textStyleFontSize = v,
                      ),
                      buildSwitch(
                        '使用屏幕宽度比例 (w)',
                        style.textStyleFontSizeUseW ?? false,
                        (v) => style.textStyleFontSizeUseW = v,
                      ),
                      buildWeightDropdown(
                        '字体粗细',
                        style.textStyleFontWeight,
                        (v) => style.textStyleFontWeight = v,
                      ),
                      const SizedBox(height: 16),

                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        '翻译歌词',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      buildSlider(
                        '字体大小',
                        style.translationTextSize ?? 14.0,
                        (v) => style.translationTextSize = v,
                      ),
                      buildSwitch(
                        '使用屏幕宽度比例 (w)',
                        style.translationTextSizeUseW ?? false,
                        (v) => style.translationTextSizeUseW = v,
                      ),
                      buildWeightDropdown(
                        '字体粗细',
                        style.translationTextWeight,
                        (v) => style.translationTextWeight = v,
                      ),
                      const SizedBox(height: 16),

                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        '排版',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      buildLineTextAlignDropdown(
                        '行文本对齐',
                        style.lineTextAlign,
                        (v) => style.lineTextAlign = v,
                      ),
                      buildContentAlignmentDropdown(
                        '内容对齐',
                        style.contentAlignment,
                        (v) => style.contentAlignment = v,
                      ),
                      buildSlider(
                        '歌词行间距',
                        (style.lineGap ?? 25.0).clamp(5.0, 60.0),
                        (v) => style.lineGap = v,
                      ),
                      buildSlider(
                        '翻译行间距',
                        (style.translationLineGap ?? 8.0).clamp(5.0, 60.0),
                        (v) => style.translationLineGap = v,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ];
    },
  );
}

Widget _buildLyricContent(BuildContext context) {
  return Obx(() {
    // 监听翻译开关状态变化，确保UI能够响应
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
      return SizedBox.shrink();
    }

    return LyricView(
      controller: lyricController.lyricController,
      style: _createThemedLyricStyle(context),
    );
  });
}

// 创建主题化的歌词样式
LyricStyle _createThemedLyricStyle(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  // final bool horizon = globalHorizon;
  XLyricStyle lyricStyle = lyricController.lyricStyle.value;
  return LyricStyle(
    textStyle: TextStyle(
      fontSize: lyricStyle.textStyleFontSizeValue,
      fontWeight: lyricStyle.textStyleFontWeightValue,
      color:
          theme.textTheme.bodyLarge?.color?.withOpacity(isDark ? 0.8 : 0.7) ??
          (isDark ? Colors.white70 : Colors.black54),
    ),
    activeStyle: TextStyle(
      fontSize: lyricStyle.activeStyleFontSizeValue,
      color: theme.colorScheme.primary,
      fontWeight: lyricStyle.activeTextWeightValue,
    ),
    translationStyle: TextStyle(
      fontSize: lyricStyle.translationTextSizeValue,
      color:
          theme.textTheme.bodyMedium?.color?.withOpacity(isDark ? 0.6 : 0.5) ??
          (isDark ? Colors.white60 : Colors.black45),
      fontWeight: lyricStyle.translationTextWeightValue,
    ),
    translationActiveColor: theme.colorScheme.primary.withOpacity(0.7),
    lineTextAlign: lyricStyle.lineTextAlignValue,
    lineGap: lyricStyle.lineGapValue,
    translationLineGap: lyricStyle.translationLineGapValue,
    contentAlignment: lyricStyle.contentAlignmentValue,
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
