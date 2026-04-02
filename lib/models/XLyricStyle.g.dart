// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'XLyricStyle.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

XLyricStyle _$XLyricStyleFromJson(Map<String, dynamic> json) => XLyricStyle(
  textStyleFontSize: (json['textStyleFontSize'] as num?)?.toDouble(),
  textStyleFontSizeUseW: json['textStyleFontSizeUseW'] as bool?,
  textStyleFontWeight: (json['textStyleFontWeight'] as num?)?.toInt(),
  activeTextSize: (json['activeTextSize'] as num?)?.toDouble(),
  activeTextSizeUseW: json['activeTextSizeUseW'] as bool?,
  activeTextWeight: (json['activeTextWeight'] as num?)?.toInt(),
  translationTextSize: (json['translationTextSize'] as num?)?.toDouble(),
  translationTextSizeUseW: json['translationTextSizeUseW'] as bool?,
  translationTextWeight: (json['translationTextWeight'] as num?)?.toInt(),
  lineGap: (json['lineGap'] as num?)?.toDouble(),
  translationLineGap: (json['translationLineGap'] as num?)?.toDouble(),
  contentAlignment: (json['contentAlignment'] as num?)?.toInt(),
)..lineTextAlign = (json['lineTextAlign'] as num?)?.toInt();

Map<String, dynamic> _$XLyricStyleToJson(XLyricStyle instance) =>
    <String, dynamic>{
      'textStyleFontSize': instance.textStyleFontSize,
      'textStyleFontSizeUseW': instance.textStyleFontSizeUseW,
      'textStyleFontWeight': instance.textStyleFontWeight,
      'activeTextSize': instance.activeTextSize,
      'activeTextSizeUseW': instance.activeTextSizeUseW,
      'activeTextWeight': instance.activeTextWeight,
      'translationTextSize': instance.translationTextSize,
      'translationTextSizeUseW': instance.translationTextSizeUseW,
      'translationTextWeight': instance.translationTextWeight,
      'lineTextAlign': instance.lineTextAlign,
      'lineGap': instance.lineGap,
      'translationLineGap': instance.translationLineGap,
      'contentAlignment': instance.contentAlignment,
    };
