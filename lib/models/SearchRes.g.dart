// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'SearchRes.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SearchRes _$SearchResFromJson(Map<String, dynamic> json) => SearchRes(
  result: (json['result'] as List<dynamic>)
      .map((e) => Track.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
  error: json['error'] as String?,
);

Map<String, dynamic> _$SearchResToJson(SearchRes instance) => <String, dynamic>{
  'result': instance.result,
  'total': instance.total,
  'error': instance.error,
};
