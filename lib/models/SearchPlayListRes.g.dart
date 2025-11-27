// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'SearchPlayListRes.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SearchPlayListItem _$SearchPlayListItemFromJson(Map<String, dynamic> json) =>
    SearchPlayListItem(
      id: json['id'] as String?,
      title: json['title'] as String?,
      source: json['source'] as String?,
      sourceUrl: json['source_url'] as String?,
      imgUrl: json['img_url'] as String?,
      url: json['url'] as String?,
      author: json['author'] as String?,
      count: (json['count'] as num?)?.toInt(),
    );

Map<String, dynamic> _$SearchPlayListItemToJson(SearchPlayListItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'source': instance.source,
      'source_url': instance.sourceUrl,
      'img_url': instance.imgUrl,
      'url': instance.url,
      'author': instance.author,
      'count': instance.count,
    };

SearchPlayListRes _$SearchPlayListResFromJson(Map<String, dynamic> json) =>
    SearchPlayListRes(
      result: (json['result'] as List<dynamic>)
          .map((e) => SearchPlayListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
      type: json['type'] as String,
    );

Map<String, dynamic> _$SearchPlayListResToJson(SearchPlayListRes instance) =>
    <String, dynamic>{
      'result': instance.result,
      'total': instance.total,
      'type': instance.type,
    };
