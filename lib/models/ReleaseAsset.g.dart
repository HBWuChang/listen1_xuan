// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ReleaseAsset.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReleaseAsset _$ReleaseAssetFromJson(Map<String, dynamic> json) => ReleaseAsset(
  url: json['url'] as String,
  browserDownloadUrl: json['browser_download_url'] as String,
  id: (json['id'] as num).toInt(),
  nodeId: json['node_id'] as String,
  name: json['name'] as String,
  label: json['label'] as String?,
  state: json['state'] as String,
  contentType: json['content_type'] as String,
  size: (json['size'] as num).toInt(),
  digest: json['digest'] as String?,
  downloadCount: (json['download_count'] as num).toInt(),
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
  uploader: json['uploader'] == null
      ? null
      : GitHubUser.fromJson(json['uploader'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ReleaseAssetToJson(ReleaseAsset instance) =>
    <String, dynamic>{
      'url': instance.url,
      'browser_download_url': instance.browserDownloadUrl,
      'id': instance.id,
      'node_id': instance.nodeId,
      'name': instance.name,
      'label': instance.label,
      'state': instance.state,
      'content_type': instance.contentType,
      'size': instance.size,
      'digest': instance.digest,
      'download_count': instance.downloadCount,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'uploader': instance.uploader,
    };
