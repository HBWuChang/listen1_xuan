import 'package:smooth_sheets/smooth_sheets.dart';

const SheetOffset playSheetMinOffset = _WidthRelativeSheetOffset(256 / 1200);
const SheetOffset playSheetMidOffset = _WidthRelativeSheetOffset(0.8);

// IdleSheetActivity retains its target offset across layouts. Resolve the
// width at layout time so that the retained target follows window resizing.
class _WidthRelativeSheetOffset implements SheetOffset {
  const _WidthRelativeSheetOffset(this.factor);

  final double factor;

  @override
  double resolve(ViewportLayout metrics) =>
      metrics.viewportSize.width * factor + metrics.contentBaseline;
}
