import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/controllers.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/global_settings_animations.dart';
import 'package:listen1_xuan/play.dart';
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
  Widget onPageBuilt(Widget page) {
    Get.find<PlayController>().collapseSheet();
    return page;
  }

  @override
  void onPageDispose() {
    debugPrint("onPageDispose: ${Get.currentRoute}");
    if (disposedByClean > 0) {
      disposedByClean--;
    } else {
      top_routeWithName.removeLast();
    }
  }
}

int last_pop_time = 0;
void router_pop() {
  debugPrint("didPop: didPop,");
  if (Get.find<PlayController>().tryCollapseSheet()) return;
  if (top_routeWithName.isNotEmpty) {
    Get.back(id: 1);
    return;
  }

  if (DateTime.now().millisecondsSinceEpoch - last_pop_time < 1000) {
    if (isDesktop) {
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
    showInfoSnackbar(isDesktop ? "再按一次以最小化" : "再按一次退出", null);
    last_pop_time = DateTime.now().millisecondsSinceEpoch;
  }
}

Future<void> closeApp() async {
  final RxBool settingsSaved = false.obs;
  final RxBool continuePlaysaved = false.obs;
  final RxBool timeoutReached = false.obs;

  // 设置超时时间（例如5秒）
  Duration timeoutDuration = Duration(
    milliseconds:
        Get.find<SettingsController>().supabaseUploadTimeoutDurationOnExit,
  );

  void performExit() {
    Get.back();
    if (kDebugMode) {
      print("exit(0)");
    } else {
      exit(0);
    }
  }

  Get.dialog(
    Obx(() {
      // 当两个任务都完成时，自动关闭
      // 或者超时且 saveSettings 完成时，自动关闭
      if ((settingsSaved.value && continuePlaysaved.value) ||
          (timeoutReached.value && settingsSaved.value)) {
        Future.microtask(performExit);
      }

      return AlertDialog(
        title: Text('正在退出'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (settingsSaved.value)
                  Icon(Icons.check_circle, color: Get.theme.colorScheme.primary)
                else
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                SizedBox(width: 12),
                Text('保存设置'),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                if (continuePlaysaved.value)
                  Icon(Icons.check_circle, color: Get.theme.colorScheme.primary)
                else if (timeoutReached.value)
                  Icon(Icons.warning, color: Get.theme.colorScheme.error)
                else
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                SizedBox(width: 12),
                Text(
                  timeoutReached.value && !continuePlaysaved.value
                      ? '同步超时'
                      : '同步播放状态',
                ),
              ],
            ),
          ],
        ),
        actions: [
          // 只有当 saveSettings 完成但 updateContinuePlay 未完成时显示跳过按钮
          if (settingsSaved.value && !continuePlaysaved.value)
            TextButton(
              onPressed: performExit,
              child: Text('跳过向 Supabase 更新状态'),
            ),
        ],
      );
    }),
    barrierDismissible: false,
  );

  // 设置超时计时器
  Future.delayed(timeoutDuration, () {
    if (!continuePlaysaved.value) {
      timeoutReached.value = true;
    }
  });
  Get.find<SettingsController>().settings[PlayController
          .positionInMillisecondsKey] =
      Get.find<PlayController>().positionInMilliseconds.value;
  // 并行执行两个任务
  Future.wait([
    Get.find<SettingsController>().saveSettings().then((_) {
      settingsSaved.value = true;
    }),
    Get.find<PlayController>().updateContinuePlay(onlyPlaying: true).then((
      _,
    ) async {
      continuePlaysaved.value = true;
    }),
  ]);
}

class RouteController extends GetxController {
  RxBool inLyricPage = false.obs;
  RxBool inNowPlayListPage = false.obs;
  RxBool inSongReplacePage = false.obs;
  @override
  void onInit() {
    super.onInit();
    ever(top_routeWithName, (callback) {
      inLyricPage.value = false;
      inNowPlayListPage.value = false;
      inSongReplacePage.value = false;
      if (top_routeWithName.isNotEmpty) {
        switch (top_routeWithName.last.name) {
          case RouteName.lyricPage:
            inLyricPage.value = true;
          case RouteName.nowPlayingPage:
            inNowPlayListPage.value = true;
          case RouteName.songReplacePage:
            inSongReplacePage.value = true;
        }
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
  static const String supabaseLoginPage = '/supabase_login';
  static const String supabasePasswordLoginPage = '/supabase_password_login';
  static const String cacheNamingPage = '/cache_naming';
  static const String songReplacePage = '/song_replace';
}
