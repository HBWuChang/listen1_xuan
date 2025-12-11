// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'MediaState.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaState _$MediaStateFromJson(Map<String, dynamic> json) => MediaState(
  position: Duration(microseconds: (json['position'] as num).toInt()),
  duration: Duration(microseconds: (json['duration'] as num).toInt()),
  playing: json['playing'] as bool,
);

Map<String, dynamic> _$MediaStateToJson(MediaState instance) =>
    <String, dynamic>{
      'position': instance.position.inMicroseconds,
      'duration': instance.duration.inMicroseconds,
      'playing': instance.playing,
    };
