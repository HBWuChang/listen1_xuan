import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/settings_controller.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/global_settings_animations.dart';

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
        return Markdown(data: settingsController.readmeContent.value);
      }),
    );
  }
}
