import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Stub implementation for non-desktop platforms.
/// 不引入 super_drag_and_drop，不产生任何原生代码依赖。
Widget wrapWithDrag({
  required Uint8List imageData,
  required String fileName,
  required Widget child,
  String? filePath,
}) {
  return child;
}
