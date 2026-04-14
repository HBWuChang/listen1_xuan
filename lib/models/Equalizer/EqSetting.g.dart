// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'EqSetting.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EqSetting _$EqSettingFromJson(Map<String, dynamic> json) => EqSetting(
  equalizers: (json['equalizers'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, AEqualizer.fromJson(e as Map<String, dynamic>)),
  ),
  nowSelected: json['nowSelected'] as String?,
);

Map<String, dynamic> _$EqSettingToJson(EqSetting instance) => <String, dynamic>{
  'equalizers': instance.equalizers,
  'nowSelected': instance.nowSelected,
};
