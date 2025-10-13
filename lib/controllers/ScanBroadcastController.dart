import 'dart:convert';

import 'package:bonsoir/bonsoir.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'BroadcastWsController.dart';
import 'settings_controller.dart';
import 'websocket_client_controller.dart';

class ScanBroadcastController extends GetxController {
  // Once defined, we can start the discovery :
  final Logger _logger = Logger();
  BonsoirDiscovery discovery = BonsoirDiscovery(type: broadcastType);
  @override
  void onInit() {
    super.onInit();
    startScan();
  }

  void foundService(BonsoirDiscoveryEvent event) {
    String? deviceId = event.service?.name;
    String? host = event.service?.host;
    String? port = event.service?.attributes['port'];
    if (isEmpty(host) || isEmpty(port) || isEmpty(deviceId)) return;

    String serverAddress = '$host:$port';
    Get.find<WebSocketClientController>().canAddAddr.add(serverAddress);
    if (Get.find<WebSocketClientController>().lastConnectedDeviceId.value ==
            deviceId &&
        Get.find<WebSocketClientController>().serverAddress != serverAddress) {
      Get.find<WebSocketClientController>().lastConnectedDeviceNewAddr.value =
          serverAddress!;
    }
  }

  Future<void> startScan() async {
    try {
      await discovery.initialize();
      // If you want to listen to the discovery :
      discovery.eventStream!.listen((event) {
        // `eventStream` is not null as the discovery instance is "ready" !
        try {
          switch (event) {
            case BonsoirDiscoveryServiceFoundEvent():
              // print('Service found : ${event.service.toJson()}');
              event.service!.resolve(
                discovery.serviceResolver,
              ); // Should be called when the user wants to connect to this service.
              foundService(event);
              break;
            case BonsoirDiscoveryServiceResolvedEvent():
              // print('Service resolved : ${event.service.toJson()}');
              foundService(event);
              break;
            case BonsoirDiscoveryServiceUpdatedEvent():
              // print('Service updated : ${event.service.toJson()}');
              foundService(event);
              break;
            case BonsoirDiscoveryServiceLostEvent():
              // print('Service lost : ${event.service.toJson()}');
              String deviceId = event.service.name;
              String? host = event.service.host;
              String? port = event.service.attributes['port'];
              if (isEmpty(host) || isEmpty(port) || isEmpty(deviceId)) return;

              String serverAddress = '$host:$port';
              Get.find<WebSocketClientController>().canAddAddr.remove(
                serverAddress,
              );
              break;
            default:
              // print('Another event occurred : $event.');
              break;
          }
        } catch (e) {
          _logger.e('Error in discovery event handling', error: e);
        }
      });

      await discovery.start();
    } catch (e) {
      _logger.e('启动地址扫描失败', error: e);
    }
  }

  Future<void> stopScan() async {
    try {
      await discovery.stop();
    } catch (e) {
      showErrorSnackbar('停止地址扫描失败', e.toString());
      _logger.e('停止地址扫描失败', error: e);
    }
  }

  @override
  void onClose() {
    stopScan();
    super.onClose();
  }
}
