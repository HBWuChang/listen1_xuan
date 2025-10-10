import 'dart:convert';

import 'package:bonsoir/bonsoir.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:uuid/uuid.dart';
import 'settings_controller.dart';

String broadcastType = '_listen1xuan._tcp';

class BroadcastWsController extends GetxController {
  late String deviceId;
  BonsoirBroadcast? broadcast;
  @override
  void onInit() {
    super.onInit();
    loadConfig();
  }

  void loadConfig() {
    if (isEmpty(Get.find<SettingsController>().settings['deviceId'])) {
      deviceId = Uuid().v4();
      Get.find<SettingsController>().settings['deviceId'] = deviceId;
    } else {
      deviceId = Get.find<SettingsController>().settings['deviceId'];
    }
  }

  Future<void> startBroadcast(String serverAddress) async {
    try {
      await stopBroadcast();
      BonsoirService service = BonsoirService(
        name: deviceId,
        type: broadcastType,
        port: 3030,
        attributes: {'address': serverAddress},
      );

      broadcast = BonsoirBroadcast(service: service);
      await broadcast!.initialize();
      await broadcast!.start();
    } catch (e) {
      showErrorSnackbar('启动地址广播失败', e.toString());
    }
  }

  Future<void> stopBroadcast() async {
    if (broadcast != null) {
      await broadcast!.stop();
    }
  }
}
