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

              // 在等待预模糊图像时，使用临时 canvas 模糊方法
              // 保存 canvas 状态
              canvas.save();

              // 应用高斯模糊滤镜到 canvas layer
              canvas.saveLayer(
                rect,
                Paint()
                  ..imageFilter = ui.ImageFilter.blur(
                    sigmaX: blurRadius,
                    sigmaY: blurRadius,
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

      // 创建一个 PictureRecorder 来录制绘制操作
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 应用模糊滤镜并绘制图像
      final paint = Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: blurRadius,
          sigmaY: blurRadius,
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
