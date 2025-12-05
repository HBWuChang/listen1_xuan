import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:logger/logger.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../global_settings_animations.dart';
import '../settings.dart';
import 'settings_controller.dart';
import 'package:cookie_jar/cookie_jar.dart';

class DioController extends GetxController {
  static const String _tag = 'DioController';
  Logger _logger = Logger();
  late String deviceId;
  final dioWithCookieManager = Dio();
  final dioWithProxyAdapter = Dio();

  @override
  void onInit() {
    super.onInit();
    loadConfig();
  }

  void loadConfig() {
    reloadCookie();
    loadProxy();
  }

  void loadProxy() {
    // dioWithCookieManager.httpClientAdapter = IOHttpClientAdapter(
    //   createHttpClient: () {
    //     final client = HttpClient();
    //     client.findProxy = (uri) {
    //       return 'PROXY 192.168.2.123:9000';
    //     };
    //     return client;
    //   },
    // );
    if (isMobile) {
      dioWithProxyAdapter.httpClientAdapter = NativeAdapter(
        createCupertinoConfiguration: () =>
            URLSessionConfiguration.ephemeralSessionConfiguration()
              ..allowsCellularAccess = true
              ..allowsConstrainedNetworkAccess = true
              ..allowsExpensiveNetworkAccess = true,
      );
    } else {
      var proxyaddr = Get.find<SettingsController>().windowsProxyAddr;
      if (proxyaddr != "") {
        dioWithProxyAdapter.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () {
            final client = HttpClient();
            client.findProxy = (uri) {
              return 'PROXY $proxyaddr';
            };
            return client;
          },
        );
      }
    }
  }

  Future<void> reloadCookie() async {
    dioWithCookieManager.interceptors.clear();
    dioWithCookieManager.interceptors.add(
      CookieManager(
        PersistCookieJar(
          ignoreExpires: true,
          storage: FileStorage(
            cookiePath(await getApplicationDocumentsDirectory()),
          ),
        ),
      ),
    );
  }

  Future<void> test() async {
    Dio().get('https://www.baidu.com');
  }
}
