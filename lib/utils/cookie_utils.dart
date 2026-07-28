import 'dart:io';

/// Cookie 工具类，提供 String 与 List<Cookie> 之间的互相转换
class CookieUtils {
  /// 将 "name=value; name2=value2" 格式的 cookie 字符串解析为 [List<Cookie>]
  ///
  /// [cookieStr] 中的 name 和 value 部分两端的空格会被修剪，
  /// value 保持原样不做转码处理。
  static List<Cookie> parseCookieString(String cookieStr) {
    if (cookieStr.isEmpty) return [];
    return cookieStr.split(';').map((item) {
      final trimmed = item.trim();
      final eqIndex = trimmed.indexOf('=');
      if (eqIndex == -1) return Cookie(trimmed, '');
      final name = trimmed.substring(0, eqIndex).trim();
      final value = trimmed.substring(eqIndex + 1).trim();
      return Cookie(name, value);
    }).toList();
  }

  /// 将 [List<Cookie>] 序列化为 "name=value; name2=value2" 格式的字符串
  ///
  /// value 保持原样不做转码，以兼容包含 URL 编码值（如 B站 SESSDATA）的 cookie。
  static String serializeCookies(List<Cookie> cookies) {
    return cookies
        .map((c) => '${c.name}=${c.value}')
        .join('; ');
  }

  /// 从 [List<Cookie>] 中获取指定 [name] 的 cookie 值，未找到时返回 null
  static String? getCookieValue(List<Cookie> cookies, String name) {
    return cookies.where((c) => c.name == name).firstOrNull?.value;
  }
}
