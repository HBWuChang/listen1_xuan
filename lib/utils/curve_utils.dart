import 'package:flutter/animation.dart';
import '../models/CurveOption.dart';

/// 曲线工具类
/// 提供根据字符串名称获取曲线对象的方法
class CurveUtils {
  /// 根据曲线名称获取对应的 Curve 对象
  /// 
  /// [curveName] 曲线的英文名称（如 'easeInSine'）
  /// 
  /// 如果找不到对应的曲线，返回默认的 Curves.linear
  static Curve getCurveByName(String curveName) {
    final option = CurveOption.findByName(curveName);
    return option?.curve ?? Curves.linear;
  }

  /// 根据曲线显示名称获取对应的 Curve 对象
  /// 
  /// [displayName] 曲线的中文显示名称（如 '正弦缓入'）
  /// 
  /// 如果找不到对应的曲线，返回默认的 Curves.linear
  static Curve getCurveByDisplayName(String displayName) {
    final option = CurveOption.findByDisplayName(displayName);
    return option?.curve ?? Curves.linear;
  }

  /// 获取曲线的显示名称
  /// 
  /// [curveName] 曲线的英文名称
  /// 
  /// 如果找不到对应的曲线，返回原名称
  static String getDisplayName(String curveName) {
    final option = CurveOption.findByName(curveName);
    return option?.displayName ?? curveName;
  }

  /// 获取曲线的描述
  /// 
  /// [curveName] 曲线的英文名称
  /// 
  /// 如果找不到对应的曲线，返回空字符串
  static String getDescription(String curveName) {
    final option = CurveOption.findByName(curveName);
    return option?.description ?? '';
  }

  /// 验证曲线名称是否有效
  /// 
  /// [curveName] 曲线的英文名称
  /// 
  /// 返回 true 表示该名称对应一个有效的曲线
  static bool isValidCurveName(String curveName) {
    return CurveOption.findByName(curveName) != null;
  }

  /// 获取所有可用的曲线名称列表
  static List<String> getAllCurveNames() {
    return CurveOption.allCurves.map((option) => option.name).toList();
  }

  /// 获取所有可用的曲线显示名称列表
  static List<String> getAllDisplayNames() {
    return CurveOption.allCurves.map((option) => option.displayName).toList();
  }
}
