// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'SongReplaceSettings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SongReplaceSettings _$SongReplaceSettingsFromJson(Map<String, dynamic> json) =>
    SongReplaceSettings(
      idMappings:
          (json['id_mappings'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          {},
      trackDetails:
          (json['track_details'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, Track.fromJson(e as Map<String, dynamic>)),
          ) ??
          {},
    );

Map<String, dynamic> _$SongReplaceSettingsToJson(
  SongReplaceSettings instance,
) => <String, dynamic>{
  'id_mappings': instance.idMappings,
  'track_details': instance.trackDetails.map((k, e) => MapEntry(k, e.toJson())),
};
