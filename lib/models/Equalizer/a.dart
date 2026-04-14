// transform, a
// Set transform type of IIR filter.
// 设置 IIR 滤波器的变换类型。

// di
// dii
// tdi
// tdii
// latt
// svf
// zdf
enum Transform {
  di('di'),
  dii('dii'),
  tdi('tdi'),
  tdii('tdii'),
  latt('latt'),
  svf('svf'),
  zdf('zdf');

  final String value;

  const Transform(this.value);

  static Transform? fromValue(String v) {
    for (final item in Transform.values) {
      if (item.value == v) return item;
    }
    return null;
  }
}
