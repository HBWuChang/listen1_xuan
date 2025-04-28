import 'package:flutter/material.dart';
import 'package:loading_animations/loading_animations.dart';
import 'package:animations/animations.dart';


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
