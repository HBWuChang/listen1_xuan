// width_type, t
// Set method to specify band-width of filter.
// 设置方法以指定滤波器的带宽。

// h
// Hz   赫兹

// q
// Q-Factor   Q 因子

// o
// octave   奥卡托

// s
// slope   斜率

// k
// kHz
enum WidthType {
  h('h', 'Hz / 赫兹'),
  q('q', 'Q-Factor / Q 因子'),
  o('o', 'octave / 八度'),
  s('s', 'slope / 斜率'),
  k('k', 'kHz');

  final String value; // 选项本身（你说的“t”值）
  final String description; // 说明

  const WidthType(this.value, this.description);

  static WidthType? fromValue(String v) {
    for (final item in WidthType.values) {
      if (item.value == v) return item;
    }
    return null;
  }
}
