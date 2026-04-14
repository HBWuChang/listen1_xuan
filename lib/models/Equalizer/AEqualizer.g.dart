// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'AEqualizer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AEqualizer _$AEqualizerFromJson(Map<String, dynamic> json) => AEqualizer(
  equalizers: (json['equalizers'] as List<dynamic>)
      .map((e) => Equalizer.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$AEqualizerToJson(AEqualizer instance) =>
    <String, dynamic>{'equalizers': instance.equalizers};
