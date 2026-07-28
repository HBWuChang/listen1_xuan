import 'dart:io';

import 'package:listen1_xuan/models/websocket_message.dart';

import 'cookie_utils.dart';

/// 平台凭据数据类
///
/// 组合 [platform]（平台标识）和 credentials（凭据）为一个对象，
/// 统一处理两类凭据的转换：
/// - **GitHub**(OAuth token)：`String get` 返回原始 token，`List<Cookie> get` 包裹为单 cookie
/// - **其他平台**(cookie)：`String get` 返回序列化的 cookie 字符串，`List<Cookie> get` 返回解析后的列表
class PlatformCredentials {
  final String platform;

  /// 内部统一以字符串存储
  /// - GitHub：原始 OAuth token
  /// - 其他平台：序列化的 cookie 字符串
  final String _raw;

  const PlatformCredentials._({
    required this.platform,
    required String raw,
  }) : _raw = raw;

  /// 统一构造器，接受 [String] 或 [List<Cookie>] 作为 credentials
  ///
  /// 不同平台行为：
  /// - **GitHub + String**：直接作为原始 OAuth token 存储
  /// - **GitHub + List\<Cookie\>**：序列化为字符串存储
  /// - **其他平台 + String**：解析 cookie 字符串后存储序列化形式
  /// - **其他平台 + List\<Cookie\>**：直接序列化存储
  factory PlatformCredentials({
    required String platform,
    dynamic credentials,
  }) {
    if (credentials is String) {
      if (platform == PlantformCodes.github) {
        // GitHub: 原始 token 直接存储
        return PlatformCredentials._(platform: platform, raw: credentials);
      }
      // 其他平台：统一序列化格式存储
      return PlatformCredentials._(
        platform: platform,
        raw: _normalizeCookieString(credentials),
      );
    } else if (credentials is List<Cookie>) {
      // 统一序列化为标准格式
      return PlatformCredentials._(
        platform: platform,
        raw: CookieUtils.serializeCookies(credentials),
      );
    }
    throw ArgumentError('credentials 必须为 String 或 List<Cookie>');
  }

  /// 获取字符串形式的凭据
  /// - GitHub：原始 OAuth token
  /// - 其他平台：序列化的 cookie 字符串
  String get token => _raw;

  /// 获取 [List<Cookie>] 形式的凭据
  /// - GitHub：将 token 包裹为单个 Cookie
  /// - 其他平台：从序列化字符串解析
  List<Cookie> get cookies {
    if (platform == PlantformCodes.github) {
      // GitHub token 包裹为单 cookie 以保持统一
      return [Cookie('token', _raw)];
    }
    return CookieUtils.parseCookieString(_raw);
  }

  /// 获取 [List<Cookie>] 的有效子集，过滤掉 value 为空的 cookie
  List<Cookie> get prcdCookies {
    return cookies.where((c) => c.value.isNotEmpty).toList();
  }

  /// 标准化 cookie 字符串：去除多余空格、统一分隔符
  static String _normalizeCookieString(String input) {
    return CookieUtils.serializeCookies(CookieUtils.parseCookieString(input));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlatformCredentials &&
          runtimeType == other.runtimeType &&
          platform == other.platform &&
          _raw == other._raw;

  @override
  int get hashCode => platform.hashCode ^ _raw.hashCode;

  @override
  String toString() => 'PlatformCredentials(platform: $platform, token: $_raw)';
}
