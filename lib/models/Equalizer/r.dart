// precision, r
// Set precision of filtering.
// 设置过滤的精度。

// auto
// Pick automatic sample format depending on surround filters.
// 根据周围过滤器选择自动样本格式。

// s16
// Always use signed 16-bit.
// 始终使用有符号的 16 位。

// s32
// Always use signed 32-bit.
// 总是使用有符号的 32 位。

// f32
// Always use float 32-bit.   始终使用 32 位浮点数。

// f64
// Always use float 64-bit.   总是使用 64 位浮点数。
enum Precision {
  auto('auto', '自动'),
  s16('s16', '有符号的 16 位'),
  s32('s32', '有符号的 32 位'),
  f32('f32', '32 位浮点数'),
  f64('f64', '64 位浮点数');

  final String value;
  final String description;

  const Precision(this.value, this.description);

  static Precision? fromValue(String v) {
    for (final item in Precision.values) {
      if (item.value == v) return item;
    }
    return null;
  }
}