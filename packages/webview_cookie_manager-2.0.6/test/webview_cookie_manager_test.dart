import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';

void main() {
  const MethodChannel channel = MethodChannel('webview_cookie_manager');

  TestWidgetsFlutterBinding.ensureInitialized();

  List<Map<String, String>> cookies = [
    {
      "name": "valid_cookie",
      "value": "1111-2222-3333-4444",
      "path": "/",
      "domain": "http://www.test.com",
    },
    {
      "name": "invalid_cookie",
      "value": "1111,2222,3333,4444",
      "path": "/",
      "domain": "http://www.test.com",
    },
    {
      "name": "another_valid_cookie",
      "value": "1111222233334444",
      "path": "/",
      "domain": "http://www.test.com",
    },
  ];

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return cookies;
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('The invalid cookie is ignored', () async {
    final cookieManager = WebviewCookieManager();

    final cookies = await cookieManager.getCookies('http://www.test.com');

    expect(cookies.length, 2);
    expect(cookies.first.name, "valid_cookie");
    expect(cookies.last.name, "another_valid_cookie");
  });
}
