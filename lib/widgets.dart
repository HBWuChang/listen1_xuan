import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

class HoverFollowWidget extends StatefulWidget {
  final Widget child;
  final double maxOffset;
  final double sensitivity;
  final Duration duration;

  /// sensitivity 控制控件移动的灵敏度，1.0为等距，2.0为2倍，0.5为一半
  const HoverFollowWidget({
    Key? key,
    required this.child,
    this.maxOffset = 8.0,
    this.sensitivity = 0.5,
    this.duration = const Duration(milliseconds: 300),
  }) : super(key: key);

  @override
  State<HoverFollowWidget> createState() => _HoverFollowWidgetState();
}

class _HoverFollowWidgetState extends State<HoverFollowWidget>
    with TickerProviderStateMixin {
  Offset _offset = Offset.zero;
  Offset _targetOffset = Offset.zero;
  Offset? _lastPointer;
  late Ticker _ticker;
  final double _spring = 0.12; // 回中速度
  final double _follow = 0.5; // 跟随鼠标的速度
  final double _stopThreshold = 0.05; // 停止阈值，当移动小于此值时停止更新
  bool _isAnimating = false; // 是否正在动画中

  @override
  void initState() {
    super.initState();
    _ticker = this.createTicker(_tick);
  }

  void _tick(Duration _) {
    final oldOffset = _offset;

    _targetOffset = Offset.lerp(_targetOffset, Offset.zero, _spring)!;
    final newOffset = Offset.lerp(_offset, _targetOffset, _follow)!;

    // 检查是否移动足够小，如果是则直接归零并停止ticker
    if (_offset.distance < _stopThreshold &&
        _targetOffset.distance < _stopThreshold) {
      if (_isAnimating) {
        setState(() {
          _offset = Offset.zero;
          _targetOffset = Offset.zero;
          _isAnimating = false;
        });
      }
      _ticker.stop();
      return;
    }

    // 只有当偏移量有实际变化时才触发setState
    final offsetDelta = (newOffset - oldOffset).distance;
    if (offsetDelta > 0.001) {
      setState(() {
        _offset = newOffset;
      });
    }
  }

  void _startAnimation() {
    if (!_isAnimating) {
      _isAnimating = true;
      if (!_ticker.isActive) {
        _ticker.start();
      }
    }
  }

  void _onEnter(PointerEnterEvent event) {
    _lastPointer = event.localPosition;
    _startAnimation();
  }

  void _onHover(PointerHoverEvent event, BoxConstraints constraints) {
    if (_lastPointer == null) {
      _lastPointer = event.localPosition;
      return;
    }
    _startAnimation();
    Offset delta = (event.localPosition - _lastPointer!) * widget.sensitivity;
    Offset newTarget = _targetOffset + delta;
    if (newTarget.distance > widget.maxOffset) {
      newTarget = Offset.fromDirection(newTarget.direction, widget.maxOffset);
    }
    _targetOffset = newTarget;
    _lastPointer = event.localPosition;
  }

  void _onExit(PointerExitEvent event) {
    _lastPointer = null;
    // 鼠标离开时启动动画，让组件回到中心
    _startAnimation();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => MouseRegion(
        onEnter: _onEnter,
        onHover: (e) => _onHover(e, constraints),
        onExit: _onExit,
        child: Transform.translate(offset: _offset, child: widget.child),
      ),
    );
  }
}

/// 带动画横条的页面切换标签栏 Widget
class AnimatedTabBarWidget extends StatelessWidget {
  final dynamic pageController; // 支持 PageController 和 PreloadPageController
  final List<TextSpan> tabLabels;
  final double? barHeight;
  final double? barWidthMultiplier;
  final double? spacing;
  final double? containerHeight;

  const AnimatedTabBarWidget({
    Key? key,
    required this.pageController,
    required this.tabLabels,
    this.barHeight = 4.0,
    this.barWidthMultiplier = 0.7,
    this.spacing = 8.0,
    this.containerHeight = 38.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: containerHeight!,
      child: Column(
        children: [
          SizedBox(
            height: (containerHeight! - barHeight! - spacing!),
            child: Row(
              children: List.generate(tabLabels.length, (index) {
                return Expanded(
                  child: AnimatedBuilder(
                    animation: pageController,
                    builder: (context, child) {
                      double page = 0.0;
                      try {
                        page =
                            pageController.hasClients &&
                                pageController.page != null
                            ? pageController.page!
                            : pageController.initialPage.toDouble();
                      } catch (_) {}

                      // 判断当前标签是否为选中状态
                      bool isSelected = (page.round() == index);

                      return TextButton(
                        onPressed: () {
                          pageController.animateToPage(
                            index,
                            duration: Duration(milliseconds: 300),
                            curve: Curves.ease,
                          );
                        },
                        child: HoverFollowWidget(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text.rich(
                              tabLabels[index],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.normal,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ),
          SizedBox(height: spacing!),
          SizedBox(
            height: barHeight!,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return AnimatedBuilder(
                  animation: pageController,
                  builder: (context, child) {
                    double page = 0.0;
                    try {
                      page =
                          pageController.hasClients &&
                              pageController.page != null
                          ? pageController.page!
                          : pageController.initialPage.toDouble();
                    } catch (_) {}

                    double tabWidth = constraints.maxWidth / tabLabels.length;
                    double minLine = tabWidth * barWidthMultiplier!;
                    double maxLine = tabWidth * (barWidthMultiplier! + 0.7);

                    double progress = (page - page.floor()).abs();
                    double dist = (progress > 0.5) ? 1 - progress : progress;
                    double lineWidth =
                        minLine + (maxLine - minLine) * (dist * 2);
                    double left = page * tabWidth + (tabWidth - lineWidth) / 2;

                    return Stack(
                      children: [
                        Positioned(
                          left: left,
                          width: lineWidth,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            height: barHeight!,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
