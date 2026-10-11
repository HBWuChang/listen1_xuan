import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 整条轨道都可直接定位和拖动，避免触屏用户必须先抓住滑块。
class TrackScrollbar extends StatefulWidget {
  const TrackScrollbar({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  State<TrackScrollbar> createState() => _TrackScrollbarState();
}

class _TrackScrollbarState extends State<TrackScrollbar>
    with SingleTickerProviderStateMixin {
  static const double _hitWidth = 24;
  static const double _thickness = 12;
  static const double _margin = 2;
  int? _pointer;
  bool _metricsUpdateScheduled = false;
  late final AnimationController _thumbOpacity;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _thumbOpacity = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _thumbOpacity.dispose();
    super.dispose();
  }

  void _showThumb() {
    _hideTimer?.cancel();
    _thumbOpacity.value = 1;
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_pointer != null) return;
    _hideTimer = Timer(const Duration(milliseconds: 800), () {
      // ScrollEnd 通知发出时 isScrollingNotifier 可能尚未更新。
      if (mounted && _pointer == null &&
          _position?.isScrollingNotifier.value != true) {
        _thumbOpacity.reverse();
      }
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      _showThumb();
    } else if (notification is ScrollEndNotification) {
      _scheduleHide();
    }
    return false;
  }

  ScrollPosition? get _position {
    final positions = widget.controller.positions;
    if (positions.length != 1) return null;
    final position = positions.single;
    if (!position.hasContentDimensions ||
        !position.hasViewportDimension ||
        axisDirectionToAxis(position.axisDirection) != Axis.vertical ||
        !position.maxScrollExtent.isFinite ||
        position.maxScrollExtent <= position.minScrollExtent) {
      return null;
    }
    return position;
  }

  bool _onMetricsChanged(ScrollMetricsNotification notification) {
    if (notification.depth == 0 && !_metricsUpdateScheduled) {
      // 尺寸通知发生在布局期间；首帧、过滤和窗口缩放后再刷新轨道。
      _metricsUpdateScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _metricsUpdateScheduled = false;
        if (mounted) setState(() {});
      });
    }
    return false;
  }

  void _seek(double y, double trackExtent, double thumbExtent) {
    final position = _position;
    final travel = trackExtent - thumbExtent;
    if (position == null || travel <= 0) return;
    var fraction = ((y - _margin - thumbExtent / 2) / travel).clamp(0.0, 1.0);
    if (position.axisDirection == AxisDirection.up) fraction = 1 - fraction;
    position.jumpTo(
      position.minScrollExtent +
          fraction * (position.maxScrollExtent - position.minScrollExtent),
    );
  }

  void _endPointer(PointerEvent event) {
    if (_pointer == event.pointer) {
      setState(() => _pointer = null);
      _scheduleHide();
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _position == null) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final position = _position;
      if (position == null) return;
      final delta =
          (event as PointerScrollEvent).scrollDelta.dy *
          (position.axisDirection == AxisDirection.up ? -1 : 1);
      _showThumb();
      position.pointerScroll(delta);
      _scheduleHide();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetricsChanged,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: LayoutBuilder(
          builder: (context, constraints) => AnimatedBuilder(
            animation: widget.controller,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              // 轨道覆盖列表边缘，不占用列表的可用宽度。
              child: widget.child,
            ),
            builder: (context, child) {
              final position = _position;
              final trackExtent = math.max(
                0.0,
                constraints.maxHeight - _margin * 2,
              );
              if (position == null || !trackExtent.isFinite || trackExtent == 0) {
                return child!;
              }
              final scrollExtent =
                  position.maxScrollExtent - position.minScrollExtent;
              final thumbExtent = math.min(
                trackExtent,
                math.max(
                  48.0,
                  trackExtent *
                      position.viewportDimension /
                      (scrollExtent + position.viewportDimension),
                ),
              );
              var fraction =
                  ((position.pixels - position.minScrollExtent) / scrollExtent)
                      .clamp(0.0, 1.0);
              if (position.axisDirection == AxisDirection.up)
                fraction = 1 - fraction;
              final thumbTop = _margin + fraction * (trackExtent - thumbExtent);
              final scrollFraction =
                  ((position.pixels - position.minScrollExtent) / scrollExtent)
                      .clamp(0.0, 1.0);
              final semanticStep =
                  position.viewportDimension * 0.8 / scrollExtent;
              return Stack(
                fit: StackFit.expand,
                children: [
                  child!,
                  PositionedDirectional(
                    top: 0,
                    bottom: 0,
                    end: 0,
                    width: _hitWidth,
                    child: Semantics(
                      label: '滚动条',
                      value: '${(scrollFraction * 100).round()}%',
                      increasedValue:
                          '${((scrollFraction + semanticStep).clamp(0.0, 1.0) * 100).round()}%',
                      decreasedValue:
                          '${((scrollFraction - semanticStep).clamp(0.0, 1.0) * 100).round()}%',
                      onIncrease: () => position.jumpTo(
                        math.min(
                          position.maxScrollExtent,
                          position.pixels + position.viewportDimension * 0.8,
                        ),
                      ),
                      onDecrease: () => position.jumpTo(
                        math.max(
                          position.minScrollExtent,
                          position.pixels - position.viewportDimension * 0.8,
                        ),
                      ),
                      child: MouseRegion(
                        cursor: _pointer == null
                            ? SystemMouseCursors.grab
                            : SystemMouseCursors.grabbing,
                        // 立即接管轨道手势，避免外层滚动容器或列表排序抢走拖动。
                        child: RawGestureDetector(
                          behavior: HitTestBehavior.opaque,
                          gestures: {
                            EagerGestureRecognizer:
                                GestureRecognizerFactoryWithHandlers<
                                  EagerGestureRecognizer
                                >(() => EagerGestureRecognizer(), (_) {}),
                          },
                          child: Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (event) {
                              if (_pointer != null ||
                                  event.buttons != kPrimaryButton)
                                return;
                              setState(() => _pointer = event.pointer);
                              _showThumb();
                              _seek(
                                event.localPosition.dy,
                                trackExtent,
                                thumbExtent,
                              );
                            },
                            onPointerMove: (event) {
                              if (_pointer == event.pointer) {
                                _seek(
                                  event.localPosition.dy,
                                  trackExtent,
                                  thumbExtent,
                                );
                              }
                            },
                            onPointerUp: _endPointer,
                            onPointerCancel: _endPointer,
                            onPointerSignal: _onPointerSignal,
                            child: Stack(
                              children: [
                                PositionedDirectional(
                                  top: thumbTop,
                                  end: _margin,
                                  width: _thickness,
                                  height: thumbExtent,
                                  // 只淡出滑块，透明时仍保留整条边缘的命中区域。
                                  child: FadeTransition(
                                    opacity: _thumbOpacity,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: _pointer == null
                                            ? theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.4)
                                            : theme.colorScheme.primary,
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
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
