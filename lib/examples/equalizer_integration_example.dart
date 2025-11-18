// 在你的设置页面中添加均衡器入口的示例代码

// 1. 首先导入页面
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:listen1_xuan/pages/android_equalizer_page.dart';
import 'package:listen1_xuan/global_settings_animations.dart';

// OpenContainer 转场动画类型说明：
// - ContainerTransitionType.fade: 淡入淡出效果
// - ContainerTransitionType.fadeThrough: 先淡出再淡入（Material Design 推荐）

// 2. 在设置列表中添加 ListTile（例如在"播放设置"部分）
Widget buildEqualizerTile(BuildContext context) {
  if (!isAndroid) {
    // 非 Android 平台不显示均衡器入口
    return SizedBox.shrink();
  }
  // 使用 OpenContainer 实现页面转场动画
  return OpenContainer(
    // 转场类型：淡入淡出
    transitionType: ContainerTransitionType.fadeThrough,
    // 转场时长
    transitionDuration: const Duration(milliseconds: 500),
    // 打开后的页面
    openBuilder: (context, action) => const AndroidEqualizerPage(),
    // 关闭状态的样式
    closedElevation: 0, // 无阴影
    closedColor: Theme.of(context).colorScheme.surface,
    // 打开状态的背景色
    openColor: Theme.of(context).colorScheme.surface,
    // 转场过程中的颜色
    middleColor: Theme.of(context).colorScheme.surface,
    // 关闭状态的构建器（ListTile）
    closedBuilder: (context, action) {
      return ListTile(
        leading: Icon(Icons.graphic_eq, ),
        title: const Text('音效调节'),
        trailing: const Icon(Icons.unfold_more_rounded),
        onTap: action, // 点击时触发转场动画
      );
    },
  );
}
