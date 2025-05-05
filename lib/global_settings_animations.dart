import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:listen1_xuan/play.dart';
import 'package:loading_animations/loading_animations.dart';
import 'package:animations/animations.dart';
import 'package:universal_io/io.dart' as universal_io;
import 'package:bot_toast/bot_toast.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'settings.dart';
import 'package:window_manager/window_manager.dart';

var My_playlist_loaddata;
Future<String> get_windows_proxy_addr() async {
  var settings = await settings_getsettings();
  var proxy = settings["proxy"];
  if (proxy == null) {
    settings["proxy"] = "";
    await settings_setsettings(settings);
    return "";
  }
  return proxy;
}

Future<Directory> xuan_getdataDirectory() async {
  if (!is_windows) return await getApplicationDocumentsDirectory();
  var tempDir = await getDownloadsDirectory();
  if (tempDir == null)
    tempDir = await getApplicationDocumentsDirectory();
  else {
    // 检查是否存在 Listen1 文件夹
    var listen1Dir = Directory('${tempDir.path}/Listen1');
    if (is_windows) {
      listen1Dir = Directory('${tempDir.path}\\Listen1');
    }
    if (!await listen1Dir.exists()) {
      // 如果不存在，则创建
      await listen1Dir.create(recursive: true);
    }
    // 更新 tempDir 为 Listen1 文件夹
    tempDir = listen1Dir;
  }
  return tempDir;
}

Future<dynamic> xuan_getdownloadDirectory({
  String? path,
}) async {
  var tempDir = is_windows
      ? await getDownloadsDirectory()
      : Directory('/storage/emulated/0/Download');
  if (tempDir == null)
    tempDir = await getApplicationDocumentsDirectory();
  else {
    // 检查是否存在 Listen1 文件夹
    var listen1Dir = Directory('${tempDir.path}/Listen1');
    if (is_windows) {
      listen1Dir = Directory('${tempDir.path}\\Listen1');
    }
    if (!await listen1Dir.exists()) {
      // 如果不存在，则创建
      await listen1Dir.create(recursive: true);
    }
    // 更新 tempDir 为 Listen1 文件夹
    tempDir = listen1Dir;
  }
  if (path != null) {
    // 检查是否存在指定的文件夹
    var customDir = '${tempDir.path}/$path';
    if (is_windows) {
      customDir = '${tempDir.path}\\$path';
    }
    return customDir;
  }
  return tempDir;
}

final bool is_windows = universal_io.Platform.isWindows;
dynamic xuan_toast({
  required String msg,
  Toast? toastLength,
  int timeInSecForIosWeb = 1,
  double? fontSize,
  String? fontAsset,
  ToastGravity? gravity,
  Color? backgroundColor,
  Color? textColor,
  bool webShowClose = false,
  webBgColor = "linear-gradient(to right, #00b09b, #96c93d)",
  webPosition = "right",
}) {
  if (is_windows) {
    return BotToast.showText(
      text: msg,
      clickClose: true,
    );
  }
  return Fluttertoast.showToast(
    msg: msg,
    toastLength: toastLength ?? Toast.LENGTH_SHORT,
    gravity: gravity ?? ToastGravity.BOTTOM,
    timeInSecForIosWeb: timeInSecForIosWeb,
    fontSize: fontSize,
    backgroundColor: backgroundColor,
    textColor: textColor,
    webBgColor: webBgColor,
    webPosition: webPosition,
    webShowClose: webShowClose,
  );
}

var volume_setState;
void init_hotkeys() async {
  var settings = await settings_getsettings();
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
    await settings_setsettings(settings);
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
  set_inapp_hotkey(true);
}

Map<String, HotKey> inapp_hotkeys = {
  "space": HotKey(
    key: PhysicalKeyboardKey.space,
    scope: HotKeyScope.inapp,
  ),
  "arrowLeft": HotKey(
    key: PhysicalKeyboardKey.keyA,
    scope: HotKeyScope.inapp,
  ),
  "arrowRight": HotKey(
    key: PhysicalKeyboardKey.keyD,
    scope: HotKeyScope.inapp,
  ),
  "arrowUp": HotKey(
    key: PhysicalKeyboardKey.keyW,
    scope: HotKeyScope.inapp,
  ),
  "arrowDown": HotKey(
    key: PhysicalKeyboardKey.keyS,
    scope: HotKeyScope.inapp,
  ),
  "next": HotKey(
    key: PhysicalKeyboardKey.keyE,
    scope: HotKeyScope.inapp,
  ),
  "previous": HotKey(
    key: PhysicalKeyboardKey.keyQ,
    scope: HotKeyScope.inapp,
  ),
};
Future<void> set_inapp_hotkey(bool enable) async {
  if (!is_windows) return;
  if (enable) {
    inapp_hotkeys.forEach((key, hotkey) async {
      await hotKeyManager.register(
        hotkey,
        keyDownHandler: (hotKey) async {
          // 处理播放/暂停的逻辑
          switch (key) {
            case "space":
              global_play_or_pause();
              break;
            case "previous":
              global_skipToPrevious();
              break;
            case "next":
              global_skipToNext();
              break;
            case "arrowUp":
              global_volume_up();
              break;
            case "arrowDown":
              global_volume_down();
              break;
            case "arrowLeft":
              global_seek_to_previous();
              break;
            case "arrowRight":
              global_seek_to_next();
              break;
          }
        },
      );
    });
  } else {
    // await hotKeyManager.unregister(inapp_space);
    inapp_hotkeys.forEach((key, hotkey) async {
      await hotKeyManager.unregister(hotkey);
    });
  }
}

double global_currentVolume = 0.5;

Future<void> set_hotkey(
  s_hotkey,
  hotkey,
  name,
) async {
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
            if (enable_hotkey) global_play_or_pause();
          },
        );
        break;
      case "next":
        await hotKeyManager.register(
          hotkey,
          keyDownHandler: (hotKey) async {
            // 处理下一首的逻辑
            if (enable_hotkey) global_skipToNext();
          },
        );
        break;
      case "previous":
        await hotKeyManager.register(
          hotkey,
          keyDownHandler: (hotKey) async {
            // 处理上一首的逻辑
            if (enable_hotkey) global_skipToPrevious();
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
List<Widget> create_hotkey_btns(context, _msg) {
  if (!is_windows) return [];
  var s_hotkeys = [
    {
      "name": "播放/暂停",
      "hotkey": "play_pause",
    },
    {
      "name": "下一首",
      "hotkey": "next",
    },
    {
      "name": "上一首",
      "hotkey": "previous",
    },
    {
      "name": "显示",
      "hotkey": "show",
    },
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
            var settings = await settings_getsettings();
            var hotkeys = settings['hotkeys'];
            hotkeys['enable'] = value;
            settings['hotkeys'] = hotkeys;
            await settings_setsettings(settings);
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
            var settings = await settings_getsettings();
            var hotkeys = settings['hotkeys'];
            var hotkeyData = hotkeys[_hotkey['hotkey']];
            var hotkey =
                hotkeyData == null ? null : HotKey.fromJson(hotkeyData);
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
                          _msg('请设置热键', 1.0);
                          return;
                        }
                        hotkeys[_hotkey['hotkey']] = hotkey!.toJson();
                        settings['hotkeys'] = hotkeys;
                        await settings_setsettings(settings);
                        await set_hotkey(s_hotkey, hotkey, _hotkey['hotkey']);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
            );
          },
          child: Text("设置 " + (_hotkey['name'] as String) + " 热键"));
    }).toList()
  ];
}

Widget global_loading_anime = LoadingBouncingGrid.square(
  backgroundColor: Colors.indigo,
);
Widget search_Animation({
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
  Axis axis = Axis.vertical,
}) {
  const curve = Curves.easeInOut;

  var curvedAnimation = CurvedAnimation(
    parent: animation,
    curve: curve,
  );

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
