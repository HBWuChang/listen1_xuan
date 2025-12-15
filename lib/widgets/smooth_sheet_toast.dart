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
double get maxToastWidth => max(1.sw - 64, 0.6.sw);

/// Toast 控制器
/// 用于控制单个 Toast 的行为（展开、收起、关闭等）
class ToastController {
  final String _toastId;
  final double _toastWidth;
  final SheetController _sheetController;
  final VoidCallback _onRemove;
  VoidCallback? _listener;
  bool _listenerAttached = false;

  ToastController({
    required String toastId,
    required double toastWidth,
    required SheetController sheetController,
    required VoidCallback onRemove,
  }) : _toastId = toastId,
       _toastWidth = toastWidth,
       _sheetController = sheetController,
       _onRemove = onRemove;

  /// 获取 Toast ID
  String get id => _toastId;

  /// 添加监听器，监听offset变化，当小于0.01时自动dismiss
  void attachDismissListener() {
    if (_listenerAttached || !_sheetController.hasClient) return;

    _listener = () {
      final metrics = _sheetController.metrics;
      if (metrics != null && metrics.offset < 0.01) {
        _removeDismissListener();
        dismiss();
      }
    };

    _sheetController.addListener(_listener!);
    _listenerAttached = true;
  }

  /// 移除监听器
  void _removeDismissListener() {
    if (_listener != null && _listenerAttached) {
      _sheetController.removeListener(_listener!);
      _listener = null;
      _listenerAttached = false;
    }
  }

  /// 展开到完全显示状态
  void expand({
    Duration duration = const Duration(milliseconds: 600),
    Curve curve = Curves.easeOutCubic,
  }) {
    if (!_sheetController.hasClient) return;
    final shownOffset = SmoothSheetToastOffset.fromWidth(
      toastWidth: _toastWidth,
    ).shownOffset;
    _sheetController.animateTo(shownOffset, duration: duration, curve: curve);
  }

  /// 收起到 peek 状态（只显示图标）
  void peek({
    Duration duration = const Duration(milliseconds: 600),
    Curve curve = Curves.easeOutCubic,
  }) {
    if (!_sheetController.hasClient) return;
    final peekOffset = SmoothSheetToastOffset.fromWidth(
      toastWidth: _toastWidth,
    ).peekOffset;
    _sheetController.animateTo(peekOffset, duration: duration, curve: curve);
  }

  /// 隐藏（动画到完全隐藏状态）
  void hide({
    Duration duration = const Duration(milliseconds: 600),
    Curve curve = Curves.easeOutCubic,
  }) {
    if (!_sheetController.hasClient) return;
    final hiddenOffset = SmoothSheetToastOffset.fromWidth(
      toastWidth: _toastWidth,
    ).hiddenOffset;
    _sheetController.animateTo(hiddenOffset, duration: duration, curve: curve);
  }

  /// 关闭并移除 Toast
  void dismiss() {
    _onRemove();
  }
}

/// Sheet Toast 条目
class _SheetToastEntry {
  final String id;
  final OverlayEntry entry;
  final Duration duration;
  final Duration fadeDuration;
  final SheetController controller;
  final bool autoDismiss;
  final double toastWidth;
  final VoidCallback? onDismiss;
  final ToastController? toastController;

  _SheetToastEntry({
    required this.id,
    required this.entry,
    required this.duration,
    required this.fadeDuration,
    required this.controller,
    required this.autoDismiss,
    required this.toastWidth,
    this.onDismiss,
    this.toastController,
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
///   builder: (context, controller) {
///     return YourWidget(
///       onDismiss: () => controller.dismiss(),
///     );
///   },
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
  double? _currentToastWidth;
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
    _currentToastWidth = _toastEntry.toastWidth;
    _overlay.insert(_entry!);

    if (kDebugMode) {
      print(
        'SmoothSheetToast: Toast entry inserted into overlay, ID: ${_toastEntry.id}',
      );
    }

    // 等待 sheet 挂载后再执行动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_toastEntry.controller.hasClient) {
        if (kDebugMode) {
          print(
            'SmoothSheetToast: Starting animation for toast ID: ${_toastEntry.id}',
          );
        }
        _toastEntry.controller
            .animateTo(
              SmoothSheetToastOffset.fromWidth(
                toastWidth: _toastEntry.toastWidth,
              ).shownOffset,
              duration: Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
            )
            .then((_) {
              // 动画完成后，添加自动dismiss监听器
              _toastEntry.toastController?.attachDismissListener();
            });
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
      print(
        'SmoothSheetToast: removeToast called with ID: $toastId, current ID: $_currentToastId',
      );
    }

    // 如果指定了 ID，检查是否是当前显示的 toast
    if (toastId != null && toastId != _currentToastId) {
      // 不是当前显示的 toast，从队列中移除
      final removedEntries = _overlayQueue
          .where((entry) => entry.id == toastId)
          .toList();
      _overlayQueue.removeWhere((entry) => entry.id == toastId);

      // 调用队列中被移除的 toast 的 onDismiss 回调
      for (var entry in removedEntries) {
        entry.onDismiss?.call();
      }

      if (kDebugMode) {
        print('SmoothSheetToast: Removed toast from queue, ID: $toastId');
      }
      return;
    }

    // 保存当前 entry 的 onDismiss 回调
    final currentOnDismiss = _overlayQueue.isNotEmpty
        ? null
        : _entry != null
        ? _findEntryById(_currentToastId)?.onDismiss
        : null;

    // 移除当前显示的 toast
    _timer?.cancel();
    _fadeTimer?.cancel();
    _timer = null;
    _fadeTimer = null;
    _entry?.remove();
    _entry = null;
    final dismissedId = _currentToastId;
    _currentToastId = null;
    _currentController = null;
    _currentToastWidth = null;

    if (kDebugMode) {
      print('SmoothSheetToast: Current toast removed, showing next');
    }

    // 在显示下一个 toast 之前调用 onDismiss
    currentOnDismiss?.call();

    _showOverlay();
  }

  /// 根据 ID 查找 entry（用于获取 onDismiss 回调）
  _SheetToastEntry? _findEntryById(String? id) {
    if (id == null) return null;
    try {
      return _overlayQueue.firstWhere((entry) => entry.id == id);
    } catch (e) {
      return null;
    }
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
    _currentToastWidth = null;
  }

  /// 获取当前 toast 数量（包括正在显示的和队列中的）
  int getToastCount() {
    int count = _overlayQueue.length;
    if (_entry != null) {
      count += 1; // 当前正在显示的 toast
    }
    return count;
  }

  /// 将当前显示的 toast 动画到 peek 状态
  void peekToast({
    Duration duration = const Duration(milliseconds: 600),
    Curve curve = Curves.easeOutCubic,
  }) {
    if (_currentController == null || !_currentController!.hasClient) {
      if (kDebugMode) {
        print('SmoothSheetToast: No active toast to peek');
      }
      return;
    }

    if (_currentToastWidth == null) {
      if (kDebugMode) {
        print('SmoothSheetToast: Current toast width is null');
      }
      return;
    }

    final peekOffset = SmoothSheetToastOffset.fromWidth(
      toastWidth: _currentToastWidth!,
    ).peekOffset;

    _currentController!.animateTo(peekOffset, duration: duration, curve: curve);

    if (kDebugMode) {
      print('SmoothSheetToast: Animating toast to peek state');
    }
  }

  /// 将当前显示的 toast 动画到 hidden 状态（完全隐藏）
  void dismissToast({
    Duration duration = const Duration(milliseconds: 600),
    Curve curve = Curves.easeOutCubic,
  }) {
    if (_currentController == null || !_currentController!.hasClient) {
      if (kDebugMode) {
        print('SmoothSheetToast: No active toast to dismiss');
      }
      return;
    }

    if (_currentToastWidth == null) {
      if (kDebugMode) {
        print('SmoothSheetToast: Current toast width is null');
      }
      return;
    }

    final hiddenOffset = SmoothSheetToastOffset.fromWidth(
      toastWidth: _currentToastWidth!,
    ).hiddenOffset;

    _currentController!.animateTo(
      hiddenOffset,
      duration: duration,
      curve: curve,
    );

    if (kDebugMode) {
      print('SmoothSheetToast: Animating toast to hidden state');
    }
  }

  /// 显示 toast
  ///
  /// [builder] Toast 内容构建器，接收 BuildContext 和 ToastController
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
  /// [onDismiss] Toast 被删除时的回调
  void showToast({
    required Widget Function(BuildContext context, ToastController controller)
    builder,
    SheetToastSide side = SheetToastSide.right,
    bool autoDismiss = false,
    Duration toastDuration = const Duration(seconds: 3),
    Duration fadeDuration = const Duration(milliseconds: 350),
    double borderRadius = 16.0,
    Color? backgroundColor,
    bool isDismissible = true,
    Widget? icon,
    VoidCallback? onDismiss,
  }) {
    if (context == null) {
      throw ("Error: Context is null, Please call init(context) before showing toast.");
    }
    if (kDebugMode) {
      print('SmoothSheetToast: showToast called');
    }

    final sheetController = SheetController();
    final toastId = 'toast_${_toastIdCounter++}';

    // 预渲染前先创建临时的 ToastController（用于测量）
    final tempController = ToastController(
      toastId: toastId,
      toastWidth: maxToastWidth,
      sheetController: sheetController,
      onRemove: () => removeToast(toastId),
    );

    // 使用 builder 创建child
    Widget child = Material(
      color: Colors.transparent,
      child: builder(context!, tempController),
    );

    // 预渲染 child 以获取实际尺寸
    _measureChild(
      child: child,
      maxContentWidth: maxToastWidth,
      maxToastHeight: maxToastHeight,
      onMeasured: (measuredSize) {
        if (kDebugMode) {
          print('SmoothSheetToast: Measured size: $measuredSize');
        }
        final showToastWidth = max(
          toasticonSize,
          min(measuredSize.width, maxToastWidth),
        );
        final showToastHeight = max(
          toasticonSize,
          min(measuredSize.height, maxToastHeight),
        );

        // 创建实际的 ToastController（使用真实的 toastWidth）
        final actualController = ToastController(
          toastId: toastId,
          toastWidth: showToastWidth,
          sheetController: sheetController,
          onRemove: () => removeToast(toastId),
        );

        // 使用实际的 controller 重新构建 child
        final actualChild = Material(
          color: Colors.transparent,
          child: builder(context!, actualController),
        );

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
              onDismiss: isDismissible
                  ? () {
                      onDismiss?.call();
                      removeToast(toastId);
                    }
                  : null,
              child: actualChild,
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
            onDismiss: onDismiss,
            toastController: actualController,
          ),
        );

        if (kDebugMode) {
          print(
            'SmoothSheetToast: Toast added to queue, ID: $toastId, queue size: ${_overlayQueue.length}',
          );
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
    final hideAnimation = SheetOffsetDrivenAnimation(
      controller: widget.controller,
      initialValue: 0,
      startOffset: toastOffsets.hiddenOffset,
      endOffset: toastOffsets.peekOffset,
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
                            double hiddenCurveValue = Curves.easeOutCubic
                                .transform(hideAnimation.value);
                            // debugPrint(
                            //   ' ${hiddenCurveValue}',
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
                                    //混合主题色
                                    color: Colors.black.withAlpha(
                                      (51 * hiddenCurveValue).toInt(),
                                    ),
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
