import 'dart:io';

/// Listen on both address families, with IPv4 fallback on IPv4-only systems.
Future<HttpServer> bindWebSocketServer(String host, int port) async {
  try {
    return await HttpServer.bind(host, port, shared: true, v6Only: false);
  } on SocketException {
    if (host != InternetAddress.anyIPv6.address) rethrow;
    return HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
  }
}
