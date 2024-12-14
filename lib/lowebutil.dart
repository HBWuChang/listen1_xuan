import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;

String? getParameterByName(String name, [String? url]) {
  if (url == null) {
    url = html.window.location.href;
  }
  name = name.replaceAll(RegExp(r'[\[\]]'), r'\\$&');
  final regex = RegExp('[?&]' + name + '(=([^&#]*)|&|#|\$)');
  final results = regex.firstMatch(url);
  if (results == null) return null;
  if (results.group(2) == null) return '';
  return Uri.decodeComponent(results.group(2)!.replaceAll('+', ' '));
}

bool isElectron() {
  return js.context.hasProperty('process') && js.context['process'].hasProperty('type');
}

void cookieGet(Map<String, String> cookieRequest, Function callback) {
  if (!isElectron()) {
    js.context.callMethod('chrome.cookies.get', [js.JsObject.jsify(cookieRequest), (cookie) {
      callback(cookie);
    }]);
  } else {
    final remote = js.context['require']('electron').remote;
    remote.session.defaultSession.cookies.get(js.JsObject.jsify(cookieRequest)).then((cookieArray) {
      var cookie = null;
      if (cookieArray.length > 0) {
        cookie = cookieArray[0];
      }
      callback(cookie);
    });
  }
}

void cookieSet(Map<String, dynamic> cookie, Function callback) {
  if (!isElectron()) {
    js.context.callMethod('chrome.cookies.set', [js.JsObject.jsify(cookie), (arg1, arg2) {
      callback(arg1, arg2);
    }]);
  } else {
    final remote = js.context['require']('electron').remote;
    remote.session.defaultSession.cookies.set(js.JsObject.jsify(cookie)).then((arg1, arg2) {
      callback(null, arg1, arg2);
    });
  }
}

void cookieRemove(Map<String, String> cookie, Function callback) {
  if (!isElectron()) {
    js.context.callMethod('chrome.cookies.remove', [js.JsObject.jsify(cookie), (arg1, arg2) {
      callback(arg1, arg2);
    }]);
  } else {
    final remote = js.context['require']('electron').remote;
    remote.session.defaultSession.cookies.remove(cookie['url'], cookie['name']).then((arg1, arg2) {
      callback(null, arg1, arg2);
    });
  }
}

// void setPrototypeOfLocalStorage() {
//   final proto = html.window.localStorage;
//   proto['getObject'] = (String key) {
//     final value = proto[key];
//     try {
//       return value != null ? jsonDecode(value) : {};
//     } catch (error) {
//       return {};
//     }
//   };
//   proto['setObject'] = (String key, dynamic value) {
//     proto[key] = jsonEncode(value);
//   };
// }

dynamic getLocalStorageValue(String key, dynamic defaultValue) {
  final keyString = html.window.localStorage[key];
  var result = keyString != null ? jsonDecode(keyString) : null;
  if (result == null) {
    result = defaultValue;
  }
  return result;
}

num easeInOutQuad(num t, num b, num c, num d) {
  t /= d / 2;
  if (t < 1) return c / 2 * t * t + b;
  t -= 1;
  return -c / 2 * (t * (t - 2) - 1) + b;
}

// void smoothScrollTo(html.Element element, num to, num duration) {
//   final start = element.scrollTop;
//   final change = to - start;
//   var currentTime = 0;
//   const increment = 20;

//   void animateScroll() {
//     currentTime += increment;
//     final val = easeInOutQuad(currentTime, start, change, duration);
//     element.scrollTop = val;
//     if (currentTime < duration) {
//       html.window.setTimeout(animateScroll, increment);
//     }
//   }

//   animateScroll();
// }