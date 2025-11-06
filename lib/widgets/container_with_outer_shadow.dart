import 'package:flutter/material.dart';

/// 反向裁剪器 - 只保留外部区域，裁剪掉内部区域
class InvertedRectClipper extends CustomClipper<Path> {
  final BorderRadiusGeometry borderRadius;

  InvertedRectClipper({required this.borderRadius});

  @override
  Path getClip(Size size) {
    // 添加整个画布区域（外部大矩形）
    final outerPath = Path();
    outerPath.addRect(Rect.largest);

    // 减去内部容器区域（带圆角）
    final innerPath = Path();
    final rRect = borderRadius
        .resolve(TextDirection.ltr)
        .toRRect(Rect.fromLTWH(0, 0, size.width, size.height));
    innerPath.addRRect(rRect);

    // 使用差集运算：外部矩形 - 内部圆角矩形 = 只保留外部区域
    return Path.combine(PathOperation.difference, outerPath, innerPath);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    return oldClipper != this;
  }
}
