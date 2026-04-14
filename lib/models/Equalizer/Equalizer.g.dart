// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Equalizer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Equalizer _$EqualizerFromJson(Map<String, dynamic> json) => Equalizer(
  f: (json['f'] as num).toInt(),
  t: $enumDecodeNullable(_$WidthTypeEnumMap, json['t']) ?? WidthType.q,
  w: (json['w'] as num?)?.toDouble() ?? 1,
  g: (json['g'] as num?)?.toDouble() ?? 0.0,
  m: (json['m'] as num?)?.toDouble(),
  a: $enumDecodeNullable(_$TransformEnumMap, json['a']),
  r: $enumDecodeNullable(_$PrecisionEnumMap, json['r']),
);

Map<String, dynamic> _$EqualizerToJson(Equalizer instance) => <String, dynamic>{
  'f': instance.f,
  't': _$WidthTypeEnumMap[instance.t]!,
  'w': instance.w,
  'g': instance.g,
  'm': instance.m,
  'a': _$TransformEnumMap[instance.a],
  'r': _$PrecisionEnumMap[instance.r],
};

const _$WidthTypeEnumMap = {
  WidthType.h: 'h',
  WidthType.q: 'q',
  WidthType.o: 'o',
  WidthType.s: 's',
  WidthType.k: 'k',
};

const _$TransformEnumMap = {
  Transform.di: 'di',
  Transform.dii: 'dii',
  Transform.tdi: 'tdi',
  Transform.tdii: 'tdii',
  Transform.latt: 'latt',
  Transform.svf: 'svf',
  Transform.zdf: 'zdf',
};

const _$PrecisionEnumMap = {
  Precision.auto: 'auto',
  Precision.s16: 's16',
  Precision.s32: 's32',
  Precision.f32: 'f32',
  Precision.f64: 'f64',
};
