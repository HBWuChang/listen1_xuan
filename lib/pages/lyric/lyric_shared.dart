part of 'lyric_page.dart';

/// 模糊封面解码宽度限制。
///
/// 背景经过高斯模糊后不需要原图分辨率，限制解码尺寸可以显著降低
/// 解码耗时、内存占用以及模糊计算量，减少打开页面时的卡顿。
const int _kBlurredCoverDecodeWidth = 480;

/// 模糊封面全局缓存：按「图片地址 + 模糊半径」复用模糊结果。
///
/// 放在全局而不是 State 中，保证页面重建、来回切歌时依然命中，
/// 避免重复解码与重复模糊；超出容量后按 LRU 淘汰并释放。
class _LyricCoverCache {
  _LyricCoverCache._();

  static const int _maxEntries = 8;

  static final Map<String, ui.Image> _images = <String, ui.Image>{};
  static final Map<String, Future<ui.Image?>> _pending =
      <String, Future<ui.Image?>>{};

  static ui.Image? get(String key) {
    final ui.Image? image = _images.remove(key);
    if (image != null) {
      _images[key] = image; // 命中后移到队尾（LRU）
    }
    return image;
  }

  /// 相同 key 只会执行一次 [loader]，并发请求共享同一个 Future。
  static Future<ui.Image?> load(
    String key,
    Future<ui.Image> Function() loader,
  ) {
    final ui.Image? cached = get(key);
    if (cached != null) {
      return Future<ui.Image?>.value(cached);
    }
    return _pending.putIfAbsent(key, () async {
      try {
        final ui.Image image = await loader();
        _images.remove(key)?.dispose();
        _images[key] = image;
        while (_images.length > _maxEntries) {
          _images.remove(_images.keys.first)?.dispose();
        }
        return image;
      } catch (e) {
        debugPrint('Failed to load lyric cover: $e');
        return null;
      } finally {
        _pending.remove(key);
      }
    });
  }
}

/// 歌词页模糊封面背景。
///
/// 关键优化：
/// 1. 后台异步解码 + 预模糊，首帧不再同步执行高斯模糊，打开页面不卡顿；
/// 2. 切歌时保留上一张封面，新封面就绪后交叉淡入，
///    加载中 / 失败都不会闪回默认渐变背景；
/// 3. 模糊结果进入全局缓存，重复打开、来回切歌直接复用。
class _LyricBlurredCover extends StatefulWidget {
  const _LyricBlurredCover({required this.imageUrl, required this.blurRadius});

  final String imageUrl;
  final double blurRadius;

  @override
  State<_LyricBlurredCover> createState() => _LyricBlurredCoverState();
}

class _LyricBlurredCoverState extends State<_LyricBlurredCover>
    with SingleTickerProviderStateMixin {
  static const Duration _fadeDuration = Duration(milliseconds: 420);

  /// 必须在 initState 中创建：若在 dispose 时才首次访问，
  /// `createTicker` 会去查找已失效 element 的祖先（TickerMode），
  /// 抛出 "Looking up a deactivated widget's ancestor is unsafe"。
  late final AnimationController _fadeController;

  /// 当前完整显示的封面（切歌期间保留上一张，避免闪回默认背景）
  ui.Image? _current;

  /// 正在淡入的封面
  ui.Image? _next;

  String? _requestedUrl;
  double? _requestedBlurRadius;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: _fadeDuration,
    );
    _syncCover();
  }

  @override
  void didUpdateWidget(covariant _LyricBlurredCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.blurRadius != widget.blurRadius) {
      _syncCover();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _current?.dispose();
    _next?.dispose();
    super.dispose();
  }

  void _syncCover() {
    final String url = widget.imageUrl;
    // 地址为空（无封面 / 信息未就绪）时保留当前画面，不闪回默认背景
    if (url.isEmpty) return;
    if (url == _requestedUrl && widget.blurRadius == _requestedBlurRadius) {
      return;
    }
    _requestedUrl = url;
    _requestedBlurRadius = widget.blurRadius;
    final int requestId = ++_requestId;

    // 同步命中缓存（页面重建、来回切歌）时直接显示，
    // 不经过异步流程，避免闪一帧兜底渐变
    final ui.Image? cached = _LyricCoverCache.get(
      _coverKey(url, widget.blurRadius),
    );
    if (cached != null && _current == null) {
      _current = cached.clone();
      return; // initState / didUpdateWidget 之后必然重新 build
    }
    unawaited(_loadAndShow(url, widget.blurRadius, requestId));
  }

  String _coverKey(String url, double blurRadius) =>
      '$url|${blurRadius.toStringAsFixed(2)}';

  Future<void> _loadAndShow(
    String url,
    double blurRadius,
    int requestId,
  ) async {
    final ui.Image? image = await _LyricCoverCache.load(
      _coverKey(url, blurRadius),
      () => _decodeAndBlur(url, blurRadius),
    );
    if (!mounted || requestId != _requestId || image == null) return;

    // 首次显示（没有旧图可对比）直接展示，避免闪一下兜底渐变
    if (_current == null) {
      setState(() {
        _next?.dispose();
        _next = null;
        _current = image.clone();
      });
      return;
    }

    // 切换封面：旧图垫底，新图淡入，加载期间画面保持不变
    setState(() {
      _next?.dispose();
      _next = image.clone();
    });
    try {
      await _fadeController.forward(from: 0).orCancel;
    } on TickerCanceled {
      return; // 已被更新的封面请求取代
    }
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _current?.dispose();
      _current = _next;
      _next = null;
    });
  }

  Future<ui.Image> _decodeAndBlur(String url, double blurRadius) async {
    final ExtendedNetworkImageProvider network = ExtendedNetworkImageProvider(
      url,
      cache: true,
      cacheMaxAge: const Duration(days: 365 * 4),
    );
    // 模糊模式按低分辨率解码；清晰模式保持原分辨率
    final ImageProvider<Object> provider = blurRadius > 0
        ? ExtendedResizeImage(
            network,
            width: _kBlurredCoverDecodeWidth,
            maxBytes: null,
          )
        : network;

    final ui.Image decoded = await _resolveImage(provider);
    if (blurRadius <= 0) return decoded;
    try {
      return await _blurImage(decoded, blurRadius);
    } finally {
      decoded.dispose(); // 模糊结果已生成，释放低分辨率原图
    }
  }

  Future<ui.Image> _resolveImage(ImageProvider<Object> provider) {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    final ImageStream stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (!completer.isCompleted) {
          // clone：避免 ImageCache 淘汰原图后持有失效的图像
          completer.complete(info.image.clone());
        }
        info.dispose(); // 监听器拥有这份副本，用完即释放
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  /// 在低分辨率图像上完成模糊，避免每次绘制都在大图上做高斯模糊。
  Future<ui.Image> _blurImage(ui.Image source, double blurRadius) {
    final int width = source.width;
    final int height = source.height;
    // 以「屏幕逻辑像素」为基准换算模糊半径，保证不同分辨率下观感一致
    final double screenWidth = 1.sw;
    final double scale = screenWidth > 0 ? width / screenWidth : 1;
    final double sigma = blurRadius * scale;
    final double adaptiveSigma = sigma < 0.5 ? 0.5 : sigma;
    final Rect rect = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.saveLayer(
      rect,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: adaptiveSigma,
          sigmaY: adaptiveSigma,
          tileMode: TileMode.clamp,
        ),
    );
    canvas.drawImage(source, Offset.zero, Paint());
    canvas.restore();

    final ui.Picture picture = recorder.endRecording();
    return picture.toImage(width, height).whenComplete(picture.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final FilterQuality quality = widget.blurRadius > 0
        ? FilterQuality.low
        : FilterQuality.medium;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildFallbackGradient(context),
          if (_current != null)
            RawImage(
              image: _current,
              fit: BoxFit.cover,
              filterQuality: quality,
            ),
          if (_next != null)
            FadeTransition(
              opacity: _fadeController,
              child: RawImage(
                image: _next,
                fit: BoxFit.cover,
                filterQuality: quality,
              ),
            ),
        ],
      ),
    );
  }

  /// 无封面 / 加载失败时的兜底渐变
  Widget _buildFallbackGradient(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).primaryColor.withValues(alpha: 0.3),
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
      ),
    );
  }
}

/// 歌词页面共享功能的 Mixin
/// 提供带模糊与淡入过渡的封面背景
mixin LyricBlurredBackgroundMixin<T extends StatefulWidget> on State<T> {
  /// 构建模糊封面背景；切歌 / 换图时自动交叉淡入，加载中保留旧图。
  Widget buildBlurredImage(String imageUrl, double blurRadius) {
    return _LyricBlurredCover(imageUrl: imageUrl, blurRadius: blurRadius);
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
              final selectedValue = availableValues.contains(value)
                  ? value
                  : null;

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
              final selectedValue = availableValues.contains(value)
                  ? value
                  : null;

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

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    8.sbh,
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
                    16.sbh,

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
                    16.sbh,

                    const Divider(),
                    8.sbh,
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
                    16.sbh,

                    const Divider(),
                    8.sbh,
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
                    24.sbh,
                  ],
                ),
              ),
            ).sbwh(globalHorizon ? 0.33.w : null, globalHorizon ? null : 200);
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
          children: [globalLoadingAnime, 16.sbh, Text('加载歌词中...')],
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
          theme.textTheme.bodyLarge?.color?.withValues(
            alpha: isDark ? 0.8 : 0.7,
          ) ??
          (isDark ? Colors.white70 : Colors.black54),
    ),
    activeStyle: TextStyle(
      fontSize: lyricStyle.activeStyleFontSizeValue,
      color:
          theme.textTheme.bodyLarge?.color?.withValues(
            alpha: isDark ? 0.8 : 0.7,
          ) ??
          (isDark ? Colors.white70 : Colors.black54),
      fontWeight: lyricStyle.activeTextWeightValue,
    ),
    translationStyle: TextStyle(
      fontSize: lyricStyle.translationTextSizeValue,
      color:
          theme.textTheme.bodyMedium?.color?.withValues(
            alpha: isDark ? 0.6 : 0.5,
          ) ??
          (isDark ? Colors.white60 : Colors.black45),
      fontWeight: lyricStyle.translationTextWeightValue,
    ),
    translationActiveColor: theme.colorScheme.primary.withValues(alpha: 0.7),
    lineTextAlign: lyricStyle.lineTextAlignValue,
    lineGap: lyricStyle.lineGapValue,
    translationLineGap: lyricStyle.translationLineGapValue,
    contentAlignment: lyricStyle.contentAlignmentValue,
    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
    selectionAnchorPosition: 0.48,
    fadeRange: FadeRange(top: 80, bottom: 80),
    selectedColor: theme.colorScheme.primary,
    selectedTranslationColor: theme.colorScheme.primary.withValues(alpha: 0.7),
    scrollDuration: Duration(milliseconds: 240),
    scrollDurations: {
      500: Duration(milliseconds: 500),
      1000: Duration(milliseconds: 1000),
    },
    enableSwitchAnimation: true,
    selectionAutoResumeMode: SelectionAutoResumeMode.selecting,
    selectionAutoResumeDuration: Duration(milliseconds: 320),
    activeAutoResumeDuration: Duration(milliseconds: 3000),
    activeHighlightColor: theme.colorScheme.primaryFixed,
    activeHighlightExtraFadeWidth: 20,
    switchEnterDuration: Duration(milliseconds: 300),
    switchExitDuration: Duration(milliseconds: 500),
    switchEnterCurve: Curves.easeOutBack,
    switchExitCurve: Curves.easeOutQuint,
    selectionAlignment: MainAxisAlignment.center,
  );
}
