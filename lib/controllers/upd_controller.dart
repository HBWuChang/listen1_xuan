import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide CircularProgressIndicator;
import 'package:get/get.dart';
import 'package:install_plugin/install_plugin.dart';
import 'package:listen1_xuan/controllers/controllers.dart';
import 'package:listen1_xuan/widgets/ext/ext_widget.dart';
import 'package:listen1_xuan/widgets/motor_progress_indicator_xuan.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:system_info3/system_info3.dart';

import '../funcs.dart';
import '../global_settings_animations.dart';
import '../services/ffmpeg_config.dart';
import '../settings.dart';
import '../models/GitHubRelease.dart';
import '../models/ReleaseAsset.dart';
import '../widgets/progress_indicator_xuan.dart';
import '../widgets/draggable_toast/draggable_toast.dart';
import 'DioController.dart';
import 'hyper_download_controller.dart';
import 'routeController.dart';

import 'settings_controller.dart';

class UpdController extends GetxController {
  static const String buildGitHash = String.fromEnvironment('gitHash');
  static const bool cronetHttpNoPlay = bool.fromEnvironment('cronetHttpNoPlay');
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
    final s = Get.find<SettingsController>();
    return await s.getString('githubOauthAccessKey');
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

  /// 文件名是否匹配 FFmpeg 变体。
  ///
  /// 命名约定：带 FFmpeg 的产物在 hash 前带 `-ffmpeg`（如
  /// `app-release-ffmpeg-<hash>.apk`），精简版不带（如
  /// `app-release-<hash>.apk`）。
  /// [enabled] 为 null 时使用当前构建的变体。
  bool _matchesFfmpegVariant(String name, {bool? enabled}) {
    return (enabled ?? isFfmpegEnabled) == name.contains('ffmpeg');
  }

  /// 查找匹配平台和 FFmpeg 变体的 artifact（精确匹配 name）。
  dynamic _findArtifactByPlatform(List<dynamic> artifacts, String platform) {
    for (var artifact in artifacts) {
      if (artifact['name'].toString() == platform) {
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
      final art = _findArtifactByPlatform(
        artifacts,
        isFfmpegEnabled
            ? 'windows-build-artifact-ffmpeg'
            : 'windows-build-artifact',
      );
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

    // 按当前构建的 FFmpeg 变体过滤 artifact
    filteredArt = filteredArt
        .where((i) => _matchesFfmpegVariant(i['name'].toString()))
        .toList();

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
      final art = _findArtifactByPlatform(
        artifacts,
        isFfmpegEnabled ? 'macos-app-artifact-ffmpeg' : 'macos-app-artifact',
      );
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
        // 先解压 canary.zip，取出内部的实际 zip 文件（如 listen1_xuan-2.5.3+45-macos-260c32f.zip）
        final actualFilePath = await _extractInnerMacosZip(tempPath, filePath);
        await _performMacosExtractAndUpdate(tempPath, actualFilePath);
      } else {
        showErrorSnackbar('安装包文件不存在', null);
      }
    } catch (e) {
      _closeProgressDialog();
      showErrorSnackbar('下载失败', e.toString());
    }
  }

  /// 从 artifact 的 canary.zip 中解压出实际的 macos zip 文件，
  /// 删除原 canary.zip，并将内部文件重命名为 canary.zip
  Future<String> _extractInnerMacosZip(String tempPath, String filePath) async {
    final bytes = File(filePath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    String? innerZipPath;
    for (final file in archive) {
      if (file.isFile) {
        final filename = file.name;
        final data = file.content as List<int>;
        final extractPath = p.join(tempPath, filename);
        File(extractPath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);

        // 匹配类似 listen1_xuan-2.5.3+45-macos-260c32f.zip 的文件
        if (filename.endsWith('.zip')) {
          innerZipPath = extractPath;
        }
      }
    }

    if (innerZipPath == null) {
      // 没有找到内部 zip，直接返回原文件路径
      debugPrint('未找到内部 zip 文件，直接使用原 canary.zip');
      return filePath;
    }

    // 删除原 canary.zip
    await File(filePath).delete();
    debugPrint('已删除原 canary.zip');

    // 将内部 zip 重命名为 canary.zip
    final newFilePath = p.join(tempPath, 'canary.zip');
    await File(innerZipPath).rename(newFilePath);
    debugPrint('已将 ${p.basename(innerZipPath)} 重命名为 canary.zip');

    return newFilePath;
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

            if (filename.endsWith('.zip') && filename.contains('macos')) {
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
            12.sbh,
            Text('注意：', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              '1. 如果macOS阻止脚本运行，请前往 系统设置 -> 隐私与安全性 中手动允许运行更新脚本和新版本应用。',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            4.sbh,
            Text(
              '2. 若更新脚本没有自动运行，请前往 下载/Listen1/ 文件夹手动运行 update_macos.command。',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            4.sbh,
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
  Future<void> delReleasesCache(
    List<GitHubRelease> releases,
    String latestBuildNumber,
  ) async {
    try {
      final tempPath = (await xuanGetdownloadDirectory()).path;
      int deletedCount = 0;
      late List<File> toDelFiles;
      if (isWindows) {
        toDelFiles = await Directory(tempPath)
            .list()
            .where(
              (entity) =>
                  entity is File &&
                  p
                      .basenameWithoutExtension(entity.path)
                      .contains('windows-build-artifact') &&
                  !p
                      .basenameWithoutExtension(entity.path)
                      .contains(latestBuildNumber),
            )
            .cast<File>()
            .toList();
      } else if (isMacOS) {
        toDelFiles = await Directory(tempPath)
            .list()
            .where(
              (entity) =>
                  entity is File &&
                  p.basenameWithoutExtension(entity.path).contains('macos') &&
                  !p
                      .basenameWithoutExtension(entity.path)
                      .contains(latestBuildNumber),
            )
            .cast<File>()
            .toList();
      } else if (isAndroid) {
        toDelFiles = await Directory(tempPath)
            .list()
            .where(
              (entity) =>
                  entity is File &&
                  p.basename(entity.path).contains('.apk') &&
                  !p
                      .basenameWithoutExtension(entity.path)
                      .contains(latestBuildNumber),
            )
            .cast<File>()
            .toList();
      } else {
        toDelFiles = [];
      }
      for (var file in toDelFiles) {
        try {
          await file.delete();
          deletedCount++;
        } catch (e) {
          logger.e('删除 Release 缓存文件 ${file.path} 失败: $e');
        }
      }
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
      List<GitHubRelease> releases = await Github.getReleasesList();
      if (releases.isEmpty) {
        showDebugSnackbar('未能获取 Releases 列表', null);
        return;
      }
      // releases.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      final latestRelease = Get.find<SettingsController>().getPreRelease
          ? releases.first
          : releases.firstWhere(
              (release) => !release.prerelease,
              orElse: () => releases.first,
            );

      final rLatestRelease = releases.first;
      final rLatestBuild = _selectReleaseAsset(rLatestRelease);
      final rLatestBuildNumber = rLatestBuild == null
          ? null
          : p.basenameWithoutExtension(rLatestBuild.name).split('-').last;
      final latestBuild = _selectReleaseAsset(latestRelease);

      if (latestBuild == null) {
        showDebugSnackbar('未能获取最新版本的安装包信息', null);
        return;
      }
      final latestBuildNumber = p
          .basenameWithoutExtension(latestBuild.name)
          .split('-')
          .last;

      showDebugSnackbar(
        '本地版本 buildNumber: $localBuildNumber, 最新版本 buildNumber: $latestBuildNumber',
        null,
      );
      // 删除除最新版本外的其他缓存文件
      if (releases.length > 1) {
        final oldReleases = releases.sublist(1);
        await delReleasesCache(oldReleases, latestBuildNumber);
      }

      if (localBuildNumber != latestBuildNumber &&
          !kDebugMode &&
          localBuildNumber != rLatestBuildNumber) {
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
    Widget _buildProgressIcon({bool isPeekIcon = false}) {
      return Obx(() {
        if (!isUpdating.value) {
          return Icon(
            Icons.system_update_rounded,
            color: isPeekIcon ? Get.theme.colorScheme.onPrimary : null,
          );
        }

        // 从 progressText 中提取百分比Ï
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              MotorCircularProgressIndicator(
                strokeWidth: 2,
                value: progress > 0 ? progress : null,
                color: Get.theme.colorScheme.onPrimary,
              ),
            ],
          ).sbs(16),
        );
      });
    }

    draggableToastManager.show(
      inLockMode: true,
      icon: _buildProgressIcon(isPeekIcon: true),
      config: DraggableToastConfig(
        areaPadding: EdgeInsets.fromLTRB(16, 100, 16, 80),
        snapThreshold: 60,
        expandedWidth: 300,
        collapsedSize: 46,
        snapEdges: {ToastSnapEdge.left, ToastSnapEdge.right},
      ),
      onDismiss: () {},
      builder: (context, state, controller) {
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
                  ],
                ),
                trailing: IconButton(
                  onPressed: controller.peek,
                  icon: Icon(Icons.minimize_rounded),
                ),
              ),
              FittedBox(
                child: Text(
                  '构建hash:${p.basenameWithoutExtension(latestBuild.name).split('-').last}',
                  maxLines: 1,
                  style: Get.theme.textTheme.bodySmall,
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
                              Future.delayed(Duration(milliseconds: 2000), () {
                                controller.peek();
                              });
                              isUpdating.value = true;
                              progressText.value = '准备下载';
                              await _downloadAndUpdateRelease(
                                latestBuild,
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
    ReleaseAsset latestBuild,
    RxBool isUpdating,
    RxString progressText,
  ) async {
    try {
      progressText.value = '获取链接';

      // 根据平台选择下载链接和对应的 asset
      String downloadUrl = latestBuild.browserDownloadUrl;

      final tempPath = (await xuanGetdownloadDirectory()).path;
      final fileName = downloadUrl.split('/').last;
      final filePath = p.join(tempPath, fileName);

      // 检查本地是否已有相同的文件且哈希匹配
      progressText.value = '检查本地';
      final needDownload = await _checkReleaseFileHash(
        filePath,
        latestBuild.digest,
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
    // 先按当前构建的 FFmpeg 变体过滤（带 FFmpeg 的产物名含 `ffmpeg`）
    assets = assets
        .where((asset) => _matchesFfmpegVariant(asset.name))
        .toList();
    if (assets.isEmpty) {
      return null;
    }
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
      List<ReleaseAsset> apkAssets = assets
          .where((asset) => asset.name.toLowerCase().endsWith('.apk'))
          .toList();
      if (apkAssets.isNotEmpty) {
        switch (SysInfo.kernelArchitecture.name) {
          case "ARM64":
            apkAssets = apkAssets
                .where((i) => i.name.toString().contains("arm64"))
                .toList();
            break;
          case "ARM":
            apkAssets = apkAssets
                .where((i) => i.name.toString().contains("armeabi"))
                .toList();
            break;
          case "X86_64":
            apkAssets = apkAssets
                .where((i) => i.name.toString().contains("x86_64"))
                .toList();
            break;
          default:
            apkAssets = apkAssets;
        }
        apkAssets.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        // GitHub release 上传时会把文件名中的空格替换为 `.`，
        // 因此这里用点号匹配 "without.embedded.Cronet"。
        if (cronetHttpNoPlay) {
          apkAssets.removeWhere(
            (asset) => asset.name.contains("without.embedded.Cronet"),
          );
        } else {
          apkAssets.removeWhere(
            (asset) => !asset.name.contains("without.embedded.Cronet"),
          );
        }
        return apkAssets.isNotEmpty ? apkAssets.first : null;
      }
    }

    return null;
  }

  /// ===================== FFmpeg 变体切换 =====================

  /// 目标（相反）FFmpeg 变体：当前带 FFmpeg 则切换到精简版，反之亦然。
  bool get _targetFfmpegEnabled => !isFfmpegEnabled;

  /// 当前平台是否支持 FFmpeg 变体切换（iOS 无自装能力）。
  bool get canSwitchFfmpegVariant => isAndroid || isWindows || isMacOS;

  String _variantDisplayName(bool ffmpegEnabled) =>
      ffmpegEnabled ? '有 FFmpeg 版' : '无 FFmpeg 版';

  /// 从资产名提取构建 hash（资产名以 `-<hash>` 结尾）。
  String _assetHash(String name) =>
      p.basenameWithoutExtension(name).split('-').last;

  /// 按平台与目标变体筛选可安装的 Release 资产。
  List<ReleaseAsset> _filterSwitchAssets(
    List<ReleaseAsset> assets, {
    required bool ffmpegEnabled,
    String? hash,
  }) {
    var list = assets
        .where(
          (asset) => _matchesFfmpegVariant(asset.name, enabled: ffmpegEnabled),
        )
        .where((asset) => hash == null || _assetHash(asset.name) == hash)
        .toList();

    if (isWindows) {
      list = list
          .where(
            (asset) =>
                asset.name.toLowerCase().contains('windows') &&
                asset.name.toLowerCase().endsWith('.zip'),
          )
          .toList();
    } else if (isMacOS) {
      list = list
          .where(
            (asset) =>
                asset.name.toLowerCase().contains('macos') &&
                asset.name.toLowerCase().endsWith('.zip'),
          )
          .toList();
    } else if (isAndroid) {
      list = list
          .where((asset) => asset.name.toLowerCase().endsWith('.apk'))
          .toList();
      switch (SysInfo.kernelArchitecture.name) {
        case "ARM64":
          list = list.where((asset) => asset.name.contains('arm64')).toList();
          break;
        case "ARM":
          list = list.where((asset) => asset.name.contains('armeabi')).toList();
          break;
        case "X86_64":
          list = list.where((asset) => asset.name.contains('x86_64')).toList();
          break;
      }
      // GitHub release 上传时会把文件名中的空格替换为 `.`，
      // 因此这里用点号匹配 "without.embedded.Cronet"。
      if (cronetHttpNoPlay) {
        list.removeWhere(
          (asset) => asset.name.contains("without.embedded.Cronet"),
        );
      } else {
        list.removeWhere(
          (asset) => !asset.name.contains("without.embedded.Cronet"),
        );
      }
    } else {
      return [];
    }

    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// 查找与当前构建 hash 完全相同、目标 FFmpeg 变体的资产。
  ///
  /// 仅当同一 Release 同时存在当前变体与目标变体时才算命中，
  /// 避免把仅有单变体命名的旧 Release 误判为精简版。
  ReleaseAsset? _findExactVariantAsset(List<GitHubRelease> releases) {
    for (final release in releases) {
      final current = _filterSwitchAssets(
        release.assets,
        ffmpegEnabled: isFfmpegEnabled,
        hash: buildGitHash,
      );
      if (current.isEmpty) continue;
      final target = _filterSwitchAssets(
        release.assets,
        ffmpegEnabled: _targetFfmpegEnabled,
        hash: buildGitHash,
      );
      if (target.isNotEmpty) return target.first;
    }
    return null;
  }

  /// 从指定 Release 中挑选目标变体的可安装资产。
  ReleaseAsset? _pickTargetVariantAsset(GitHubRelease release) {
    final list = _filterSwitchAssets(
      release.assets,
      ffmpegEnabled: _targetFfmpegEnabled,
    );
    return list.isEmpty ? null : list.first;
  }

  /// 切换到相反的 FFmpeg 变体：优先同 hash 精确匹配，
  /// 未命中时弹窗让用户选择从最新正式版或 PreRelease 下载。
  Future<void> switchFfmpegVariant() async {
    if (!canSwitchFfmpegVariant) {
      showWarningSnackbar('当前平台不支持切换 FFmpeg 变体', null);
      return;
    }
    if (isEmpty(buildGitHash)) {
      showWarningSnackbar('开发构建不支持切换', '当前构建未包含 gitHash');
      return;
    }
    try {
      final releases = await Github.getReleasesList();
      if (releases.isEmpty) {
        showDebugSnackbar('未能获取 Releases 列表', null);
        return;
      }
      final targetAsset = _findExactVariantAsset(releases);
      if (targetAsset != null) {
        await _confirmAndSwitchVariant(targetAsset);
        return;
      }
      await _showVariantFallbackDialog(releases);
    } catch (e) {
      showErrorSnackbar('切换 FFmpeg 变体失败', e.toString());
    }
  }

  /// 切换时的平台特定提示。
  String? _switchPlatformTip() {
    if (isWindows) {
      return '更新时应用会被关闭，由脚本完成替换并重启。';
    } else if (isMacOS) {
      return '若脚本被拦截，请在 系统设置 → 隐私与安全性 中手动允许。';
    } else if (isAndroid) {
      return '安装时请允许来自本应用的未知来源安装。';
    }
    return null;
  }

  /// 拼装切换确认信息（目标变体、hash、大小及平台提示）。
  String _switchVariantMessage(ReleaseAsset asset) {
    final targetName = _variantDisplayName(_targetFfmpegEnabled);
    final sizeMb = (asset.size / 1024 / 1024).toStringAsFixed(2);
    final buffer = StringBuffer()
      ..writeln('目标版本：$targetName')
      ..writeln('Build hash：${_assetHash(asset.name)}')
      ..writeln('文件大小：$sizeMb MB')
      ..writeln()
      ..writeln('切换后用户数据保留，安装将由系统确认。');
    final tip = _switchPlatformTip();
    if (tip != null) buffer.writeln(tip);
    return buffer.toString().trimRight();
  }

  /// 确认后下载并安装目标变体。
  Future<void> _confirmAndSwitchVariant(ReleaseAsset asset) async {
    final targetName = _variantDisplayName(_targetFfmpegEnabled);
    final confirmed = await showConfirmDialog(
      _switchVariantMessage(asset),
      '切换到$targetName',
      confirmText: '下载并安装',
      cancelText: '取消',
    );
    if (confirmed != true) return;
    await _downloadVariantWithProgress(asset, targetName);
  }

  /// 展示可拖动下载进度 Toast 并执行下载安装。
  Future<void> _downloadVariantWithProgress(
    ReleaseAsset asset,
    String targetName,
  ) async {
    final isUpdating = true.obs;
    final progressText = '准备下载'.obs;

    final toastController = draggableToastManager.show(
      inLockMode: true,
      icon: Icon(
        Icons.system_update_alt_rounded,
        color: Get.theme.colorScheme.onPrimary,
      ),
      config: DraggableToastConfig(
        areaPadding: EdgeInsets.fromLTRB(16, 100, 16, 80),
        snapThreshold: 60,
        expandedWidth: 300,
        collapsedSize: 46,
        snapEdges: {ToastSnapEdge.left, ToastSnapEdge.right},
      ),
      onDismiss: () {},
      builder: (context, state, controller) {
        return Padding(
          padding: EdgeInsets.all(8),
          child: Row(
            children: [
              Obx(() {
                final text = progressText.value;
                double progress = 0.0;
                if (text.contains('%')) {
                  progress =
                      (double.tryParse(text.replaceAll('%', '')) ?? 0) / 100.0;
                }
                return MotorCircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress > 0 ? progress : null,
                  color: Get.theme.colorScheme.primary,
                );
              }).sbs(16),
              12.sbw,
              Expanded(
                child: Obx(
                  () => Text(
                    '切换到$targetName：${progressText.value}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Get.theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      await _downloadAndUpdateRelease(asset, isUpdating, progressText);
    } finally {
      toastController.exitLockedMode();
      toastController.hide();
    }
  }

  /// hash 未命中时的回退弹窗：从最新正式版或最新 PreRelease 下载目标变体。
  Future<void> _showVariantFallbackDialog(List<GitHubRelease> releases) async {
    final targetName = _variantDisplayName(_targetFfmpegEnabled);

    GitHubRelease? stableRelease;
    for (final release in releases) {
      if (!release.prerelease) {
        stableRelease = release;
        break;
      }
    }
    final stable = stableRelease;
    final latestRelease = releases.first;

    final currentBuildNumber =
        int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;

    ListTile buildOption({
      required String title,
      required GitHubRelease release,
      required ReleaseAsset? asset,
    }) {
      final targetBuildNumber =
          int.tryParse(release.tagName.split('+').last) ?? 0;
      final isDowngrade =
          currentBuildNumber > 0 &&
          targetBuildNumber > 0 &&
          targetBuildNumber < currentBuildNumber;
      final enabled = asset != null && !isDowngrade;

      String subtitle;
      if (asset == null) {
        subtitle = '该渠道未找到$targetName安装包';
      } else {
        final sizeMb = (asset.size / 1024 / 1024).toStringAsFixed(2);
        subtitle =
            '版本：${release.tagName}\n'
            'Build hash：${_assetHash(asset.name)}\n'
            '文件大小：$sizeMb MB';
        if (isDowngrade) {
          subtitle += '\n目标版本低于当前版本（$currentBuildNumber），已禁用';
        }
      }

      return ListTile(
        enabled: enabled,
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: enabled ? () => Get.back(result: asset) : null,
      );
    }

    final selected = await Get.dialog<ReleaseAsset>(
      AlertDialog(
        title: const Text('未找到相同 Build hash 的另一变体'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前构建（hash：$buildGitHash）没有可直接切换的$targetName，'
                '请选择从最新渠道下载：',
              ),
              const SizedBox(height: 8),
              if (stable != null)
                buildOption(
                  title: '最新正式版',
                  release: stable,
                  asset: _pickTargetVariantAsset(stable),
                ),
              if (stable == null || latestRelease.id != stable.id)
                buildOption(
                  title: '最新 PreRelease',
                  release: latestRelease,
                  asset: _pickTargetVariantAsset(latestRelease),
                ),
              if (_switchPlatformTip() != null) ...[
                const SizedBox(height: 8),
                Text(
                  _switchPlatformTip()!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Get.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
        ],
      ),
    );

    if (selected == null) return;
    await _downloadVariantWithProgress(selected, targetName);
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

  /// 处理 Release 更新
  Future<void> processFileUpdate(List<String> filePaths) async {
    try {
      if (filePaths.isEmpty) return;
      if (filePaths.length == 1 && isWindows) {
        String filePath = filePaths.first;
        final basename = p.basename(filePath);
        if (basename.endsWith('.zip') &&
            basename.startsWith('windows-build-artifact')) {
          showInfoSnackbar('正在安装更新...', null);
          final downDir = (await xuanGetdownloadDirectory()).path;
          // 移动文件到下载目录
          final newFilePath = p.join(downDir, 'canary.zip');
          if (filePath != newFilePath) {
            await File(filePath).copy(newFilePath);
            File(filePath).delete().catchError((e) {
              showDebugSnackbar('删除原文件失败', '请手动删除 $filePath');
            });
            filePath = newFilePath;
          }
          await _performWindowsExtractAndUpdate(downDir, filePath);
          return;
        }
      }
      Get.find<PasteController>().onFilesPasted(filePaths);
    } catch (e) {
      debugPrint('处理文件更新失败: $e');
      showErrorSnackbar('处理文件更新失败', e.toString());
    }
  }
}
