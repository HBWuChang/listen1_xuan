import 'package:json_annotation/json_annotation.dart';

part 'ProviderUser.g.dart';

@JsonSerializable()
class ProviderUser {
  final String userId;

  final String name;

  final String platform;

  ProviderUser({
    required this.userId,
    required this.name,
    required this.platform,
  });

  /// 从 JSON 创建实例
  factory ProviderUser.fromJson(Map<String, dynamic> json) =>
      _$ProviderUserFromJson(json);

  /// 转换为 JSON
  Map<String, dynamic> toJson() => _$ProviderUserToJson(this);
}
