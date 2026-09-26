import 'dart:math';
import 'package:flutter/material.dart';

/// {@template material_wave_slider}
///
/// MaterialWaveSlider
/// ------------------
/// Material Design 3 / Material You inspired waveform slider.
///
/// [SliderTheme] & [SliderThemeData] may be used to customize the visual appearance of the slider.
///
/// {@endtemplate}
class MaterialWaveSlider extends StatefulWidget {
  // --------------------------------------------------

  /// The current value of the slider.
  final double value;

  /// The minimum value the user can select.
  final double min;

  /// The maximum value the user can select.
  final double max;

  /// Called during a drag when the user is selecting a new value for the slider by dragging.
  final void Function(double)? onChanged;

  // --------------------------------------------------

  /// The height of the slider.
  final double height;

  /// The amplitude of the wave.
  final double? amplitude;

  /// The velocity of the wave.
  final double velocity;

  /// Whether the wave is currently paused.
  final bool paused;

  /// The [Curve] of the amplitude change transition.
  final Curve transitionCurve;

  /// The [Duration] of the amplitude change transition.
  final Duration transitionDuration;

  /// Whether to show amplitude change transition upon value change.
  final bool transitionOnChange;

  /// Builder that may be used to customize the default thumb.
  final Widget Function(BuildContext)? thumbBuilder;

  /// The width of the default thumb.
  final double thumbWidth;

  // --------------------------------------------------

  /// {@macro material_wave_slider}
  const MaterialWaveSlider({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    required this.onChanged,
    this.height = 48.0,
    this.velocity = 2600.0,
    this.paused = false,
    this.amplitude,
    this.transitionCurve = Curves.easeInOut,
    this.transitionDuration = const Duration(milliseconds: 200),
    this.transitionOnChange = true,
    this.thumbBuilder,
    this.thumbWidth = 6.0,
  });

  @override
  State<MaterialWaveSlider> createState() => MaterialWaveSliderState();
}

class MaterialWaveSliderState extends State<MaterialWaveSlider> with TickerProviderStateMixin {
  // --------------------------------------------------
  // Animation state.
  //
  // The wave is painted by a single [CustomPainter] (instead of a scrolling
  // [ListView]), which is driven straight by the [AnimationController]s below
  // through `repaint:`.
  //
  // This means:
  //
  // * Running the wave does NOT rebuild any widget, it only repaints one
  //   [RepaintBoundary] with a cached [Path].
  // * The number of widgets / render objects does NOT depend on the width of
  //   the slider (the previous implementation created one [CustomPaint] per
  //   wavelength, i.e. hundreds of them across the viewport).
  // * When paused, no ticker is running at all.
  // --------------------------------------------------

  /// Drives the horizontal phase of the wave.
  ///
  /// `0.0 -> 1.0` moves the wave by exactly one wavelength ([_wavelength]).
  late final AnimationController _phaseController;

  /// Drives the amplitude of the wave.
  ///
  /// `0.0` is a flattened wave (paused) and `1.0` is the full amplitude.
  late final AnimationController _amplitudeController;

  /// Curved view of [_amplitudeController], honoring [MaterialWaveSlider.transitionCurve].
  late final CurvedAnimation _amplitude;

  /// Merged [Listenable] handed over to the painter, so that either animation
  /// only repaints the wave.
  late final Listenable _repaint;

  /// Reuses the [Path] of the wave in between frames & rebuilds.
  final _WavePathCache _pathCache = _WavePathCache();

  // --------------------------------------------------

  double? _current;
  bool _paused = false;
  bool _dragging = false;

  /// The amplitude of the wave in logical pixels.
  double get _maxAmplitude => widget.amplitude ?? (widget.height / 12.0);

  /// The horizontal distance between two crests of the wave, in logical pixels.
  ///
  /// One wavelength is as wide as the slider is tall, which is what makes the
  /// wave look like a continuously repeating pattern.
  double get _wavelength => max(widget.height, 1.0);

  /// The horizontal distance between two points used to draw the wave.
  double get _delta => max(widget.height / 25.0, 0.1);

  /// The fraction of the slider which is currently active.
  double get _percent {
    final range = widget.max - widget.min;
    if (range <= 0.0) {
      return 0.0;
    }
    final value = _current ?? widget.value;
    return ((value - widget.min) / range).clamp(0.0, 1.0);
  }

  /// The duration of a single wavelength, derived from [MaterialWaveSlider.velocity].
  Duration get _phaseDuration {
    final velocity = widget.velocity.isFinite ? widget.velocity : 2600.0;
    return Duration(milliseconds: velocity.round().clamp(16, 1 << 30));
  }

  /// Whether the wave should currently move at full amplitude.
  ///
  /// This is the same condition which previously controlled
  /// `MaterialWaveSliderState._running`.
  bool get _running => !_paused && !(_dragging && widget.transitionOnChange);

  /// Starts / stops the tickers according to [_running].
  ///
  /// Both `AnimationController`s notify the painter, hence no [setState] is
  /// required here.
  void _syncAnimation() {
    if (_running) {
      _amplitudeController.forward();
      if (!_phaseController.isAnimating) {
        _phaseController.repeat();
      }
    } else {
      _amplitudeController.reverse();
      _phaseController.stop();
    }
  }

  /// Pauses the wave (it flattens & stops moving).
  void pause() {
    if (_paused) return;
    _paused = true;
    _syncAnimation();
  }

  /// Resumes the wave.
  void resume() {
    if (!_paused) return;
    _paused = false;
    _syncAnimation();
  }

  void _onPointerDown(PointerDownEvent e, BoxConstraints constraints) {
    if (widget.onChanged == null) return;
    _dragging = true;
    _syncAnimation();
    final width = constraints.maxWidth;
    setState(() {
      _current = widget.min + (width == 0.0 ? 0.0 : e.localPosition.dx / width) * (widget.max - widget.min);
    });
  }

  void _onPointerMove(PointerMoveEvent e, BoxConstraints constraints) {
    if (widget.onChanged == null) return;
    final width = constraints.maxWidth;
    setState(() {
      _current = widget.min + (width == 0.0 ? 0.0 : e.localPosition.dx / width) * (widget.max - widget.min);
    });
  }

  void _onPointerUp(PointerUpEvent e, BoxConstraints constraints) {
    if (widget.onChanged == null) return;
    _dragging = false;
    _syncAnimation();
    final width = constraints.maxWidth;
    final value = widget.min + (width == 0.0 ? 0.0 : e.localPosition.dx / width) * (widget.max - widget.min);
    setState(() {
      _current = null;
    });
    widget.onChanged?.call(value.clamp(widget.min, widget.max));
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (widget.onChanged == null) return;
    _dragging = false;
    _syncAnimation();
    setState(() {
      _current = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _paused = widget.paused;
    _amplitudeController = AnimationController(
      vsync: this,
      duration: widget.transitionDuration,
      value: _paused ? 0.0 : 1.0,
    );
    _amplitude = CurvedAnimation(
      parent: _amplitudeController,
      curve: widget.transitionCurve,
    );
    _phaseController = AnimationController(
      vsync: this,
      duration: _phaseDuration,
    );
    _repaint = Listenable.merge([_phaseController, _amplitude]);
    if (!_paused) {
      _phaseController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant MaterialWaveSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused != oldWidget.paused) {
      if (widget.paused) {
        pause();
      } else {
        resume();
      }
    }
    if (widget.height != oldWidget.height || widget.amplitude != oldWidget.amplitude) {
      // The amplitude & wavelength of the wave changed, the cached path is stale.
      _pathCache.clear();
    }
    if (widget.transitionDuration != oldWidget.transitionDuration) {
      _amplitudeController.duration = widget.transitionDuration;
    }
    if (widget.transitionCurve != oldWidget.transitionCurve) {
      _amplitude.curve = widget.transitionCurve;
    }
    if (widget.velocity != oldWidget.velocity) {
      _phaseController.duration = _phaseDuration;
      if (_running) {
        // Restart the repeating simulation to pick up the new duration.
        _phaseController.repeat();
      }
    }
  }

  @override
  void dispose() {
    _amplitude.dispose();
    _amplitudeController.dispose();
    _phaseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaults = theme.useMaterial3 ? _SliderDefaultsM3(context) : _SliderDefaultsM2(context);

    SliderThemeData sliderTheme = SliderTheme.of(context);
    sliderTheme = sliderTheme.copyWith(
      trackHeight: sliderTheme.trackHeight ?? defaults.trackHeight,
      activeTrackColor: sliderTheme.activeTrackColor ?? defaults.activeTrackColor,
      inactiveTrackColor: sliderTheme.inactiveTrackColor ?? defaults.inactiveTrackColor,
      secondaryActiveTrackColor: sliderTheme.secondaryActiveTrackColor ?? defaults.secondaryActiveTrackColor,
      disabledActiveTrackColor: sliderTheme.disabledActiveTrackColor ?? defaults.disabledActiveTrackColor,
      disabledInactiveTrackColor: sliderTheme.disabledInactiveTrackColor ?? defaults.disabledInactiveTrackColor,
      disabledSecondaryActiveTrackColor: sliderTheme.disabledSecondaryActiveTrackColor ?? defaults.disabledSecondaryActiveTrackColor,
      activeTickMarkColor: sliderTheme.activeTickMarkColor ?? defaults.activeTickMarkColor,
      inactiveTickMarkColor: sliderTheme.inactiveTickMarkColor ?? defaults.inactiveTickMarkColor,
      disabledActiveTickMarkColor: sliderTheme.disabledActiveTickMarkColor ?? defaults.disabledActiveTickMarkColor,
      disabledInactiveTickMarkColor: sliderTheme.disabledInactiveTickMarkColor ?? defaults.disabledInactiveTickMarkColor,
      thumbColor: sliderTheme.thumbColor ?? defaults.thumbColor,
      disabledThumbColor: sliderTheme.disabledThumbColor ?? defaults.disabledThumbColor,
      valueIndicatorTextStyle: sliderTheme.valueIndicatorTextStyle ?? defaults.valueIndicatorTextStyle,
    );

    final double trackHeight = sliderTheme.trackHeight!;
    final Color activeTrackColor = sliderTheme.activeTrackColor!;
    final Color inactiveTrackColor = sliderTheme.inactiveTrackColor!;
    final Color thumbColor = sliderTheme.thumbColor!;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final percent = _percent;

          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _onPointerDown(e, constraints),
            onPointerMove: (e) => _onPointerMove(e, constraints),
            onPointerUp: (e) => _onPointerUp(e, constraints),
            onPointerCancel: _onPointerCancel,
            child: SizedBox(
              height: widget.height,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // The wave (active part).
                  //
                  // Wrapped inside a [RepaintBoundary] so that the animation of
                  // the wave does not repaint the track / thumb next to it.
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _WaveTrackPainter(
                          color: activeTrackColor,
                          phase: _phaseController,
                          amplitude: _amplitude,
                          maxAmplitude: _maxAmplitude,
                          wavelength: _wavelength,
                          delta: _delta,
                          strokeWidth: trackHeight,
                          percent: percent,
                          pathCache: _pathCache,
                          repaint: _repaint,
                        ),
                      ),
                    ),
                  ),
                  // 未播放部分的轨道（可视指示器）
                  Positioned(
                    left: width * percent - widget.thumbWidth / 2.0,
                    right: 0.0,
                    top: (widget.height - trackHeight) / 2.0,
                    child: Container(
                      color: inactiveTrackColor,
                      height: trackHeight,
                    ),
                  ),
                  Positioned(
                    left: (width * percent - widget.thumbWidth / 3.0).limit(width * percent - widget.thumbWidth),
                    top: (widget.height - widget.height * 0.6) / 2.0,
                    child: widget.thumbBuilder?.call(context) ??
                        Container(
                          width: widget.thumbWidth,
                          height: widget.height * 0.6,
                          decoration: BoxDecoration(
                            color: thumbColor,
                            borderRadius: BorderRadius.circular(
                              widget.thumbWidth / 2.0,
                            ),
                          ),
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Paints the active part of [MaterialWaveSlider] as a repeating sine wave.
///
/// The wave is a single [Path] which is computed only when its shape changes
/// (amplitude, size, stroke width). Moving the wave is a pure horizontal
/// translation of that path, driven by the [Animation]s passed to the painter
/// through [CustomPainter.repaint], i.e. the widget tree is never rebuilt while
/// the wave is animating.
class _WaveTrackPainter extends CustomPainter {
  _WaveTrackPainter({
    required this.color,
    required this.phase,
    required this.amplitude,
    required this.maxAmplitude,
    required this.wavelength,
    required this.delta,
    required this.strokeWidth,
    required this.percent,
    required _WavePathCache pathCache,
    required Listenable repaint,
  })  : _pathCache = pathCache,
        super(repaint: repaint);

  /// The color of the wave.
  final Color color;

  /// The horizontal phase of the wave, `0.0 -> 1.0` equals one [wavelength].
  final Animation<double> phase;

  /// The amplitude of the wave, `0.0 -> 1.0` equals [maxAmplitude].
  final Animation<double> amplitude;

  /// The amplitude of the wave in logical pixels.
  final double maxAmplitude;

  /// The horizontal distance between two crests of the wave, in logical pixels.
  final double wavelength;

  /// The horizontal distance between two points used to draw the wave.
  final double delta;

  /// The stroke-width of the wave.
  final double strokeWidth;

  /// The fraction of the slider which is active (`0.0 - 1.0`).
  final double percent;

  final _WavePathCache _pathCache;

  late final Paint _paint = Paint()
    ..strokeCap = StrokeCap.butt
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final clipWidth = size.width * percent;
    if (clipWidth <= 0.0 || size.height <= 0.0) return;

    final shift = wavelength * phase.value;
    final path = _pathCache.pathFor(
      amplitude: maxAmplitude * amplitude.value,
      delta: delta,
      wavelength: wavelength,
      width: size.width,
      height: size.height,
    );

    _paint
      ..color = color
      ..strokeWidth = strokeWidth;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0.0, 0.0, clipWidth, size.height));
    // The wave travels from right to left, like the previous scrolling
    // implementation did.
    canvas.translate(-shift, 0.0);
    canvas.drawPath(path, _paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WaveTrackPainter oldDelegate) {
    // The animation values are intentionally not compared here, they are
    // delivered through `repaint`.
    return color != oldDelegate.color ||
        maxAmplitude != oldDelegate.maxAmplitude ||
        wavelength != oldDelegate.wavelength ||
        delta != oldDelegate.delta ||
        strokeWidth != oldDelegate.strokeWidth ||
        percent != oldDelegate.percent;
  }
}

/// Caches the [Path] of the wave in between paints / rebuilds.
class _WavePathCache {
  Path? _path;
  double? _amplitude;
  double? _delta;
  double? _wavelength;
  double? _width;
  double? _height;

  void clear() {
    _path = null;
  }

  Path pathFor({
    required double amplitude,
    required double delta,
    required double wavelength,
    required double width,
    required double height,
  }) {
    // The amplitude changes on every frame of the flatten transition, quantizing
    // it keeps the cached path alive in between those frames (a quarter of a
    // logical pixel is not visible).
    final quantizedAmplitude = (amplitude * 4.0).roundToDouble() / 4.0;
    final cached = _path;
    if (cached != null &&
        _amplitude == quantizedAmplitude &&
        _delta == delta &&
        _wavelength == wavelength &&
        _width == width &&
        _height == height) {
      return cached;
    }

    final path = Path();
    // One extra wavelength is drawn, so that the path may be translated
    // horizontally by up to one wavelength without leaving a gap.
    final end = width + wavelength;
    for (double x = 0.0; x <= end; x += delta) {
      final y = height / 2.0 + quantizedAmplitude * sin(x / wavelength * 2.0 * pi);
      if (x == 0.0) {
        path.moveTo(x, y);
      }
      path.lineTo(x, y);
    }

    _path = path;
    _amplitude = quantizedAmplitude;
    _delta = delta;
    _wavelength = wavelength;
    _width = width;
    _height = height;
    return path;
  }
}

/// {@template sine_painter}
///
/// SinePainter
/// -----------
/// A [CustomPainter] to draw a sine wave.
///
/// {@endtemplate}
class SinePainter extends CustomPainter {
  /// The color of the wave.
  final Color color;

  /// The delta used to calculate the [sin] value when drawing the path.
  final double delta;

  /// The phase of the wave.
  final double phase;

  /// The amplitude of the wave.
  final double amplitude;

  /// The stroke-cap of the wave.
  final StrokeCap strokeCap;

  /// The stroke-width of the wave.
  final double strokeWidth;

  /// Pre-calculated [Path] to draw the wave.
  final Path? path;

  /// {@macro sine_painter}
  SinePainter({
    required this.color,
    this.delta = 2.0,
    this.phase = pi,
    this.amplitude = 16.0,
    this.strokeCap = StrokeCap.butt,
    this.strokeWidth = 2.0,
    this.path,
  });

  static Path calculatePath(double delta, double amplitude, double phase, double width, double height) {
    final path = Path();
    for (double x = 0.0; x <= width + delta; x += delta) {
      final y = height / 2.0 + amplitude * sin(x / width * 2 * pi + phase);
      if (x == 0.0) {
        path.moveTo(x, y);
      }
      path.lineTo(x, y);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = strokeCap
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawPath(
      path ?? calculatePath(delta, amplitude, phase, size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    final previous = (oldDelegate as SinePainter);
    return color != previous.color || delta != previous.delta || phase != previous.phase || amplitude != previous.amplitude || strokeCap != previous.strokeCap || strokeWidth != previous.strokeWidth;
  }
}

/// {@template rect_clipper}
///
/// RectClipper
/// -----------
/// A [CustomClipper] to clip the wave.
///
/// {@endtemplate}
class RectClipper extends CustomClipper<Rect> {
  /// The percentage of the clip.
  final double percent;

  /// {@macro rect_clipper}
  const RectClipper(this.percent);

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0.0, 0.0, size.width * percent, size.height);

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => (oldClipper as RectClipper).percent != percent;
}

// --------------------------------------------------

class _SliderDefaultsM3 extends SliderThemeData {
  _SliderDefaultsM3(this.context) : super(trackHeight: 2.5);

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

  @override
  Color? get activeTrackColor => _colors.primary;

  @override
  Color? get inactiveTrackColor => _colors.surfaceVariant;

  @override
  Color? get secondaryActiveTrackColor => _colors.primary.withOpacity(0.54);

  @override
  Color? get disabledActiveTrackColor => _colors.onSurface.withOpacity(0.38);

  @override
  Color? get disabledInactiveTrackColor => _colors.onSurface.withOpacity(0.12);

  @override
  Color? get disabledSecondaryActiveTrackColor => _colors.onSurface.withOpacity(0.12);

  @override
  Color? get activeTickMarkColor => _colors.onPrimary.withOpacity(0.38);

  @override
  Color? get inactiveTickMarkColor => _colors.onSurfaceVariant.withOpacity(0.38);

  @override
  Color? get disabledActiveTickMarkColor => _colors.onSurface.withOpacity(0.38);

  @override
  Color? get disabledInactiveTickMarkColor => _colors.onSurface.withOpacity(0.38);

  @override
  Color? get thumbColor => _colors.primary;

  @override
  Color? get disabledThumbColor => Color.alphaBlend(_colors.onSurface.withOpacity(0.38), _colors.surface);

  @override
  Color? get overlayColor => MaterialStateColor.resolveWith((Set<MaterialState> states) {
        if (states.contains(MaterialState.dragged)) {
          return _colors.primary.withOpacity(0.12);
        }
        if (states.contains(MaterialState.hovered)) {
          return _colors.primary.withOpacity(0.08);
        }
        if (states.contains(MaterialState.focused)) {
          return _colors.primary.withOpacity(0.12);
        }

        return Colors.transparent;
      });

  @override
  TextStyle? get valueIndicatorTextStyle => Theme.of(context).textTheme.labelMedium!.copyWith(
        color: _colors.onPrimary,
      );

  @override
  SliderComponentShape? get valueIndicatorShape => const DropSliderValueIndicatorShape();
}

class _SliderDefaultsM2 extends SliderThemeData {
  _SliderDefaultsM2(this.context)
      : _colors = Theme.of(context).colorScheme,
        super(trackHeight: 2.5);

  final BuildContext context;
  final ColorScheme _colors;

  @override
  Color? get activeTrackColor => _colors.primary;

  @override
  Color? get inactiveTrackColor => _colors.primary.withOpacity(0.24);

  @override
  Color? get secondaryActiveTrackColor => _colors.primary.withOpacity(0.54);

  @override
  Color? get disabledActiveTrackColor => _colors.onSurface.withOpacity(0.32);

  @override
  Color? get disabledInactiveTrackColor => _colors.onSurface.withOpacity(0.12);

  @override
  Color? get disabledSecondaryActiveTrackColor => _colors.onSurface.withOpacity(0.12);

  @override
  Color? get activeTickMarkColor => _colors.onPrimary.withOpacity(0.54);

  @override
  Color? get inactiveTickMarkColor => _colors.primary.withOpacity(0.54);

  @override
  Color? get disabledActiveTickMarkColor => _colors.onPrimary.withOpacity(0.12);

  @override
  Color? get disabledInactiveTickMarkColor => _colors.onSurface.withOpacity(0.12);

  @override
  Color? get thumbColor => _colors.primary;

  @override
  Color? get disabledThumbColor => Color.alphaBlend(_colors.onSurface.withOpacity(.38), _colors.surface);

  @override
  Color? get overlayColor => _colors.primary.withOpacity(0.12);

  @override
  TextStyle? get valueIndicatorTextStyle => Theme.of(context).textTheme.bodyLarge!.copyWith(
        color: _colors.onPrimary,
      );

  @override
  SliderComponentShape? get valueIndicatorShape => const RectangularSliderValueIndicatorShape();
}

// --------------------------------------------------

extension on double {
  double limit(double value) => max(min(this, value), 0.0);
}
