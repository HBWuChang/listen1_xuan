import 'package:json_annotation/json_annotation.dart';

part 'Playlist.g.dart';

/// 播放列表模型
/// 对应 Supabase playlist 表
/// 注意：只有 Pro 用户可以创建、修改和删除播放列表
@JsonSerializable()
class Playlist {
  /// 播放列表唯一标识符
  final String id;

  /// 用户ID
  @JsonKey(name: 'user_id')
  final String userId;

  /// 是否公开分享
  @JsonKey(name: 'is_share', defaultValue: false)
  final bool isShare;

  /// 播放列表名称
  final String name;

  /// 播放列表数据（JSONB格式）
  /// 存储歌曲列表等信息
  @JsonKey(defaultValue: <String, dynamic>{})
  final Map<String, dynamic> data;

  /// 创建时间
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  /// 更新时间
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  Playlist({
    required this.id,
    required this.userId,
    this.isShare = false,
    required this.name,
    this.data = const <String, dynamic>{},
    this.createdAt,
    this.updatedAt,
  });

  /// 从 JSON 创建实例
  factory Playlist.fromJson(Map<String, dynamic> json) =>
      _$PlaylistFromJson(json);

  /// 转换为 JSON
  Map<String, dynamic> toJson() => _$PlaylistToJson(this);

  /// 创建副本
  Playlist copyWith({
    String? id,
    String? userId,
    bool? isShare,
    String? name,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      isShare: isShare ?? this.isShare,
      name: name ?? this.name,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 获取播放列表中的歌曲数量
  int get songCount {
    if (data['songs'] is List) {
      return (data['songs'] as List).length;
    }
    return 0;
  }

  /// 获取歌曲列表
  List<dynamic> get songs {
    if (data['songs'] is List) {
      return data['songs'] as List;
    }
    return [];
  }

  /// 判断播放列表是否为空
  bool get isEmpty => songCount == 0;

  @override
  String toString() {
    return 'Playlist(id: $id, name: $name, isShare: $isShare, songCount: $songCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Playlist &&
        other.id == id &&
        other.userId == userId &&
        other.isShare == isShare &&
        other.name == name &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        isShare.hashCode ^
        name.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
