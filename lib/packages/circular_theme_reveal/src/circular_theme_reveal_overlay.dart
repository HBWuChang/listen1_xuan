import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:listen1_xuan/funcs.dart';

import 'circular_reveal_painter.dart';

/// A widget that provides a circular reveal animation for theme transitions.
///
/// Wrap your [MaterialApp] or root widget with this to enable smooth,
/// Telegram-style circular animations when switching between themes.
///
/// Example:
/// ```dart
/// MaterialApp(
///   theme: ThemeData.light(),
///   darkTheme: ThemeData.dark(),
///   builder: (context, child) {
///     return CircularThemeRevealOverlay(
///       child: child ?? SizedBox.shrink(),
///     );
///   },
/// )
/// ```
class CircularThemeRevealOverlay extends StatefulWidget {
  /// Creates a circular theme reveal overlay.
  ///
  /// The [child] is typically your [MaterialApp] or root widget.
  const CircularThemeRevealOverlay({required this.child, super.key});

  /// The widget below this widget in the tree.
  final Widget child;

  /// Returns the [CircularThemeRevealOverlayState] from the closest instance
  /// of this class that encloses the given context.
  ///
  /// Use this to trigger theme transitions:
  /// ```dart
  /// final overlay = CircularThemeRevealOverlay.of(context);
  /// await overlay?.startTransition(...);
  /// ```
  static CircularThemeRevealOverlayState? of(BuildContext context) {
    return context.findAncestorStateOfType<CircularThemeRevealOverlayState>();
  }

  /// Helper method to get the center position of a widget from its [BuildContext].
  ///
  /// Useful for getting the position of your theme toggle button:
  /// ```dart
  /// final center = CircularThemeRevealOverlay.getCenterFromContext(context);
  /// await overlay.startTransition(center: center, ...);
  /// ```
  static Offset getCenterFromContext(BuildContext context) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;

    final Offset position = box.localToGlobal(Offset.zero);
    final Size size = box.size;

    return Offset(position.dx + size.width / 2, position.dy + size.height / 2);
  }

  @override
  CircularThemeRevealOverlayState createState() =>
      CircularThemeRevealOverlayState();
}

class CircularThemeRevealOverlayState extends State<CircularThemeRevealOverlay>
    with SingleTickerProviderStateMixin {
  final GlobalKey _repaintKey = GlobalKey();
  late AnimationController _controller;
  late Animation<double> _animation;

  ui.Image? _snapshot;
  Offset? _center;
  bool _isAnimating = false;
  bool _isReverse = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    // Usar curva diferente para expansão vs contração
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
      reverseCurve: Curves.easeInExpo, // Contração mais cinematográfica
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  /// Starts a circular reveal transition animation.
  ///
  /// This method captures a snapshot of the current screen, applies the theme
  /// change via [onThemeChange], and animates a circular reveal effect.
  ///
  /// Parameters:
  /// - [center]: The center point of the circular animation (typically the
  ///   position of your theme toggle button).
  /// - [reverse]: If true, the circle contracts (for dark→light transition).
  ///   If false, the circle expands (for light→dark transition).
  /// - [onThemeChange]: Callback to actually change your theme. This is called
  ///   after the snapshot is captured but before the animation starts.
  ///
  /// Example:
  /// ```dart
  /// final overlay = CircularThemeRevealOverlay.of(context);
  /// final center = CircularThemeRevealOverlay.getCenterFromContext(context);
  ///
  /// await overlay?.startTransition(
  ///   center: center,
  ///   reverse: isDarkMode, // true when going dark→light
  ///   onThemeChange: () {
  ///     setState(() {
  ///       isDarkMode = !isDarkMode;
  ///     });
  ///   },
  /// );
  /// ```
  Future<void> startTransition({
    required Offset center,
    required VoidCallback onThemeChange,
    required bool reverse,
  }) async {
    if (_isAnimating) return;

    final ui.Image? capturedImage = await _captureSnapshot();
    if (capturedImage == null) {
      onThemeChange();
      return;
    }

    setState(() {
      _snapshot = capturedImage;
      _center = center;
      _isAnimating = true;
      _isReverse = reverse;
    });

    await Future.delayed(const Duration(milliseconds: 30));

    onThemeChange();

    await Future.delayed(const Duration(milliseconds: 20));

    await _controller.forward(from: 0.0);

    // Pequeno delay para garantir que fade e glow terminem antes de remover
    if (_isReverse) {
      await Future.delayed(const Duration(milliseconds: 16));
    }

    if (mounted) {
      setState(() {
        _isAnimating = false;
        _isReverse = false;
        _snapshot?.dispose();
        _snapshot = null;
        _center = null;
      });
    }

    _controller.reset();
  }

  Future<ui.Image?> _captureSnapshot() async {
    try {
      await Future.delayed(const Duration(milliseconds: 20));

      final RenderRepaintBoundary? boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null || (kDebugMode && !boundary.debugNeedsPaint)) {
        return null;
      }

      if (!mounted) return null;

      final double pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      return image;
    } catch (e) {
      showDebugSnackbar('截图失败', e.toString());
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RepaintBoundary(key: _repaintKey, child: widget.child),
        if (_isAnimating && _snapshot != null && _center != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (BuildContext context, Widget? child) {
                  return CustomPaint(
                    painter: CircularRevealPainter(
                      image: _snapshot!,
                      center: _center!,
                      progress: _animation.value,
                      isReverse: _isReverse,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
