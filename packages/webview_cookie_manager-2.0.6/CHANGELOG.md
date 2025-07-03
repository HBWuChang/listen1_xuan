## 2.0.6

* Remove engine dependency([#55](https://github.com/fryette/webview_cookie_manager/pull/55))
* Document secure cookie usage and restructuring readme([#56](https://github.com/fryette/webview_cookie_manager/pull/56))

## 2.0.5

* bugfix: Build error with Flutter 2.5.1([#47](https://github.com/fryette/webview_cookie_manager/issues/53))

## 2.0.4

* bugfix: Fixed bug where iOS would never return future if cookie list is empty([#47](https://github.com/fryette/webview_cookie_manager/issues/47))

## 2.0.3

* bugfix: Future returned by setCookies never finishes([#47](https://github.com/fryette/webview_cookie_manager/issues/47))

## 2.0.2

* feat: ignore cookies with invalid values([#49](https://github.com/fryette/webview_cookie_manager/pull/49))

## 2.0.1

* feat: add origin url parameter ([#43](https://github.com/fryette/webview_cookie_manager/pull/43))
* bugfix: Forbidden character in cookies ([#44](https://github.com/fryette/webview_cookie_manager/issues/44))

## 2.0.0

* Stable null safety release ([#32](https://github.com/fryette/webview_cookie_manager/issues/32))

## 1.0.8

* Failed to save the cookies without "domain" attribute ([#34](https://github.com/amag2511/webview_cookie_manager/issues/34))

## 1.0.7

* Fix Cannot convert value of type 'Bool' to expected argument type ([#30](https://github.com/amag2511/webview_cookie_manager/issues/30))

## 1.0.6

* Fix failing on get cookies on iOS ([#20](https://github.com/amag2511/webview_cookie_manager/issues/20))

## 1.0.5

* Fix deprecation android warnings ([#22](https://github.com/amag2511/webview_cookie_manager/issues/22))
* Fix remove cookie cause clearing all cookies for all urls ([#23](https://github.com/amag2511/webview_cookie_manager/issues/23))

## 1.0.4

* Update getCookies apply HTTPCookieStorage for iOS
* Bump iOS min version

## 1.0.3

* Fixed `getCookies()` without a URL parameter causes NullPointerExceptions ([#11](https://github.com/amag2511/webview_cookie_manager/issues/8))
* Added `hasCookies()` function
* Added `removeCookie()` function

## 1.0.2

* Fixed Android CookieManager null reference exception ([#8](https://github.com/amag2511/webview_cookie_manager/issues/8))

## 1.0.1

* Update readme
* Set minimum iOS version to 11

## 1.0.0+4

* Improve documentation
* Minor improvements

## 1.0.0+3

* Add issue tracker link

## 1.0.0+2

* Update readme


## 1.0.0+1

* initial release.