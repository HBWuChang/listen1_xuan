// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'SubtitleDetail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubtitleDetail _$SubtitleDetailFromJson(Map<String, dynamic> json) =>
    SubtitleDetail(
      from: (json['from'] as num?)?.toDouble(),
      to: (json['to'] as num?)?.toDouble(),
      content: json['content'] as String?,
    );

Map<String, dynamic> _$SubtitleDetailToJson(SubtitleDetail instance) =>
    <String, dynamic>{
      'from': instance.from,
      'to': instance.to,
      'content': instance.content,
    };
