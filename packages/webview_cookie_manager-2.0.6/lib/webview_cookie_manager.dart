import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class WebviewCookieManager {
  static const _channel = MethodChannel('webview_cookie_manager');

  /// Creates a [CookieManager] -- returns the instance if it's already been called.
  factory WebviewCookieManager() {
    return _instance ??= WebviewCookieManager._();
  }

  WebviewCookieManager._();

  static WebviewCookieManager? _instance;

  /// Gets whether there are stored cookies
  Future<bool> hasCookies() {
    return _channel
        .invokeMethod<bool>('hasCookies')
        .then<bool>((bool? result) => result ?? false);
  }

  /// Read out all cookies, or all cookies for a [url] when provided
  Future<List<Cookie>> getCookies(String? url) {
    return _channel.invokeListMethod<Map>('getCookies', {'url': url}).then(
        (results) => results == null
            ? <Cookie>[]
            : results
                .map((Map result) {
                  Cookie? c;
                  try {
                    c = Cookie(result['name'] ?? '',
                        removeInvalidCharacter(result['value'] ?? ''))
                      // following values optionally work on iOS only
                      ..path = result['path']
                      ..domain = result['domain']
                      ..secure = result['secure'] ?? false
                      ..httpOnly = result['httpOnly'] ?? true;

                    if (result['expires'] != null) {
                      c.expires = DateTime.fromMillisecondsSinceEpoch(
                          (result['expires'] * 1000).toInt());
                    }
                  } on FormatException catch (_) {
                    c = null;
                  }
                  return c;
                })
                .whereType<Cookie>()
                .toList());
  }

  /// Remove cookies with [currentUrl] for IOS and Android
  Future<void> removeCookie(String currentUrl) async {
    final listCookies = await getCookies(currentUrl);
    final serializedCookies = listCookies
        .where((element) => element.domain != null
            ? currentUrl.contains(element.domain!)
            : false)
        .toList();
    serializedCookies
        .forEach((c) => c.expires = DateTime.fromMicrosecondsSinceEpoch(0));
    await setCookies(serializedCookies);
  }

  /// Remove all cookies
  Future<void> clearCookies() {
    return _channel.invokeMethod<void>('clearCookies');
  }

  /// Set [cookies] into the web view
  Future<void> setCookies(List<Cookie> cookies, {String? origin}) {
    final transferCookies = cookies.map((Cookie c) {
      final output = <String, dynamic>{
        if (origin != null) 'origin': origin,
        'name': c.name,
        'value': c.value,
        'path': c.path,
        'domain': c.domain,
        'secure': c.secure,
        'httpOnly': c.httpOnly,
        'asString': c.toString(),
      };

      if (c.expires != null) {
        output['expires'] = c.expires!.millisecondsSinceEpoch ~/ 1000;
      }

      return output;
    }).toList();
    return _channel.invokeMethod<void>('setCookies', transferCookies);
  }

  String removeInvalidCharacter(String value) {
    // Remove Invalid Character
    var valueModified = value.replaceAll('\\"', "'").replaceAll("\\", "");
    valueModified = valueModified.replaceAll(String.fromCharCode(32), "");
    return valueModified;
  }
}
