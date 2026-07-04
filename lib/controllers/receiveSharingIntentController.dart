import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/paste_controller.dart';
import 'package:listen1_xuan/controllers/websocket_card_controller.dart';
import 'package:listen1_xuan/controllers/websocket_client_controller.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/settings.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class ReceiveSharingIntentController extends GetxController {
  late StreamSubscription _intentSub;
  final _sharedFiles = <SharedMediaFile>[];
  @override
  void onInit() {
    super.onInit();
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (value) {
        _sharedFiles.clear();
        _sharedFiles.addAll(value);
        processFiles();
      },
      onError: (err) {
        logger.e('ReceiveSharingIntentController getMediaStream', error: err);
      },
    );

    // Get the media sharing coming from outside the app while the app is closed.
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      _sharedFiles.clear();
      _sharedFiles.addAll(value);
      processFiles();

      ReceiveSharingIntent.instance.reset();
    });
  }

  @override
  void onClose() {
    _intentSub.cancel();
    super.onClose();
  }

  String _sendText = '';
  List<String> _sendFiles = [];
  void processFiles() {
    if (_sharedFiles.isNotEmpty) {
      final file = _sharedFiles.first;
      if (file.type == SharedMediaType.text ||
          file.type == SharedMediaType.url) {
        _sendText = file.path;
        reg(sendText);
      } else {
        _sendFiles = _sharedFiles.map((e) => e.path).toList();
        reg(sendFile);
      }
    }
  }

  Worker? wscReg;
  Worker? wssReg;
  void reg(VoidCallback todo) {
    if (isConnected()) {
      todo.call();
    } else {
      call = todo;
      showInfoSnackbar('检测到分享内容，正在等待网络连接...', null);
      regController();
    }
  }

  void regController() {
    final wsc = Get.isRegistered<WebSocketClientController>()
        ? Get.find<WebSocketClientController>()
        : null;
    final wss = Get.isRegistered<WebSocketCardController>()
        ? Get.find<WebSocketCardController>()
        : null;
    if (wsc != null && wscReg == null) {
      wscReg = ever(wsc.i_isConnected, (c) {
        if (c) {
          tryCall();
        }
      });
    }
    if (wss != null && wssReg == null) {
      wscReg = ever(wss.i_clientCount, (c) {
        if (c == 1) {
          tryCall();
        }
      });
    }
  }

  void tryCall() {
    if (call != null) call?.call();
    call = null;
  }

  VoidCallback? call;
  bool isConnected() {
    final wsc = Get.isRegistered<WebSocketClientController>()
        ? Get.find<WebSocketClientController>()
        : null;
    final wss = Get.isRegistered<WebSocketCardController>()
        ? Get.find<WebSocketCardController>()
        : null;
    if (wsc != null && wsc.isConnected) {
      return true;
    }
    if (wss != null && wss.clientCount == 1) {
      return true;
    }
    return false;
  }

  void sendText() {
    Get.find<PasteController>().onTextPasted(_sendText);
  }

  void sendFile() {
    Get.find<PasteController>().onFilesPasted(_sendFiles);
  }
}
