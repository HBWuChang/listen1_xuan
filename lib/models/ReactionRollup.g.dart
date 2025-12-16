// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ReactionRollup.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReactionRollup _$ReactionRollupFromJson(Map<String, dynamic> json) =>
    ReactionRollup(
      url: json['url'] as String,
      totalCount: (json['total_count'] as num).toInt(),
      plusOne: (json['+1'] as num).toInt(),
      minusOne: (json['-1'] as num).toInt(),
      laugh: (json['laugh'] as num).toInt(),
      confused: (json['confused'] as num).toInt(),
      heart: (json['heart'] as num).toInt(),
      hooray: (json['hooray'] as num).toInt(),
      eyes: (json['eyes'] as num).toInt(),
      rocket: (json['rocket'] as num).toInt(),
    );

Map<String, dynamic> _$ReactionRollupToJson(ReactionRollup instance) =>
    <String, dynamic>{
      'url': instance.url,
      'total_count': instance.totalCount,
      '+1': instance.plusOne,
      '-1': instance.minusOne,
      'laugh': instance.laugh,
      'confused': instance.confused,
      'heart': instance.heart,
      'hooray': instance.hooray,
      'eyes': instance.eyes,
      'rocket': instance.rocket,
    };
