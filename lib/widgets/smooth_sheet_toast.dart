import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:get/get.dart';

/// 侧边通知弹出的方向
enum SheetToastSide { left, right }

double toasticonSize = 48.0;
double maxToastHeight = 300.0;
double get maxToastWidth => max(1.sw - 128, 0.6.sw);

/// Sheet Toast 条目
class _SheetToastEntry {
  final String id;
  final OverlayEntry entry;
  final Duration duration;
  final Duration fadeDuration;
  final SheetController controller;
  final bool autoDismiss;
  final double toastWidth;

  _SheetToastEntry({
    required this.id,
    required this.entry,
    required this.duration,
    required this.fadeDuration,
    required this.controller,
    required this.autoDismiss,
    required this.toastWidth,
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
    : hiddenOffset = SheetOffset(0),
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
  String? _currentToastId;
  List<_SheetToastEntry> _overlayQueue = [];
  Timer? _timer;
  Timer? _fadeTimer;
  SheetController? _currentController;
  int _toastIdCounter = 0;

  /// 显示 overlay
  _showOverlay() {
    if (_overlayQueue.isEmpty) {
      _entry = null;
      _currentToastId = null;
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
    _currentToastId = _toastEntry.id;
    _currentController = _toastEntry.controller;
    _overlay.insert(_entry!);

    if (kDebugMode) {
      print('SmoothSheetToast: Toast entry inserted into overlay, ID: ${_toastEntry.id}');
    }

    // 等待 sheet 挂载后再执行动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_toastEntry.controller.hasClient) {
        if (kDebugMode) {
          print('SmoothSheetToast: Starting animation for toast ID: ${_toastEntry.id}');
        }
        _toastEntry.controller.animateTo(
          SmoothSheetToastOffset.fromWidth(
            toastWidth: _toastEntry.toastWidth,
          ).shownOffset,
          duration: Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });

    // 只在 autoDismiss 为 true 时设置自动消失定时器
    if (_toastEntry.autoDismiss) {
      _timer = Timer(_toastEntry.duration, () {
        _fadeTimer = Timer(_toastEntry.fadeDuration, () {
          removeToast(_toastEntry.id);
        });
      });
    }
  }
  
  /// 移除指定 ID 的 toast
  removeToast([String? toastId]) {
    if (kDebugMode) {
      print('SmoothSheetToast: removeToast called with ID: $toastId, current ID: $_currentToastId');
    }

    // 如果指定了 ID，检查是否是当前显示的 toast
    if (toastId != null && toastId != _currentToastId) {
      // 不是当前显示的 toast，从队列中移除
      _overlayQueue.removeWhere((entry) => entry.id == toastId);
      if (kDebugMode) {
        print('SmoothSheetToast: Removed toast from queue, ID: $toastId');
      }
      return;
    }

    // 移除当前显示的 toast
    _timer?.cancel();
    _fadeTimer?.cancel();
    _timer = null;
    _fadeTimer = null;
    _entry?.remove();
    _entry = null;
    _currentToastId = null;
    _currentController = null;
    
    if (kDebugMode) {
      print('SmoothSheetToast: Current toast removed, showing next');
    }
    
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
    _currentToastId = null;
    _currentController = null;
  }

  /// 获取当前 toast 数量（包括正在显示的和队列中的）
  int getToastCount() {
    int count = _overlayQueue.length;
    if (_entry != null) {
      count += 1; // 当前正在显示的 toast
    }
    return count;
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
    final toastId = 'toast_${_toastIdCounter++}';

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
              onDismiss: isDismissible ? () => removeToast(toastId) : null,
              child: child,
              icon: icon ?? Icon(Icons.notifications_rounded),
            );
          },
        );

        _overlayQueue.add(
          _SheetToastEntry(
            id: toastId,
            entry: newEntry,
            duration: toastDuration,
            fadeDuration: fadeDuration,
            controller: sheetController,
            autoDismiss: autoDismiss,
            toastWidth: showToastWidth,
          ),    
        );
        
        if (kDebugMode) {
          print('SmoothSheetToast: Toast added to queue, ID: $toastId, queue size: ${_overlayQueue.length}');
        }
        
        // 只有当前没有显示的 toast 时，才显示新的 toast
        if (_entry == null) {
          if (kDebugMode) {
            print('SmoothSheetToast: No current toast, calling _showOverlay');
          }
          _showOverlay();
        } else {
          if (kDebugMode) {
            print('SmoothSheetToast: Toast already showing, added to queue');
          }
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
  bool _hasBeenDismissed = false;
  
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
    // 如果已经触发过 dismiss，不再重复触发
    if (_hasBeenDismissed) return;
    
    // 监听 sheet 的滑动，当完全划出屏幕时删除
    final metrics = widget.controller.metrics;
    if (metrics != null) {
      final offset = metrics.offset;
      if (_hadScrolled == false && offset > 0.01) {
        _hadScrolled = true;
      }
      // 当滑动到完全隐藏位置时，触发删除
      if (offset <= 0.01 && _hadScrolled) {
        _hasBeenDismissed = true;
        debugPrint('SheetToast: Dismissed by user swipe');
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
                            double curveValue = Curves.easeOutCubic.transform(
                              expandAnimation.value,
                            );
                            // debugPrint(
                            //   'Expand animation value: ${expandAnimation.value}',
                            // );
                            return Container(
                              height:
                                  widget.height * curveValue +
                                  (toasticonSize * (1 - curveValue)),
                              decoration: BoxDecoration(
                                color: Get.theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(
                                  widget.borderRadius,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 6.0,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: isLeftSide
                                        ? null
                                        : -curveValue * toasticonSize,
                                    right: isLeftSide
                                        ? -curveValue * toasticonSize
                                        : null,
                                    width: toasticonSize,
                                    height: toasticonSize,
                                    child: GestureDetector(
                                      onTap: () => widget.controller.animateTo(
                                        toastOffsets.shownOffset,
                                        duration: Duration(milliseconds: 500),
                                      ),
                                      child: widget.icon,
                                    ),
                                  ),
                                  Positioned(
                                    left: widget.side == SheetToastSide.left
                                        ? 0 - (1 - curveValue) * toasticonSize
                                        : null,
                                    right: widget.side == SheetToastSide.right
                                        ? 0 - (1 - curveValue) * toasticonSize
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
