import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

/// 桌面端实现：使用 super_drag_and_drop 包裹 widget，
/// 允许用户将图片拖拽到桌面或其他应用。
///
/// 当 [filePath] 不为 null 时，使用真实文件路径（fileUri）拖拽；
/// 否则使用 virtual file 方式从内存导出数据。
Widget wrapWithDrag({
  required Uint8List imageData,
  required String fileName,
  required Widget child,
  String? filePath,
}) {
  return DragItemWidget(
    dragItemProvider: (request) {
      final item = DragItem(
        localData: {'fileName': fileName},
        suggestedName: fileName,
      );

      if (filePath != null) {
        // 使用真实文件 URI，直接指向缓存目录中的文件
        item.add(Formats.fileUri(Uri.file(filePath)));
      } else {
        // 使用 virtual file 方式从内存导出 PNG 数据
        item.addVirtualFile(
          format: Formats.png,
          provider: (sinkProvider, progress) {
            final sink = sinkProvider(fileSize: imageData.length);
            sink.add(imageData);
            sink.close();
          },
          storageSuggestion: VirtualFileStorage.memory,
        );
      }

      return item;
    },
    allowedOperations: () => [DropOperation.copy],
    child: DraggableWidget(
      child: child,
    ),
  );
}
