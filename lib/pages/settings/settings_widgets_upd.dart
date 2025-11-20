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
                bool flag = true;
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
                    flag = false;
                  }
                }
                if (flag) {
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
                      // 解压 ZIP 文件
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
                      String executablePath = Platform.resolvedExecutable;
                      String executableDir = File(executablePath).parent.path;
                      debugPrint(executableDir);
                      createAndRunBatFile(tempPath, executableDir);
                    },
                    onFailed: (String reason) {
                      showErrorSnackbar('下载失败', reason);
                    },
                  );
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
            onPressed: () async {
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
            },
            child: const Text('清除安装包缓存'),
          ),
      ].map((e) => Padding(padding: EdgeInsets.all(8.0), child: e)),
    ],
  );
}
