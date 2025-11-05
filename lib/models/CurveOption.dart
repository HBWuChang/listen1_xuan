import 'package:flutter/animation.dart';

/// 曲线选项模型
/// 封装曲线的名称、描述和实际的曲线对象
class CurveOption {
  /// 曲线的唯一标识符（英文名称）
  final String name;
  
  /// 曲线的中文显示名称
  final String displayName;
  
  /// 曲线的描述
  final String description;
  
  /// 实际的曲线对象
  final Curve curve;
  
  /// 曲线所属的分类
  final String category;

  const CurveOption({
    required this.name,
    required this.displayName,
    required this.description,
    required this.curve,
    required this.category,
  });

  /// 所有可用的曲线选项
  static const List<CurveOption> allCurves = [
    // ==================== 线性 ====================
    CurveOption(
      name: 'linear',
      displayName: '线性',
      description: '匀速运动，无加速或减速',
      curve: Curves.linear,
      category: '线性',
    ),

    // ==================== 标准缓动 ====================
    CurveOption(
      name: 'easeIn',
      displayName: '缓入',
      description: '开始慢，逐渐加速',
      curve: Curves.easeIn,
      category: '标准',
    ),
    CurveOption(
      name: 'easeOut',
      displayName: '缓出',
      description: '开始快，逐渐减速',
      curve: Curves.easeOut,
      category: '标准',
    ),
    CurveOption(
      name: 'easeInOut',
      displayName: '缓入缓出',
      description: '两端慢，中间快',
      curve: Curves.easeInOut,
      category: '标准',
    ),
    CurveOption(
      name: 'ease',
      displayName: '标准缓动',
      description: 'CSS标准缓动曲线',
      curve: Curves.ease,
      category: '标准',
    ),

    // ==================== 正弦曲线 ====================
    CurveOption(
      name: 'easeInSine',
      displayName: '正弦缓入',
      description: '正弦波加速效果',
      curve: Curves.easeInSine,
      category: '正弦',
    ),
    CurveOption(
      name: 'easeOutSine',
      displayName: '正弦缓出',
      description: '正弦波减速效果',
      curve: Curves.easeOutSine,
      category: '正弦',
    ),
    CurveOption(
      name: 'easeInOutSine',
      displayName: '正弦缓入缓出',
      description: '正弦波加减速效果',
      curve: Curves.easeInOutSine,
      category: '正弦',
    ),

    // ==================== 二次曲线 ====================
    CurveOption(
      name: 'easeInQuad',
      displayName: '二次缓入',
      description: '二次方加速',
      curve: Curves.easeInQuad,
      category: '二次',
    ),
    CurveOption(
      name: 'easeOutQuad',
      displayName: '二次缓出',
      description: '二次方减速',
      curve: Curves.easeOutQuad,
      category: '二次',
    ),
    CurveOption(
      name: 'easeInOutQuad',
      displayName: '二次缓入缓出',
      description: '二次方加减速',
      curve: Curves.easeInOutQuad,
      category: '二次',
    ),

    // ==================== 三次曲线 ====================
    CurveOption(
      name: 'easeInCubic',
      displayName: '三次缓入',
      description: '三次方加速',
      curve: Curves.easeInCubic,
      category: '三次',
    ),
    CurveOption(
      name: 'easeOutCubic',
      displayName: '三次缓出',
      description: '三次方减速',
      curve: Curves.easeOutCubic,
      category: '三次',
    ),
    CurveOption(
      name: 'easeInOutCubic',
      displayName: '三次缓入缓出',
      description: '三次方加减速',
      curve: Curves.easeInOutCubic,
      category: '三次',
    ),

    // ==================== 四次曲线 ====================
    CurveOption(
      name: 'easeInQuart',
      displayName: '四次缓入',
      description: '四次方加速',
      curve: Curves.easeInQuart,
      category: '四次',
    ),
    CurveOption(
      name: 'easeOutQuart',
      displayName: '四次缓出',
      description: '四次方减速',
      curve: Curves.easeOutQuart,
      category: '四次',
    ),
    CurveOption(
      name: 'easeInOutQuart',
      displayName: '四次缓入缓出',
      description: '四次方加减速',
      curve: Curves.easeInOutQuart,
      category: '四次',
    ),

    // ==================== 五次曲线 ====================
    CurveOption(
      name: 'easeInQuint',
      displayName: '五次缓入',
      description: '五次方加速',
      curve: Curves.easeInQuint,
      category: '五次',
    ),
    CurveOption(
      name: 'easeOutQuint',
      displayName: '五次缓出',
      description: '五次方减速',
      curve: Curves.easeOutQuint,
      category: '五次',
    ),
    CurveOption(
      name: 'easeInOutQuint',
      displayName: '五次缓入缓出',
      description: '五次方加减速',
      curve: Curves.easeInOutQuint,
      category: '五次',
    ),

    // ==================== 指数曲线 ====================
    CurveOption(
      name: 'easeInExpo',
      displayName: '指数缓入',
      description: '指数加速',
      curve: Curves.easeInExpo,
      category: '指数',
    ),
    CurveOption(
      name: 'easeOutExpo',
      displayName: '指数缓出',
      description: '指数减速',
      curve: Curves.easeOutExpo,
      category: '指数',
    ),
    CurveOption(
      name: 'easeInOutExpo',
      displayName: '指数缓入缓出',
      description: '指数加减速',
      curve: Curves.easeInOutExpo,
      category: '指数',
    ),

    // ==================== 圆形曲线 ====================
    CurveOption(
      name: 'easeInCirc',
      displayName: '圆形缓入',
      description: '圆形加速',
      curve: Curves.easeInCirc,
      category: '圆形',
    ),
    CurveOption(
      name: 'easeOutCirc',
      displayName: '圆形缓出',
      description: '圆形减速',
      curve: Curves.easeOutCirc,
      category: '圆形',
    ),
    CurveOption(
      name: 'easeInOutCirc',
      displayName: '圆形缓入缓出',
      description: '圆形加减速',
      curve: Curves.easeInOutCirc,
      category: '圆形',
    ),

    // ==================== 回弹曲线 ====================
    CurveOption(
      name: 'easeInBack',
      displayName: '回弹缓入',
      description: '先后退再加速',
      curve: Curves.easeInBack,
      category: '回弹',
    ),
    CurveOption(
      name: 'easeOutBack',
      displayName: '回弹缓出',
      description: '减速后超出再回弹',
      curve: Curves.easeOutBack,
      category: '回弹',
    ),
    CurveOption(
      name: 'easeInOutBack',
      displayName: '回弹缓入缓出',
      description: '两端都有回弹效果',
      curve: Curves.easeInOutBack,
      category: '回弹',
    ),

    // ==================== 弹性曲线 ====================
    CurveOption(
      name: 'elasticIn',
      displayName: '弹性缓入',
      description: '开始有弹性振荡',
      curve: Curves.elasticIn,
      category: '弹性',
    ),
    CurveOption(
      name: 'elasticOut',
      displayName: '弹性缓出',
      description: '结束有弹性振荡',
      curve: Curves.elasticOut,
      category: '弹性',
    ),
    CurveOption(
      name: 'elasticInOut',
      displayName: '弹性缓入缓出',
      description: '两端都有弹性振荡',
      curve: Curves.elasticInOut,
      category: '弹性',
    ),

    // ==================== 弹跳曲线 ====================
    CurveOption(
      name: 'bounceIn',
      displayName: '弹跳缓入',
      description: '开始弹跳效果',
      curve: Curves.bounceIn,
      category: '弹跳',
    ),
    CurveOption(
      name: 'bounceOut',
      displayName: '弹跳缓出',
      description: '结束弹跳效果',
      curve: Curves.bounceOut,
      category: '弹跳',
    ),
    CurveOption(
      name: 'bounceInOut',
      displayName: '弹跳缓入缓出',
      description: '两端都有弹跳效果',
      curve: Curves.bounceInOut,
      category: '弹跳',
    ),

    // ==================== 快速曲线 ====================
    CurveOption(
      name: 'fastOutSlowIn',
      displayName: '快出慢入',
      description: 'Material Design推荐',
      curve: Curves.fastOutSlowIn,
      category: '快速',
    ),
    CurveOption(
      name: 'slowMiddle',
      displayName: '中间慢',
      description: '中间减速',
      curve: Curves.slowMiddle,
      category: '快速',
    ),
    CurveOption(
      name: 'linearToEaseOut',
      displayName: '线性到缓出',
      description: '从线性过渡到缓出',
      curve: Curves.linearToEaseOut,
      category: '快速',
    ),
    CurveOption(
      name: 'easeInToLinear',
      displayName: '缓入到线性',
      description: '从缓入过渡到线性',
      curve: Curves.easeInToLinear,
      category: '快速',
    ),

    // ==================== 减速曲线 ====================
    CurveOption(
      name: 'decelerate',
      displayName: '减速',
      description: '持续减速',
      curve: Curves.decelerate,
      category: '减速',
    ),
    CurveOption(
      name: 'fastLinearToSlowEaseIn',
      displayName: '快速线性到慢缓入',
      description: '快速线性后缓慢缓入',
      curve: Curves.fastLinearToSlowEaseIn,
      category: '减速',
    ),
  ];

  /// 获取所有曲线分类
  static List<String> getAllCategories() {
    return allCurves.map((e) => e.category).toSet().toList();
  }

  /// 根据分类获取曲线列表
  static List<CurveOption> getCurvesByCategory(String category) {
    return allCurves.where((curve) => curve.category == category).toList();
  }

  /// 根据名称查找曲线选项
  static CurveOption? findByName(String name) {
    try {
      return allCurves.firstWhere((curve) => curve.name == name);
    } catch (e) {
      return null;
    }
  }

  /// 根据显示名称查找曲线选项
  static CurveOption? findByDisplayName(String displayName) {
    try {
      return allCurves.firstWhere((curve) => curve.displayName == displayName);
    } catch (e) {
      return null;
    }
  }
}
