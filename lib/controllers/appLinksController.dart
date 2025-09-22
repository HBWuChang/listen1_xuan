import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/bodys.dart';
import 'package:listen1_xuan/controllers/play_controller.dart';
import 'package:win32_registry/win32_registry.dart';
import '../global_settings_animations.dart';
import '../play.dart';

class Applinkscontroller extends GetxController {
  var appLink = Uri.parse('').obs;
  Applinkscontroller.initWithAppLinks(Uri appLink) {
    this.appLink.value = appLink;
  }
  Applinkscontroller();
  @override
  void onInit() {
    super.onInit();
    register('listen1-xuan');
    ever(appLink, (Uri uri) {
      if (uri.toString() != '') {
        debugPrint('Received app link: $uri');
        processAppLink();
      }
    });
  }

  String getShareAppLink(Track track) {
    String base64Track = track.toBase64();
    Uri appLink = Uri(
      scheme: 'https',
      host: 'listen1-xuan.040905.xyz',
      path: '/Apeiria',
      queryParameters: {'trackId': track.id, 'track': base64Track},
    );
    return appLink.toString();
  }

  Future<void> processAppLink() async {
    try {
      if (appLink.value.toString() != '') {
        Uri uri = appLink.value;
        Map<String, String> queryParameters = uri.queryParameters;
        debugPrint('Query Parameters: $queryParameters');
        if (queryParameters.containsKey('track')) {
          String trackUtf8Base64 = queryParameters['track']!;
          Track track = Track.fromBase64(trackUtf8Base64);
          song_dialog(Get.context!, track);
          // }
          //  else if (queryParameters.containsKey('trackId')) {
          //   String trackId = queryParameters['trackId']!;
          //   xuan_toast(msg: '正在通过 trackId 获取歌曲信息...');
        } else {
          debugPrint('No track information found in the app link.');
          throw '无效的分享链接';
        }
        appLink.value = Uri.parse('');
      }
    } catch (e) {
      xuan_toast(msg: '$e');
      Clipboard.setData(ClipboardData(text: e.toString()));
    }
  }

  Future<void> register(String scheme) async {
    String appPath = Platform.resolvedExecutable;

    String protocolRegKey = 'Software\\Classes\\$scheme';
    RegistryValue protocolRegValue = const RegistryValue.string(
      'URL Protocol',
      '',
    );
    String protocolCmdRegKey = 'shell\\open\\command';
    RegistryValue protocolCmdRegValue = RegistryValue.string(
      '',
      '"$appPath" "%1"',
    );

    final regKey = Registry.currentUser.createKey(protocolRegKey);
    regKey.createValue(protocolRegValue);
    regKey.createKey(protocolCmdRegKey).createValue(protocolCmdRegValue);
  }
}
