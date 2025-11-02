import 'package:listen1_xuan/models/Track.dart';

/// Supabase 继续播放模型
/// 用于在多设备间同步播放进度
class SupaContinuePlay {
  /// 当前播放的曲目
  final Track track;

  /// 更新时间（由 Supabase 自动生成）
  final DateTime? updTime;

  /// 是否正在播放
  final bool playing;

  /// 扩展字段（JSON 类型，保留使用）
  final Map<String, dynamic>? ext;

  /// 设备 ID（用于确认发送设备）
  final String deviceId;

  SupaContinuePlay({
    required this.track,
    this.updTime,
    required this.playing,
    this.ext,
    required this.deviceId,
  });

  /// 从 JSON 创建实例
  factory SupaContinuePlay.fromJson(Map<String, dynamic> json) {
    return SupaContinuePlay(
      track: Track.fromJson(json['track'] as Map<String, dynamic>),
      updTime: json['upd_time'] != null
          ? DateTime.parse(json['upd_time'] as String)
          : null,
      playing: json['playing'] as bool,
      ext: json['ext'] as Map<String, dynamic>?,
      deviceId: json['device_id'] as String,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'track': track.toJson(),
      'playing': playing,
      'ext': ext,
      'device_id': deviceId,
      // upd_time 由 Supabase 自动生成，不需要在这里设置
    };
  }

  /// 创建副本
  SupaContinuePlay copyWith({
    Track? track,
    DateTime? updTime,
    bool? playing,
    Map<String, dynamic>? ext,
    String? deviceId,
  }) {
    return SupaContinuePlay(
      track: track ?? this.track,
      updTime: updTime ?? this.updTime,
      playing: playing ?? this.playing,
      ext: ext ?? this.ext,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
