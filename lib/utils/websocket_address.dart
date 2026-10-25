import 'package:punycode/punycode.dart';

/// Shared address handling for WebSocket connections and their HTTP endpoints.
class WebSocketAddress {
  final String host;
  final int port;

  const WebSocketAddress(this.host, this.port);

  factory WebSocketAddress.parse(String address) {
    final input = address.trim();
    final uri = Uri.parse(
      input.toLowerCase().startsWith('ws://') ? input : 'ws://$input',
    );
    if (uri.scheme != 'ws' ||
        uri.host.isEmpty ||
        !uri.hasPort ||
        uri.port < 1 ||
        uri.port > 65535 ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('地址格式错误，应为 "主机:端口" 或 "[IPv6地址]:端口"');
    }
    // Uri.host includes brackets for IPv6; constructors accept an unbracketed host.
    final host = uri.host;
    return WebSocketAddress(
      host.startsWith('[')
          ? host.substring(1, host.length - 1)
          : Uri.decodeComponent(host),
      uri.port,
    );
  }

  String get address => host.contains(':') ? '[$host]:$port' : '$host:$port';

  Uri uri({String scheme = 'ws', String path = ''}) {
    // Keep international hostnames usable for both WS and HTTP requests.
    final encodedHost = host
        .split('.')
        .map((part) {
          if (part.codeUnits.any((unit) => unit > 127)) {
            return 'xn--${punycodeEncode(part)}';
          }
          return part;
        })
        .join('.');
    return Uri(scheme: scheme, host: encodedHost, port: port, path: path);
  }
}
