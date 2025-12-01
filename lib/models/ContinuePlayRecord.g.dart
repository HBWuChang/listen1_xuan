// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ContinuePlayRecord.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ContinuePlayRecord _$ContinuePlayRecordFromJson(Map<String, dynamic> json) =>
    ContinuePlayRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      track: json['track'] as Map<String, dynamic>? ?? {},
      updTime: json['upd_time'] == null
          ? null
          : DateTime.parse(json['upd_time'] as String),
      playing: json['playing'] as bool? ?? false,
      ext: json['ext'] as Map<String, dynamic>?,
      deviceId: json['device_id'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$ContinuePlayRecordToJson(ContinuePlayRecord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'track': instance.track,
      'upd_time': instance.updTime?.toIso8601String(),
      'playing': instance.playing,
      'ext': instance.ext,
      'device_id': instance.deviceId,
      'created_at': instance.createdAt?.toIso8601String(),
    };
