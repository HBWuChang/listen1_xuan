part of '../../settings.dart';

// Future<void> outputAllSettingsToFile([bool toJsonString = false]) async {
Future<Map<String, dynamic>> outputAllSettingsToFile([
  bool toJsonString = false,
]) async {
  final prefs = await SharedPreferences.getInstance();
  Map<String, dynamic> settings = {};
  final allkeys = prefs.getKeys();
  for (var key in allkeys) {
    switch (key) {
      case 'playerlists':
        settings[key] = prefs.getStringList(key);
        break;
      case 'auto_choose_source_list':
        settings[key] = prefs.getStringList(key);
        break;
      case 'favoriteplayerlists':
        settings[key] = prefs.getStringList(key);
        break;
      case 'settings':
        if (toJsonString) continue;
      case 'local-cache-list':
        continue;
      default:
        try {
          settings[key] = jsonDecode(prefs.getString(key) ?? '{}');
        } catch (e) {
          try {
            settings[key] = prefs.get(key);
          } catch (e) {}
        }
    }
  }
  if (toJsonString) {
    settings.remove('githubOauthAccessKey');
    return settings;
  }
  // 申请所有文件访问权限
  if (await Permission.manageExternalStorage.request().isGranted ||
      await Permission.storage.request().isGranted) {
    try {
      // 确保路径存在
      final outputPath = await xuanGetdownloadDirectory(path: 'settings.json');
      final file = File(outputPath);
      // 将设置写入 JSON 文件
      await file.writeAsString(jsonEncode(settings));
      showSuccessSnackbar('设置已保存到', outputPath);
    } catch (e) {
      showErrorSnackbar('保存设置时出错', '$e');
    }
  } else {
    showErrorSnackbar('存储权限未授予', null);
  }
  return {};
}

Future<void> importSettingsFromFile(
// [bool fromjson = false, String jsonString = '']) async {
[bool fromjson = false, Map<String, dynamic> jsonString = const {}]) async {
  Future<void> _sets(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    for (var key in settings.keys) {
      switch (key) {
        case 'playerlists':
          // settings[key] = prefs.getStringList(key);
          prefs.setStringList(key, settings[key].cast<String>());
          break;
        case 'auto_choose_source_list':
          prefs.setStringList(key, settings[key].cast<String>());
          break;
        case 'favoriteplayerlists':
          prefs.setStringList(key, settings[key].cast<String>());
          break;
        case 'settings':
          continue;
        default:
          try {
            prefs.setString(key, jsonEncode(settings[key]));
          } catch (e) {}
      }
    }
    await Get.find<SettingsController>().loadSettings();
    Get.find<PlayController>().loadDatas();
    Get.find<MyPlayListController>().loadDatas();
    showSuccessSnackbar('配置导入成功', null);
  }

  if (fromjson) {
    // final settings = jsonDecode(jsonString) as Map<String, dynamic>;
    final settings = jsonString;
    await _sets(settings);
    return;
  }
  // 申请所有文件访问权限
  if (await Permission.manageExternalStorage.request().isGranted ||
      await Permission.storage.request().isGranted) {
    try {
      // 弹出系统文件选择器选择文件
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final settings = jsonDecode(content) as Map<String, dynamic>;

        await _sets(settings);
      } else {
        showErrorSnackbar('未选择文件', null);
      }
    } catch (e) {
      showErrorSnackbar('导入设置时出错', '$e');
    }
  } else {
    showErrorSnackbar('存储权限未授予', null);
  }
}

String cookiePath(Directory dir) {
  return p.join(dir.path, '.cookies');
}

Future<void> setSaveCookie({
  required String url,
  required List<Cookie> cookies,
}) async {
  //Save cookies
  final tempDir = await getApplicationDocumentsDirectory();
  final _cookiePath = cookiePath(tempDir);
  await PersistCookieJar(
    ignoreExpires: true,
    storage: FileStorage(_cookiePath),
  ).delete(Uri.parse(url));
  await PersistCookieJar(
    ignoreExpires: true,
    storage: FileStorage(_cookiePath),
  ).saveFromResponse(Uri.parse(url), cookies);
}

Map<String, List<String>> _cookieUrls = {
  'bl': ['https://api.bilibili.com', 'https://www.bilibili.com'],
  'ne': ['https://music.163.com', 'https://interface3.music.163.com'],
  'qq': ['https://u.y.qq.com'],
};

void g_launchURL(Uri url) async {
  try {
    // if (await canLaunchUrl(url)) {
    await launchUrl(url);
    // } else {
    //   throw 'Could not launch $url';
    // }
  } catch (e) {
    showErrorSnackbar('无法打开链接', '$e');
  }
}

Map<String, dynamic> settings_getsettings() {
  return Get.find<SettingsController>().settings;
}

Future<String?> outputPlatformToken(String platform) async {
  if (platform == 'github') {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('githubOauthAccessKey');
  }
  return Get.find<SettingsController>().settings[platform];
}

Future<void> savePlatformToken(
  String platform,
  String token, {
  bool saveRightNow = true,
}) async {
  try {
    if (platform == 'github') {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('githubOauthAccessKey', token);
      return;
    }
    final settings = Get.find<SettingsController>().settings;
    settings[platform] = token;
    if (saveRightNow) Get.find<SettingsController>().saveSettings();
    List<Cookie> cookies = [];
    for (var item in token.split(';')) {
      // 除去两端空格
      var cookie = item.trim().split('=');
      var cookieName = cookie[0].trim();
      var cookieValue = Uri.encodeComponent(cookie[1].trim());
      cookies.add(Cookie(cookieName, cookieValue));
    }

    if (_cookieUrls.containsKey(platform)) {
      for (var url in _cookieUrls[platform]!) {
        await setSaveCookie(url: url, cookies: cookies);
      }
    }
    await Get.find<DioController>().reloadCookie();
  } catch (e) {
    showErrorSnackbar('保存Cookie时出错', '$e');
  }
}

Future<void> createAndRunBatFile(String tempPath, String executableDir) async {
  // 定义文件夹路径
  final folderA = executableDir;
  final folderB = '$tempPath\\canary';

  // 定义 .bat 文件路径
  final batFilePath = '$tempPath\\script.bat';

  // 创建 .bat 文件内容，使用 \r\n 作为换行符
  String batContent =
      '''
@echo off\r
:: Check if running as administrator\r
net session >nul 2>&1\r
if %errorlevel% neq 0 (\r
    echo Requesting administrator privileges...\r
    powershell -Command "Start-Process '%~f0' -Verb RunAs"\r
    exit /b\r
)\r
\r
:: Terminate listen1_xuan.exe process\r
echo Terminating listen1_xuan.exe process...\r
taskkill /F /IM listen1_xuan.exe >nul 2>&1\r
\r
:: Wait for 5 seconds\r
echo Waiting for 5 seconds before proceeding...\r
timeout /t 5 /nobreak >nul\r
\r
:: Delete all data in folder A\r
echo Deleting all data in folder A...\r
rmdir /S /Q "$folderA"\r
\r
:: Copy all data from folder B to folder A\r
echo Copying all data from folder B to folder A...\r
xcopy "$folderB\\*" "$folderA\\" /E /H /C /I\r
\r
:: Start the specified program in folder A\r
echo Starting the program...\r
start "" "$folderA\\listen1_xuan.exe"\r
\r
''';

  // 将内容转换为 GBK 编码的字节
  Uint8List gbkBytes = await CharsetConverter.encode("gb2312", batContent);

  // 写入文件
  File file = File(batFilePath);
  await file.writeAsBytes(gbkBytes, flush: true);

  // 像双击一样运行 .bat 文件
  try {
    await Process.run('cmd', ['/c', batFilePath], runInShell: true);
    logger.i('Script executed successfully');
  } catch (e) {
    print('Error while executing script: $e');
  }
}

Future<void> createAndRunMacOSScript(String tempPath, String appPath) async {
  // 定义路径
  final newAppPath = p.join(tempPath, 'canary', 'listen1_xuan.app');
  final scriptPath = p.join(tempPath, 'update_macos.command');

  // 获取当前进程PID
  final currentPid = pid;

  // 创建更新脚本内容
  final script =
      '''#!/bin/bash

# 等待当前应用进程结束
echo "Waiting for application to quit..."
while kill -0 $currentPid 2>/dev/null; do
  sleep 1
done

# 额外等待2秒确保完全退出
sleep 2

# 备份当前应用
echo "Backing up current application..."
if [ -d "$appPath.backup" ]; then
  rm -rf "$appPath.backup"
fi
mv "$appPath" "$appPath.backup"

# 复制新应用
echo "Installing new version..."
cp -R "$newAppPath" "$appPath"

# 设置执行权限
chmod -R +x "$appPath/Contents/MacOS/"
xattr -rd com.apple.quarantine "$appPath"

# 启动新应用
echo "Launching new version..."
open "$appPath"

# 清理备份（可选，等待10秒后删除）
sleep 10
rm -rf "$appPath.backup"
''';

  // 写入脚本文件
  final scriptFile = File(scriptPath);
  if (await scriptFile.exists()) {
    await scriptFile.delete();
  }
  await scriptFile.writeAsString(script);

  // 设置执行权限
  await Process.run('chmod', ['+x', scriptPath]);

  // 在Terminal窗口中显示执行脚本（类似Windows的命令窗口）
  await Process.start('open', [
    '-a',
    'Terminal.app',
    scriptPath,
  ], mode: ProcessStartMode.detached);
  debugPrint('macOS update script started successfully in Terminal');
}

Future<void> outputPlaylistToGithubGist() async {
  if (Github.status != 2) {
    // _msg('请先登录Github', 1.0);
    showInfoSnackbar('请先登录Github', '');
    return;
  }
  var playlists = await Github.listExistBackup();
  print(playlists);

  try {
    showDialog(
      context: Get.context!,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('导出歌单到Github Gist'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length,
              itemBuilder: (BuildContext context, int index) {
                final playlist = playlists[index];
                return ListTile(
                  title: Text(playlist['id']),
                  subtitle: Text(playlist['description']),
                  onTap: () async {
                    try {
                      showInfoSnackbar('正在导出', null);
                      final settings = await outputAllSettingsToFile(true);
                      final jsfile = Github.json2gist(settings);
                      await Github.backupMySettings2Gist(
                        jsfile,
                        playlist['id'],
                        playlist['public'],
                      );
                      showSuccessSnackbar('导出成功', null);
                      Navigator.of(context).pop();
                    } catch (e) {
                      showErrorSnackbar('导出失败', '$e');
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  showInfoSnackbar('正在导出', null);
                  final settings = await outputAllSettingsToFile(true);
                  final jsfile = Github.json2gist(settings);
                  await Github.backupMySettings2Gist(jsfile, null, true);
                  showSuccessSnackbar('导出成功', null);
                  Navigator.of(context).pop();
                } catch (e) {
                  showErrorSnackbar('导出失败', '$e');
                }
              },
              child: Text('创建公开备份'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  showInfoSnackbar('正在导出', null);
                  final settings = await outputAllSettingsToFile(true);
                  final jsfile = Github.json2gist(settings);
                  await Github.backupMySettings2Gist(jsfile, null, false);
                  showSuccessSnackbar('导出成功', null);
                  Navigator.of(context).pop();
                } catch (e) {
                  showErrorSnackbar('导出失败', '$e');
                }
              },
              child: Text('创建私有备份'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('取消'),
            ),
          ],
        );
      },
    );
  } catch (e) {
    showErrorSnackbar('添加失败', '$e');
  }
}
