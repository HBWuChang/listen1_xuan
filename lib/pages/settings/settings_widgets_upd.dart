part of '../../settings.dart';

Widget updSettingsTile(BuildContext context) {
  return Wrap(
    alignment: WrapAlignment.center,
    children: [
      ...[
        ElevatedButton(
          onPressed: () async {
            var dia_context;

            if (isWindows) {
              try {
                final tempPath = (await xuanGetdownloadDirectory()).path;

                final filePath = p.join(tempPath, 'canary.zip');
                final url_list =
                    'https://api.github.com/repos/HBWuChang/listen1_xuan/actions/artifacts';
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('githubOauthAccessKey');
                if (token == null) {
                  showWarningSnackbar('请先登录Github', null);
                  return;
                }
                final response = await dioWithProxyAdapter.get(
                  url_list,
                  options: Options(
                    headers: {
                      'accept': 'application/vnd.github.v3+json',
                      'authorization': 'Bearer ' + token,
                      'x-github-api-version': '2022-11-28',
                    },
                  ),
                );
                late var art;

                for (var i in response.data["artifacts"]) {
                  if (i['name'].indexOf("windows") >= 0) {
                    art = i;
                    break;
                  }
                }
                bool needDownload = true;
                if (await File(filePath).exists()) {
                  // 获取sha256值
                  var sha256 = await Process.run('certutil', [
                    '-hashfile',
                    filePath,
                    'SHA256',
                  ]);
                  var sha256_str = sha256.stdout
                      .toString()
                      .split('\n')[1]
                      .trim();
                  print('sha256: $sha256_str');
                  String r_sha256 = art["digest"]
                      .replaceAll("sha256:", "")
                      .trim();
                  if (sha256_str == r_sha256) {
                    needDownload = false;
                    debugPrint('文件已存在且hash一致，跳过下载');
                  }
                }

                if (needDownload) {
                  final download_url = art["archive_download_url"];

                  // 首先获取302重定向的实际下载链接
                  final redirectResponse = await dioWithProxyAdapter.get(
                    download_url,
                    options: Options(
                      followRedirects: false,
                      validateStatus: (status) => status! < 400,
                      headers: {
                        'accept': 'application/vnd.github.v3+json',
                        'authorization': 'Bearer ' + token,
                        'x-github-api-version': '2022-11-28',
                      },
                    ),
                  );
                  String actualDownloadUrl = download_url;
                  if (redirectResponse.statusCode == 302) {
                    actualDownloadUrl =
                        redirectResponse.headers.value('location') ??
                        download_url;
                  }

                  // 使用 HyperDownloadController 下载
                  // 移除旧的控制器实例（如果存在）
                  if (Get.isRegistered<HyperDownloadController>()) {
                    Get.delete<HyperDownloadController>();
                  }
                  final hyperDownloadController = Get.put(
                    HyperDownloadController(),
                  );

                  await hyperDownloadController.downloadFile(
                    url: actualDownloadUrl,
                    savePath: filePath,
                    context: context,
                    threadCount: Platform.numberOfProcessors,
                    onComplete: () async {
                      showSuccessSnackbar('下载成功', null);
                      // 继续进行解压和更新
                      await _performWindowsExtractAndUpdate(tempPath, filePath);
                    },
                    onFailed: (String reason) {
                      showErrorSnackbar('下载失败', reason);
                    },
                  );
                } else {
                  // 跳过下载，直接进行解压和更新
                  await _performWindowsExtractAndUpdate(tempPath, filePath);
                }
              } catch (e) {
                try {
                  Navigator.of(dia_context).pop(); // 关闭进度条对话框
                } catch (e) {
                  print('关闭进度条对话框失败: $e');
                }
                showErrorSnackbar('下载失败', e.toString());
              }
            } else if (isAndroid) {
              try {
                if (await Permission.manageExternalStorage
                        .request()
                        .isGranted ||
                    await Permission.storage.request().isGranted) {
                  final tempPath = (await xuanGetdownloadDirectory()).path;

                  // 检查 tempPath 下是否已存在 .apk 文件
                  final tempDir = Directory(tempPath);
                  final apkFiles = await tempDir
                      .list()
                      .where(
                        (entity) =>
                            entity is File && entity.path.endsWith('.apk'),
                      )
                      .toList();

                  if (apkFiles.isNotEmpty) {
                    final res = await showConfirmDialog(
                      '检测到已有下载好的安装包',
                      '安装包已存在',
                      cancelText: '安装已有安装包',
                      confirmText: '继续下载最新安装包',
                      barrierDismissible: false,
                    );
                    if (res == false) {
                      try {
                        final apkPath = (apkFiles.first as File).path;
                        debugPrint('apkFile: $apkPath');
                        InstallPlugin.installApk(apkPath)
                            .then((result) {
                              debugPrint('install apk $result');
                            })
                            .catchError((error) {
                              debugPrint('install apk error: $error');
                            });
                        return;
                      } catch (e) {
                        debugPrint('安装APK失败: $e');
                        return;
                      }
                    } else {
                      await delAndroidApkCache();
                    }
                  }

                  final filePath = p.join(tempPath, 'canary.zip');

                  final url_list =
                      'https://api.github.com/repos/HBWuChang/listen1_xuan/actions/artifacts';
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('githubOauthAccessKey');
                  if (token == null) {
                    showWarningSnackbar('请先登录Github', null);
                    return;
                  }
                  final response = await dioWithProxyAdapter.get(
                    url_list,
                    options: Options(
                      headers: {
                        'accept': 'application/vnd.github.v3+json',
                        'authorization': 'Bearer ' + token,
                        'x-github-api-version': '2022-11-28',
                      },
                    ),
                  );
                  debugPrint(
                    'Kernel architecture: ${SysInfo.kernelArchitecture.name}',
                  );
                  List<dynamic> art = [];

                  switch (SysInfo.kernelArchitecture.name) {
                    case "ARM64":
                      for (var i in response.data["artifacts"]) {
                        if (i['name'].indexOf("arm64") > 0) {
                          art.add(i);
                        }
                      }
                    case "ARM":
                      for (var i in response.data["artifacts"]) {
                        if (i['name'].indexOf("armeabi") > 0) {
                          art.add(i);
                        }
                      }
                    case "X86_64":
                      for (var i in response.data["artifacts"]) {
                        if (i['name'].indexOf("x86_64") > 0) {
                          art.add(i);
                        }
                      }
                    default:
                      art = response.data["artifacts"];
                  }
                  // 弹窗让用户选择
                  final res = await Get.dialog(
                    AlertDialog(
                      title: Text('选择适合您设备的版本'),
                      content: Container(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: art.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Text(art[index]['name']),
                              subtitle: Text(
                                '创建时间: ${art[index]['created_at']}',
                              ),
                              trailing: Text(
                                '${(art[index]['size_in_bytes'] / 1024 / 1024).toStringAsFixed(2)} MB',
                              ),
                              onTap: () {
                                Navigator.of(context).pop(art[index]);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  );
                  if (res == null) {
                    return;
                  }
                  final download_url = res["archive_download_url"];

                  // 使用 HyperDownloadController 下载
                  // 移除旧的控制器实例（如果存在）
                  if (Get.isRegistered<HyperDownloadController>()) {
                    Get.delete<HyperDownloadController>();
                  }
                  final hyperDownloadController = Get.put(
                    HyperDownloadController(),
                  );

                  // 首先获取302重定向的实际下载链接
                  final redirectResponse = await dioWithProxyAdapter.get(
                    download_url,
                    options: Options(
                      followRedirects: false,
                      validateStatus: (status) => status! < 400,
                      headers: {
                        'accept': 'application/vnd.github.v3+json',
                        'authorization': 'Bearer ' + token,
                        'x-github-api-version': '2022-11-28',
                      },
                    ),
                  );
                  String actualDownloadUrl = download_url;
                  if (redirectResponse.statusCode == 302) {
                    actualDownloadUrl =
                        redirectResponse.headers.value('location') ??
                        download_url;
                  }

                  await hyperDownloadController.downloadFile(
                    url: actualDownloadUrl,
                    savePath: filePath,
                    context: context,
                    threadCount: Platform.numberOfProcessors,
                    onComplete: () async {
                      showSuccessSnackbar('下载成功', null);
                      // 解压 ZIP 文件
                      final bytes = File(filePath).readAsBytesSync();
                      final archive = ZipDecoder().decodeBytes(bytes);
                      String apkfilePath = '';
                      for (final file in archive) {
                        final filename = file.name;
                        if (file.isFile) {
                          final data = file.content as List<int>;
                          final extractPath = p.join(tempPath, filename);
                          File(extractPath)
                            ..createSync(recursive: true)
                            ..writeAsBytesSync(data);
                          if (p.extension(filename) == '.apk') {
                            apkfilePath = extractPath;
                          }
                        } else {
                          Directory(
                            p.join(tempPath, filename),
                          ).create(recursive: true);
                        }
                      }

                      if (apkfilePath.isNotEmpty) {
                        try {
                          InstallPlugin.installApk(apkfilePath)
                              .then((result) {
                                debugPrint('install apk $result');
                              })
                              .catchError((error) {
                                debugPrint('install apk error: $error');
                              });
                        } catch (e) {
                          debugPrint('安装APK失败: $e');
                        }
                      } else {
                        showErrorSnackbar('APK 文件未找到', null);
                      }
                    },
                    onFailed: (String reason) {
                      showErrorSnackbar('下载失败', reason);
                    },
                  );
                } else {
                  throw Exception("没有权限访问存储空间");
                }
              } catch (e) {
                try {
                  Navigator.of(dia_context).pop(); // 关闭进度条对话框
                } catch (e) {
                  debugPrint('关闭进度条对话框失败: $e');
                }
                showErrorSnackbar('下载失败', e.toString());
              }
            } else if (isMacOS) {
              try {
                final tempPath = (await xuanGetdownloadDirectory()).path;

                final filePath = p.join(tempPath, 'canary.zip');
                final url_list =
                    'https://api.github.com/repos/HBWuChang/listen1_xuan/actions/artifacts';
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('githubOauthAccessKey');
                if (token == null) {
                  showWarningSnackbar('请先登录Github', null);
                  return;
                }
                final response = await dioWithProxyAdapter.get(
                  url_list,
                  options: Options(
                    headers: {
                      'accept': 'application/vnd.github.v3+json',
                      'authorization': 'Bearer ' + token,
                      'x-github-api-version': '2022-11-28',
                    },
                  ),
                );
                late var art;

                for (var i in response.data["artifacts"]) {
                  if (i['name'].indexOf("macos") >= 0) {
                    art = i;
                    break;
                  }
                }
                bool needDownload = true;
                if (await File(filePath).exists()) {
                  // 获取sha256值
                  var sha256 = await Process.run('shasum', [
                    '-a',
                    '256',
                    filePath,
                  ]);
                  var sha256_str = sha256.stdout
                      .toString()
                      .split(' ')[0]
                      .trim();
                  debugPrint('sha256: $sha256_str');
                  String r_sha256 = art["digest"]
                      .replaceAll("sha256:", "")
                      .trim();
                  if (sha256_str == r_sha256) {
                    needDownload = false;
                    debugPrint('文件已存在且hash一致，跳过下载');
                  }
                }

                if (needDownload) {
                  final download_url = art["archive_download_url"];

                  // 首先获取302重定向的实际下载链接
                  final redirectResponse = await dioWithProxyAdapter.get(
                    download_url,
                    options: Options(
                      followRedirects: false,
                      validateStatus: (status) => status! < 400,
                      headers: {
                        'accept': 'application/vnd.github.v3+json',
                        'authorization': 'Bearer ' + token,
                        'x-github-api-version': '2022-11-28',
                      },
                    ),
                  );
                  String actualDownloadUrl = download_url;
                  if (redirectResponse.statusCode == 302) {
                    actualDownloadUrl =
                        redirectResponse.headers.value('location') ??
                        download_url;
                  }

                  // 使用 HyperDownloadController 下载
                  // 移除旧的控制器实例（如果存在）
                  if (Get.isRegistered<HyperDownloadController>()) {
                    Get.delete<HyperDownloadController>();
                  }
                  final hyperDownloadController = Get.put(
                    HyperDownloadController(),
                  );

                  await hyperDownloadController.downloadFile(
                    url: actualDownloadUrl,
                    savePath: filePath,
                    context: context,
                    threadCount: Platform.numberOfProcessors,
                    onComplete: () async {
                      showSuccessSnackbar('下载成功', null);
                    },
                    onFailed: (String reason) {
                      showErrorSnackbar('下载失败', reason);
                    },
                  );
                }

                // 无论是否下载，都进行解压和更新操作
                if (await File(filePath).exists()) {
                  try {
                    showSuccessSnackbar('正在解压...', null);
                    // 第一次解压 ZIP 文件（从 artifact 解压出 listen1_xuan-macos.app.zip）
                    final bytes = File(filePath).readAsBytesSync();
                    final archive = ZipDecoder().decodeBytes(bytes);
                    // 删除canary文件夹
                    final canaryDir = Directory(p.join(tempPath, 'canary'));
                    if (await canaryDir.exists()) {
                      await canaryDir.delete(recursive: true);
                    }

                    for (final file in archive) {
                      final filename = file.name;
                      if (file.isFile) {
                        final data = file.content as List<int>;
                        final extractPath = p.join(
                          tempPath,
                          'canary',
                          filename,
                        );
                        File(extractPath)
                          ..createSync(recursive: true)
                          ..writeAsBytesSync(data);

                      } else {
                        final dirPath = p.join(tempPath, 'canary', file.name);
                        Directory(dirPath).create(recursive: true);
                      }
                    }

                    // 获取当前应用路径
                    String executablePath = Platform.resolvedExecutable;
                    // macOS应用路径通常是 .../listen1_xuan.app/Contents/MacOS/listen1_xuan
                    String appPath = executablePath;
                    // while (!appPath.endsWith('.app') && appPath.isNotEmpty) {
                    //   appPath = File(appPath).parent.path;
                    // }
                    appPath = appPath
                        .split('/Contents/MacOS/')[0]; // 获取 .app 目录路径

                    debugPrint('当前应用路径: $appPath');
                    debugPrint('解压路径: ${p.join(tempPath, 'canary')}');

                    // 显示提示并执行更新
                    await Get.dialog(
                      AlertDialog(
                        title: Text('准备更新'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('应用将自动关闭并更新到最新版本，更新完成后会自动重启。'),
                            SizedBox(height: 12),
                            Text(
                              '注意：',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '1. 如果macOS阻止脚本运行，请前往 系统设置 -> 隐私与安全性 中手动允许运行更新脚本和新版本应用。',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '2. 若更新脚本没有自动运行，请前往 下载/Listen1/ 文件夹手动运行 update_macos.command。',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Get.back();
                            },
                            child: Text('取消'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Get.back();
                              // 调用脚本函数
                              await createAndRunMacOSScript(tempPath, appPath);
                              // 打开macOS的隐私与安全性设置页面
                              try {
                                await Process.run('open', [
                                  'x-apple.systempreferences:com.apple.preference.security',
                                ]);
                              } catch (e) {
                                debugPrint('打开系统设置失败: $e');
                              }
                              // 退出应用
                              closeApp();
                            },
                            child: Text('确定'),
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    showErrorSnackbar('解压或更新失败', e.toString());
                  }
                } else {
                  showErrorSnackbar('安装包文件不存在', null);
                }
              } catch (e) {
                try {
                  Navigator.of(dia_context).pop(); // 关闭进度条对话框
                } catch (e) {
                  debugPrint('关闭进度条对话框失败: $e');
                }
                showErrorSnackbar('下载失败', e.toString());
              }
            } else {
              showWarningSnackbar('暂未实现', null);
            }
          },
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
            onPressed: delAndroidApkCache,
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
      ].map((e) => Padding(padding: EdgeInsets.all(8.0), child: e)),
    ],
  );
}

/// Windows 平台的解压和更新辅助函数
Future<void> _performWindowsExtractAndUpdate(
  String tempPath,
  String filePath,
) async {
  try {
    showSuccessSnackbar('正在解压...', null);
    // 解压 ZIP 文件
    final bytes = File(filePath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 删除 canary 文件夹
    final canaryDir = Directory(p.join(tempPath, 'canary'));
    if (await canaryDir.exists()) {
      await canaryDir.delete(recursive: true);
      debugPrint('已删除旧的 canary 文件夹');
    }

    // 解压文件
    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        final extractPath = p.join(tempPath, 'canary', filename);
        File(extractPath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      } else {
        final dirPath = p.join(tempPath, 'canary', file.name);
        Directory(dirPath).createSync(recursive: true);
      }
    }

    debugPrint('解压完成，准备更新...');

    String executablePath = Platform.resolvedExecutable;
    String executableDir = File(executablePath).parent.path;
    debugPrint('应用目录: $executableDir');

    showSuccessSnackbar('解压成功，准备更新', null);
    createAndRunBatFile(tempPath, executableDir);
  } catch (e) {
    debugPrint('Windows 解压或更新失败: $e');
    showErrorSnackbar('解压或更新失败', e.toString());
  }
}

Future<void> delAndroidApkCache() async {
  if (await Permission.manageExternalStorage.request().isGranted ||
      await Permission.storage.request().isGranted) {
    Directory tempPath = await xuanGetdownloadDirectory();
    final filelist = tempPath
        .listSync()
        .where(
          (element) =>
              element is File &&
              (p.extension(element.path).endsWith('.apk') ||
                  p.basename(element.path) == 'canary.zip'),
        )
        .toList();
    if (filelist.isEmpty) {
      showWarningSnackbar('没有找到安装包缓存', null);
      return;
    }
    for (var file in filelist) {
      try {
        await file.delete();
      } catch (e) {
        debugPrint('删除文件失败: $e');
      }
    }
    showSuccessSnackbar('清理成功', null);
  } else {
    showErrorSnackbar('没有权限访问存储空间', null);
  }
}
