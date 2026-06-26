import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

extension WidgetExts on Widget {
  ///  Extension to easily add a [ClipSmoothRect] to any widget.
  ClipSmoothRect clipSmoothRectSize(double size, {double radPre = 0.08}) =>
      clipSmoothRect(cornerRadius: size * radPre);
  ClipSmoothRect clipSmoothRect({
    double cornerRadius = 16,
    double cornerSmoothing = 1,
  }) => ClipSmoothRect(
    radius: SmoothBorderRadius(
      cornerRadius: cornerRadius,
      cornerSmoothing: cornerSmoothing,
    ),
    child: this,
  );
  SizedBox sbw(double width) => SizedBox(width: width, child: this);
  SizedBox sbh(double height) => SizedBox(height: height, child: this);
  SizedBox sbwh(double? width, double? height) =>
      SizedBox(height: height, width: width, child: this);
  SizedBox sbs(double size) => sbwh(size, size);

  SizedBox wsbw(double width) => sbw(width.w);
  SizedBox wsbh(double height) => sbh(height.w);
  SizedBox wsbwh(double width, double height) => sbwh(width.w, height.w);
  SizedBox wsbs(double size) => sbwh(size.w, size.w);

  SizedBox hsbw(double width) => sbw(width.h);
  SizedBox hsbh(double height) => sbh(height.h);
  SizedBox hsbwh(double width, double height) => sbwh(width.h, height.h);
  SizedBox hsbs(double size) => sbwh(size.h, size.h);

  Center get center => Center(child: this);
}

extension SizedBoxExt on num {
  SizedBox get sbw => SizedBox(width: toDouble());
  SizedBox get sbh => SizedBox(height: toDouble());
  SizedBox get wsbw => SizedBox(width: w);
  SizedBox get wsbh => SizedBox(height: w);
  SizedBox get hsbw => SizedBox(width: h);
  SizedBox get hsbh => SizedBox(height: h);
}
