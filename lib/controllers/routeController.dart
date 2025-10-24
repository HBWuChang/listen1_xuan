import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/global_settings_animations.dart';
import 'package:window_manager/window_manager.dart';

import 'settings_controller.dart';

class routeWithName {
  final Route route;
  final String name;
  routeWithName(this.route, this.name);
}

Route get topRoute {
  if (top_routeWithName.isNotEmpty) {
    return top_routeWithName.last.route;
  } else {
    throw Exception("No routes in stack");
  }
}

int disposedByClean = 0;

RxList<routeWithName> top_routeWithName = RxList.empty(growable: true);

void addAndCleanReapeatRoute(Route route, String name) {
  if (top_routeWithName.isNotEmpty) {
    // 清除重复的路由
    top_routeWithName.removeWhere((r) {
      if (r.route.settings.name == route.settings.name) {
        disposedByClean++;
        Get.removeRoute(r.route, id: 1);
        return true;
      }
      return false;
    });
  }
  top_routeWithName.add(routeWithName(route, name));
}

class ListenPopMiddleware extends GetMiddleware {
  @override
  void onPageDispose() {
    print("onPageDispose: ${Get.currentRoute}");
    if (disposedByClean > 0) {
      disposedByClean--;
    } else {
      top_routeWithName.removeLast();
    }
  }
}

int last_pop_time = 0;
void router_pop() {
  print("didPop: didPop,");
  if (top_routeWithName.isNotEmpty) {
    Get.back(id: 1);
    return;
  }

  if (DateTime.now().millisecondsSinceEpoch - last_pop_time < 1000) {
    if (is_windows) {
      windowManager.minimize();
      windowManager.setSkipTaskbar(false);
      return;
    }
    if (kDebugMode) {
      print("exit(0)");
    } else {
      closeApp();
    }
  } else {
    xuan_toast(
      msg: is_windows ? "再按一次以最小化" : "再按一次退出",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.black54,
      textColor: Colors.white,
      fontSize: 16.0,
    );
    last_pop_time = DateTime.now().millisecondsSinceEpoch;
  }
}

Future<void> closeApp() async {
  Get.dialog(
    AlertDialog(title: Text('正在保存设置'), content: CircularProgressIndicator()),
    barrierDismissible: false,
  );
  await Get.find<SettingsController>().saveSettings();
  exit(0);
}

class RouteController extends GetxController {
  RxBool inLyricPage = false.obs;
  @override
  void onInit() {
    super.onInit();
    ever(top_routeWithName, (callback) {
      if (top_routeWithName.isNotEmpty &&
          top_routeWithName.last.name == RouteName.lyricPage) {
        inLyricPage.value = true;
      } else {
        inLyricPage.value = false;
      }
    });
  }
}

class RouteName {
  static const String defaultPage = '/';
  static const String lyricPage = '/lyric';
  static const String searchPage = '/search';
  static const String nowPlayingPage = '/now_playing';
  static const String settingsPage = '/settings';
  static const String settingsReadmePage = '/settings_readme';
  static const String downloadPage = '/download';
}
