// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'MediaState.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaState _$MediaStateFromJson(Map<String, dynamic> json) => MediaState(
  position: Duration(microseconds: (json['position'] as num).toInt()),
  duration: Duration(microseconds: (json['duration'] as num).toInt()),
  buffer: Duration(microseconds: (json['buffer'] as num?)?.toInt() ?? 0),
  buffering: json['buffering'] as bool? ?? false,
  playing: json['playing'] as bool,
);

Map<String, dynamic> _$MediaStateToJson(MediaState instance) =>
    <String, dynamic>{
      'position': instance.position.inMicroseconds,
      'duration': instance.duration.inMicroseconds,
      'buffer': instance.buffer.inMicroseconds,
      'buffering': instance.buffering,
      'playing': instance.playing,
    };
