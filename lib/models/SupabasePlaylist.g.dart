// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'SupabasePlaylist.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SupabasePlaylist _$SupabasePlaylistFromJson(Map<String, dynamic> json) =>
    SupabasePlaylist(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      isShare: json['is_share'] as bool? ?? false,
      name: json['name'] as String,
      data: json['data'] as Map<String, dynamic>? ?? {},
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$SupabasePlaylistToJson(SupabasePlaylist instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'is_share': instance.isShare,
      'name': instance.name,
      'data': instance.data,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
