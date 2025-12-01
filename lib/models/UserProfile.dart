import 'package:json_annotation/json_annotation.dart';

part 'UserProfile.g.dart';

/// 用户资料模型
/// 对应 Supabase users 表
@JsonSerializable()
class UserProfile {
  /// 用户记录的唯一标识符
  final String id;

  /// 关联到 auth.users 表的用户ID
  @JsonKey(name: 'user_id')
  final String userId;

  /// 用户昵称
  final String? nickname;

  /// 用户创建时间
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  /// 用户最后登录时间
  @JsonKey(name: 'last_login_at')
  final DateTime? lastLoginAt;

  /// 记录最后更新时间
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  /// Pro 用户状态
  /// 注意：此字段只能通过 Supabase Dashboard 修改，应用内无法修改
  @JsonKey(name: 'is_pro', defaultValue: false)
  final bool isPro;

  UserProfile({
    required this.id,
    required this.userId,
    this.nickname,
    this.createdAt,
    this.lastLoginAt,
    this.updatedAt,
    this.isPro = false,
  });

  /// 从 JSON 创建实例
  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  /// 转换为 JSON
  Map<String, dynamic> toJson() => _$UserProfileToJson(this);

  /// 创建副本
  UserProfile copyWith({
    String? id,
    String? userId,
    String? nickname,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    DateTime? updatedAt,
    bool? isPro,
  }) {
    return UserProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPro: isPro ?? this.isPro,
    );
  }

  /// 获取显示名称（优先昵称，否则使用邮箱）
  String getDisplayName(String? email) {
    if (nickname != null && nickname!.isNotEmpty) {
      return nickname!;
    }
    if (email != null && email.isNotEmpty) {
      return email;
    }
    return '未知用户';
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, userId: $userId, nickname: $nickname, isPro: $isPro)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserProfile &&
        other.id == id &&
        other.userId == userId &&
        other.nickname == nickname &&
        other.createdAt == createdAt &&
        other.lastLoginAt == lastLoginAt &&
        other.updatedAt == updatedAt &&
        other.isPro == isPro;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        nickname.hashCode ^
        createdAt.hashCode ^
        lastLoginAt.hashCode ^
        updatedAt.hashCode ^
        isPro.hashCode;
  }
}
