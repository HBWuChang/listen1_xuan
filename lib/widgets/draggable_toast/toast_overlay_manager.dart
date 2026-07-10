import 'package:flutter/material.dart';
import 'draggable_toast.dart';

/// Toast Overlay 管理器
/// 用于在 Overlay 中显示和管理可拖动 Toast
class ToastOverlayManager {
  ToastOverlayManager._();
  static final ToastOverlayManager instance = ToastOverlayManager._();

  BuildContext? _context;

  final Map<String, _ToastEntry> _entries = {};
  int _idCounter = 0;

  /// 初始化，保存 context
  ToastOverlayManager init(BuildContext context) {
    _context = context;
    return this;
  }

  /// 显示一个可拖动 Toast
  ///
  /// 返回 DraggableToastController，可用于外部控制
  DraggableToastController show({
    BuildContext? context,
    required Widget Function(
      BuildContext context,
      ToastState state,
      DraggableToastController controller,
    ) builder,
    Widget icon = const Icon(Icons.notifications_rounded, color: Colors.white),
    DraggableToastConfig config = const DraggableToastConfig(),
    Offset? initialPosition,
    Color? backgroundColor,
    Color? collapsedBackgroundColor,
    bool autoDismiss = false,
    bool inLockMode = false,
    Duration autoDismissDuration = const Duration(seconds: 5),
    Duration initialDisplayDuration = const Duration(seconds: 3),
    VoidCallback? onDismiss,
  }) {
    final ctx = context ?? _context;
    if (ctx == null) {
      throw Exception(
        'ToastOverlayManager: context is null. '
        'Call init(context) first or pass context to show().',
      );
    }

    final id = 'toast_${_idCounter++}';

    final controller = DraggableToastController(
      toastId: id,
      onRemove: () => dismiss(id),
    );

    if (inLockMode) {
      controller.enterLockedMode();
    }

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => Positioned.fill(
        child: DraggableMotorToast(
          controller: controller,
          autoDismiss: autoDismiss,
          autoDismissDuration: autoDismissDuration,
          initialDisplayDuration: initialDisplayDuration,
          initialLockedMode: inLockMode,
          icon: icon,
          config: config,
          initialPosition: initialPosition,
          backgroundColor: backgroundColor,
          collapsedBackgroundColor: collapsedBackgroundColor,
          onDismiss: () {
            onDismiss?.call();
            dismiss(id);
          },
          builder: (context, state) => builder(context, state, controller),
        ),
      ),
    );

    _entries[id] = _ToastEntry(entry: entry, controller: controller);
    Overlay.of(ctx).insert(entry);

    return controller;
  }

  /// 移除指定 toast
  void dismiss(String id) {
    final toastEntry = _entries.remove(id);
    if (toastEntry != null) {
      toastEntry.entry.remove();
      toastEntry.entry.dispose();
    }
  }

  /// 移除所有 toast
  void dismissAll() {
    for (final toastEntry in _entries.values) {
      toastEntry.entry.remove();
      toastEntry.entry.dispose();
    }
    _entries.clear();
  }

  /// 获取当前显示的 toast 数量
  int get count => _entries.length;
}

class _ToastEntry {
  final OverlayEntry entry;
  final DraggableToastController controller;

  _ToastEntry({required this.entry, required this.controller});
}
