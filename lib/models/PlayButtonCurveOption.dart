import 'package:flutter/animation.dart';

/// 播放按钮旋转曲线选项
class PlayButtonCurveOption {
  final String name;
  final String description;
  final Curve curve;
  final String category;

  const PlayButtonCurveOption({
    required this.name,
    required this.description,
    required this.curve,
    required this.category,
  });

  /// 所有可用的曲线选项
  static const List<PlayButtonCurveOption> allCurves = [
    // ==================== 线性 ====================
    PlayButtonCurveOption(
      name: '线性',
      description: '匀速旋转，无加速减速',
      curve: Curves.linear,
      category: '线性',
    ),

    // ==================== 标准缓动 ====================
    PlayButtonCurveOption(
      name: '缓入缓出',
      description: '开始和结束都缓慢，中间快速',
      curve: Curves.easeInOut,
      category: '标准',
    ),
    PlayButtonCurveOption(
      name: '缓入',
      description: '开始缓慢，逐渐加速',
      curve: Curves.easeIn,
      category: '标准',
    ),
    PlayButtonCurveOption(
      name: '缓出',
      description: '开始快速，逐渐减速',
      curve: Curves.easeOut,
      category: '标准',
    ),

    // ==================== 正弦曲线 ====================
    PlayButtonCurveOption(
      name: '正弦缓入缓出',
      description: '平滑的正弦波动效果',
      curve: Curves.easeInOutSine,
      category: '正弦',
    ),
    PlayButtonCurveOption(
      name: '正弦缓入',
      description: '正弦波加速效果',
      curve: Curves.easeInSine,
      category: '正弦',
    ),
    PlayButtonCurveOption(
      name: '正弦缓出',
      description: '正弦波减速效果',
      curve: Curves.easeOutSine,
      category: '正弦',
    ),

    // ==================== 二次曲线 ====================
    PlayButtonCurveOption(
      name: '二次缓入缓出',
      description: '适度的加速和减速',
      curve: Curves.easeInOutQuad,
      category: '二次',
    ),
    PlayButtonCurveOption(
      name: '二次缓入',
      description: '平缓的加速',
      curve: Curves.easeInQuad,
      category: '二次',
    ),
    PlayButtonCurveOption(
      name: '二次缓出',
      description: '平缓的减速',
      curve: Curves.easeOutQuad,
      category: '二次',
    ),

    // ==================== 三次曲线 ====================
    PlayButtonCurveOption(
      name: '三次缓入缓出',
      description: '明显的加速和减速',
      curve: Curves.easeInOutCubic,
      category: '三次',
    ),
    PlayButtonCurveOption(
      name: '三次缓入',
      description: '较强的加速',
      curve: Curves.easeInCubic,
      category: '三次',
    ),
    PlayButtonCurveOption(
      name: '三次缓出',
      description: '较强的减速',
      curve: Curves.easeOutCubic,
      category: '三次',
    ),

    // ==================== 四次曲线 ====================
    PlayButtonCurveOption(
      name: '四次缓入缓出',
      description: '非常明显的加速和减速',
      curve: Curves.easeInOutQuart,
      category: '四次',
    ),
    PlayButtonCurveOption(
      name: '四次缓入',
      description: '强烈的加速',
      curve: Curves.easeInQuart,
      category: '四次',
    ),
    PlayButtonCurveOption(
      name: '四次缓出',
      description: '强烈的减速',
      curve: Curves.easeOutQuart,
      category: '四次',
    ),

    // ==================== 五次曲线 ====================
    PlayButtonCurveOption(
      name: '五次缓入缓出',
      description: '极其明显的加速和减速',
      curve: Curves.easeInOutQuint,
      category: '五次',
    ),
    PlayButtonCurveOption(
      name: '五次缓入',
      description: '极强的加速',
      curve: Curves.easeInQuint,
      category: '五次',
    ),
    PlayButtonCurveOption(
      name: '五次缓出',
      description: '极强的减速',
      curve: Curves.easeOutQuint,
      category: '五次',
    ),

    // ==================== 指数曲线 ====================
    PlayButtonCurveOption(
      name: '指数缓入缓出',
      description: '戏剧性的加速和减速',
      curve: Curves.easeInOutExpo,
      category: '指数',
    ),
    PlayButtonCurveOption(
      name: '指数缓入',
      description: '爆炸式加速',
      curve: Curves.easeInExpo,
      category: '指数',
    ),
    PlayButtonCurveOption(
      name: '指数缓出',
      description: '急刹车减速',
      curve: Curves.easeOutExpo,
      category: '指数',
    ),

    // ==================== 圆形曲线 ====================
    PlayButtonCurveOption(
      name: '圆形缓入缓出',
      description: '圆弧形的加速和减速',
      curve: Curves.easeInOutCirc,
      category: '圆形',
    ),
    PlayButtonCurveOption(
      name: '圆形缓入',
      description: '圆弧形加速',
      curve: Curves.easeInCirc,
      category: '圆形',
    ),
    PlayButtonCurveOption(
      name: '圆形缓出',
      description: '圆弧形减速',
      curve: Curves.easeOutCirc,
      category: '圆形',
    ),

    // ==================== 回弹曲线 ====================
    PlayButtonCurveOption(
      name: '回弹缓入缓出',
      description: '前后都有回弹效果',
      curve: Curves.easeInOutBack,
      category: '回弹',
    ),
    PlayButtonCurveOption(
      name: '回弹缓入',
      description: '先回退再前进',
      curve: Curves.easeInBack,
      category: '回弹',
    ),
    PlayButtonCurveOption(
      name: '回弹缓出',
      description: '超过目标后回弹',
      curve: Curves.easeOutBack,
      category: '回弹',
    ),

    // ==================== 弹性曲线 ====================
    PlayButtonCurveOption(
      name: '弹性缓入缓出',
      description: '橡皮筋般的弹性效果',
      curve: Curves.elasticInOut,
      category: '弹性',
    ),
    PlayButtonCurveOption(
      name: '弹性缓入',
      description: '开始有弹性振荡',
      curve: Curves.elasticIn,
      category: '弹性',
    ),
    PlayButtonCurveOption(
      name: '弹性缓出',
      description: '结束有弹性振荡',
      curve: Curves.elasticOut,
      category: '弹性',
    ),

    // ==================== 弹跳曲线 ====================
    PlayButtonCurveOption(
      name: '弹跳缓入缓出',
      description: '球体弹跳效果',
      curve: Curves.bounceInOut,
      category: '弹跳',
    ),
    PlayButtonCurveOption(
      name: '弹跳缓入',
      description: '开始弹跳',
      curve: Curves.bounceIn,
      category: '弹跳',
    ),
    PlayButtonCurveOption(
      name: '弹跳缓出',
      description: '结束弹跳',
      curve: Curves.bounceOut,
      category: '弹跳',
    ),

    // ==================== 快速曲线 ====================
    PlayButtonCurveOption(
      name: '快速离开慢速进入',
      description: '快速启动，缓慢结束',
      curve: Curves.fastOutSlowIn,
      category: '快速',
    ),
    PlayButtonCurveOption(
      name: '线性离开慢速进入',
      description: 'Material Design 标准',
      curve: Curves.linearToEaseOut,
      category: '快速',
    ),
    PlayButtonCurveOption(
      name: '快速线性离开慢速进入',
      description: '快速线性启动，缓慢结束',
      curve: Curves.fastLinearToSlowEaseIn,
      category: '快速',
    ),

    // ==================== 减速曲线 ====================
    PlayButtonCurveOption(
      name: '减速',
      description: 'Android 标准减速',
      curve: Curves.decelerate,
      category: '减速',
    ),
    PlayButtonCurveOption(
      name: '快速减速',
      description: '快速启动后减速',
      curve: Curves.fastEaseInToSlowEaseOut,
      category: '减速',
    ),
  ];

  /// 根据分类获取曲线
  static Map<String, List<PlayButtonCurveOption>> getCurvesByCategory() {
    final Map<String, List<PlayButtonCurveOption>> result = {};
    for (var option in allCurves) {
      result.putIfAbsent(option.category, () => []).add(option);
    }
    return result;
  }

  /// 根据名称查找曲线
  static PlayButtonCurveOption? findByName(String name) {
    try {
      return allCurves.firstWhere((option) => option.name == name);
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() => name;
}
