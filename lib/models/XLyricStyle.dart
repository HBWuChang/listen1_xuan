import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:json_annotation/json_annotation.dart';

part 'XLyricStyle.g.dart';

@JsonSerializable()
class XLyricStyle {
  double? textStyleFontSize;
  bool? textStyleFontSizeUseW;
  int? textStyleFontWeight;
  double? activeTextSize;
  bool? activeTextSizeUseW;
  int? activeTextWeight;
  double? translationTextSize;
  bool? translationTextSizeUseW;
  int? translationTextWeight;
  int? lineTextAlign;
  double? lineGap;
  double? translationLineGap;
  int? contentAlignment;

  double get textStyleFontSizeValue =>
      w(textStyleFontSize ?? 16.0, textStyleFontSizeUseW);
  double get activeStyleFontSizeValue =>
      w(activeTextSize ?? 24.0, activeTextSizeUseW);
  double get translationTextSizeValue =>
      w(translationTextSize ?? 14.0, translationTextSizeUseW);
  FontWeight? get textStyleFontWeightValue => toFontWeight(textStyleFontWeight);
  FontWeight get activeTextWeightValue =>
      toFontWeight(activeTextWeight) ?? FontWeight.w600;
  FontWeight? get translationTextWeightValue => 
      toFontWeight(translationTextWeight);
  TextAlign get lineTextAlignValue {
    return TextAlign.values[lineTextAlign ?? 2];
  }

  double get lineGapValue => lineGap ?? 25.0;
  double get translationLineGapValue => translationLineGap ?? 8.0;
  CrossAxisAlignment get contentAlignmentValue {
    return CrossAxisAlignment.values[contentAlignment ?? 2];
  }

  FontWeight? toFontWeight(int? weight) {
    switch (weight) {
      case 100:
        return FontWeight.w100;
      case 200:
        return FontWeight.w200;
      case 300:
        return FontWeight.w300;
      case 400:
        return FontWeight.w400;
      case 500:
        return FontWeight.w500;
      case 600:
        return FontWeight.w600;
      case 700:
        return FontWeight.w700;
      case 800:
        return FontWeight.w800;
      case 900:
        return FontWeight.w900;
      default:
        return null;
    }
  }

  double w(double value, bool? useW) => (useW == true) ? value * 1.w : value;
  XLyricStyle({
    this.textStyleFontSize,
    this.textStyleFontSizeUseW,
    this.textStyleFontWeight,
    this.activeTextSize,
    this.activeTextSizeUseW,
    this.activeTextWeight,
    this.translationTextSize,
    this.translationTextSizeUseW,
    this.translationTextWeight,
    this.lineGap,
    this.translationLineGap,
    this.contentAlignment,
  });

  factory XLyricStyle.fromJson(Map<String, dynamic> json) =>
      _$XLyricStyleFromJson(json);

  Map<String, dynamic> toJson() => _$XLyricStyleToJson(this);
}
