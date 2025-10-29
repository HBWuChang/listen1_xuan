import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/settings_controller.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/global_settings_animations.dart';

import '../../settings.dart';

class SettingsReadmePage extends StatelessWidget {
  SettingsReadmePage({Key? key}) : super(key: key);

  final SettingsController settingsController = Get.find<SettingsController>();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (settingsController.hasReadmeContent) return;
      settingsController.loadReadme();
    });
    return Scaffold(
      appBar: AppBar(
        title: Text('README'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              settingsController.loadReadme();
            },
          ),
        ],
      ),
      body: Obx(() {
        if (isEmpty(settingsController.readmeContent.value)) {
          return Center(child: globalLoadingAnime);
        }
        return Markdown(
          onTapLink: (text, href, title) {
            if (href != null) {
              Uri uri = Uri.parse(href);
              if (uri.host.isEmpty) {
                uri = Uri.parse(
                  'https://github.com/HBWuChang/listen1_xuan/blob/main/$href',
                );
              }
              g_launchURL(uri);
            }
          },
          selectable: true,
          data: settingsController.readmeContent.value,
        );
      }),
    );
  }
}
