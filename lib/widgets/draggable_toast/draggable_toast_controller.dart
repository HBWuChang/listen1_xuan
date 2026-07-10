import 'package:flutter/foundation.dart';

/// 可拖动 Toast 的控制器
/// 提供给 builder 使用，用于控制 Toast 的展开、收起、隐藏、关闭等行为
class DraggableToastController {
  final String _toastId;
  final VoidCallback _onRemove;

  /// 内部回调 — 由 widget state 设置
  VoidCallback? _expandCallback;
  VoidCallback? _peekCallback;
  VoidCallback? _hideCallback;

  /// 标记当前是否处于"锁定"状态
  bool _isLockedMode = false;

  DraggableToastController({
    required String toastId,
    required VoidCallback onRemove,
  })  : _toastId = toastId,
        _onRemove = onRemove;

  String get id => _toastId;

  bool get isLockedMode => _isLockedMode;

  void enterLockedMode() {
    _isLockedMode = true;
  }

  void exitLockedMode() {
    _isLockedMode = false;
  }

  void expand() {
    _expandCallback?.call();
  }

  void peek() {
    _peekCallback?.call();
  }

  void hide() {
    _hideCallback?.call();
  }

  void dismiss() {
    _onRemove();
  }

  void bindCallbacks({
    required VoidCallback onExpand,
    required VoidCallback onPeek,
    required VoidCallback onHide,
  }) {
    _expandCallback = onExpand;
    _peekCallback = onPeek;
    _hideCallback = onHide;
  }
}
