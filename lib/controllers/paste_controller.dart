import 'dart:io';

import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/controllers.dart';
import 'package:listen1_xuan/models/websocket_message.dart';
import 'package:listen1_xuan/widgets/image_preview_dialog.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;

import '../funcs.dart';
import '../global_settings_animations.dart';
import '../main.dart';

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
        if (isDesktop) {
          // 桌面端弹出图片预览 Dialog，用户可拖出或点击发送
          _showImagePreviewDialog(image);
        } else {
          _onImagePasted(image);
        }
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

    final wsc = Get.isRegistered<WebSocketClientController>()
        ? Get.find<WebSocketClientController>()
        : null;
    final wss = Get.isRegistered<WebSocketCardController>()
        ? Get.find<WebSocketCardController>()
        : null;

    // 优先通过客户端连接，POST 文件到服务器
    if (wsc != null && wsc.isConnected) {
      showInfoSnackbar('尝试发送 ${files.length} 个文件到服务器', null);
      _postFilesToServer(files, wsc.serverAddress);
      return;
    }

    // 其次，如果本机是服务器且有1个客户端连接，广播 reqToGetFile
    if (wss != null && wss.wsServerController != null && wss.clientCount == 1) {
      final fileNames = files.map((f) => p.basename(f)).toList();
      wss.wsServerController!.nowPasteFiles = files;
      wss.wsServerController!.broadcastMessage(
        WebSocketMessageBuilder.createReqToGetFileMessage(fileNames),
      );
      showInfoSnackbar('已通知客户端下载 ${files.length} 个文件', null);
      return;
    }

    // 没有连接时，仅本地提示
    showInfoSnackbar('粘贴了 ${files.length} 个文件', files.first.split('/').last);
  }

  /// 通过 HTTP POST multipart/form-data 将文件发送到服务器的 /onPasteFile
  Future<void> _postFilesToServer(
    List<String> files,
    String serverAddress,
  ) async {
    try {
      final uri = 'http://$serverAddress/onPasteFile';
      final formData = dio_pkg.FormData();

      for (final filePath in files) {
        final file = File(filePath);
        if (await file.exists()) {
          formData.files.add(
            MapEntry(
              'files',
              await dio_pkg.MultipartFile.fromFile(
                filePath,
                filename: p.basename(filePath),
              ),
            ),
          );
        }
      }

      final dio = dioWithCookieManager;
      final response = await dio.post(uri, data: formData);

      if (response.statusCode == 200) {
        final saved = response.data['saved'] ?? files.length;
        showSuccessSnackbar('已发送 $saved 个文件到服务器', null);
      } else {
        showErrorSnackbar('发送文件失败', '状态码: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[PasteController] POST文件到服务器失败: $e');
      showErrorSnackbar('发送文件失败', e.toString());
    }
  }

  /// 客户端收到 reqToGetFile 消息后，从服务器 /getPasteFile 下载所有文件
  Future<void> onReceivedReqToGetFile(List<String> fileNames) async {
    try {
      final wsc = Get.find<WebSocketClientController>();
      final serverAddress = wsc.serverAddress;
      final uri = 'http://$serverAddress/getPasteFile';

      final dio = dioWithCookieManager;
      final response = await dio.get<List<int>>(
        uri,
        options: dio_pkg.Options(responseType: dio_pkg.ResponseType.bytes),
      );

      if (response.statusCode != 200 || response.data == null) {
        showErrorSnackbar('下载粘贴文件失败', '状态码: ${response.statusCode}');
        return;
      }

      // 解析 multipart/mixed 响应
      final contentTypeHeader =
          response.headers.value(dio_pkg.Headers.contentTypeHeader) ?? '';
      final boundaryMatch = RegExp(
        r'boundary=(.+)',
      ).firstMatch(contentTypeHeader);
      if (boundaryMatch == null) {
        showErrorSnackbar('下载粘贴文件失败', '无法解析 boundary');
        return;
      }
      final boundary = boundaryMatch.group(1)!.trim();

      // 获取保存目录
      final saveDir = await getPasteFileDownloadDir();

      final parts = _parseMultipartResponse(response.data!, boundary);
      int savedCount = 0;

      for (final part in parts) {
        final fileName = part['filename'] as String?;
        final data = part['data'] as List<int>?;
        if (fileName != null && data != null) {
          final savePath = _getUniqueFilePath(saveDir, fileName);
          await File(savePath).writeAsBytes(data);
          savedCount++;
          debugPrint('[PasteController] 保存文件: $savePath');
        }
      }

      if (savedCount > 0) {
        showSuccessSnackbar('已下载 $savedCount 个粘贴文件', '保存到 $saveDir');
      }
    } catch (e) {
      debugPrint('[PasteController] 下载粘贴文件失败: $e');
      showErrorSnackbar('下载粘贴文件失败', e.toString());
    }
  }

  /// 解析 multipart/mixed 响应体
  List<Map<String, dynamic>> _parseMultipartResponse(
    List<int> bytes,
    String boundary,
  ) {
    final parts = <Map<String, dynamic>>[];
    final boundaryBytes = '--$boundary'.codeUnits;

    int searchFrom = 0;
    List<List<int>> rawParts = [];

    while (true) {
      final start = _indexOfBytes(bytes, boundaryBytes, searchFrom);
      if (start == -1) break;

      final contentStart = start + boundaryBytes.length;
      int dataStart = contentStart;
      // 跳过 \r\n
      if (dataStart < bytes.length - 1 &&
          bytes[dataStart] == 13 &&
          bytes[dataStart + 1] == 10) {
        dataStart += 2;
      }

      // 找到下一个 boundary
      final nextBoundary = _indexOfBytes(bytes, boundaryBytes, dataStart);
      if (nextBoundary == -1) break;

      int dataEnd = nextBoundary;
      if (dataEnd >= 2 &&
          bytes[dataEnd - 2] == 13 &&
          bytes[dataEnd - 1] == 10) {
        dataEnd -= 2;
      }

      rawParts.add(bytes.sublist(dataStart, dataEnd));
      searchFrom = nextBoundary;

      // 检查是否为结束 boundary (--boundary--)
      if (nextBoundary + boundaryBytes.length + 2 <= bytes.length &&
          bytes[nextBoundary + boundaryBytes.length] == 45 &&
          bytes[nextBoundary + boundaryBytes.length + 1] == 45) {
        break;
      }
    }

    for (final partBytes in rawParts) {
      // 找到 \r\n\r\n 分隔 headers 和 body
      final headerEnd = _indexOfBytes(partBytes, [13, 10, 13, 10], 0);
      if (headerEnd == -1) continue;

      final headerStr = String.fromCharCodes(partBytes.sublist(0, headerEnd));
      final bodyBytes = partBytes.sublist(headerEnd + 4);

      String? fileName;
      for (final line in headerStr.split('\r\n')) {
        if (line.toLowerCase().startsWith('content-disposition:')) {
          // filename*=UTF-8''xxx
          final utf8Match = RegExp(
            r"filename\*=UTF-8''(.+?)(\s|;|$)",
          ).firstMatch(line);
          if (utf8Match != null) {
            fileName = Uri.decodeComponent(utf8Match.group(1)!);
          } else {
            final match = RegExp(r'filename="?([^";]+)"?').firstMatch(line);
            if (match != null) {
              fileName = match.group(1);
            }
          }
        }
      }

      if (fileName != null && bodyBytes.isNotEmpty) {
        parts.add({'filename': fileName, 'data': bodyBytes});
      }
    }

    return parts;
  }

  /// 在字节数组中查找子数组
  int _indexOfBytes(List<int> data, List<int> pattern, int start) {
    for (int i = start; i <= data.length - pattern.length; i++) {
      bool found = true;
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  /// 获取不重名的文件路径
  String _getUniqueFilePath(String dirPath, String fileName) {
    var filePath = p.join(dirPath, fileName);
    if (!File(filePath).existsSync()) return filePath;

    final nameWithoutExt = p.basenameWithoutExtension(fileName);
    final ext = p.extension(fileName);
    int counter = 1;
    while (File(filePath).existsSync()) {
      filePath = p.join(dirPath, '$nameWithoutExt($counter)$ext');
      counter++;
    }
    return filePath;
  }

  /// 桌面端显示图片预览 Dialog
  void _showImagePreviewDialog(Uint8List imageData) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      // fallback: 没有 context 时直接执行
      _onImagePasted(imageData);
      return;
    }
    if (Get.find<SettingsController>().sendImgWhenOpenImgDialog) {
      _onImagePasted(imageData);
    }
    ImagePreviewDialog.show(
      context,
      imageData: imageData,
      fileName: 'paste_image_${DateTime.now().millisecondsSinceEpoch}.png',
      onConfirm: () => _onImagePasted(imageData),
    );
  }

  /// 图片粘贴回调
  void _onImagePasted(Uint8List imageData) {
    final wsc = Get.isRegistered<WebSocketClientController>()
        ? Get.find<WebSocketClientController>()
        : null;
    final wss = Get.isRegistered<WebSocketCardController>()
        ? Get.find<WebSocketCardController>()
        : null;

    final fileName = 'paste_image_${DateTime.now().millisecondsSinceEpoch}.png';

    // 优先通过客户端连接，POST 图片到服务器
    if (wsc != null && wsc.isConnected) {
      showInfoSnackbar(
        '尝试发送图片到服务器',
        '${(imageData.length / 1024).toStringAsFixed(1)} KB',
      );
      _postImageToServer(imageData, fileName, wsc.serverAddress);
      return;
    }

    // 其次，如果本机是服务器且有1个客户端连接，保存到内存并广播通知
    if (wss != null && wss.wsServerController != null && wss.clientCount == 1) {
      wss.wsServerController!.nowPasteImageData = imageData;
      wss.wsServerController!.nowPasteImageFileName = fileName;
      wss.wsServerController!.broadcastMessage(
        WebSocketMessageBuilder.createReqToGetImageMessage(fileName),
      );
      showInfoSnackbar('已通知客户端下载图片', null);
      return;
    }

    // 没有连接时，仅本地提示
    showInfoSnackbar('粘贴了图片,但无事发生', null);
  }

  /// 通过 HTTP POST 将图片数据发送到服务器的 /onPasteImage
  Future<void> _postImageToServer(
    Uint8List imageData,
    String fileName,
    String serverAddress,
  ) async {
    try {
      final uri = 'http://$serverAddress/onPasteImage';
      final dio = dioWithCookieManager;
      final response = await dio.post(
        uri,
        data: Stream.fromIterable([imageData]),
        options: dio_pkg.Options(
          headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Length': imageData.length,
            'x-filename': Uri.encodeComponent(fileName),
          },
        ),
      );

      if (response.statusCode == 200) {
        showSuccessSnackbar('已发送图片到服务器', null);
      } else {
        showErrorSnackbar('发送图片失败', '状态码: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[PasteController] POST图片到服务器失败: $e');
      showErrorSnackbar('发送图片失败', e.toString());
    }
  }

  /// 客户端收到 reqToGetImage 消息后，从服务器 /getPasteImage 下载图片
  Future<void> onReceivedReqToGetImage(String fileName) async {
    try {
      final wsc = Get.find<WebSocketClientController>();
      final serverAddress = wsc.serverAddress;
      final uri = 'http://$serverAddress/getPasteImage';

      final dio = dioWithCookieManager;
      final response = await dio.get<List<int>>(
        uri,
        options: dio_pkg.Options(responseType: dio_pkg.ResponseType.bytes),
      );

      if (response.statusCode != 200 || response.data == null) {
        showErrorSnackbar('下载粘贴图片失败', '状态码: ${response.statusCode}');
        return;
      }

      // 从响应头获取文件名
      final contentDisposition =
          response.headers.value('content-disposition') ?? '';
      String saveFileName = fileName;
      final utf8Match = RegExp(
        r"filename\*=UTF-8''(.+?)(\s|;|$)",
      ).firstMatch(contentDisposition);
      if (utf8Match != null) {
        saveFileName = Uri.decodeComponent(utf8Match.group(1)!);
      }

      // 保存到下载目录
      final saveDir = await getPasteFileDownloadDir();
      final savePath = _getUniqueFilePath(saveDir, saveFileName);
      await File(savePath).writeAsBytes(response.data!);

      showSuccessSnackbar('已下载粘贴图片', '保存到 ${p.basename(savePath)}');
      debugPrint('[PasteController] 保存图片: $savePath');
    } catch (e) {
      debugPrint('[PasteController] 下载粘贴图片失败: $e');
      showErrorSnackbar('下载粘贴图片失败', e.toString());
    }
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
