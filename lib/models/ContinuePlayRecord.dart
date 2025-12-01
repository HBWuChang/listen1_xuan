import 'package:json_annotation/json_annotation.dart';

part 'ContinuePlayRecord.g.dart';

/// 继续播放记录模型
/// 对应 Supabase continue_play 表
/// 用于在多设备间同步播放进度
@JsonSerializable()
class ContinuePlayRecord {
  /// 记录唯一标识符
  final String id;

  /// 用户ID
  @JsonKey(name: 'user_id')
  final String userId;

  /// 当前播放的曲目信息（JSONB格式）
  @JsonKey(defaultValue: <String, dynamic>{})
  final Map<String, dynamic> track;

  /// 更新时间（由 Supabase 自动生成）
  @JsonKey(name: 'upd_time')
  final DateTime? updTime;

  /// 是否正在播放
  @JsonKey(defaultValue: false)
  final bool playing;

  /// 扩展字段（JSON格式，保留使用）
  final Map<String, dynamic>? ext;

  /// 设备ID（用于确认发送设备）
  @JsonKey(name: 'device_id')
  final String deviceId;

  /// 记录创建时间
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  ContinuePlayRecord({
    required this.id,
    required this.userId,
    this.track = const <String, dynamic>{},
    this.updTime,
    this.playing = false,
    this.ext,
    required this.deviceId,
    this.createdAt,
  });

  /// 从 JSON 创建实例
  factory ContinuePlayRecord.fromJson(Map<String, dynamic> json) =>
      _$ContinuePlayRecordFromJson(json);

  /// 转换为 JSON
  Map<String, dynamic> toJson() => _$ContinuePlayRecordToJson(this);

  /// 创建副本
  ContinuePlayRecord copyWith({
    String? id,
    String? userId,
    Map<String, dynamic>? track,
    DateTime? updTime,
    bool? playing,
    Map<String, dynamic>? ext,
    String? deviceId,
    DateTime? createdAt,
  }) {
    return ContinuePlayRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      track: track ?? this.track,
      updTime: updTime ?? this.updTime,
      playing: playing ?? this.playing,
      ext: ext ?? this.ext,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 获取曲目ID
  String? get trackId => track['id'] as String?;

  /// 获取曲目标题
  String? get trackTitle => track['title'] as String?;

  /// 获取艺术家
  String? get trackArtist => track['artist'] as String?;

  /// 获取专辑
  String? get trackAlbum => track['album'] as String?;

  /// 获取封面图片URL
  String? get trackImageUrl => track['img_url'] as String?;

  /// 获取音源
  String? get trackSource => track['source'] as String?;

  /// 判断是否有有效的曲目信息
  bool get hasTrack => trackId != null && trackId!.isNotEmpty;

  @override
  String toString() {
    return 'ContinuePlayRecord(id: $id, userId: $userId, deviceId: $deviceId, '
        'playing: $playing, trackTitle: $trackTitle)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ContinuePlayRecord &&
        other.id == id &&
        other.userId == userId &&
        other.deviceId == deviceId &&
        other.playing == playing &&
        other.updTime == updTime;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        deviceId.hashCode ^
        playing.hashCode ^
        updTime.hashCode;
  }
}
