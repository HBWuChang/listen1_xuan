// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'package:flutter/semantics.dart';
///
/// @docImport 'refresh_indicator.dart';
library;

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/src/material/color_scheme.dart';
import 'package:flutter/src/material/material.dart';
import 'package:flutter/src/material/progress_indicator_theme.dart';
import 'package:flutter/src/material/theme.dart';

import 'cubic_derivative.dart';

class _CombineAnimatable extends Animatable<double> {
  _CombineAnimatable(this.a, this.b, this.op);

  final Animatable<double> a;
  final Animatable<double> b;
  final double Function(double av, double bv) op;

  @override
  double transform(double t) => op(a.transform(t), b.transform(t));
}

class _UnaryAnimatable extends Animatable<double> {
  _UnaryAnimatable(this.base, this.op);

  final Animatable<double> base;
  final double Function(double v) op;

  @override
  double transform(double t) => op(base.transform(t));
}

extension AnimatableMath on Animatable<double> {
  Animatable<double> plus(Animatable<double> other) =>
      _CombineAnimatable(this, other, (double a, double b) => a + b);

  Animatable<double> minus(Animatable<double> other) =>
      _CombineAnimatable(this, other, (double a, double b) => a - b);

  Animatable<double> scale(double factor) =>
      _UnaryAnimatable(this, (double value) => value * factor);
}

const int _kIndeterminateLinearDuration = 1800;
const int _kIndeterminateCircularDuration = 1333 * 2222;

enum _ActivityIndicatorType { material, adaptive }

/// A base class for Material Design progress indicators.
///
/// This widget cannot be instantiated directly. For a linear progress
/// indicator, see [LinearProgressIndicator]. For a circular progress indicator,
/// see [CircularProgressIndicator].
///
/// See also:
///
///  * <https://material.io/components/progress-indicators>
abstract class ProgressIndicator extends StatefulWidget {
  /// Creates a progress indicator.
  ///
  /// {@template flutter.material.ProgressIndicator.ProgressIndicator}
  /// The [value] argument can either be null for an indeterminate
  /// progress indicator, or a non-null value between 0.0 and 1.0 for a
  /// determinate progress indicator.
  ///
  /// ## Accessibility
  ///
  /// The [semanticsLabel] can be used to identify the purpose of this progress
  /// bar for screen reading software. The [semanticsValue] property may be used
  /// for determinate progress indicators to indicate how much progress has been made.
  /// {@endtemplate}
  const ProgressIndicator({
    super.key,
    this.value,
    this.backgroundColor,
    this.color,
    this.valueColor,
    this.semanticsLabel,
    this.semanticsValue,
  });

  /// If non-null, the value of this progress indicator.
  ///
  /// A value of 0.0 means no progress and 1.0 means that progress is complete.
  /// The value will be clamped to be in the range 0.0-1.0.
  ///
  /// If null, this progress indicator is indeterminate, which means the
  /// indicator displays a predetermined animation that does not indicate how
  /// much actual progress is being made.
  final double? value;

  /// The progress indicator's background color.
  ///
  /// It is up to the subclass to implement this in whatever way makes sense
  /// for the given use case. See the subclass documentation for details.
  final Color? backgroundColor;

  /// {@template flutter.progress_indicator.ProgressIndicator.color}
  /// The progress indicator's color.
  ///
  /// This is only used if [ProgressIndicator.valueColor] is null.
  /// If [ProgressIndicator.color] is also null, then the ambient
  /// [ProgressIndicatorThemeData.color] will be used. If that
  /// is null then the current theme's [ColorScheme.primary] will
  /// be used by default.
  /// {@endtemplate}
  final Color? color;

  /// The progress indicator's color as an animated value.
  ///
  /// If null, the progress indicator is rendered with [color]. If that is null,
  /// then it will use the ambient [ProgressIndicatorThemeData.color]. If that
  /// is also null then it defaults to the current theme's [ColorScheme.primary].
  final Animation<Color?>? valueColor;

  /// {@template flutter.progress_indicator.ProgressIndicator.semanticsLabel}
  /// The [SemanticsProperties.label] for this progress indicator.
  ///
  /// This value indicates the purpose of the progress bar, and will be
  /// read out by screen readers to indicate the purpose of this progress
  /// indicator.
  /// {@endtemplate}
  final String? semanticsLabel;

  /// {@template flutter.progress_indicator.ProgressIndicator.semanticsValue}
  /// The [SemanticsProperties.value] for this progress indicator.
  ///
  /// This will be used in conjunction with the [semanticsLabel] by
  /// screen reading software to identify the widget, and is primarily
  /// intended for use with determinate progress indicators to announce
  /// how far along they are.
  ///
  /// For determinate progress indicators, this will be defaulted to
  /// [ProgressIndicator.value] expressed as a percentage, i.e. `0.1` will
  /// become '10%'.
  /// {@endtemplate}
  final String? semanticsValue;

  Color _getValueColor(BuildContext context, {Color? defaultColor}) {
    return valueColor?.value ??
        color ??
        ProgressIndicatorTheme.of(context).color ??
        defaultColor ??
        Theme.of(context).colorScheme.primary;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      PercentProperty(
        'value',
        value,
        showName: false,
        ifNull: '<indeterminate>',
      ),
    );
  }

  Widget _buildSemanticsWrapper({
    required BuildContext context,
    required Widget child,
  }) {
    String? expandedSemanticsValue = semanticsValue;
    if (value != null) {
      expandedSemanticsValue ??= '${(value! * 100).round()}%';
    }
    return Semantics(
      label: semanticsLabel,
      value: expandedSemanticsValue,
      child: child,
    );
  }
}

class _CircularProgressIndicatorPainter extends CustomPainter {
  _CircularProgressIndicatorPainter({
    this.trackColor,
    required this.valueColor,
    required this.value,
    required this.headValue,
    required this.tailValue,
    required this.offsetValue,
    required this.rotationValue,
    required this.strokeWidth,
    required this.strokeAlign,
    this.strokeCap,
    this.trackGap,
    this.useROnValue = false,
  }) : arcStart = value != null
           ? useROnValue
                 ? _startAngle + rotationValue * math.pi * 2.0
                 : _startAngle
           : _startAngle +
                 tailValue * 3 / 2 * math.pi +
                 rotationValue * math.pi * 2.0 +
                 offsetValue * 0.5 * math.pi,
       arcSweep = value != null
           ? clampDouble(value, 0.0, 1.0) * _sweep
           : math.max(
               headValue * 3 / 2 * math.pi - tailValue * 3 / 2 * math.pi,
               _epsilon,
             );

  final Color? trackColor;
  final Color valueColor;
  final double? value;
  final double headValue;
  final double tailValue;
  final double offsetValue;
  final double rotationValue;
  final double strokeWidth;
  final double strokeAlign;
  final double arcStart;
  final double arcSweep;
  final StrokeCap? strokeCap;
  final double? trackGap;
  final bool useROnValue;

  static const double _twoPi = math.pi * 2.0;
  static const double _epsilon = .001;
  // Canvas.drawArc(r, 0, 2*PI) doesn't draw anything, so just get close.
  static const double _sweep = _twoPi - _epsilon;
  static const double _startAngle = -math.pi / 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = valueColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Use the negative operator as intended to keep the exposed constant value
    // as users are already familiar with.
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
      // If hasGap is true, draw the background arc with a gap.
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
        // Flip the canvas for the background arc.
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
        // Restore the canvas to draw the foreground arc.
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
      // Indeterminate
      paint.strokeCap = StrokeCap.square;
    } else {
      // Butt when determinate (value != null) && strokeCap == null;
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
  bool shouldRepaint(_CircularProgressIndicatorPainter oldPainter) {
    return oldPainter.trackColor != trackColor ||
        oldPainter.valueColor != valueColor ||
        oldPainter.value != value ||
        oldPainter.headValue != headValue ||
        oldPainter.tailValue != tailValue ||
        oldPainter.offsetValue != offsetValue ||
        oldPainter.rotationValue != rotationValue ||
        oldPainter.strokeWidth != strokeWidth ||
        oldPainter.strokeAlign != strokeAlign ||
        oldPainter.strokeCap != strokeCap ||
        oldPainter.trackGap != trackGap;
  }
}

class CircularProgressIndicator extends ProgressIndicator {
  /// Creates a circular progress indicator.
  ///
  /// {@macro flutter.material.ProgressIndicator.ProgressIndicator}
  const CircularProgressIndicator({
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
    this.valueMilliseconds = 300,
  }) : _indicatorType = _ActivityIndicatorType.material;

  /// Creates an adaptive progress indicator that is a
  /// [CupertinoActivityIndicator] on [TargetPlatform.iOS] &
  /// [TargetPlatform.macOS] and a [CircularProgressIndicator] in material
  /// theme/non-Apple platforms.
  ///
  /// The [valueColor], [strokeWidth], [strokeAlign], [strokeCap],
  /// [semanticsLabel], [semanticsValue], [trackGap], [year2023] will be
  /// ignored on iOS & macOS.
  ///
  /// {@macro flutter.material.ProgressIndicator.ProgressIndicator}
  const CircularProgressIndicator.adaptive({
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
    this.valueMilliseconds = 600,
  }) : _indicatorType = _ActivityIndicatorType.adaptive;

  final _ActivityIndicatorType _indicatorType;

  final int valueMilliseconds;

  /// {@template flutter.material.CircularProgressIndicator.trackColor}
  /// Color of the circular track being filled by the circular indicator.
  ///
  /// If [CircularProgressIndicator.backgroundColor] is null then the
  /// ambient [ProgressIndicatorThemeData.circularTrackColor] will be used.
  /// If that is null, then the track will not be painted.
  /// {@endtemplate}
  @override
  Color? get backgroundColor => super.backgroundColor;

  /// The width of the line used to draw the circle.
  final double? strokeWidth;

  /// The relative position of the stroke on a [CircularProgressIndicator].
  ///
  /// Values typically range from -1.0 ([strokeAlignInside], inside stroke)
  /// to 1.0 ([strokeAlignOutside], outside stroke),
  /// without any bound constraints (e.g., a value of -2.0 is not typical, but allowed).
  /// A value of 0 ([strokeAlignCenter]) will center the border
  /// on the edge of the widget.
  ///
  /// If [year2023] is true, then the default value is [strokeAlignCenter].
  /// Otherwise, the default value is [strokeAlignInside].
  final double? strokeAlign;

  /// The progress indicator's line ending.
  ///
  /// This determines the shape of the stroke ends of the progress indicator.
  /// By default, [strokeCap] is null.
  /// When [value] is null (indeterminate), the stroke ends are set to
  /// [StrokeCap.square]. When [value] is not null, the stroke
  /// ends are set to [StrokeCap.butt].
  ///
  /// Setting [strokeCap] to [StrokeCap.round] will result in a rounded end.
  /// Setting [strokeCap] to [StrokeCap.butt] with [value] == null will result
  /// in a slightly different indeterminate animation; the indicator completely
  /// disappears and reappears on its minimum value.
  /// Setting [strokeCap] to [StrokeCap.square] with [value] != null will
  /// result in a different display of [value]. The indicator will start
  /// drawing from slightly less than the start, and end slightly after
  /// the end. This will produce an alternative result, as the
  /// default behavior, for example, that a [value] of 0.5 starts at 90 degrees
  /// and ends at 270 degrees. With [StrokeCap.square], it could start 85
  /// degrees and end at 275 degrees.
  final StrokeCap? strokeCap;

  /// Defines minimum and maximum sizes for a [CircularProgressIndicator].
  ///
  /// If null, then the [ProgressIndicatorThemeData.constraints] will be used.
  /// Otherwise, defaults to a minimum width and height of 36 pixels.
  final BoxConstraints? constraints;

  /// The gap between the active indicator and the background track.
  ///
  /// If [year2023] is false or [ThemeData.useMaterial3] is false, then no track
  /// gap will be drawn.
  ///
  /// Set [trackGap] to 0 to hide the track gap.
  ///
  /// If null, then the [ProgressIndicatorThemeData.trackGap] will be used.
  /// If that is null, then defaults to 4.
  final double? trackGap;

  /// When true, the [CircularProgressIndicator] will use the 2023 Material Design 3
  /// appearance.
  ///
  /// If null, then the [ProgressIndicatorThemeData.year2023] will be used.
  /// If that is null, then defaults to true.
  ///
  /// If this is set to false, the [CircularProgressIndicator] will use the
  /// latest Material Design 3 appearance, which was introduced in December 2023.
  ///
  /// If [ThemeData.useMaterial3] is false, then this property is ignored.

  @Deprecated(
    'Set this flag to false to opt into the 2024 progress indicator appearance. Defaults to true. '
    'In the future, this flag will default to false. Use ProgressIndicatorThemeData to customize individual properties. '
    'This feature was deprecated after v3.27.0-0.2.pre.',
  )
  final bool? year2023;

  /// The padding around the indicator track.
  ///
  /// If null, then the [ProgressIndicatorThemeData.circularTrackPadding] will be
  /// used. If that is null and [year2023] is false, then defaults to `EdgeInsets.all(4.0)`
  /// padding. Otherwise, defaults to zero padding.
  final EdgeInsetsGeometry? padding;

  /// The indicator stroke is drawn fully inside of the indicator path.
  ///
  /// This is a constant for use with [strokeAlign].
  static const double strokeAlignInside = -1.0;

  /// The indicator stroke is drawn on the center of the indicator path,
  /// with half of the [strokeWidth] on the inside, and the other half
  /// on the outside of the path.
  ///
  /// This is a constant for use with [strokeAlign].
  ///
  /// This is the default value for [strokeAlign].
  static const double strokeAlignCenter = 0.0;

  /// The indicator stroke is drawn on the outside of the indicator path.
  ///
  /// This is a constant for use with [strokeAlign].
  static const double strokeAlignOutside = 1.0;

  @override
  State<CircularProgressIndicator> createState() =>
      _CircularProgressIndicatorState();
}

class _CircularProgressIndicatorState extends State<CircularProgressIndicator>
    with TickerProviderStateMixin {
  static const int _pathCount = _kIndeterminateCircularDuration ~/ 1333;
  static const int _rotationCount = _kIndeterminateCircularDuration ~/ 2222;

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

  late AnimationController _controller;
  late AnimationController _valueController;
  late AnimationController _fromNullToZeroOrfromValueToNullController;
  // double? _lastValue;
  static final Animatable<double> _valueTween = CurveTween(
    curve: Curves.easeInOut,
  );
  static final Animatable<double> _valueTween2 = CurveTween(
    curve: Curves.easeInQuad,
  );
  // Animatable<double>? _lastV;

  Animatable<double> _nowOrSwpTween = _valueTween;
  Animatable<double> _tailOrRTween = _valueTween;

  bool fromNullToZeroOrValueToZero = false;

  double _easeInOutDerivative(double t) {
    final double x = t.clamp(0.0, 1.0);
    if (x < 0.5) {
      return 4 * x;
    }
    return 4 * (1 - x);
  }

  Animatable<double>? _nowControllerVEaseInOut(AnimationController controller) {
    try {
      final double x = controller.value.clamp(0.0, 1.0);
      final double slope =
          _easeInOutDerivative(x) *
          (_nowOrSwpTween.transform(1) - _nowOrSwpTween.transform(0));
      return Tween<double>(begin: 0.0, end: slope);
    } catch (e) {
      return null;
    }
  }

  Animatable<double>? _nowControllerV(
    AnimationController controller,
    Animatable<double> tween,
  ) {
    try {
      final double x = controller.value.clamp(0.0, 1.0);
      // Use a small symmetric delta to estimate the tangent slope numerically.
      const double epsilon = 1e-2;
      final double x0 = math.max(0.0, x - epsilon);
      final double x1 = math.min(1.0, x + epsilon);

      if (x1 == x0) {
        return null;
      }

      final double y0 = tween.transform(x0);
      final double y1 = tween.transform(x1);
      final double slope = (y1 - y0) / (x1 - x0);
      return Tween<double>(begin: 0.0, end: slope);
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: _kIndeterminateCircularDuration),
      vsync: this,
    );
    _valueController = AnimationController(
      duration: Duration(milliseconds: widget.valueMilliseconds),
      vsync: this,
    );
    _fromNullToZeroOrfromValueToNullController = AnimationController(
      duration: Duration(milliseconds: widget.valueMilliseconds),
      vsync: this,
    );
    if (widget.value == null) {
      _controller.repeat();
    }

    // _controller.addListener(() {
    //   debugPrint(_controller.value.toString());
    //   debugPrint('head: ${_strokeHeadTween.evaluate(_controller)}');
    //   debugPrint('tail: ${_strokeTailTween.evaluate(_controller)}');
    //   debugPrint('offset: ${_offsetTween.evaluate(_controller)}');
    //   debugPrint('rotation: ${_rotationTween.evaluate(_controller)}');
    // });
    _valueController.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _valueController.reset();
      }
    });
    _fromNullToZeroOrfromValueToNullController.addStatusListener((
      AnimationStatus status,
    ) {
      // debugPrint(status.toString());
      if (status == AnimationStatus.completed && fromNullToZeroOrValueToZero) {
        _fromNullToZeroOrfromValueToNullController.reset();
        // setState(() {
        fromNullToZeroOrValueToZero = false;
        // });
        if (widget.value != null) {
          _valueController.reset();
          didUpdateWidget(const CircularProgressIndicator(value: 0));
        } else {
          _controller.reset();
          _controller.repeat();
        }
      }
    });
  }

  double get realControllerValueOfPathCountHead =>
      (((_controller.value * _pathCount) % 1.0) * 2).clamp(0.0, 1.0);

  double get realControllerValueOfPathCountTail =>
      (((_controller.value * _pathCount) % 1.0).clamp(0.5, 1.0) - 0.5) * 2;

  @override
  void didUpdateWidget(CircularProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (fromNullToZeroOrValueToZero) return;
    if (widget.value == null && !_controller.isAnimating) {
      _controller.repeat();
    } else if (widget.value != null && _controller.isAnimating) {
      _controller.stop();
    }
    if (widget.value != null && oldWidget.value != null) {
      if (_valueController.isAnimating) {
        final Animatable<double>? v = _nowControllerVEaseInOut(
          _valueController,
        );
        if (v != null) {
          double now = _nowOrSwpTween.evaluate(_valueController);
          double vM = v.transform(1);
          _nowOrSwpTween = Tween<double>(
            begin: now,
            end: now,
          ).plus(v).plus(_valueTween.scale(widget.value! - now - vM));
          _valueController.reset();
          _valueController.forward();
          return;
        }
      }
      _nowOrSwpTween = Tween<double>(
        begin: oldWidget.value!,
        end: oldWidget.value!,
      ).plus(_valueTween.scale(widget.value! - oldWidget.value!));
      _valueController.reset();
      _valueController.forward();
    } else {
      // debugPrint(
      //   CurveTween(
      //     curve: Curves.fastOutSlowIn,
      //   ).transform(realControllerValueOfPathCountHead).toString(),
      // );
      // debugPrint(
      //   cubicDerivativeAt(
      //     0.4,
      //     0.0,
      //     0.2,
      //     1.0,
      //     realControllerValueOfPathCountHead,
      //   ).toString(),
      // );
      if (widget.value == null && oldWidget.value == null) return;
      if (widget.value == null) {
        final double end = .001;
        if (_valueController.isAnimating) {
          _valueController.stop();
          // _tailTween = _valueTween.scale(0);
          _tailOrRTween = _valueTween;
          final Animatable<double>? v = _nowControllerVEaseInOut(
            _valueController,
          );
          if (v != null) {
            double now = _nowOrSwpTween.evaluate(_valueController);
            double vM = v.transform(1);
            _nowOrSwpTween = Tween<double>(
              begin: now,
              end: now,
            ).plus(v).plus(_valueTween.scale(end - now - vM));
            _valueController.reset();
            _fromNullToZeroOrfromValueToNullController.reset();
            fromNullToZeroOrValueToZero = true;
            _fromNullToZeroOrfromValueToNullController.forward();
            return;
          }
        }
        _tailOrRTween = _valueTween;
        _nowOrSwpTween = Tween<double>(
          begin: oldWidget.value!,
          end: oldWidget.value!,
        ).plus(_valueTween.scale(end - oldWidget.value!));
        _fromNullToZeroOrfromValueToNullController.reset();
        fromNullToZeroOrValueToZero = true;
        _fromNullToZeroOrfromValueToNullController.forward();
      } else {
        double _epsilon = .001;
        double end = 1;
        double headValue = _strokeHeadTween.evaluate(_controller);
        double tailValue = _strokeTailTween.evaluate(_controller);
        double offsetValue = _offsetTween.evaluate(_controller);
        double rotationValue = _rotationTween.evaluate(_controller);

        double tail = tailValue * 3 / 4 + rotationValue + offsetValue * 0.25;
        double swp = math.max(headValue * 3 / 4 - tailValue * 3 / 4, _epsilon);
        double head = tail + swp;
        // debugPrint('head: $head, tail: $tail, swp: $swp');
        double headV =
            cubicDerivativeAt(
              0.4,
              0.0,
              0.2,
              1.0,
              realControllerValueOfPathCountHead,
            ) *
            3 /
            4;
        double tailV =
            cubicDerivativeAt(
              0.4,
              0.0,
              0.2,
              1.0,
              realControllerValueOfPathCountTail,
            ) *
            3 /
            4;
        if (head > 1) end = 2;
        tailV += _rotationCount / _pathCount;
        headV += _rotationCount / _pathCount;
        double swpV = headV - tailV;
        _tailOrRTween = Tween<double>(begin: tail, end: tail)
            .plus(Tween<double>(begin: 0, end: tailV))
            .plus(_valueTween.scale(end - tail - tailV));
        _nowOrSwpTween = Tween<double>(begin: swp, end: swp)
            .plus(Tween<double>(begin: 0, end: swpV))
            .plus(_valueTween.scale(0 - swp - swpV));
        _fromNullToZeroOrfromValueToNullController.reset();
        fromNullToZeroOrValueToZero = true;
        _fromNullToZeroOrfromValueToNullController.forward();
      }
      _valueController.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Widget _buildCupertinoIndicator(BuildContext context) {
    final Color? tickColor = widget.backgroundColor;
    final double? value = widget.value;
    if (value == null) {
      return CupertinoActivityIndicator(key: widget.key, color: tickColor);
    }
    return CupertinoActivityIndicator.partiallyRevealed(
      key: widget.key,
      color: tickColor,
      progress: value,
    );
  }

  Widget _buildMaterialIndicator(
    BuildContext context,
    double headValue,
    double tailValue,
    double offsetValue,
    double rotationValue, {
    double? aValue,
    bool useROnValue = false,
  }) {
    final ProgressIndicatorThemeData indicatorTheme = ProgressIndicatorTheme.of(
      context,
    );
    final bool year2023 = widget.year2023 ?? indicatorTheme.year2023 ?? true;
    final ProgressIndicatorThemeData defaults = switch (Theme.of(
      context,
    ).useMaterial3) {
      true =>
        year2023
            ? _CircularProgressIndicatorDefaultsM3Year2023(
                context,
                indeterminate: widget.value == null,
              )
            : _CircularProgressIndicatorDefaultsM3(
                context,
                indeterminate: widget.value == null,
              ),
      false => _CircularProgressIndicatorDefaultsM2(
        context,
        indeterminate: widget.value == null,
      ),
    };
    final Color? trackColor =
        widget.backgroundColor ??
        indicatorTheme.circularTrackColor ??
        defaults.circularTrackColor;
    final double strokeWidth =
        widget.strokeWidth ??
        indicatorTheme.strokeWidth ??
        defaults.strokeWidth!;
    final double strokeAlign =
        widget.strokeAlign ??
        indicatorTheme.strokeAlign ??
        defaults.strokeAlign!;
    final StrokeCap? strokeCap = widget.strokeCap ?? indicatorTheme.strokeCap;
    final BoxConstraints constraints =
        widget.constraints ??
        indicatorTheme.constraints ??
        defaults.constraints!;
    final double? trackGap =
        widget.trackGap ?? indicatorTheme.trackGap ?? defaults.trackGap;
    final EdgeInsetsGeometry? effectivePadding =
        widget.padding ??
        indicatorTheme.circularTrackPadding ??
        defaults.circularTrackPadding;

    Widget result = ConstrainedBox(
      constraints: constraints,
      child: CustomPaint(
        painter: _CircularProgressIndicatorPainter(
          trackColor: trackColor,
          valueColor: widget._getValueColor(
            context,
            defaultColor: defaults.color,
          ),
          value: aValue ?? widget.value, // may be null
          headValue:
              headValue, // remaining arguments are ignored if widget.value is not null
          tailValue: tailValue,
          offsetValue: offsetValue,
          rotationValue: rotationValue,
          strokeWidth: strokeWidth,
          strokeAlign: strokeAlign,
          strokeCap: strokeCap,
          trackGap: trackGap,
          useROnValue: useROnValue,
        ),
      ),
    );

    if (effectivePadding != null) {
      result = Padding(padding: effectivePadding, child: result);
    }

    return widget._buildSemanticsWrapper(context: context, child: result);
  }

  Widget _buildAnimation() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        // debugPrint('head: ${_strokeHeadTween.evaluate(_controller)}');
        // debugPrint('tail: ${_strokeTailTween.evaluate(_controller)}');
        return _buildMaterialIndicator(
          context,
          _strokeHeadTween.evaluate(_controller),
          _strokeTailTween.evaluate(_controller),
          _offsetTween.evaluate(_controller),
          _rotationTween.evaluate(_controller),
          // 0,0
        );
      },
    );
  }

  Widget _buildAMaterialIndicator(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _valueController,
        _fromNullToZeroOrfromValueToNullController,
      ]),
      builder: (BuildContext context, Widget? child) {
        if (fromNullToZeroOrValueToZero) {
          // debugPrint('fromNullToZeroOrValueToZero');
          double swp = _nowOrSwpTween.evaluate(
            _fromNullToZeroOrfromValueToNullController,
          );
          double r = _tailOrRTween.evaluate(
            _fromNullToZeroOrfromValueToNullController,
          );
          if (swp < 0) {
            r = r + swp;
            swp = swp.abs();
          }
          return _buildMaterialIndicator(
            context,
            0.0,
            0.0,
            0.0,
            r,
            aValue: swp,
            useROnValue: true,
          );
        }
        if (widget.value == null) {
          // debugPrint('widget.value is null');
          return _buildAnimation();
        }
        if (!_valueController.isAnimating) {
          // debugPrint('no Ani');
          return _buildMaterialIndicator(context, 0.0, 0.0, 0.0, 0.0);
        }
        // debugPrint('Animating');
        return _buildMaterialIndicator(
          context,
          0.0,
          0.0,
          0.0,
          0.0,
          aValue: _nowOrSwpTween.evaluate(_valueController),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (widget._indicatorType) {
      case _ActivityIndicatorType.material:
        return _buildAMaterialIndicator(context);
      case _ActivityIndicatorType.adaptive:
        final ThemeData theme = Theme.of(context);
        switch (theme.platform) {
          case TargetPlatform.iOS:
          case TargetPlatform.macOS:
            return _buildCupertinoIndicator(context);
          case TargetPlatform.android:
          case TargetPlatform.fuchsia:
          case TargetPlatform.linux:
          case TargetPlatform.windows:
            return _buildAMaterialIndicator(context);
        }
    }
  }
}

// Hand coded defaults based on Material Design 2.
class _CircularProgressIndicatorDefaultsM2 extends ProgressIndicatorThemeData {
  _CircularProgressIndicatorDefaultsM2(
    this.context, {
    required this.indeterminate,
  });

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  final bool indeterminate;

  @override
  Color get color => _colors.primary;

  @override
  double? get strokeWidth => 4.0;

  @override
  double? get strokeAlign => CircularProgressIndicator.strokeAlignCenter;

  @override
  BoxConstraints get constraints =>
      const BoxConstraints(minWidth: 36.0, minHeight: 36.0);
}

class _CircularProgressIndicatorDefaultsM3Year2023
    extends ProgressIndicatorThemeData {
  _CircularProgressIndicatorDefaultsM3Year2023(
    this.context, {
    required this.indeterminate,
  });

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  final bool indeterminate;

  @override
  Color get color => _colors.primary;

  @override
  double get strokeWidth => 4.0;

  @override
  double? get strokeAlign => CircularProgressIndicator.strokeAlignCenter;

  @override
  BoxConstraints get constraints =>
      const BoxConstraints(minWidth: 36.0, minHeight: 36.0);
}

class _CircularProgressIndicatorDefaultsM3 extends ProgressIndicatorThemeData {
  _CircularProgressIndicatorDefaultsM3(
    this.context, {
    required this.indeterminate,
  });

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  final bool indeterminate;

  @override
  Color get color => _colors.primary;

  @override
  Color? get circularTrackColor =>
      indeterminate ? null : _colors.secondaryContainer;

  @override
  double get strokeWidth => 4.0;

  @override
  double? get strokeAlign => CircularProgressIndicator.strokeAlignInside;

  @override
  BoxConstraints get constraints =>
      const BoxConstraints(minWidth: 40.0, minHeight: 40.0);

  @override
  double? get trackGap => 4.0;

  @override
  EdgeInsetsGeometry? get circularTrackPadding => const EdgeInsets.all(4.0);
}
