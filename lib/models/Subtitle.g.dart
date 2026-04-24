// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Subtitle.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Subtitle _$SubtitleFromJson(Map<String, dynamic> json) => Subtitle(
  id: _subtitleIdReadValue(json, 'id') as String?,
  language: json['lan'] as String?,
  languageDescription: json['lan_doc'] as String?,
  isLocked: json['is_lock'] as bool?,
  subtitleUrl: json['subtitle_url'] as String?,
  subtitleUrlV2: json['subtitle_url_v2'] as String?,
  type: (json['type'] as num?)?.toInt(),
  idStr: json['id_str'] as String?,
  aiType: (json['ai_type'] as num?)?.toInt(),
  aiStatus: (json['ai_status'] as num?)?.toInt(),
);

Map<String, dynamic> _$SubtitleToJson(Subtitle instance) => <String, dynamic>{
  'id': instance.id,
  'lan': instance.language,
  'lan_doc': instance.languageDescription,
  'is_lock': instance.isLocked,
  'subtitle_url': instance.subtitleUrl,
  'subtitle_url_v2': instance.subtitleUrlV2,
  'type': instance.type,
  'id_str': instance.idStr,
  'ai_type': instance.aiType,
  'ai_status': instance.aiStatus,
};
