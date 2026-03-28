import 'package:json_annotation/json_annotation.dart';

part 'MediaState.g.dart';

/// 媒体播放状态模型
/// 用于表示音频播放器的当前状态
@JsonSerializable()
class MediaState {
  /// 当前播放位置
  Duration position;

  /// 音频总时长
  Duration duration;

  Duration buffer;

  bool buffering;

  /// 是否正在播放
  bool playing;

  MediaState({
    required this.position,
    required this.duration,
    required this.buffer,
    required this.buffering,
    required this.playing,
  });

  /// 创建带有更新字段的副本
  MediaState copyWith({
    Duration? position,
    Duration? duration,
    Duration? buffer,
    bool? buffering,
    bool? playing,
  }) {
    return MediaState(
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffer: buffer ?? this.buffer,
      buffering: buffering ?? this.buffering,
      playing: playing ?? this.playing,
    );
  }

  /// 从 JSON 创建实例
  factory MediaState.fromJson(Map<String, dynamic> json) =>
      _$MediaStateFromJson(json);

  /// 转换为 JSON
  Map<String, dynamic> toJson() => _$MediaStateToJson(this);

  @override
  String toString() =>
      'MediaState(position: $position, duration: $duration, buffer: $buffer, buffering: $buffering, playing: $playing)';
}
