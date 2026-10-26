import 'dart:async';
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
import 'package:share_plus/share_plus.dart';

import '../funcs.dart';
import '../global_settings_animations.dart';
import '../main.dart';
import '../utils/websocket_address.dart';
import '../services/paste_file_transfer.dart';

/// 全局粘贴控制器
/// 监听 Ctrl+V / Cmd+V 快捷键，处理剪贴板中的文件、图片或文本
class PasteController extends GetxController {
  /// 最近粘贴的文件路径列表
  final pastedFiles = <String>[].obs;

  /// 最近粘贴的文本
  final pastedText = Rxn<String>();

  /// 最近粘贴的图片数据
  final pastedImage = Rxn<Uint8List>();

  final _transfers = <dio_pkg.CancelToken>{};

  /// 是否正在处理粘贴
  final isProcessing = false.obs;
  @override
  void onInit() {
    super.onInit();
    unawaited(
      getPasteFileDownloadDir().then(PasteFileTransfer.cleanStale).catchError((
        Object e,
      ) {
        debugPrint('[PasteController] 清理过期传输失败: $e');
      }),
    );
  }

  @override
  void onClose() {
    for (final token in _transfers) {
      token.cancel('Paste controller closed');
    }
    _transfers.clear();
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
        onFilesPasted(files);
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
        onTextPasted(text);
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
  void onFilesPasted(List<String> files) {
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
    final token = dio_pkg.CancelToken();
    _transfers.add(token);
    try {
      final uri = WebSocketAddress.parse(
        serverAddress,
      ).uri(scheme: 'http', path: '/onPasteFile').toString();
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
      final response = await dio.post(uri, data: formData, cancelToken: token);

      if (response.statusCode == 200) {
        final saved = response.data['saved'] ?? files.length;
        showSuccessSnackbar('已发送 $saved 个文件到服务器', null);
      } else {
        showErrorSnackbar('发送文件失败', '状态码: ${response.statusCode}');
      }
    } catch (e) {
      if (token.isCancelled) return;
      debugPrint('[PasteController] POST文件到服务器失败: $e');
      showErrorSnackbar('发送文件失败', e.toString());
    } finally {
      _transfers.remove(token);
    }
  }

  /// 客户端收到 reqToGetFile 消息后，从服务器 /getPasteFile 下载所有文件
  Future<void> onReceivedReqToGetFile(List<String> fileNames) async {
    final token = dio_pkg.CancelToken();
    _transfers.add(token);
    try {
      final wsc = Get.find<WebSocketClientController>();
      final serverAddress = wsc.serverAddress;
      final uri = WebSocketAddress.parse(
        serverAddress,
      ).uri(scheme: 'http', path: '/getPasteFile').toString();

      final dio = dioWithCookieManager;
      final response = await dio.get<dio_pkg.ResponseBody>(
        uri,
        cancelToken: token,
        options: dio_pkg.Options(responseType: dio_pkg.ResponseType.stream),
      );
      final body = response.data;
      if (response.statusCode != 200 || body == null) {
        await body?.stream.drain<void>();
        throw HttpException('状态码: ${response.statusCode}');
      }
      // Consume the response even if headers/destination validation fails.
      final iterator = StreamIterator<List<int>>(body.stream);
      late final List<String> savedFiles;
      late final String saveDir;
      try {
        saveDir = await getPasteFileDownloadDir();
        final boundary = PasteFileTransfer.boundaryFromContentType(
          response.headers.value(dio_pkg.Headers.contentTypeHeader) ?? '',
        );
        savedFiles = await PasteFileTransfer.receive(
          stream: _iteratorStream(iterator),
          isCancelled: () => token.isCancelled,
          saveDir: saveDir,
          boundary: boundary,
          expectedLength: int.tryParse(
            response.headers.value('content-length') ?? '',
          ),
        );
      } finally {
        await iterator.cancel();
      }
      final savedCount = savedFiles.length;

      if (savedCount > 0) {
        showSuccessSnackbar('已下载 $savedCount 个粘贴文件', '保存到 $saveDir');
        SharePlus.instance.share(
          ShareParams(files: savedFiles.map((f) => XFile(f)).toList()),
        );
      }
    } catch (e) {
      if (token.isCancelled) return;
      debugPrint('[PasteController] 下载粘贴文件失败: $e');
      showErrorSnackbar('下载粘贴文件失败', e.toString());
    } finally {
      _transfers.remove(token);
    }
  }

  static Stream<List<int>> _iteratorStream(
    StreamIterator<List<int>> iterator,
  ) async* {
    while (await iterator.moveNext()) {
      yield iterator.current;
    }
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
  Future<void> _onImagePasted(Uint8List imageData) async {
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

    // 其次，如果本机是服务器且有1个客户端连接，落盘后广播通知
    if (wss != null && wss.wsServerController != null && wss.clientCount == 1) {
      try {
        if (!await wss.wsServerController!.setPasteImage(imageData, fileName)) {
          return;
        }
      } catch (e) {
        showErrorSnackbar('保存待发送图片失败', e.toString());
        return;
      }
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
    final token = dio_pkg.CancelToken();
    _transfers.add(token);
    try {
      final uri = WebSocketAddress.parse(
        serverAddress,
      ).uri(scheme: 'http', path: '/onPasteImage').toString();
      final dio = dioWithCookieManager;
      final response = await dio.post(
        uri,
        cancelToken: token,
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
      if (token.isCancelled) return;
      debugPrint('[PasteController] POST图片到服务器失败: $e');
      showErrorSnackbar('发送图片失败', e.toString());
    } finally {
      _transfers.remove(token);
    }
  }

  /// 客户端收到 reqToGetImage 消息后，从服务器 /getPasteImage 下载图片
  Future<void> onReceivedReqToGetImage(String fileName) async {
    final token = dio_pkg.CancelToken();
    _transfers.add(token);
    try {
      final wsc = Get.find<WebSocketClientController>();
      final serverAddress = wsc.serverAddress;
      final uri = WebSocketAddress.parse(
        serverAddress,
      ).uri(scheme: 'http', path: '/getPasteImage').toString();

      final dio = dioWithCookieManager;
      final response = await dio.get<dio_pkg.ResponseBody>(
        uri,
        cancelToken: token,
        options: dio_pkg.Options(responseType: dio_pkg.ResponseType.stream),
      );
      final body = response.data;
      if (response.statusCode != 200 || body == null) {
        await body?.stream.drain<void>();
        throw HttpException('状态码: ${response.statusCode}');
      }
      final iterator = StreamIterator<List<int>>(body.stream);
      late final String savePath;
      try {
        final saveFileName =
            PasteFileTransfer.fileNameFromDisposition(
              response.headers.value('content-disposition') ?? '',
            ) ??
            fileName;
        final files = await PasteFileTransfer.receive(
          stream: _iteratorStream(iterator),
          isCancelled: () => token.isCancelled,
          saveDir: await getPasteFileDownloadDir(),
          fileName: saveFileName,
          expectedLength: int.tryParse(
            response.headers.value('content-length') ?? '',
          ),
        );
        savePath = files.single;
      } finally {
        await iterator.cancel();
      }

      showSuccessSnackbar('已下载粘贴图片', '保存到 ${p.basename(savePath)}');
      SharePlus.instance.share(ShareParams(files: [XFile(savePath)]));
      debugPrint('[PasteController] 保存图片: $savePath');
    } catch (e) {
      if (token.isCancelled) return;
      debugPrint('[PasteController] 下载粘贴图片失败: $e');
      showErrorSnackbar('下载粘贴图片失败', e.toString());
    } finally {
      _transfers.remove(token);
    }
  }

  /// 文本粘贴回调
  void onTextPasted(String text) {
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
      onTextPasted(res.text!);
    }
  }
}
