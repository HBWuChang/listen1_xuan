// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'GitHubRelease.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GitHubRelease _$GitHubReleaseFromJson(Map<String, dynamic> json) =>
    GitHubRelease(
      url: json['url'] as String,
      htmlUrl: json['html_url'] as String,
      assetsUrl: json['assets_url'] as String,
      uploadUrl: json['upload_url'] as String,
      tarballUrl: json['tarball_url'] as String?,
      zipballUrl: json['zipball_url'] as String?,
      id: (json['id'] as num).toInt(),
      nodeId: json['node_id'] as String,
      tagName: json['tag_name'] as String,
      targetCommitish: json['target_commitish'] as String,
      name: json['name'] as String?,
      body: json['body'] as String?,
      draft: json['draft'] as bool,
      prerelease: json['prerelease'] as bool,
      immutable: json['immutable'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      publishedAt: json['published_at'] == null
          ? null
          : DateTime.parse(json['published_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      author: GitHubUser.fromJson(json['author'] as Map<String, dynamic>),
      assets: (json['assets'] as List<dynamic>)
          .map((e) => ReleaseAsset.fromJson(e as Map<String, dynamic>))
          .toList(),
      bodyHtml: json['body_html'] as String?,
      bodyText: json['body_text'] as String?,
      mentionsCount: (json['mentions_count'] as num?)?.toInt(),
      discussionUrl: json['discussion_url'] as String?,
      reactions: json['reactions'] == null
          ? null
          : ReactionRollup.fromJson(json['reactions'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$GitHubReleaseToJson(GitHubRelease instance) =>
    <String, dynamic>{
      'url': instance.url,
      'html_url': instance.htmlUrl,
      'assets_url': instance.assetsUrl,
      'upload_url': instance.uploadUrl,
      'tarball_url': instance.tarballUrl,
      'zipball_url': instance.zipballUrl,
      'id': instance.id,
      'node_id': instance.nodeId,
      'tag_name': instance.tagName,
      'target_commitish': instance.targetCommitish,
      'name': instance.name,
      'body': instance.body,
      'draft': instance.draft,
      'prerelease': instance.prerelease,
      'immutable': instance.immutable,
      'created_at': instance.createdAt.toIso8601String(),
      'published_at': instance.publishedAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'author': instance.author,
      'assets': instance.assets,
      'body_html': instance.bodyHtml,
      'body_text': instance.bodyText,
      'mentions_count': instance.mentionsCount,
      'discussion_url': instance.discussionUrl,
      'reactions': instance.reactions,
    };
