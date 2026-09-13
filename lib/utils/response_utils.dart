import 'dart:convert';

/// Dio 只有在响应头为 JSON 时才会自动解析 `response.data`，
/// 而部分平台接口（网易云、QQ、酷狗）会以 text/plain 返回，
/// 这里统一兼容「已解析的 Map」与「待解析的 String」两种形式。
dynamic decodeResponseData(dynamic data) {
  if (data is String) {
    return data.isEmpty ? null : jsonDecode(data);
  }
  return data;
}
