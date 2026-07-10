import 'dart:async';

import 'package:flutter/material.dart';
import 'package:motor/motor.dart';
import 'draggable_toast_controller.dart';

export 'draggable_toast_controller.dart';
export 'toast_overlay_manager.dart';

/// Toast 吸附边界
enum ToastSnapEdge { left, right, top, bottom }

/// Toast 当前状态
enum ToastState {
  expanded,
  collapsed,
  dragging,
}

/// 可拖动 Toast 的配置
class DraggableToastConfig {
  final EdgeInsets areaPadding;
  final double snapThreshold;
  final Set<ToastSnapEdge> snapEdges;
  final double expandedWidth;
  final double expandedHeight;
  final double collapsedSize;
  final double borderRadius;
  final double collapsedBorderRadius;

  const DraggableToastConfig({
    this.areaPadding = const EdgeInsets.all(16),
    this.snapThreshold = 60.0,
    this.snapEdges = const {
      ToastSnapEdge.left,
      ToastSnapEdge.right,
      ToastSnapEdge.top,
      ToastSnapEdge.bottom,
    },
    this.expandedWidth = 280,
    this.expandedHeight = 160,
    this.collapsedSize = 48,
    this.borderRadius = 16,
    this.collapsedBorderRadius = 24,
  });
}

/// 使用 Motor 实现的可拖动 Toast 组件
class DraggableMotorToast extends StatefulWidget {
  final Widget Function(BuildContext context, ToastState state) builder;
  final Widget icon;
  final DraggableToastConfig config;
  final Offset? initialPosition;
  final Color? backgroundColor;
  final Color? collapsedBackgroundColor;
  final VoidCallback? onDismiss;
  final Motion motion;
  final DraggableToastController? controller;
  final bool autoDismiss;
  final Duration autoDismissDuration;
  final Duration initialDisplayDuration;
  final bool initialLockedMode;

  const DraggableMotorToast({
    super.key,
    required this.builder,
    this.icon = const Icon(Icons.notifications_rounded, color: Colors.white),
    this.config = const DraggableToastConfig(),
    this.initialPosition,
    this.backgroundColor,
    this.collapsedBackgroundColor,
    this.onDismiss,
    this.motion = const CupertinoMotion.bouncy(),
    this.controller,
    this.autoDismiss = false,
    this.autoDismissDuration = const Duration(seconds: 5),
    this.initialDisplayDuration = const Duration(seconds: 3),
    this.initialLockedMode = false,
  });

  @override
  State<DraggableMotorToast> createState() => _DraggableMotorToastState();
}

class _DraggableMotorToastState extends State<DraggableMotorToast>
    with TickerProviderStateMixin {
  late MotionController<Offset> _positionController;
  late MotionController<double> _scaleController;
  late MotionController<double> _expandController;

  ToastState _state = ToastState.expanded;
  Offset _currentPosition = Offset.zero;
  bool _isDragging = false;
  ToastSnapEdge? _snappedEdge;
  Timer? _autoPeekTimer;
  Timer? _autoDismissTimer;
  Size? _cachedAreaSize;
  bool _needsInitialCentering = false;

  @override
  void initState() {
    super.initState();

    // If no explicit position, we'll center on first layout
    _needsInitialCentering = widget.initialPosition == null;
    final initialPos = widget.initialPosition ?? Offset.zero;

    _positionController = MotionController<Offset>(
      motion: widget.motion,
      vsync: this,
      converter: const OffsetMotionConverter(),
      initialValue: initialPos,
    );

    _scaleController = MotionController<double>(
      motion: widget.motion,
      vsync: this,
      converter: const SingleMotionConverter(),
      initialValue: 1.0,
    );

    _expandController = MotionController<double>(
      motion: widget.motion,
      vsync: this,
      converter: const SingleMotionConverter(),
      initialValue: 1.0,
    );

    _currentPosition = initialPos;

    widget.controller?.bindCallbacks(
      onExpand: _controllerExpand,
      onPeek: _controllerPeek,
      onHide: _controllerHide,
    );

    if (widget.initialLockedMode) {
      widget.controller?.enterLockedMode();
    }

    _startAutoPeekTimer();
  }

  @override
  void dispose() {
    _autoPeekTimer?.cancel();
    _autoDismissTimer?.cancel();
    _positionController.dispose();
    _scaleController.dispose();
    _expandController.dispose();
    super.dispose();
  }

  void _startAutoPeekTimer() {
    _autoPeekTimer?.cancel();
    _autoPeekTimer = Timer(widget.initialDisplayDuration, () {
      if (_state == ToastState.expanded && !_isDragging) {
        _performPeek();
      }
    });
  }

  void _startAutoDismissTimer() {
    if (!widget.autoDismiss) return;
    if (widget.controller?.isLockedMode ?? false) return;

    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(widget.autoDismissDuration, () {
      if (_state == ToastState.collapsed) {
        widget.onDismiss?.call();
      }
    });
  }

  void _cancelAutoDismissTimer() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
  }

  void _controllerExpand() {
    if (_state == ToastState.collapsed || _state == ToastState.dragging) {
      _performExpand();
    }
  }

  void _controllerPeek() {
    if (_state == ToastState.expanded || _state == ToastState.dragging) {
      _performPeek();
    }
  }

  void _controllerHide() {
    _expandController.animateTo(0.0);
    setState(() => _state = ToastState.collapsed);
    Future.delayed(const Duration(milliseconds: 400), () {
      widget.onDismiss?.call();
    });
  }

  void _performPeek() {
    _cancelAutoDismissTimer();
    final areaSize = _cachedAreaSize;
    if (areaSize == null) return;

    final config = widget.config;
    final center = Offset(
      _currentPosition.dx + config.expandedWidth / 2,
      _currentPosition.dy + config.expandedHeight / 2,
    );

    final distances = <ToastSnapEdge, double>{};
    if (config.snapEdges.contains(ToastSnapEdge.left)) {
      distances[ToastSnapEdge.left] = center.dx;
    }
    if (config.snapEdges.contains(ToastSnapEdge.right)) {
      distances[ToastSnapEdge.right] = areaSize.width - center.dx;
    }
    if (config.snapEdges.contains(ToastSnapEdge.top)) {
      distances[ToastSnapEdge.top] = center.dy;
    }
    if (config.snapEdges.contains(ToastSnapEdge.bottom)) {
      distances[ToastSnapEdge.bottom] = areaSize.height - center.dy;
    }

    if (distances.isEmpty) return;

    final nearestEdge =
        distances.entries.reduce((a, b) => a.value < b.value ? a : b).key;

    _snappedEdge = nearestEdge;
    final snapPos = _getSnapPosition(nearestEdge, _currentPosition, areaSize);
    _currentPosition = snapPos;
    _positionController.animateTo(snapPos);
    _expandController.animateTo(0.0);
    setState(() => _state = ToastState.collapsed);
    _startAutoDismissTimer();
  }

  void _performExpand() {
    _cancelAutoDismissTimer();
    final areaSize = _cachedAreaSize;
    if (areaSize == null) return;

    final config = widget.config;
    double newX = _currentPosition.dx;
    double newY = _currentPosition.dy;

    if (_snappedEdge == ToastSnapEdge.right) {
      newX = areaSize.width - config.expandedWidth;
    } else if (_snappedEdge == ToastSnapEdge.bottom) {
      newY = areaSize.height - config.expandedHeight;
    }

    newX = newX.clamp(0.0, areaSize.width - config.expandedWidth);
    newY = newY.clamp(0.0, areaSize.height - config.expandedHeight);

    _currentPosition = Offset(newX, newY);
    _snappedEdge = null;

    _positionController.animateTo(_currentPosition);
    _expandController.animateTo(1.0);
    setState(() => _state = ToastState.expanded);
    _startAutoPeekTimer();
  }

  Size _getAvailableArea(BoxConstraints constraints) {
    final padding = widget.config.areaPadding;
    return Size(
      constraints.maxWidth - padding.left - padding.right,
      constraints.maxHeight - padding.top - padding.bottom,
    );
  }

  ToastSnapEdge? _getSnapEdge(Offset position, Size areaSize) {
    final threshold = widget.config.snapThreshold;
    final config = widget.config;
    final currentWidth = _state == ToastState.collapsed
        ? config.collapsedSize
        : config.expandedWidth;
    final currentHeight = _state == ToastState.collapsed
        ? config.collapsedSize
        : config.expandedHeight;

    if (config.snapEdges.contains(ToastSnapEdge.left) &&
        position.dx < threshold) {
      return ToastSnapEdge.left;
    }
    if (config.snapEdges.contains(ToastSnapEdge.right) &&
        (areaSize.width - position.dx - currentWidth) < threshold) {
      return ToastSnapEdge.right;
    }
    if (config.snapEdges.contains(ToastSnapEdge.top) &&
        position.dy < threshold) {
      return ToastSnapEdge.top;
    }
    if (config.snapEdges.contains(ToastSnapEdge.bottom) &&
        (areaSize.height - position.dy - currentHeight) < threshold) {
      return ToastSnapEdge.bottom;
    }
    return null;
  }

  Offset _getSnapPosition(ToastSnapEdge edge, Offset current, Size areaSize) {
    final config = widget.config;
    final collapsedSize = config.collapsedSize;

    switch (edge) {
      case ToastSnapEdge.left:
        return Offset(0, current.dy.clamp(0, areaSize.height - collapsedSize));
      case ToastSnapEdge.right:
        return Offset(
          areaSize.width - collapsedSize,
          current.dy.clamp(0, areaSize.height - collapsedSize),
        );
      case ToastSnapEdge.top:
        return Offset(current.dx.clamp(0, areaSize.width - collapsedSize), 0);
      case ToastSnapEdge.bottom:
        return Offset(
          current.dx.clamp(0, areaSize.width - collapsedSize),
          areaSize.height - collapsedSize,
        );
    }
  }

  void _onPanStart(DragStartDetails details) {
    _isDragging = true;
    _autoPeekTimer?.cancel();
    _cancelAutoDismissTimer();
    setState(() => _state = ToastState.dragging);
    _scaleController.animateTo(1.05);
    if (_expandController.value < 1.0) {
      _expandController.animateTo(1.0);
    }
  }

  void _onPanUpdate(DragUpdateDetails details, Size areaSize) {
    if (!_isDragging) return;
    final config = widget.config;
    final newX = (_currentPosition.dx + details.delta.dx)
        .clamp(0.0, areaSize.width - config.expandedWidth);
    final newY = (_currentPosition.dy + details.delta.dy)
        .clamp(0.0, areaSize.height - config.expandedHeight);
    _currentPosition = Offset(newX, newY);
    _positionController.value = _currentPosition;
  }

  void _onPanEnd(DragEndDetails details, Size areaSize) {
    _isDragging = false;
    _scaleController.animateTo(1.0);

    final config = widget.config;
    final velocity = details.velocity.pixelsPerSecond;
    const decelerationFactor = 0.15;
    final projectedX = (_currentPosition.dx + velocity.dx * decelerationFactor)
        .clamp(0.0, areaSize.width - config.expandedWidth);
    final projectedY = (_currentPosition.dy + velocity.dy * decelerationFactor)
        .clamp(0.0, areaSize.height - config.expandedHeight);
    final projectedPosition = Offset(projectedX, projectedY);

    final snapEdge = _getSnapEdge(projectedPosition, areaSize);

    if (snapEdge != null) {
      _snappedEdge = snapEdge;
      final snapPos = _getSnapPosition(snapEdge, projectedPosition, areaSize);
      _currentPosition = snapPos;
      _positionController.animateTo(snapPos, withVelocity: velocity);
      _expandController.animateTo(0.0);
      setState(() => _state = ToastState.collapsed);
      _startAutoDismissTimer();
    } else {
      _snappedEdge = null;
      _currentPosition = projectedPosition;
      _positionController.animateTo(projectedPosition, withVelocity: velocity);
      _expandController.animateTo(1.0);
      setState(() => _state = ToastState.expanded);
      _startAutoPeekTimer();
    }
  }

  void _onCollapsedTap(Size areaSize) {
    if (_state != ToastState.collapsed) return;
    _performExpand();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final bgColor =
        widget.backgroundColor ?? Theme.of(context).colorScheme.primaryContainer;
    final collapsedBgColor =
        widget.collapsedBackgroundColor ?? Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final areaSize = _getAvailableArea(constraints);
        _cachedAreaSize = areaSize;

        // 首次布局时居中定位
        if (_needsInitialCentering) {
          _needsInitialCentering = false;
          final centeredX =
              (areaSize.width - widget.config.expandedWidth) / 2;
          final centeredY =
              (areaSize.height - widget.config.expandedHeight) / 3;
          _currentPosition = Offset(
            centeredX.clamp(0.0, areaSize.width - widget.config.expandedWidth),
            centeredY.clamp(0.0, areaSize.height - widget.config.expandedHeight),
          );
          _positionController.value = _currentPosition;
        }

        return Padding(
          padding: config.areaPadding,
          child: SizedBox(
            width: areaSize.width,
            height: areaSize.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ListenableBuilder(
                  listenable: Listenable.merge([
                    _positionController,
                    _scaleController,
                    _expandController,
                  ]),
                  builder: (context, _) {
                    final position = _positionController.value;
                    final scale = _scaleController.value;
                    final expand = _expandController.value;

                    final currentWidth = config.collapsedSize +
                        (config.expandedWidth - config.collapsedSize) * expand;
                    final currentHeight = config.collapsedSize +
                        (config.expandedHeight - config.collapsedSize) * expand;
                    final currentRadius = config.collapsedBorderRadius +
                        (config.borderRadius - config.collapsedBorderRadius) *
                            expand;
                    final currentColor =
                        Color.lerp(collapsedBgColor, bgColor, expand) ?? bgColor;

                    return Positioned(
                      left: position.dx,
                      top: position.dy,
                      child: GestureDetector(
                        onPanStart: _onPanStart,
                        onPanUpdate: (d) => _onPanUpdate(d, areaSize),
                        onPanEnd: (d) => _onPanEnd(d, areaSize),
                        onTap: _state == ToastState.collapsed
                            ? () => _onCollapsedTap(areaSize)
                            : null,
                        child: Transform.scale(
                          scale: scale,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 50),
                            width: currentWidth,
                            height: currentHeight,
                            decoration: BoxDecoration(
                              color: currentColor,
                              borderRadius: BorderRadius.circular(currentRadius),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: expand.clamp(0.0, 1.0),
                                    child: IgnorePointer(
                                      ignoring: _state == ToastState.collapsed,
                                      child: OverflowBox(
                                        alignment: Alignment.topLeft,
                                        maxWidth: config.expandedWidth,
                                        maxHeight: config.expandedHeight,
                                        minWidth: config.expandedWidth,
                                        minHeight: config.expandedHeight,
                                        child: Material(
                                          type: MaterialType.transparency,
                                          child: widget.builder(context, _state),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Opacity(
                                  opacity: (1.0 - expand).clamp(0.0, 1.0),
                                  child: SizedBox(
                                    width: config.collapsedSize,
                                    height: config.collapsedSize,
                                    child: Center(child: widget.icon),
                                  ),
                                ),
                                if (widget.onDismiss != null && expand > 0.5)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Opacity(
                                      opacity:
                                          ((expand - 0.5) * 2).clamp(0.0, 1.0),
                                      child: GestureDetector(
                                        onTap: widget.onDismiss,
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
