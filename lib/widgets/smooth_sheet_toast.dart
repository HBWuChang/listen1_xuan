import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:get/get.dart';

/// 侧边通知弹出的方向
enum SheetToastSide { left, right }

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
    double? width,
    double? height,
    double iconSize = 48.0,
    double borderRadius = 16.0,
    Color? backgroundColor,
    bool isDismissible = true,
  }) {
    if (context == null) {
      throw ("Error: Context is null, Please call init(context) before showing toast.");
    }

    if (kDebugMode) {
      print('SmoothSheetToast: showToast called');
    }

    final sheetController = SheetController();
    final screenSize = MediaQuery.of(context!).size;

    // 默认宽度和高度
    final toastWidth = width ?? 400.0;
    final toastHeight = height ?? screenSize.height;

    // 计算偏移量
    // 完全隐藏时的偏移量（屏幕外）
    final hiddenOffset = SheetOffset(0.0);
    // 显示一个图标大小时的偏移量
    final peekOffset = SheetOffset(iconSize / toastWidth);
    // 完全显示时的偏移量
    final shownOffset = SheetOffset(1.0);

    OverlayEntry newEntry = OverlayEntry(
      builder: (context) {
        return _SheetToastWidget(
          controller: sheetController,
          side: side,
          width: toastWidth,
          height: toastHeight,
          iconSize: iconSize,
          borderRadius: borderRadius,
          backgroundColor:
              backgroundColor ?? Get.theme.colorScheme.surfaceContainerHighest,
          isDismissible: isDismissible,
          onDismiss: isDismissible ? () => removeToast() : null,
          child: child,
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
            peekOffset,
            duration: fadeDuration,
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }
}

/// Sheet Toast Widget
class _SheetToastWidget extends StatefulWidget {
  final SheetController controller;
  final SheetToastSide side;
  final double width;
  final double height;
  final double iconSize;
  final double borderRadius;
  final Color backgroundColor;
  final bool isDismissible;
  final VoidCallback? onDismiss;
  final Widget child;

  const _SheetToastWidget({
    Key? key,
    required this.controller,
    required this.side,
    required this.width,
    required this.height,
    required this.iconSize,
    required this.borderRadius,
    required this.backgroundColor,
    required this.isDismissible,
    required this.onDismiss,
    required this.child,
  }) : super(key: key);

  @override
  State<_SheetToastWidget> createState() => _SheetToastWidgetState();
}

class _SheetToastWidgetState extends State<_SheetToastWidget> {
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
      // 当滑动到完全隐藏位置时，触发删除
      if (offset <= 0.0) {
        widget.onDismiss?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // 计算偏移量
    final hiddenOffset = SheetOffset(0.0);
    final peekOffset = SheetOffset(widget.iconSize / widget.width);
    final shownOffset = SheetOffset(1.0);

    // 根据侧边确定旋转角度和位置
    final isLeftSide = widget.side == SheetToastSide.left;
    final rotationQuarters = isLeftSide ? 1 : 3; // 左侧顺时针90度，右侧逆时针90度

    if (kDebugMode) {
      print(
        'SmoothSheetToast _SheetToastWidget: Building with width=${widget.width}, height=${widget.height}',
      );
      print(
        'SmoothSheetToast _SheetToastWidget: Offsets - hidden=$hiddenOffset, peek=$peekOffset, shown=$shownOffset',
      );
    }

    return Stack(
      children: [
        Positioned(
          top: isLeftSide ? 0 : null,
          bottom: isLeftSide ? null : 0,
          left: isLeftSide ? 0 : null,
          right: isLeftSide ? null : 0,
          child: RotatedBox(
            quarterTurns: rotationQuarters,
            child: SizedBox(
              width: screenSize.height, // 旋转后的宽度是屏幕高度
              height: widget.width, // 旋转后的高度是toast宽度
              child: SheetViewport(
                child: Sheet(
                  controller: widget.controller,
                  initialOffset: peekOffset, // 初始显示 peek 状态
                  snapGrid: SheetSnapGrid(
                    snaps: [hiddenOffset, peekOffset, shownOffset],
                  ),
                  child: NotificationListener<SheetNotification>(
                    onNotification: (notification) {
                      if (kDebugMode) {
                        print(
                          'SmoothSheetToast: Sheet notification: $notification',
                        );
                      }
                      return false;
                    },
                    child: Container(
                      width: screenSize.height, // Sheet内容宽度
                      height: widget.width, // Sheet内容高度
                      decoration: BoxDecoration(
                        color: widget.backgroundColor,
                        borderRadius: BorderRadius.circular(
                          widget.borderRadius,
                        ),
                      ),
                      child: widget.child,
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
