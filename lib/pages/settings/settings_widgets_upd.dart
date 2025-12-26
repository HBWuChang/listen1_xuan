part of '../../settings.dart';

UpdController updController = Get.find<UpdController>();
Widget updSettingsTile(BuildContext context) {
  return Wrap(
    alignment: WrapAlignment.center,
    children: [
      ...[
        ElevatedButton(
          onPressed: updController.downloadArtifact,
          child: const Text('下载最新测试版'),
        ),
        ElevatedButton(
          onPressed: () {
            g_launchURL(
              Uri.parse('https://github.com/HBWuChang/listen1_xuan/releases'),
            );
          },
          child: Text('打开GitHub Release页面'),
        ),
        if (isAndroid)
          ElevatedButton(
            onPressed: updController.delAndroidApkCache,
            child: const Text('清除安装包缓存'),
          ),
        if (isMacOS)
          ElevatedButton(
            onPressed: () async {
              try {
                Directory tempPath = await xuanGetdownloadDirectory();
                final filelist = tempPath
                    .listSync()
                    .where(
                      (element) =>
                          element is File &&
                          (p.basename(element.path) == 'canary.zip' ||
                              p.basename(element.path) ==
                                  'update_macos.command'),
                    )
                    .toList();

                // 同时清理canary文件夹
                final canaryDir = Directory(p.join(tempPath.path, 'canary'));
                if (await canaryDir.exists()) {
                  filelist.add(canaryDir);
                }

                if (filelist.isEmpty) {
                  showWarningSnackbar('没有找到安装包缓存', null);
                  return;
                }

                for (var file in filelist) {
                  try {
                    if (file is Directory) {
                      await file.delete(recursive: true);
                    } else {
                      await file.delete();
                    }
                  } catch (e) {
                    debugPrint('删除文件失败: $e');
                  }
                }
                showSuccessSnackbar('清理成功', null);
              } catch (e) {
                showErrorSnackbar('清理失败', e.toString());
              }
            },
            child: const Text('清除安装包缓存'),
          ),
        Obx(
          () => SwitchListTile(
            title: const Text('获取PreRelease更新'),
            value: Get.find<SettingsController>().getPreRelease,
            onChanged: (value) {
              Get.find<SettingsController>().getPreRelease = value;
            },
          ),
        ),
      ].map((e) => Padding(padding: EdgeInsets.all(8.0), child: e)),
    ],
  );
}
