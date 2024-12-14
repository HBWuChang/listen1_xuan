import 'dart:convert';
// import 'dart:html' as html;
// import 'dart:js' as js;

// dynamic getParameterByName(String name, [String? url]) {
dynamic getParameterByName(String name, String url) {
  // if (url == null) {
  //   url = html.window.location.href;
  // }
  name = name.replaceAll(RegExp(r'[\[\]]'), r'\\$&');
  final regex = RegExp('[?&]' + name + '(=([^&#]*)|&|#|\$)');
  final results = regex.firstMatch(url);
  if (results == null) return null;
  if (results.group(2) == null) return '';
  return Uri.decodeComponent(results.group(2)!.replaceAll('+', ' '));
  // return "";
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