import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/controllers.dart';
import 'package:listen1_xuan/models/websocket_message.dart';
import 'package:pasteboard/pasteboard.dart';

import '../funcs.dart';
import '../global_settings_animations.dart';

/// 全局粘贴控制器
/// 监听 Ctrl+V / Cmd+V 快捷键，处理剪贴板中的文件、图片或文本
class PasteController extends GetxController {
  /// 最近粘贴的文件路径列表
  final pastedFiles = <String>[].obs;

  /// 最近粘贴的文本
  final pastedText = Rxn<String>();

  /// 最近粘贴的图片数据
  final pastedImage = Rxn<Uint8List>();

  /// 是否正在处理粘贴
  final isProcessing = false.obs;
  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onClose() {
    super.onClose();
  }

  /// 处理键盘粘贴事件
  /// 在顶层 Focus widget 的 onKeyEvent 中调用
  /// 返回 true 表示已处理该事件
  bool handleKeyEvent(KeyEvent event) {
    if (!isDesktop) return false;

    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyV) {
      final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
      final isMetaPressed = HardwareKeyboard.instance.isMetaPressed;

      if ((isMacOS && isMetaPressed) || (!isMacOS && isCtrlPressed)) {
        _handlePaste();
        return true;
      }
    }
    return false;
  }

  /// 核心粘贴处理逻辑
  Future<void> _handlePaste() async {
    if (isProcessing.value) return;
    isProcessing.value = true;

    try {
      // 优先检查文件
      final files = await Pasteboard.files();
      if (files.isNotEmpty) {
        pastedFiles.value = files;
        pastedText.value = null;
        pastedImage.value = null;
        _onFilesPasted(files);
        return;
      }

      // 其次检查图片
      final image = await Pasteboard.image;
      if (image != null && image.isNotEmpty) {
        pastedImage.value = image;
        pastedFiles.clear();
        pastedText.value = null;
        _onImagePasted(image);
        return;
      }

      // 最后检查文本
      final text = await Pasteboard.text;
      if (text != null && text.isNotEmpty) {
        pastedText.value = text;
        pastedFiles.clear();
        pastedImage.value = null;
        _onTextPasted(text);
        return;
      }

      debugPrint('[PasteController] 剪贴板为空');
    } catch (e) {
      debugPrint('[PasteController] 粘贴处理出错: $e');
      showErrorSnackbar('粘贴失败', e.toString());
    } finally {
      isProcessing.value = false;
    }
  }

  /// 文件粘贴回调
  void _onFilesPasted(List<String> files) {
    debugPrint('[PasteController] 粘贴了 ${files.length} 个文件');
    for (final f in files) {
      debugPrint('  -> $f');
    }

    // 筛选音频文件
    final audioExtensions = [
      '.mp3',
      '.flac',
      '.wav',
      '.aac',
      '.ogg',
      '.m4a',
      '.wma',
    ];
    final audioFiles = files.where((f) {
      final ext = f.toLowerCase().split('.').last;
      return audioExtensions.contains('.$ext');
    }).toList();

    if (audioFiles.isNotEmpty) {
      showSuccessSnackbar('检测到 ${audioFiles.length} 个音频文件', '可用于导入播放列表');
      // TODO: 在这里添加导入逻辑，如调用 UpdController.processFileUpdate 等
    } else {
      showInfoSnackbar('粘贴了 ${files.length} 个文件', files.first.split('/').last);
    }
  }

  /// 图片粘贴回调
  void _onImagePasted(Uint8List imageData) {
    debugPrint('[PasteController] 粘贴了图片, 大小: ${imageData.length} bytes');
    showInfoSnackbar(
      '粘贴了图片',
      '${(imageData.length / 1024).toStringAsFixed(1)} KB',
    );
    // TODO: 在这里处理图片粘贴逻辑，如设置封面等
  }

  /// 文本粘贴回调
  void _onTextPasted(String text) {
    final wsc = Get.isRegistered<WebSocketClientController>()
        ? Get.find<WebSocketClientController>()
        : null;
    final wss = Get.isRegistered<WebSocketCardController>()
        ? Get.find<WebSocketCardController>()
        : null;
    if (wsc != null && wsc.isConnected) {
      if (wsc.sendMessage(
        WebSocketMessageBuilder.createSendPasteTextMessage(text),
      )) {
        showSuccessSnackbar('已发送剪切板到WS服务器', null);
        return;
      }
    }
    if (wss != null && wss.clientCount == 1) {
      wss.wsServerController?.broadcastMessage(
        WebSocketMessageBuilder.createSendPasteTextMessage(text),
      );
      showInfoSnackbar('尝试发送剪切板到WS客户端', null);
    }
  }

  Future<void> onReceivedPasteText(String text) async {
    showInfoSnackbar('收到外部文本粘贴', null);
    try {
      await Clipboard.setData(ClipboardData(text: text));
      showSuccessSnackbar(
        '已写入剪贴板',
        text.length > 50 ? '${text.substring(0, 50)}...' : text,
      );
    } catch (e) {
      showErrorSnackbar('写入剪切板失败', e.toString());
    }
  }

  Future<void> trySendNowClip() async {
    final res = await Clipboard.getData('text/plain');
    if (res != null && res.text != null) {
      _onTextPasted(res.text!);
    }
  }
}
