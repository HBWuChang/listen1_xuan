import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:install_plugin/install_plugin.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_info3/system_info3.dart';

import '../funcs.dart';
import '../global_settings_animations.dart';
import '../settings.dart';
import '../models/GitHubRelease.dart';
import '../models/ReleaseAsset.dart';
import 'DioController.dart';
import 'hyper_download_controller.dart';
import 'routeController.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdController extends GetxController {
  static const String buildGitHash = String.fromEnvironment('gitHash');
  @override
  void onInit() {
    super.onInit();
    if (!isIos) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        checkReleasesUpdate();
      });
    }
  }

  Future<void> downloadArtifact() async {
    if (isWindows) {
      await downloadArtifactWindows();
    } else if (isMacOS) {
      await downloadArtifactMacos();
    } else if (isAndroid) {
      await downloadArtifactAndroid();
    } else if (isIos) {
      await downloadArtifactIos();
    } else {
      showWarningSnackbar('当前平台不支持该功能', null);
    }
  }

  /// 获取 GitHub OAuth Token
  Future<String?> _getGithubToken() async {
    final prefs = SharedPreferencesAsync();
    return await prefs.getString('githubOauthAccessKey');
  }

  /// 获取 GitHub API 请求头
  Map<String, String> _getGithubHeaders(String token) {
    return {
      'accept': 'application/vnd.github.v3+json',
      'authorization': 'Bearer $token',
      'x-github-api-version': '2022-11-28',
    };
  }

  /// 获取 GitHub Actions Artifacts
  Future<List<dynamic>> _fetchArtifacts(String token) async {
    final url_list =
        'https://api.github.com/repos/HBWuChang/listen1_xuan/actions/artifacts';
    final response = await dioWithProxyAdapter.get(
      url_list,
      options: Options(headers: _getGithubHeaders(token)),
    );
    return response.data["artifacts"];
  }

  /// 查找匹配平台的 artifact
  dynamic _findArtifactByPlatform(List<dynamic> artifacts, String platform) {
    for (var artifact in artifacts) {
      if (artifact['name'].toString().contains(platform)) {
        return artifact;
      }
    }
    return null;
  }

  /// 检查文件哈希是否匹配 (通用)
  Future<bool> _checkFileHash(
    String filePath,
    String expectedHash,
    List<String> hashCommand,
  ) async {
    if (!await File(filePath).exists()) {
      return false;
    }

    try {
      final result = await Process.run(hashCommand[0], hashCommand.sublist(1));
      final hashStr = result.stdout.toString();
      final actualHash = _extractHash(hashStr, hashCommand[0]);
      final cleanExpectedHash = expectedHash.replaceAll("sha256:", "").trim();

      debugPrint('文件哈希: $actualHash');
      debugPrint('预期哈希: $cleanExpectedHash');

      if (actualHash == cleanExpectedHash) {
        debugPrint('文件已存在且hash一致，跳过下载');
        return true;
      }
    } catch (e) {
      debugPrint('哈希检查失败: $e');
    }
    return false;
  }

  /// 提取哈希值
  String _extractHash(String output, String command) {
    if (command == 'certutil') {
      return output.split('\n')[1].trim();
    } else if (command == 'shasum') {
      return output.split(' ')[0].trim();
    }
    return '';
  }

  /// 获取302重定向的实际下载链接
  Future<String> _getActualDownloadUrl(String downloadUrl, String token) async {
    final redirectResponse = await dioWithProxyAdapter.get(
      downloadUrl,
      options: Options(
        followRedirects: false,
        validateStatus: (status) => status! < 400,
        headers: _getGithubHeaders(token),
      ),
    );

    if (redirectResponse.statusCode == 302) {
      return redirectResponse.headers.value('location') ?? downloadUrl;
    }
    return downloadUrl;
  }

  /// 使用 HyperDownloadController 下载文件
  Future<void> _downloadWithHyperController({
    required String url,
    required String savePath,
    required BuildContext context,
    required Future<void> Function() onComplete,
  }) async {
    // 移除旧的控制器实例（如果存在）
    if (Get.isRegistered<HyperDownloadController>()) {
      Get.delete<HyperDownloadController>();
    }
    final hyperDownloadController = Get.put(HyperDownloadController());

    await hyperDownloadController.downloadFile(
      url: url,
      savePath: savePath,
      context: context,
      threadCount: Platform.numberOfProcessors,
      onComplete: onComplete,
      onFailed: (String reason) {
        showErrorSnackbar('下载失败', reason);
      },
    );
  }

  /// 关闭进度对话框
  void _closeProgressDialog() {
    try {
      Get.back();
    } catch (e) {
      debugPrint('关闭进度条对话框失败: $e');
    }
  }

  Future<void> downloadArtifactWindows() async {
    try {
      final token = await _getGithubToken();
      if (token == null) {
        showWarningSnackbar('请先登录Github', null);
        return;
      }

      final tempPath = (await xuanGetdownloadDirectory()).path;
      final filePath = p.join(tempPath, 'canary.zip');

      final artifacts = await _fetchArtifacts(token);
      final art = _findArtifactByPlatform(artifacts, 'windows');
      if (art == null) {
        showErrorSnackbar('未找到 Windows 版本', null);
        return;
      }

      // 检查文件哈希
      final needDownload = !await _checkFileHash(filePath, art["digest"], [
        'certutil',
        '-hashfile',
        filePath,
        'SHA256',
      ]);

      if (needDownload) {
        final downloadUrl = art["archive_download_url"];
        final actualDownloadUrl = await _getActualDownloadUrl(
          downloadUrl,
          token,
        );

        await _downloadWithHyperController(
          url: actualDownloadUrl,
          savePath: filePath,
          context: Get.context!,
          onComplete: () async {
            showSuccessSnackbar('下载成功', null);
            await _performWindowsExtractAndUpdate(tempPath, filePath);
          },
        );
      } else {
        await _performWindowsExtractAndUpdate(tempPath, filePath);
      }
    } catch (e) {
      _closeProgressDialog();
      showErrorSnackbar('下载失败', e.toString());
    }
  }

  Future<void> downloadArtifactAndroid() async {
    try {
      if (!await Permission.manageExternalStorage.request().isGranted &&
          !await Permission.storage.request().isGranted) {
        throw Exception("没有权限访问存储空间");
      }

      final token = await _getGithubToken();
      if (token == null) {
        showWarningSnackbar('请先登录Github', null);
        return;
      }

      final tempPath = (await xuanGetdownloadDirectory()).path;

      // 检查是否已有 APK 文件
      if (await _checkExistingApk(tempPath)) {
        return;
      }

      final filePath = p.join(tempPath, 'canary.zip');
      final artifacts = await _fetchArtifacts(token);
      final selectedArt = await _selectAndroidArtifact(artifacts);
      if (selectedArt == null) {
        return;
      }

      final downloadUrl = selectedArt["archive_download_url"];
      final actualDownloadUrl = await _getActualDownloadUrl(downloadUrl, token);

      await _downloadWithHyperController(
        url: actualDownloadUrl,
        savePath: filePath,
        context: Get.context!,
        onComplete: () async {
          showSuccessSnackbar('下载成功', null);
          await _extractAndInstallApk(tempPath, filePath);
        },
      );
    } catch (e) {
      _closeProgressDialog();
      showErrorSnackbar('下载失败', e.toString());
    }
  }

  /// 检查已有的 APK 文件
  Future<bool> _checkExistingApk(String tempPath) async {
    final tempDir = Directory(tempPath);
    final apkFiles = await tempDir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.apk'))
        .toList();

    if (apkFiles.isEmpty) {
      return false;
    }

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
        return true;
      } catch (e) {
        debugPrint('安装APK失败: $e');
        return true;
      }
    } else {
      await delAndroidApkCache();
      return false;
    }
  }

  /// 选择 Android artifact
  Future<dynamic> _selectAndroidArtifact(List<dynamic> artifacts) async {
    debugPrint('Kernel architecture: ${SysInfo.kernelArchitecture.name}');
    List<dynamic> filteredArt = [];

    switch (SysInfo.kernelArchitecture.name) {
      case "ARM64":
        filteredArt = artifacts
            .where((i) => i['name'].toString().contains("arm64"))
            .toList();
        break;
      case "ARM":
        filteredArt = artifacts
            .where((i) => i['name'].toString().contains("armeabi"))
            .toList();
        break;
      case "X86_64":
        filteredArt = artifacts
            .where((i) => i['name'].toString().contains("x86_64"))
            .toList();
        break;
      default:
        filteredArt = artifacts;
    }

    return await Get.dialog(
      AlertDialog(
        title: Text('选择适合您设备的版本'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: filteredArt.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(filteredArt[index]['name']),
                subtitle: Text('创建时间: ${filteredArt[index]['created_at']}'),
                trailing: Text(
                  '${(filteredArt[index]['size_in_bytes'] / 1024 / 1024).toStringAsFixed(2)} MB',
                ),
                onTap: () {
                  Get.back(result: filteredArt[index]);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// 解压并安装 APK
  Future<void> _extractAndInstallApk(
    String tempPath,
    String filePath, {
    bool isRelease = false,
  }) async {
    if (isRelease) {
      try {
        InstallPlugin.installApk(filePath)
            .then((result) {
              debugPrint('install apk $result');
            })
            .catchError((error) {
              debugPrint('install apk error: $error');
            });
      } catch (e) {
        debugPrint('安装APK失败: $e');
        try {
          InstallPlugin.installApk(filePath)
              .then((result) {
                debugPrint('install apk $result');
              })
              .catchError((error) {
                debugPrint('install apk error: $error');
              });
        } catch (e) {
          debugPrint('安装APK失败: $e');
          try {
            InstallPlugin.installApk(filePath)
                .then((result) {
                  debugPrint('install apk $result');
                })
                .catchError((error) {
                  debugPrint('install apk error: $error');
                });
          } catch (e) {
            debugPrint('安装APK失败: $e');
          }
        }
      }
      return;
    }
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
        Directory(p.join(tempPath, filename)).create(recursive: true);
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
  }

  Future<void> downloadArtifactMacos() async {
    try {
      final token = await _getGithubToken();
      if (token == null) {
        showWarningSnackbar('请先登录Github', null);
        return;
      }

      final tempPath = (await xuanGetdownloadDirectory()).path;
      final filePath = p.join(tempPath, 'canary.zip');

      final artifacts = await _fetchArtifacts(token);
      final art = _findArtifactByPlatform(artifacts, 'macos');
      if (art == null) {
        showErrorSnackbar('未找到 macOS 版本', null);
        return;
      }

      // 检查文件哈希
      final needDownload = !await _checkFileHash(filePath, art["digest"], [
        'shasum',
        '-a',
        '256',
        filePath,
      ]);

      if (needDownload) {
        final downloadUrl = art["archive_download_url"];
        final actualDownloadUrl = await _getActualDownloadUrl(
          downloadUrl,
          token,
        );

        await _downloadWithHyperController(
          url: actualDownloadUrl,
          savePath: filePath,
          context: Get.context!,
          onComplete: () async {
            showSuccessSnackbar('下载成功', null);
          },
        );
      }

      // 无论是否下载，都进行解压和更新操作
      if (await File(filePath).exists()) {
        await _performMacosExtractAndUpdate(tempPath, filePath);
      } else {
        showErrorSnackbar('安装包文件不存在', null);
      }
    } catch (e) {
      _closeProgressDialog();
      showErrorSnackbar('下载失败', e.toString());
    }
  }

  /// macOS 平台的解压和更新
  Future<void> _performMacosExtractAndUpdate(
    String tempPath,
    String filePath,
  ) async {
    try {
      showSuccessSnackbar('正在解压...', null);

      // 删除canary文件夹
      final canaryDir = Directory(p.join(tempPath, 'canary'));
      if (await canaryDir.exists()) {
        await canaryDir.delete(recursive: true);
      }

      // release下载
      if (!p.basename(filePath).contains('artifact')) {
        await extractFileToDisk(filePath, p.join(tempPath, 'canary'));
      } else {
        // 第一次解压 ZIP 文件
        final bytes = File(filePath).readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(bytes);

        String innerZipPath = '';
        for (final file in archive) {
          final filename = file.name;
          if (file.isFile) {
            final data = file.content as List<int>;
            final extractPath = p.join(tempPath, 'canary', filename);
            File(extractPath)
              ..createSync(recursive: true)
              ..writeAsBytesSync(data);

            if (filename.endsWith('macos.zip')) {
              innerZipPath = extractPath;
            }
          } else {
            final dirPath = p.join(tempPath, 'canary', file.name);
            Directory(dirPath).create(recursive: true);
          }
        }

        // 第二次解压
        if (innerZipPath.isNotEmpty && await File(innerZipPath).exists()) {
          debugPrint('找到内部zip文件: $innerZipPath');
          await extractFileToDisk(innerZipPath, p.join(tempPath, 'canary'));
          await File(innerZipPath).delete();
        } else {
          showErrorSnackbar('未找到 .app.zip 文件', null);
          return;
        }
      }

      // 获取当前应用路径
      String executablePath = Platform.resolvedExecutable;
      String appPath = executablePath.split('/Contents/MacOS/')[0];

      debugPrint('当前应用路径: $appPath');
      debugPrint('解压路径: ${p.join(tempPath, 'canary')}');

      // 显示更新确认对话框
      await _showMacosUpdateDialog(tempPath, appPath);
    } catch (e) {
      showErrorSnackbar('解压或更新失败', e.toString());
    }
  }

  /// 显示 macOS 更新确认对话框
  Future<void> _showMacosUpdateDialog(String tempPath, String appPath) async {
    await Get.dialog(
      AlertDialog(
        title: Text('准备更新'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('应用将自动关闭并更新到最新版本，更新完成后会自动重启。'),
            SizedBox(height: 12),
            Text('注意：', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              '1. 如果macOS阻止脚本运行，请前往 系统设置 -> 隐私与安全性 中手动允许运行更新脚本和新版本应用。',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            SizedBox(height: 4),
            Text(
              '2. 若更新脚本没有自动运行，请前往 下载/Listen1/ 文件夹手动运行 update_macos.command。',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            SizedBox(height: 4),
            Text(
              '3. 若更新脚本运行后仍无法启动应用,请手动移动并运行 下载/Listen1/canary 文件夹下的 新版应用程序',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
              try {
                Get.back();
                await createAndRunMacOSScript(tempPath, appPath);
                await Process.run('open', [
                  'x-apple.systempreferences:com.apple.preference.security',
                ]);
                closeApp();
              } catch (e) {
                showErrorSnackbar('更新失败', e.toString());
              }
            },
            child: Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> downloadArtifactIos() async {
    showWarningSnackbar('暂未实现', null);
  }

  /// Windows 平台的解压和更新辅助函数
  Future<void> _performWindowsExtractAndUpdate(
    String tempPath,
    String filePath,
  ) async {
    try {
      showSuccessSnackbar('正在解压...', null);
      // 删除 canary 文件夹
      final canaryDir = Directory(p.join(tempPath, 'canary'));
      if (await canaryDir.exists()) {
        await canaryDir.delete(recursive: true);
        debugPrint('已删除旧的 canary 文件夹');
      }
      // 解压 ZIP 文件
      await extractFileToDisk(filePath, p.join(tempPath, 'canary'));
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

  /// ===================== Releases 更新检查相关方法 =====================

  /// 删除 releases 缓存文件
  /// [releases] 需要删除缓存的 releases 列表
  Future<void> delReleasesCache(List<GitHubRelease> releases) async {
    try {
      final tempPath = (await xuanGetdownloadDirectory()).path;
      int deletedCount = 0;

      // 遍历所有 releases
      for (final release in releases) {
        // 遍历每个 release 中的 assets
        for (final asset in release.assets) {
          final fileName = asset.name;
          final filePath = p.join(tempPath, fileName);

          // 检查文件是否存在并删除
          if (await File(filePath).exists()) {
            try {
              await File(filePath).delete();
              debugPrint('已删除 Release 缓存文件: $fileName');
              deletedCount++;
            } catch (e) {
              debugPrint('删除 Release 缓存文件 $fileName 失败: $e');
            }
          }
        }
      }

      if (deletedCount > 0) {
        showSuccessSnackbar('Release 缓存清理完成 (删除了 $deletedCount 个文件)', null);
      }
    } catch (e) {
      debugPrint('清理 Release 缓存失败: $e');
      showErrorSnackbar('清理失败', e.toString());
    }
  }

  /// 检查 Releases 更新
  /// 获取所有 releases 列表，比较最新版本的 buildNumber 和本地应用的 buildNumber
  /// 如果有新版本，弹出更新对话框，并删除除最新版本外的其他缓存文件
  Future<void> checkReleasesUpdate() async {
    try {
      String localBuildNumber = buildGitHash;
      final releases = await Github.getReleasesList();
      if (releases.isEmpty) {
        showDebugSnackbar('未能获取 Releases 列表', null);
        return;
      }

      final latestRelease = releases.firstWhere(
        (release) => !release.prerelease,
        orElse: () => releases.first,
      );
      final latestBuild = _selectReleaseAsset(latestRelease);
      if (latestBuild == null) {
        showDebugSnackbar('未能获取最新版本的安装包信息', null);
        return;
      }
      final latestBuildNumber = p
          .basenameWithoutExtension(latestBuild.name)
          .split('_')
          .last;

      showDebugSnackbar(
        '本地版本 buildNumber: $localBuildNumber, 最新版本 buildNumber: $latestBuildNumber',
        null,
      );
      // 删除除最新版本外的其他缓存文件
      if (releases.length > 1) {
        final oldReleases = releases.sublist(1);
        await delReleasesCache(oldReleases);
      }

      if (localBuildNumber != latestBuildNumber) {
        // 有新版本可用
        _showReleaseUpdateDialog(latestRelease, latestBuild);
      }
    } catch (e) {
      // debugPrint('检查 Releases 更新失败: $e');
      showErrorSnackbar('检查 Releases 更新失败', e.toString());
    }
  }

  /// 显示 Release 更新对话框
  void _showReleaseUpdateDialog(
    GitHubRelease release,
    ReleaseAsset latestBuild,
  ) {
    // 用于控制下载进度和加载状态
    RxBool isUpdating = false.obs;
    RxString progressText = '准备下载'.obs;

    // 构建进度指示器 widget，支持显示百分比
    Widget _buildProgressIcon() {
      return Obx(() {
        if (!isUpdating.value) {
          return Icon(Icons.system_update_rounded);
        }

        // 从 progressText 中提取百分比
        double progress = 0.0;
        if (progressText.value.contains('%')) {
          try {
            progress =
                double.parse(progressText.value.replaceAll('%', '')) / 100.0;
          } catch (e) {
            progress = 0.0;
          }
        }

        return Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress > 0 ? progress : null,
                  color: Get.theme.colorScheme.onPrimary,
                ),
              ],
            ),
          ),
        );
      });
    }

    smoothSheetToast.showToast(
      inLockMode: true,
      icon: _buildProgressIcon(),
      onDismiss: () {},
      builder: (context, controller) {
        return Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ListTile(
                contentPadding: EdgeInsets.only(left: 16),
                title: Text('发现新版本', style: Get.theme.textTheme.titleMedium),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      child: Text(
                        '版本: ${release.tagName}',
                        maxLines: 1,
                        style: Get.theme.textTheme.bodyMedium,
                      ),
                    ),
                    if (!isEmpty(release.bodyText))
                      FittedBox(
                        child: Text(
                          '${release.bodyText}',
                          maxLines: 1,
                          style: Get.theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
                trailing: IconButton(
                  onPressed: controller.peek,
                  icon: Icon(Icons.minimize_rounded),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(
                    () => TextButton(
                      onPressed: isUpdating.value
                          ? null
                          : () {
                              controller.exitLockedMode();
                              debugPrint(controller.isLockedMode.toString());
                              controller.hide();
                            },
                      child: Text(
                        '稍后更新',
                        style: TextStyle(color: Get.theme.colorScheme.primary),
                      ),
                    ),
                  ),
                  Obx(
                    () => ElevatedButton.icon(
                      onPressed: isUpdating.value
                          ? null
                          : () async {
                              // 进入锁定模式，防止用户滑动时关闭Toast
                              controller.enterLockedMode();
                              isUpdating.value = true;
                              progressText.value = '准备下载';
                              await _downloadAndUpdateRelease(
                                release,
                                isUpdating,
                                progressText,
                              );
                              // 下载完成后返回正常模式
                              controller.exitLockedMode();
                            },
                      icon: _buildProgressIcon(),
                      label: FittedBox(
                        child: Obx(
                          () => Text(
                            isUpdating.value ? progressText.value : '立即更新',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 下载并更新 Release
  Future<void> _downloadAndUpdateRelease(
    GitHubRelease release,
    RxBool isUpdating,
    RxString progressText,
  ) async {
    try {
      progressText.value = '获取链接';

      // 根据平台选择下载链接和对应的 asset
      String? downloadUrl = _selectReleaseAssetUrl(release);
      if (downloadUrl == null) {
        showWarningSnackbar('暂未支持当前平台', null);
        isUpdating.value = false;
        return;
      }

      // 获取对应的 asset 对象，用于获取 digest（哈希值）
      ReleaseAsset? selectedAsset = _selectReleaseAsset(release);
      if (selectedAsset == null) {
        showWarningSnackbar('未找到对应的安装包信息', null);
        isUpdating.value = false;
        return;
      }

      final tempPath = (await xuanGetdownloadDirectory()).path;
      final fileName = downloadUrl.split('/').last;
      final filePath = p.join(tempPath, fileName);

      // 检查本地是否已有相同的文件且哈希匹配
      progressText.value = '检查本地';
      final needDownload = await _checkReleaseFileHash(
        filePath,
        selectedAsset.digest,
      );

      if (!needDownload) {
        debugPrint('文件已存在且哈希匹配，跳过下载');
        progressText.value = '正在处理';
        await _processReleaseUpdate(filePath, tempPath);
        isUpdating.value = false;
        return;
      }

      progressText.value = '正在下载';

      // 使用 HyperDownloadController 下载文件
      if (Get.isRegistered<HyperDownloadController>()) {
        Get.delete<HyperDownloadController>();
      }
      final hyperDownloadController = Get.put(HyperDownloadController());

      await hyperDownloadController.downloadFile(
        url: downloadUrl,
        savePath: filePath,
        threadCount: Platform.numberOfProcessors,
        showDialog: false,
        onProgress: (DownloadProgressInfo info) {
          // 更新进度文本，显示百分比
          progressText.value = '${(info.progress * 100).toStringAsFixed(1)}%';
        },
        onComplete: () async {
          progressText.value = '正在处理';
          await _processReleaseUpdate(filePath, tempPath);
          isUpdating.value = false;
        },
        onFailed: (String reason) {
          showErrorSnackbar('下载失败', reason);
          isUpdating.value = false;
        },
      );
    } catch (e) {
      debugPrint('下载 Release 失败: $e');
      showErrorSnackbar('下载失败', e.toString());
      isUpdating.value = false;
    }
  }

  /// 检查 Release 文件哈希是否匹配
  /// 返回 true 表示需要下载，false 表示文件已存在且哈希匹配
  Future<bool> _checkReleaseFileHash(
    String filePath,
    String? expectedHash,
  ) async {
    if (expectedHash == null || isEmpty(expectedHash)) {
      // 如果没有哈希值信息，则需要下载
      return true;
    }

    if (!await File(filePath).exists()) {
      return true;
    }

    try {
      List<String> hashCommand;
      if (isWindows) {
        hashCommand = ['certutil', '-hashfile', filePath, 'SHA256'];
      } else if (isMacOS) {
        hashCommand = ['shasum', '-a', '256', filePath];
      } else {
        // 其他平台，需要下载
        return true;
      }

      final result = await Process.run(hashCommand[0], hashCommand.sublist(1));
      final hashStr = result.stdout.toString();
      final actualHash = _extractHash(hashStr, hashCommand[0]);
      final cleanExpectedHash = expectedHash.replaceAll('sha256:', '').trim();

      debugPrint('文件哈希: $actualHash');
      debugPrint('预期哈希: $cleanExpectedHash');

      if (actualHash == cleanExpectedHash) {
        debugPrint('Release 文件已存在且哈希一致，跳过下载');
        return false;
      }
    } catch (e) {
      debugPrint('Release 文件哈希检查失败: $e');
    }

    return true;
  }

  /// 从 Release 中选择对应平台的 Asset
  ReleaseAsset? _selectReleaseAsset(GitHubRelease release) {
    if (release.assets.isEmpty) {
      return null;
    }

    List<ReleaseAsset> assets = release.assets;
    assets.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (isWindows) {
      for (var asset in assets) {
        if (asset.name.toLowerCase().contains('windows') &&
            (asset.name.endsWith('.exe') || asset.name.endsWith('.zip'))) {
          return asset;
        }
      }
    } else if (isMacOS) {
      for (var asset in assets) {
        if (asset.name.toLowerCase().contains('macos') &&
            (asset.name.endsWith('.dmg') || asset.name.endsWith('.zip'))) {
          return asset;
        }
      }
    } else if (isAndroid) {
      for (var asset in assets) {
        if (asset.name.toLowerCase().endsWith('.apk')) {
          return asset;
        }
      }
    }

    return null;
  }

  /// 选择对应平台的 Release Asset 下载链接
  String? _selectReleaseAssetUrl(GitHubRelease release) {
    final asset = _selectReleaseAsset(release);
    return asset?.browserDownloadUrl;
  }

  /// 处理 Release 更新
  Future<void> _processReleaseUpdate(String filePath, String tempPath) async {
    try {
      showSuccessSnackbar('下载完成，准备更新', null);

      if (isWindows) {
        await _performWindowsExtractAndUpdate(tempPath, filePath);
      } else if (isMacOS) {
        await _performMacosExtractAndUpdate(tempPath, filePath);
      } else if (isAndroid) {
        await _extractAndInstallApk(tempPath, filePath, isRelease: true);
      } else {
        showWarningSnackbar('当前平台暂不支持自动更新', null);
      }
    } catch (e) {
      debugPrint('处理 Release 更新失败: $e');
      showErrorSnackbar('更新处理失败', e.toString());
    }
  }
}
