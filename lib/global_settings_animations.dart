import 'package:flutter/material.dart';
import 'package:loading_animations/loading_animations.dart';
import 'package:animations/animations.dart';
import 'package:universal_io/io.dart' as universal_io;
import 'package:bot_toast/bot_toast.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

Future<Directory> xuan_getdataDirectory() async {
  var tempDir = is_windows
      ? await getDownloadsDirectory()
      : await getApplicationDocumentsDirectory();
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

Future<dynamic> xuan_getdownloadDirectory(
  String? path,
) async {
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
