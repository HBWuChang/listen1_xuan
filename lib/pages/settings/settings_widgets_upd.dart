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
                final response = await dio_with_ProxyAdapter.get(
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
                  final created_at = art["created_at"];
                  double total = art["size_in_bytes"].toDouble();
                  double received = 0;
                  final StreamController<double> progressStreamController =
                      StreamController<double>();
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      dia_context = context;
                      return PopScope(
                        canPop: false,
                        onPopInvokedWithResult: (didPop, result) => {},
                        child: StatefulBuilder(
                          builder: (BuildContext context, StateSetter setState) {
                            return AlertDialog(
                              title: Text('下载进度: ${created_at}'),
                              content: StreamBuilder<double>(
                                stream: progressStreamController.stream,
                                builder: (context, snapshot) {
                                  double progress = snapshot.data ?? 0;
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      LinearProgressIndicator(value: progress),
                                      SizedBox(height: 20),
                                      Text(
                                        '${(progress * total / 1024 / 1024).toStringAsFixed(2)}MB/${(total / 1024 / 1024).toStringAsFixed(2)}MB',
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                  await dio_with_ProxyAdapter.download(
                    download_url,
                    filePath,
                    options: Options(
                      headers: {
                        'accept': 'application/vnd.github.v3+json',
                        'authorization': 'Bearer ' + token,
                        'x-github-api-version': '2022-11-28',
                      },
                    ),
                    onReceiveProgress: (receivedBytes, totalBytes) {
                      received = receivedBytes.toDouble();
                      double progress = received / total;
                      progressStreamController.add(progress);
                    },
                  );
                  try {
                    Navigator.of(dia_context).pop(); // 关闭进度条对话框
                  } catch (e) {
                    print('关闭进度条对话框失败: $e');
                  }
                }
                showSuccessSnackbar('下载成功', null);
                // 解压 ZIP 文件
                final bytes = File(filePath).readAsBytesSync();
                final archive = ZipDecoder().decodeBytes(bytes);
                // 删除canary文件夹
                final canaryDir = Directory('$tempPath\\canary');
                if (await canaryDir.exists()) {
                  await canaryDir.delete(recursive: true);
                }
                for (final file in archive) {
                  final filename = file.name;
                  if (file.isFile) {
                    final data = file.content as List<int>;
                    File('$tempPath\\canary\\$filename')
                      ..createSync(recursive: true)
                      ..writeAsBytesSync(data);
                  } else {
                    Directory(
                      '$filePath\\canary\\$filename',
                    ).create(recursive: true);
                  }
                }
                String executablePath = Platform.resolvedExecutable;
                String executableDir = File(executablePath).parent.path;
                print(executableDir);
                createAndRunBatFile(tempPath, executableDir);
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

                  final apkFile = File(apkfile_name);
                  print('apkFile: $apkFile');
                  if (await apkFile.exists()) {
                    try {
                      InstallPlugin.installApk(apkfile_name)
                          .then((result) {
                            print('install apk $result');
                          })
                          .catchError((error) {
                            print('install apk error: $error');
                          });
                      return;
                    } catch (e) {
                      print('安装APK失败: $e');
                      return;
                    }
                  }
                  final filePath = '$tempPath/canary.zip';

                  final url_list =
                      'https://api.github.com/repos/HBWuChang/listen1_xuan/actions/artifacts';
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('githubOauthAccessKey');
                  if (token == null) {
                    showWarningSnackbar('请先登录Github', null);
                    return;
                  }
                  final response = await dio_with_ProxyAdapter.get(
                    url_list,
                    options: Options(
                      headers: {
                        'accept': 'application/vnd.github.v3+json',
                        'authorization': 'Bearer ' + token,
                        'x-github-api-version': '2022-11-28',
                      },
                    ),
                  );
                  print(
                    'Kernel architecture: ${SysInfo.kernelArchitecture.name}',
                  );
                  late var art;

                  switch (SysInfo.kernelArchitecture.name) {
                    case "ARM64":
                      for (var i in response.data["artifacts"]) {
                        if (i['name'].indexOf("arm64") > 0) {
                          art = i;
                          break;
                        }
                      }
                    case "ARM":
                      for (var i in response.data["artifacts"]) {
                        if (i['name'].indexOf("armeabi") > 0) {
                          art = i;
                          break;
                        }
                      }
                    case "X86_64":
                      for (var i in response.data["artifacts"]) {
                        if (i['name'].indexOf("x86_64") > 0) {
                          art = i;
                          break;
                        }
                      }
                    default:
                      art = response.data["artifacts"][0];
                  }
                  final download_url = art["archive_download_url"];
                  final created_at = art["created_at"];
                  double total = art["size_in_bytes"].toDouble();
                  double received = 0;
                  final StreamController<double> progressStreamController =
                      StreamController<double>();
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      dia_context = context;
                      return PopScope(
                        canPop: false,
                        onPopInvokedWithResult: (didPop, result) => {},
                        child: StatefulBuilder(
                          builder: (BuildContext context, StateSetter setState) {
                            return AlertDialog(
                              title: Text('下载进度: ${created_at}'),
                              content: StreamBuilder<double>(
                                stream: progressStreamController.stream,
                                builder: (context, snapshot) {
                                  double progress = snapshot.data ?? 0;
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      LinearProgressIndicator(value: progress),
                                      SizedBox(height: 20),
                                      Text(
                                        '${(progress * total / 1024 / 1024).toStringAsFixed(2)}MB/${(total / 1024 / 1024).toStringAsFixed(2)}MB',
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                  // 首先获取302重定向的实际下载链接
                  final redirectResponse = await dio_with_ProxyAdapter.get(
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

                  // 使用实际下载链接进行下载，不添加GitHub API请求头
                  await dio_with_ProxyAdapter.download(
                    // await Dio().download(
                    actualDownloadUrl,
                    filePath,
                    onReceiveProgress: (receivedBytes, totalBytes) {
                      received = receivedBytes.toDouble();
                      double progress = received / total;
                      progressStreamController.add(progress);
                    },
                  );

                  try {
                    Navigator.of(dia_context).pop(); // 关闭进度条对话框
                  } catch (e) {
                    print('关闭进度条对话框失败: $e');
                  }
                  // 解压 ZIP 文件
                  final bytes = File(filePath).readAsBytesSync();
                  final archive = ZipDecoder().decodeBytes(bytes);

                  for (final file in archive) {
                    final filename = file.name;
                    if (file.isFile) {
                      final data = file.content as List<int>;
                      File('$tempPath/$filename')
                        ..createSync(recursive: true)
                        ..writeAsBytesSync(data);
                    } else {
                      Directory('$filePath/$filename').create(recursive: true);
                    }
                  }
                  if (await apkFile.exists()) {
                    try {
                      InstallPlugin.installApk(apkfile_name)
                          .then((result) {
                            print('install apk $result');
                          })
                          .catchError((error) {
                            print('install apk error: $error');
                          });
                    } catch (e) {
                      print('安装APK失败: $e');
                    }
                  } else {
                    showErrorSnackbar('APK 文件未找到', null);
                  }
                  showSuccessSnackbar('下载成功', null);
                } else {
                  throw Exception("没有权限访问存储空间");
                }
              } catch (e) {
                try {
                  Navigator.of(dia_context).pop(); // 关闭进度条对话框
                } catch (e) {
                  print('关闭进度条对话框失败: $e');
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
                final tempDir = await getApplicationDocumentsDirectory();
                var tempPath = tempDir.path;
                var filePath = '$tempPath/canary.zip';

                var file = File(filePath);
                if (await file.exists()) {
                  await file.delete();
                }
                file = File('$tempPath/app-arm64-v8a-release.apk');
                if (await file.exists()) {
                  await file.delete();
                }
                file = File('$tempPath/app-armeabi-v7a-release.apk');
                if (await file.exists()) {
                  await file.delete();
                }
                file = File('$tempPath/app-x86_64-release.apk');
                if (await file.exists()) {
                  await file.delete();
                }
                file = File('$tempPath/app-release.apk');
                if (await file.exists()) {
                  await file.delete();
                }
                tempPath = '/storage/emulated/0/Download/Listen1';
                filePath = '$tempPath/canary.zip';

                file = File(filePath);
                if (await file.exists()) {
                  await file.delete();
                }
                file = File('$tempPath/app-arm64-v8a-release.apk');
                if (await file.exists()) {
                  await file.delete();
                }
                file = File('$tempPath/app-armeabi-v7a-release.apk');
                if (await file.exists()) {
                  await file.delete();
                }
                file = File('$tempPath/app-x86_64-release.apk');
                if (await file.exists()) {
                  await file.delete();
                }
                file = File('$tempPath/app-release.apk');
                if (await file.exists()) {
                  await file.delete();
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
