/// A scalar curve over [0, 1].
typedef ScalarCurve = double Function(double t);

/// Returns the derivative curve for a cubic bezier defined by
/// control points (a, b, c, d), matching Flutter's [Cubic(a, b, c, d)].
///
/// The returned function accepts x in [0, 1] and returns dy/dx.
ScalarCurve cubicDerivativeCurve(
  double a,
  double b,
  double c,
  double d, {
  double errorBound = 0.001,
}) {
  assert(errorBound > 0);

  return (double t) {
    final double x = t.clamp(0.0, 1.0);

    // Match Cubic.transformInternal: binary-search m from x(m) ~= x.
    double start = 0.0;
    double end = 1.0;
    double m = x;

    while (true) {
      m = (start + end) / 2;
      final double estimate = _evaluateCubic(a, c, m);
      if ((x - estimate).abs() < errorBound) {
        break;
      }
      if (estimate < x) {
        start = m;
      } else {
        end = m;
      }
    }

    final double dxDm = _evaluateCubicDerivative(a, c, m);
    final double dyDm = _evaluateCubicDerivative(b, d, m);

    // Guard against a near-zero denominator.
    if (dxDm.abs() < 1e-12) {
      if (dyDm == 0) {
        return 0.0;
      }
      return dyDm > 0 ? double.infinity : -double.infinity;
    }

    return dyDm / dxDm;
  };
}

double _evaluateCubic(double p1, double p2, double m) {
  final double oneMinusM = 1 - m;
  return 3 * p1 * oneMinusM * oneMinusM * m +
      3 * p2 * oneMinusM * m * m +
      m * m * m;
}

double _evaluateCubicDerivative(double p1, double p2, double m) {
  final double oneMinusM = 1 - m;
  return 3 * p1 * oneMinusM * oneMinusM +
      6 * (p2 - p1) * oneMinusM * m +
      3 * (1 - p2) * m * m;
}

/// Convenience helper: directly evaluate dy/dx at x=t.
double cubicDerivativeAt(
  double a,
  double b,
  double c,
  double d,
  double t, {
  double errorBound = 0.001,
}) {
  return cubicDerivativeCurve(a, b, c, d, errorBound: errorBound)(t);
}
