# Webview Cookie Manager
[![pub package](https://img.shields.io/pub/v/webview_cookie_manager.svg)](https://pub.dartlang.org/packages/webview_cookie_manager)

A flutter library to manager your web cookies for Android (API level 9+) and iOS (11+).

The cookies stores and retrieves using the [httpCookieStore](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/2881956-httpcookiestore) for iOS and [CookieManager](https://developer.android.com/reference/android/webkit/CookieManager) for Android.

## Get started iOS
Set minimum version for iOS to 11.0

## Usage
The WebCookieManager can be used directly or together with [webview_flutter](https://pub.dev/packages/webview_flutter).

### Get cookies
```dart
final cookieManager = WebviewCookieManager();

final gotCookies = await cookieManager.getCookies('https://youtube.com');
for (var item in gotCookies) {
  print(item);
}
```

### Set a cookie
```dart
await cookieManager.setCookies([
              Cookie('cookieName', 'cookieValue')
                ..domain = 'youtube.com'
                ..expires = DateTime.now().add(Duration(days: 10))
                ..httpOnly = false
            ]);
```

### Check is any cookie available
```dart
await cookieManager.hasCookies();
```

### Remove a cookie
```dart
await cookieManager.removeCookie();
```

### Clear cookies
```dart
await cookieManager.clearCookies();
```

### Domain attribute
Domain attribute is not required according to [RFC](https://tools.ietf.org/html/rfc6265#section-5.2.3), but it is important to remember that empty domain causes undefined behavior. So it is highly reccommended to specify it this this way:
```dart
final cookie = Cookie('cookieName', 'cookieValue')..domain = 'youtube.com';
```

### Secure attribute
If you see the error `Strict Secure Cookie policy does not allow setting a secure cookie for http://your-domain.net/ for apps targeting >= R. Please either use the 'https:' scheme for this URL or omit the 'Secure' directive in the cookie value.` Then you need to set the origin while setting the cookie, in that case setting the domain is not required.
```dart
final cookies = <Cookie>[];
// Add your cookie with secure flag to the array
cookieManager.setCookies(cookies, origin: 'https://your-domain.net')
```

## Troubleshooting on iOS
 1) Set minimum target iOS version to 11 ([see also #17](https://github.com/fryette/webview_cookie_manager/issues/17#issuecomment-682382429))
 2) If you are using Objective C, check that PodFile have a flag use_frameworks ([see also #4](https://github.com/fryette/webview_cookie_manager/issues/4#issuecomment-665508540))
```
target 'Runner' do
  use_frameworks!
  use_modular_headers!
  ..........
end
```
