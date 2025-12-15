import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:get/get.dart';

/// 侧边通知弹出的方向
enum SheetToastSide { left, right }

double toasticonSize = 64.0;
double maxToastHeight = 300.0;
double get maxToastWidth => max(1.sw - 128, 0.6.sw);

/// Sheet Toast 条目
class _SheetToastEntry {
  final OverlayEntry entry;
  final Duration duration;
  final Duration fadeDuration;
  final SheetController controller;
  final bool autoDismiss;

  _SheetToastEntry({
    required this.entry,
    required this.duration,
    required this.fadeDuration,
    required this.controller,
    required this.autoDismiss,
  });
}

class SmoothSheetToastOffset {
  SheetOffset hiddenOffset;
  SheetOffset peekOffset;
  SheetOffset shownOffset;
  SmoothSheetToastOffset({
    required this.hiddenOffset,
    required this.peekOffset,
    required this.shownOffset,
  });
  SmoothSheetToastOffset.fromWidth({required double toastWidth})
    : hiddenOffset = SheetOffset(0.0),
      peekOffset = SheetOffset(toasticonSize / toastWidth),
      shownOffset = SheetOffset((0.5 * 1.sw / toastWidth) + 0.5);
  List<SheetOffset> get offsets => [hiddenOffset, peekOffset, shownOffset];
}

/// SmoothSheetToast - 使用 smooth_sheets 实现的侧边滑入通知
///
/// 使用方式：
/// ```dart
/// final toast = SmoothSheetToast();
/// toast.init(context);
/// toast.showToast(
///   child: YourWidget(),
///   side: SheetToastSide.right,
/// );
/// ```
class SmoothSheetToast {
  BuildContext? context;

  static final SmoothSheetToast _instance = SmoothSheetToast._internal();

  /// 主构造函数
  factory SmoothSheetToast() {
    return _instance;
  }

  /// 初始化，保存 context
  SmoothSheetToast init(BuildContext context) {
    _instance.context = context;
    return _instance;
  }

  SmoothSheetToast._internal();

  OverlayEntry? _entry;
  List<_SheetToastEntry> _overlayQueue = [];
  Timer? _timer;
  Timer? _fadeTimer;
  SheetController? _currentController;

  /// 显示 overlay
  _showOverlay() {
    if (_overlayQueue.isEmpty) {
      _entry = null;
      _currentController = null;
      return;
    }
    if (context == null) {
      removeQueuedToasts();
      throw ("Error: Context is null, Please call init(context) before showing toast.");
    }

    // 防止在 widget 已卸载的情况下显示
    if (context?.mounted != true) {
      if (kDebugMode) {
        print(
          'SmoothSheetToast: Context was unmounted, can not show ${_overlayQueue.length} toast.',
        );
      }
      removeQueuedToasts();
      return;
    }

    OverlayState? _overlay;
    try {
      _overlay = Overlay.of(context!);
      if (kDebugMode) {
        print('SmoothSheetToast: Overlay found, inserting toast entry');
      }
    } catch (err) {
      if (kDebugMode) {
        print('SmoothSheetToast: Failed to get overlay: $err');
      }
      removeQueuedToasts();
      throw ("""Error: Overlay is null. 
      Please don't use top of the widget tree context (such as Navigator or MaterialApp) or 
      create overlay manually in MaterialApp builder.""");
    }

    /// 创建 entry
    _SheetToastEntry _toastEntry = _overlayQueue.removeAt(0);
    _entry = _toastEntry.entry;
    _currentController = _toastEntry.controller;
    _overlay.insert(_entry!);

    if (kDebugMode) {
      print('SmoothSheetToast: Toast entry inserted into overlay');
    }

    // 只在 autoDismiss 为 true 时设置自动消失定时器
    if (_toastEntry.autoDismiss) {
      _timer = Timer(_toastEntry.duration, () {
        _fadeTimer = Timer(_toastEntry.fadeDuration, () {
          removeToast();
        });
      });
    }
  }

  /// 移除当前 toast
  removeToast() {
    _timer?.cancel();
    _fadeTimer?.cancel();
    _timer = null;
    _fadeTimer = null;
    _entry?.remove();
    _entry = null;
    _currentController = null;
    _showOverlay();
  }

  /// 移除队列中的所有 toast
  removeQueuedToasts() {
    _timer?.cancel();
    _fadeTimer?.cancel();
    _timer = null;
    _fadeTimer = null;
    _overlayQueue.clear();
    _entry?.remove();
    _entry = null;
    _currentController = null;
  }

  /// 显示 toast
  ///
  /// [child] 通知内容 widget
  /// [side] 弹出方向，默认右侧
  /// [autoDismiss] 是否自动消失，默认 false
  /// [toastDuration] 显示时长（仅在 autoDismiss 为 true 时有效），默认 3 秒
  /// [fadeDuration] 淡出时长，默认 350 毫秒
  /// [width] 通知宽度（旋转后的高度），默认 400
  /// [height] 通知高度（旋转后的宽度），默认占满屏幕
  /// [maxToastHeight] 通知的最大高度，默认 300
  /// [maxContentWidth] 内容的最大宽度，默认 350
  /// [iconSize] 保留在边缘的图标大小，默认 48
  /// [borderRadius] 圆角半径，默认 16
  /// [backgroundColor] 背景颜色，默认使用主题色
  /// [isDismissible] 是否可以滑动关闭，默认 true
  void showToast({
    required Widget child,
    SheetToastSide side = SheetToastSide.right,
    bool autoDismiss = false,
    Duration toastDuration = const Duration(seconds: 3),
    Duration fadeDuration = const Duration(milliseconds: 350),
    double borderRadius = 16.0,
    Color? backgroundColor,
    bool isDismissible = true,
    Widget? icon,
  }) {
    if (context == null) {
      throw ("Error: Context is null, Please call init(context) before showing toast.");
    }

    if (kDebugMode) {
      print('SmoothSheetToast: showToast called');
    }

    final sheetController = SheetController();

    // 预渲染 child 以获取实际尺寸
    _measureChild(
      child: child,
      maxContentWidth: maxToastWidth,
      maxToastHeight: maxToastHeight,
      onMeasured: (measuredSize) {
        if (kDebugMode) {
          print('SmoothSheetToast: Measured size: $measuredSize');
          print('SmoothSheetToast: Measured width: ${measuredSize.width}');
          print('SmoothSheetToast: Measured height: ${measuredSize.height}');
        }
        final showToastWidth = min(measuredSize.width, maxToastWidth);
        final showToastHeight = min(measuredSize.height, maxToastHeight);

        OverlayEntry newEntry = OverlayEntry(
          builder: (context) {
            return _SheetToastWidget(
              controller: sheetController,
              side: side,
              width: showToastWidth,
              height: showToastHeight,
              measuredSize: measuredSize,
              borderRadius: borderRadius,
              backgroundColor:
                  backgroundColor ??
                  Get.theme.colorScheme.surfaceContainerHighest,
              isDismissible: isDismissible,
              onDismiss: isDismissible ? () => removeToast() : null,
              child: child,
              icon: icon ?? Icon(Icons.notifications, size: toasticonSize),
            );
          },
        );

        _overlayQueue.add(
          _SheetToastEntry(
            entry: newEntry,
            duration: toastDuration,
            fadeDuration: fadeDuration,
            controller: sheetController,
            autoDismiss: autoDismiss,
          ),
        );

        if (_timer == null) {
          if (kDebugMode) {
            print('SmoothSheetToast: Calling _showOverlay');
          }
          _showOverlay();
          // 等待 sheet 挂载后再执行动画
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (kDebugMode) {
              print(
                'SmoothSheetToast: PostFrameCallback - hasClient: ${sheetController.hasClient}',
              );
            }
            if (sheetController.hasClient) {
              if (kDebugMode) {
                print('SmoothSheetToast: Animating to peek position');
              }
              sheetController.animateTo(
                SmoothSheetToastOffset.fromWidth(
                  toastWidth: showToastWidth,
                ).shownOffset,
                duration: fadeDuration,
                curve: Curves.easeOutCubic,
              );
            }
          });
        }
      },
    );
  }

  /// 预渲染 child 以获取实际尺寸
  void _measureChild({
    required Widget child,
    required double maxContentWidth,
    required double maxToastHeight,
    required Function(Size) onMeasured,
  }) {
    final measureKey = GlobalKey();
    OverlayEntry? measureEntry;

    measureEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: -10000, // 移出屏幕外
          top: -10000,
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxContentWidth,
                // 不设置 maxHeight，让 child 自然展开
              ),
              child: IntrinsicWidth(
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Container(key: measureKey, child: child),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    try {
      final overlay = Overlay.of(context!);
      overlay.insert(measureEntry);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final renderBox =
              measureKey.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final size = renderBox.size;
            if (kDebugMode) {
              print('SmoothSheetToast: Raw measured size: $size');
            }

            // 检查是否为无限大小
            if (size.height.isInfinite || size.height > 10000) {
              if (kDebugMode) {
                print(
                  'SmoothSheetToast: Detected infinite height, using maxToastHeight',
                );
              }
              onMeasured(
                Size(
                  size.width.isInfinite ? maxContentWidth : size.width,
                  maxToastHeight,
                ),
              );
            } else {
              onMeasured(size);
            }
          } else {
            if (kDebugMode) {
              print('SmoothSheetToast: Failed to get RenderBox, using default');
            }
            onMeasured(Size(maxContentWidth, maxToastHeight));
          }
        } catch (e) {
          if (kDebugMode) {
            print('SmoothSheetToast: Error measuring child: $e');
          }
          onMeasured(Size(maxContentWidth, maxToastHeight));
        } finally {
          measureEntry?.remove();
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('SmoothSheetToast: Error creating measure overlay: $e');
      }
      onMeasured(Size(maxContentWidth, maxToastHeight));
    }
  }
}

/// Sheet Toast Widget
class _SheetToastWidget extends StatefulWidget {
  final SheetController controller;
  final SheetToastSide side;
  final double width;
  final double height;
  final Size measuredSize;
  final double borderRadius;
  final Color backgroundColor;
  final bool isDismissible;
  final VoidCallback? onDismiss;
  final Widget child;
  final Widget icon;

  const _SheetToastWidget({
    Key? key,
    required this.controller,
    required this.side,
    required this.width,
    required this.height,
    required this.measuredSize,
    required this.borderRadius,
    required this.backgroundColor,
    required this.isDismissible,
    required this.onDismiss,
    required this.child,
    this.icon = const Icon(Icons.notifications),
  }) : super(key: key);

  @override
  State<_SheetToastWidget> createState() => _SheetToastWidgetState();
}

class _SheetToastWidgetState extends State<_SheetToastWidget> {
  bool _hadScrolled = false;
  @override
  void initState() {
    super.initState();
    if (widget.isDismissible) {
      widget.controller.addListener(_onSheetChange);
    }
  }

  @override
  void dispose() {
    if (widget.isDismissible) {
      widget.controller.removeListener(_onSheetChange);
    }
    super.dispose();
  }

  void _onSheetChange() {
    // 监听 sheet 的滑动，当完全划出屏幕时删除
    final metrics = widget.controller.metrics;
    if (metrics != null) {
      final offset = metrics.offset;
      if (_hadScrolled == false && offset > 0) {
        _hadScrolled = true;
      }
      // 当滑动到完全隐藏位置时，触发删除
      if (offset <= 0.0 && _hadScrolled) {
        widget.onDismiss?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = 1.sw;
    double screenHeight = 1.sh;

    bool needsScroll = widget.measuredSize.height > widget.height;

    // 计算偏移量
    SmoothSheetToastOffset toastOffsets = SmoothSheetToastOffset.fromWidth(
      toastWidth: widget.width,
    );
    final expandAnimation = SheetOffsetDrivenAnimation(
      controller: widget.controller,
      initialValue: 0,
      startOffset: toastOffsets.peekOffset,
      endOffset: toastOffsets.shownOffset,
    );
    // 根据侧边确定旋转角度和位置
    final isLeftSide = widget.side == SheetToastSide.left;
    final rotationQuarters = isLeftSide ? 1 : 3; // 左侧顺时针90度，右侧逆时针90度

    debugPrint('Widget width: ${widget.width}, height: ${widget.height}');

    return Stack(
      children: [
        Positioned(
          top: isLeftSide
              ? screenHeight * (1 - 0.618) - widget.height / 2
              : null,
          bottom: isLeftSide ? null : screenHeight * 0.618 - widget.height / 2,
          left: isLeftSide ? 0 : null,
          right: isLeftSide ? null : 0,
          child: RotatedBox(
            quarterTurns: rotationQuarters,
            child: SizedBox(
              width: widget.height,
              height: screenWidth,
              child: SheetViewport(
                child: Sheet(
                  controller: widget.controller,
                  initialOffset: toastOffsets.hiddenOffset, // 初始显示 peek 状态
                  snapGrid: SheetSnapGrid(snaps: toastOffsets.offsets),
                  child: RotatedBox(
                    quarterTurns: isLeftSide ? 3 : 1,
                    child: SizedBox(
                      width: widget.width,
                      child: Align(
                        alignment: AlignmentGeometry.topLeft,
                        child: AnimatedBuilder(
                          animation: expandAnimation,
                          builder: (context, child) {
                            debugPrint(
                              'Expand animation value: ${expandAnimation.value}',
                            );
                            return Container(
                              height:
                                  widget.height * expandAnimation.value +
                                  (toasticonSize * (1 - expandAnimation.value)),
                              decoration: BoxDecoration(
                                color: widget.backgroundColor,
                                borderRadius: BorderRadius.circular(
                                  widget.borderRadius,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8.0,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: isLeftSide
                                        ? null
                                        : -expandAnimation.value *
                                              toasticonSize,
                                    right: isLeftSide
                                        ? -expandAnimation.value * toasticonSize
                                        : null,
                                    width: toasticonSize,
                                    height: toasticonSize,
                                    child: widget.icon,
                                  ),
                                  Positioned(
                                    left: widget.side == SheetToastSide.left
                                        ? 0 -
                                              (1 - expandAnimation.value) *
                                                  toasticonSize
                                        : null,
                                    right: widget.side == SheetToastSide.right
                                        ? 0 -
                                              (1 - expandAnimation.value) *
                                                  toasticonSize
                                        : null,
                                    top: 0,
                                    width: widget.width,
                                    child: needsScroll
                                        ? SingleChildScrollView(
                                            padding: EdgeInsets.zero,
                                            child: widget.child,
                                          )
                                        : widget.child,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
