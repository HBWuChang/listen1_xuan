import 'package:json_annotation/json_annotation.dart';

import 'GitHubUser.dart';
import 'ReleaseAsset.dart';
import 'ReactionRollup.dart';

part 'GitHubRelease.g.dart';

/// GitHub Release 模型
@JsonSerializable()
class GitHubRelease {
  final String url;
  @JsonKey(name: 'html_url')
  final String htmlUrl;
  @JsonKey(name: 'assets_url')
  final String assetsUrl;
  @JsonKey(name: 'upload_url')
  final String uploadUrl;
  @JsonKey(name: 'tarball_url')
  final String? tarballUrl;
  @JsonKey(name: 'zipball_url')
  final String? zipballUrl;
  final int id;
  @JsonKey(name: 'node_id')
  final String nodeId;
  @JsonKey(name: 'tag_name')
  final String tagName;
  @JsonKey(name: 'target_commitish')
  final String targetCommitish;
  final String? name;
  final String? body;
  final bool draft;
  final bool prerelease;
  final bool immutable;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'published_at')
  final DateTime? publishedAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;
  final GitHubUser author;
  final List<ReleaseAsset> assets;
  @JsonKey(name: 'body_html')
  final String? bodyHtml;
  @JsonKey(name: 'body_text')
  final String? bodyText;
  @JsonKey(name: 'mentions_count')
  final int? mentionsCount;
  @JsonKey(name: 'discussion_url')
  final String? discussionUrl;
  final ReactionRollup? reactions;

  GitHubRelease({
    required this.url,
    required this.htmlUrl,
    required this.assetsUrl,
    required this.uploadUrl,
    this.tarballUrl,
    this.zipballUrl,
    required this.id,
    required this.nodeId,
    required this.tagName,
    required this.targetCommitish,
    this.name,
    this.body,
    required this.draft,
    required this.prerelease,
    required this.immutable,
    required this.createdAt,
    this.publishedAt,
    this.updatedAt,
    required this.author,
    required this.assets,
    this.bodyHtml,
    this.bodyText,
    this.mentionsCount,
    this.discussionUrl,
    this.reactions,
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) =>
      _$GitHubReleaseFromJson(json);

  Map<String, dynamic> toJson() => _$GitHubReleaseToJson(this);
}
