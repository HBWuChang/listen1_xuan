import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/play.dart';
import 'package:loading_animations/loading_animations.dart';
import 'package:animations/animations.dart';
import 'package:universal_io/io.dart' as universal_io;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'const.dart';
import 'controllers/settings_controller.dart';
import 'funcs.dart';
import 'settings.dart';
import 'package:window_manager/window_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;

Future<Directory> xuanGetdataDirectory() async {
  if (isAndroid || isIos) {
    if (!(await Permission.manageExternalStorage.request().isGranted ||
        await Permission.storage.request().isGranted)) {
      showInfoSnackbar('请务必授予存储权限以下载歌曲及读取配置文件等操作', '本应用不会访问您的个人数据');
      if (!(await Permission.manageExternalStorage.request().isGranted ||
          await Permission.storage.request().isGranted))
        throw Exception('Storage permission not granted');
    }
  }

  return await xuanGetdownloadDirectory();
}

///若传入 path，则返回 dataDirectory/path 的字符串路径，否则返回 Directory 对象
Future<dynamic> xuanGetdownloadDirectory({String? path}) async {
  Directory? tempDir;
  if (isWindows) {
    tempDir = await getDownloadsDirectory();
  } else if (isMacOS) {
    tempDir = await getDownloadsDirectory();
  } else if (isAndroid) {
    tempDir = Directory('/storage/emulated/0/Download');
  } else if (isIos) {
    // tempDir = await getdirectory
  }
  tempDir ??= await getApplicationDocumentsDirectory();
  // 检查是否存在 Listen1 文件夹
  var listen1Dir = isIos
      ? tempDir
      : Directory(p.join(tempDir.path, downDirName));
  if (!await listen1Dir.exists()) {
    // 如果不存在，则创建
    await listen1Dir.create(recursive: true);
  }
  // 更新 tempDir 为 Listen1 文件夹
  tempDir = listen1Dir;

  if (path != null) {
    // 检查是否存在指定的文件夹
    var customDir = p.join(tempDir.path, path);
    return customDir;
  }
  return tempDir;
}

final bool isWindows = universal_io.Platform.isWindows;
final bool isIos = universal_io.Platform.isIOS;
final bool isMacOS = universal_io.Platform.isMacOS;
final bool isAndroid = universal_io.Platform.isAndroid;
final bool isDesktop =
    universal_io.Platform.isWindows ||
    universal_io.Platform.isMacOS ||
    universal_io.Platform.isLinux;
final bool isMobile =
    universal_io.Platform.isIOS || universal_io.Platform.isAndroid;
void init_hotkeys() async {
  var settings = settings_getsettings();
  var hotskeys = settings["hotkeys"];
  if (hotskeys == null) {
    hotskeys = {
      "enable": false,
      "play_pause": null,
      "next": null,
      "previous": null,
      "show": null,
    };
    settings["hotkeys"] = hotskeys;
    Get.find<SettingsController>().setSettings(settings);
  }
  enable_hotkey = hotskeys["enable"];
  if (hotskeys["play_pause"] != null) {
    set_hotkey(null, HotKey.fromJson(hotskeys["play_pause"]), "play_pause");
  }
  if (hotskeys["next"] != null) {
    set_hotkey(null, HotKey.fromJson(hotskeys["next"]), "next");
  }
  if (hotskeys["previous"] != null) {
    set_hotkey(null, HotKey.fromJson(hotskeys["previous"]), "previous");
  }
  if (hotskeys["show"] != null) {
    set_hotkey(null, HotKey.fromJson(hotskeys["show"]), "show");
  }
}

Map<String, HotKey> inapp_hotkeys = {
  "space": HotKey(key: PhysicalKeyboardKey.space, scope: HotKeyScope.inapp),
  "arrowLeft": HotKey(key: PhysicalKeyboardKey.keyA, scope: HotKeyScope.inapp),
  "arrowRight": HotKey(key: PhysicalKeyboardKey.keyD, scope: HotKeyScope.inapp),
  "arrowUp": HotKey(key: PhysicalKeyboardKey.keyW, scope: HotKeyScope.inapp),
  "arrowDown": HotKey(key: PhysicalKeyboardKey.keyS, scope: HotKeyScope.inapp),
  "next": HotKey(key: PhysicalKeyboardKey.keyE, scope: HotKeyScope.inapp),
  "previous": HotKey(key: PhysicalKeyboardKey.keyQ, scope: HotKeyScope.inapp),
};
Map<LogicalKeyboardKey, dynamic> inappShortcuts = {
  LogicalKeyboardKey.space: globalPlayOrPause,
  LogicalKeyboardKey.keyA: globalSeekToPrevious,
  LogicalKeyboardKey.keyD: globalSeekToNext,
  LogicalKeyboardKey.keyW: globalVolumeUp,
  LogicalKeyboardKey.keyS: globalVolumeDown,
  LogicalKeyboardKey.keyE: globalSkipToNext,
  LogicalKeyboardKey.keyQ: globalSkipToPrevious,
  LogicalKeyboardKey.arrowLeft: globalSeekToPrevious,
  LogicalKeyboardKey.arrowRight: globalSeekToNext,
  LogicalKeyboardKey.arrowUp: globalVolumeUp,
  LogicalKeyboardKey.arrowDown: globalVolumeDown,
  // ","
  LogicalKeyboardKey.comma: globalSkipToPrevious,
  // "."
  LogicalKeyboardKey.period: globalSkipToNext,
};
bool enable_inapp_hotkey = true;
void set_inapp_hotkey(enable) {
  enable_inapp_hotkey = enable;
}

Future<void> set_hotkey(s_hotkey, hotkey, name) async {
  if (s_hotkey != null) {
    await hotKeyManager.unregister(s_hotkey);
  }
  if (hotkey != null) {
    switch (name) {
      case "play_pause":
        await hotKeyManager.register(
          hotkey,
          keyDownHandler: (hotKey) async {
            // 处理播放/暂停的逻辑
            if (enable_hotkey) globalPlayOrPause();
          },
        );
        break;
      case "next":
        await hotKeyManager.register(
          hotkey,
          keyDownHandler: (hotKey) async {
            // 处理下一首的逻辑
            if (enable_hotkey) globalSkipToNext();
          },
        );
        break;
      case "previous":
        await hotKeyManager.register(
          hotkey,
          keyDownHandler: (hotKey) async {
            // 处理上一首的逻辑
            if (enable_hotkey) globalSkipToPrevious();
          },
        );
        break;
      case "show":
        await hotKeyManager.register(
          hotkey,
          keyDownHandler: (hotKey) async {
            // 处理显示的逻辑
            if (enable_hotkey) {
              windowManager.show();
              windowManager.setSkipTaskbar(false);
              windowManager.setAlwaysOnTop(true);
              windowManager.setAlwaysOnTop(false);
            }
          },
        );
        break;
    }
  }
}

var enable_hotkey_setstate;
var enable_hotkey;
List<Widget> create_hotkey_btns(context) {
  if (!(isWindows || isMacOS)) return [];
  var s_hotkeys = [
    {"name": "播放/暂停", "hotkey": "play_pause"},
    {"name": "下一首", "hotkey": "next"},
    {"name": "上一首", "hotkey": "previous"},
    {"name": "显示", "hotkey": "show"},
  ];
  return <Widget>[
    StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        enable_hotkey_setstate = setState;
        return SwitchListTile(
          title: const Text('启用热键'),
          value: enable_hotkey,
          onChanged: (bool value) async {
            enable_hotkey = value;
            var settings = settings_getsettings();
            var hotkeys = settings['hotkeys'];
            hotkeys['enable'] = value;
            settings['hotkeys'] = hotkeys;
            Get.find<SettingsController>().setSettings(settings);
            try {
              setState(() {
                enable_hotkey = value;
              });
            } catch (e) {}
          },
        );
      },
    ),
    ...s_hotkeys.map((_hotkey) {
      return TextButton(
        onPressed: () async {
          var settings = settings_getsettings();
          var hotkeys = settings['hotkeys'];
          var hotkeyData = hotkeys[_hotkey['hotkey']];
          var hotkey = hotkeyData == null ? null : HotKey.fromJson(hotkeyData);
          var s_hotkey = hotkey;
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('设置${_hotkey['name']}热键'),
                content: HotKeyRecorder(
                  initalHotKey: hotkey,
                  onHotKeyRecorded: (hotKey) {
                    print(hotKey.toJson());
                    hotkey = hotKey;
                  },
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('确定'),
                    onPressed: () async {
                      if (hotkey == null) {
                        // _msg('请设置热键', 1.0);
                        showWarningSnackbar('请设置热键', null);
                        return;
                      }
                      hotkeys[_hotkey['hotkey']] = hotkey!.toJson();
                      settings['hotkeys'] = hotkeys;
                      Get.find<SettingsController>().setSettings(settings);
                      await set_hotkey(s_hotkey, hotkey, _hotkey['hotkey']);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        },
        child: Text("设置 " + (_hotkey['name'] as String) + " 热键"),
      );
    }).toList(),
  ];
}

Widget get globalLoadingAnime => LoadingBouncingGrid.square(
  backgroundColor: AdaptiveTheme.of(Get.context!).theme.colorScheme.primary,
);
Widget search_Animation({
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
  Axis axis = Axis.vertical,
}) {
  const curve = Curves.easeInOut;

  var curvedAnimation = CurvedAnimation(parent: animation, curve: curve);

  var alignmentTween = Tween<Alignment>(
    // begin: Alignment.topCenter, // 从顶部开始
    begin: axis == Axis.vertical ? Alignment.topCenter : Alignment.topRight,
    end: Alignment.center, // 到达中心
  ).animate(curvedAnimation);

  // return AlignTransition(
  //   alignment: alignmentTween, // 使用动态的 Alignment 动画
  //   child: SizeTransition(
  //     sizeFactor: curvedAnimation, // 控制高度从 0 到 1 的变化
  //     axis: axis, // 垂直方向展开
  //     child: FadeTransition(
  //       opacity: curvedAnimation, // 添加淡入淡出效果
  //       child: child,
  //     ),
  //   ),
  // );
  return SharedAxisTransition(
    animation: animation,
    secondaryAnimation: secondaryAnimation,
    transitionType: SharedAxisTransitionType.vertical,
    child: child,
  );
}
