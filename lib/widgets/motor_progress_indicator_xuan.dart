import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';

import 'progress_indicator_xuan.dart' as xuan;

class MotorCircularProgressIndicator extends xuan.ProgressIndicator {
  const MotorCircularProgressIndicator({
    super.key,
    super.value,
    super.backgroundColor,
    super.color,
    super.valueColor,
    this.strokeWidth,
    this.strokeAlign,
    super.semanticsLabel,
    super.semanticsValue,
    this.strokeCap,
    this.constraints,
    this.trackGap,
    this.padding,
    this.year2023,
    this.motion = const CupertinoMotion.bouncy(
      duration: Duration(milliseconds: 500),
    ),
    this.morphMotion = const CupertinoMotion.smooth(
      duration: Duration(milliseconds: 700),
    ),
  });

  const MotorCircularProgressIndicator.adaptive({
    super.key,
    super.value,
    super.backgroundColor,
    super.valueColor,
    this.strokeWidth,
    super.semanticsLabel,
    super.semanticsValue,
    this.strokeCap,
    this.strokeAlign,
    this.constraints,
    this.trackGap,
    this.padding,
    this.year2023,
    this.motion,
    this.morphMotion,
  });

  final double? strokeWidth;
  final double? strokeAlign;
  final StrokeCap? strokeCap;
  final BoxConstraints? constraints;
  final double? trackGap;
  final bool? year2023;
  final EdgeInsetsGeometry? padding;

  /// The motion property used by the motor package to define the spring effect
  /// Defaults to CupertinoMotion.bouncy().
  final Motion? motion;

  /// The motion used specifically for transitioning between determinate (value)
  /// and indeterminate (null) states.
  /// Defaults to CupertinoMotion.smooth().
  final Motion? morphMotion;

  static const double strokeAlignInside = -1.0;
  static const double strokeAlignCenter = 0.0;
  static const double strokeAlignOutside = 1.0;

  @override
  State<MotorCircularProgressIndicator> createState() =>
      _MotorCircularProgressIndicatorState();
}

class _MotorCircularProgressIndicatorState
    extends State<MotorCircularProgressIndicator>
    with TickerProviderStateMixin {
  static const int _kIndeterminateCircularDuration = 1333 * 2222;
  static const int _pathCount = _kIndeterminateCircularDuration ~/ 1333;
  static const int _rotationCount = _kIndeterminateCircularDuration ~/ 2222;

  // Indeterminate Tweens
  static final Animatable<double> _strokeHeadTween = CurveTween(
    curve: const Interval(0.0, 0.5, curve: Curves.fastOutSlowIn),
  ).chain(CurveTween(curve: const SawTooth(_pathCount)));

  static final Animatable<double> _strokeTailTween = CurveTween(
    curve: const Interval(0.5, 1.0, curve: Curves.fastOutSlowIn),
  ).chain(CurveTween(curve: const SawTooth(_pathCount)));

  static final Animatable<double> _offsetTween = CurveTween(
    curve: const SawTooth(_pathCount),
  );

  static final Animatable<double> _rotationTween = CurveTween(
    curve: const SawTooth(_rotationCount),
  );

  late SequenceMotionController<int, double> _indeterminateController;

  // Motor package property
  late final SingleMotionController _valueMotionController;
  late final SingleMotionController _morphMotionController;

  @override
  void initState() {
    super.initState();
    _valueMotionController = SingleMotionController(
      initialValue: widget.value ?? 0.0,
      motion: widget.motion ?? const CupertinoMotion.bouncy(),
      vsync: this,
    );

    // Used to morph between determinate (0.0) and indeterminate (1.0) states
    _morphMotionController = SingleMotionController(
      initialValue: widget.value == null ? 1.0 : 0.0,
      motion: widget.morphMotion ?? const CupertinoMotion.smooth(),
      vsync: this,
    );

    _indeterminateController = SequenceMotionController<int, double>(
      initialValue: 0.0,
      motion: Motion.linear(
        const Duration(milliseconds: _kIndeterminateCircularDuration),
      ),
      converter: const SingleMotionConverter(),
      vsync: this,
    );

    if (widget.value == null) {
      _startIndeterminate();
    }
  }

  void _startIndeterminate() {
    if (!_indeterminateController.isPlayingSequence) {
      _indeterminateController.playSequence(
        MotionSequence.steps<double>(
          [0.0, 1.0],
          motion: Motion.linear(
            const Duration(milliseconds: _kIndeterminateCircularDuration),
          ),
          loop: LoopMode.loop,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(MotorCircularProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update motion config if deeply modified
    if (widget.motion != oldWidget.motion) {
      _valueMotionController.motion =
          widget.motion ?? const CupertinoMotion.bouncy();
    }
    if (widget.morphMotion != oldWidget.morphMotion) {
      _morphMotionController.motion =
          widget.morphMotion ?? const CupertinoMotion.smooth();
    }

    if (widget.value != null && oldWidget.value == null) {
      // Indeterminate to Determinate
      _morphMotionController.animateTo(0.0); // Morph back to determinate
      _valueMotionController.animateTo(widget.value!); // Spring to exact value
      _indeterminateController.stop();
    } else if (widget.value == null && oldWidget.value != null) {
      // Determinate to Indeterminate
      _morphMotionController.animateTo(1.0); // Morph to indeterminate
      // Start spinning
      _startIndeterminate();
    } else if (widget.value != null && widget.value != oldWidget.value) {
      // Value to Value
      _valueMotionController.animateTo(widget.value!);
    }
  }

  @override
  void dispose() {
    _indeterminateController.dispose();
    _valueMotionController.dispose();
    _morphMotionController.dispose();
    super.dispose();
  }

  Widget _buildMaterialIndicator(BuildContext context) {
    final ProgressIndicatorThemeData indicatorTheme = ProgressIndicatorTheme.of(
      context,
    );

    final Color? trackColor =
        widget.backgroundColor ?? indicatorTheme.circularTrackColor;
    final double strokeWidth =
        widget.strokeWidth ?? indicatorTheme.strokeWidth ?? 4.0;
    final double strokeAlign =
        widget.strokeAlign ??
        indicatorTheme.strokeAlign ??
        MotorCircularProgressIndicator.strokeAlignCenter;
    final StrokeCap? strokeCap = widget.strokeCap ?? indicatorTheme.strokeCap;
    final BoxConstraints constraints =
        widget.constraints ??
        indicatorTheme.constraints ??
        const BoxConstraints(minWidth: 36.0, minHeight: 36.0);
    final double trackGap = widget.trackGap ?? indicatorTheme.trackGap ?? 4.0;
    final EdgeInsetsGeometry effectivePadding =
        widget.padding ??
        indicatorTheme.circularTrackPadding ??
        EdgeInsets.zero;

    Widget result = ConstrainedBox(
      constraints: constraints,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _indeterminateController,
          _valueMotionController,
          _morphMotionController,
        ]),
        builder: (context, child) {
          final morph = _morphMotionController.value; // 0.0=det, 1.0=indet
          final detValue = _valueMotionController.value;

          // Indeterminate calculations
          final headValue = _strokeHeadTween.evaluate(_indeterminateController);
          final tailValue = _strokeTailTween.evaluate(_indeterminateController);
          final offsetValue = _offsetTween.evaluate(_indeterminateController);
          final rotationValue = _rotationTween.evaluate(
            _indeterminateController,
          );

          final arcSweepIndet = math.max(
            headValue * 3 / 2 * math.pi - tailValue * 3 / 2 * math.pi,
            0.001,
          );
          final arcStartIndet =
              (-math.pi / 2.0) +
              tailValue * 3 / 2 * math.pi +
              rotationValue * math.pi * 2.0 +
              offsetValue * 0.5 * math.pi;

          // Determinate calculations
          final arcSweepDet =
              clampDouble(detValue, 0.0, 1.0) * (math.pi * 2.0 - 0.001);
          final arcStartDet = -math.pi / 2.0;

          // Morph between the two
          final arcSweep = arcSweepDet * (1 - morph) + arcSweepIndet * morph;
          final arcStart = arcStartDet * (1 - morph) + arcStartIndet * morph;

          final isEffectivelyNull = (widget.value == null && morph > 0.99);

          return CustomPaint(
            painter: _MotorCircularProgressIndicatorPainter(
              trackColor: trackColor,
              valueColor:
                  widget.valueColor?.value ??
                  widget.color ??
                  indicatorTheme.color ??
                  Theme.of(context).colorScheme.primary,
              value: isEffectivelyNull
                  ? null
                  : detValue, // Fallback to handle full indeterminate appearance
              arcStart: arcStart,
              arcSweep: arcSweep,
              strokeWidth: strokeWidth,
              strokeAlign: strokeAlign,
              strokeCap: strokeCap,
              trackGap: trackGap * (1 - morph),
            ),
          );
        },
      ),
    );

    if (effectivePadding != EdgeInsets.zero) {
      result = Padding(padding: effectivePadding, child: result);
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return _buildMaterialIndicator(context);
  }
}

class _MotorCircularProgressIndicatorPainter extends CustomPainter {
  _MotorCircularProgressIndicatorPainter({
    this.trackColor,
    required this.valueColor,
    required this.value,
    required this.arcStart,
    required this.arcSweep,
    required this.strokeWidth,
    required this.strokeAlign,
    this.strokeCap,
    this.trackGap,
  });

  final Color? trackColor;
  final Color valueColor;
  final double? value;
  final double arcStart;
  final double arcSweep;
  final double strokeWidth;
  final double strokeAlign;
  final StrokeCap? strokeCap;
  final double? trackGap;

  static const double _twoPi = math.pi * 2.0;
  static const double _epsilon = .001;
  static const double _sweep = _twoPi - _epsilon;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = valueColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final double strokeOffset = strokeWidth / 2 * -strokeAlign;
    final Offset arcBaseOffset = Offset(strokeOffset, strokeOffset);
    final Size arcActualSize = Size(
      size.width - strokeOffset * 2,
      size.height - strokeOffset * 2,
    );
    final bool hasGap = trackGap != null && trackGap! > 0;

    if (trackColor != null) {
      final Paint backgroundPaint = Paint()
        ..color = trackColor!
        ..strokeWidth = strokeWidth
        ..strokeCap = strokeCap ?? StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (hasGap && value != null && value! > _epsilon) {
        final double arcRadius = arcActualSize.shortestSide / 2;
        final double strokeRadius = strokeWidth / arcRadius;
        final double gapRadius = trackGap! / arcRadius;
        final double startGap = strokeRadius + gapRadius;
        final double endGap = value! < _epsilon ? startGap : startGap * 2;
        final double startSweep = (-math.pi / 2.0) + startGap;
        final double endSweep = math.max(
          0.0,
          _twoPi - clampDouble(value!, 0.0, 1.0) * _twoPi - endGap,
        );
        canvas.save();
        canvas.scale(-1, 1);
        canvas.translate(-size.width, 0);
        canvas.drawArc(
          arcBaseOffset & arcActualSize,
          startSweep,
          endSweep,
          false,
          backgroundPaint,
        );
        canvas.restore();
      } else {
        canvas.drawArc(
          arcBaseOffset & arcActualSize,
          0,
          _sweep,
          false,
          backgroundPaint,
        );
      }
    }

    if (value == null && strokeCap == null) {
      paint.strokeCap = StrokeCap.square;
    } else {
      paint.strokeCap = strokeCap ?? StrokeCap.butt;
    }

    canvas.drawArc(
      arcBaseOffset & arcActualSize,
      arcStart,
      arcSweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_MotorCircularProgressIndicatorPainter oldPainter) {
    return oldPainter.trackColor != trackColor ||
        oldPainter.valueColor != valueColor ||
        oldPainter.value != value ||
        oldPainter.arcStart != arcStart ||
        oldPainter.arcSweep != arcSweep ||
        oldPainter.strokeWidth != strokeWidth ||
        oldPainter.strokeAlign != strokeAlign ||
        oldPainter.strokeCap != strokeCap ||
        oldPainter.trackGap != trackGap;
  }
}
