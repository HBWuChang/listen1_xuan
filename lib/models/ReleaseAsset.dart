import 'package:json_annotation/json_annotation.dart';

import 'GitHubUser.dart';

part 'ReleaseAsset.g.dart';

/// GitHub Release Asset 模型
@JsonSerializable()
class ReleaseAsset {
  final String url;
  @JsonKey(name: 'browser_download_url')
  final String browserDownloadUrl;
  final int id;
  @JsonKey(name: 'node_id')
  final String nodeId;
  final String name;
  final String? label;
  final String state;
  @JsonKey(name: 'content_type')
  final String contentType;
  final int size;
  final String? digest;
  @JsonKey(name: 'download_count')
  final int downloadCount;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  final GitHubUser? uploader;

  ReleaseAsset({
    required this.url,
    required this.browserDownloadUrl,
    required this.id,
    required this.nodeId,
    required this.name,
    this.label,
    required this.state,
    required this.contentType,
    required this.size,
    this.digest,
    required this.downloadCount,
    required this.createdAt,
    required this.updatedAt,
    this.uploader,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) =>
      _$ReleaseAssetFromJson(json);

  Map<String, dynamic> toJson() => _$ReleaseAssetToJson(this);
}
