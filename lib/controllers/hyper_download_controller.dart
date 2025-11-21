import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hyper_thread_downloader/hyper_thread_downloader.dart';

class HyperDownloadController extends GetxController {
  final isDownloading = false.obs;
  final downloadProgress = 0.0.obs;
  final downloadSpeed = 0.0.obs;
  final remainTime = 0.0.obs;
  final currentCount = 0.obs;
  final totalCount = 0.obs;
  int _currentTaskId = -1;
  late HyperDownload _hyperDownload;

  @override
  void onInit() {
    super.onInit();
    _hyperDownload = HyperDownload();
  }

  /// 开始下载文件
  /// [url] 下载链接
  /// [savePath] 保存路径
  /// [threadCount] 线程数
  /// [onComplete] 下载完成回调
  /// [onFailed] 下载失败回调
  Future<void> downloadFile({
    required String url,
    required String savePath,
    required BuildContext context,
    int threadCount = 8,
    VoidCallback? onComplete,
    Function(String)? onFailed,
  }) async {
    try {
      // 重置下载状态
      _resetDownloadState();
      if (File(savePath).existsSync()) {
        await File(savePath).delete();
      }
      isDownloading.value = true;

      // 显示不可关闭的下载进度对话框
      _showDownloadDialog();

      // 首先尝试使用代理地址下载
      final proxyUrl = url.replaceAll(
        'https://',
        'https://h3.040905.xyz/default/https/',
      );
      debugPrint('Attempting download with proxy URL: $proxyUrl');

      bool proxyDownloadSuccess = false;
      try {
        await _hyperDownload.startDownload(
          url: proxyUrl,
          savePath: savePath,
          threadCount: threadCount,
          downloadProgress:
              ({
                required double progress,
                required double speed,
                required double remainTime,
                required int count,
                required int total,
              }) {
                downloadProgress.value = progress;
                downloadSpeed.value = speed;
                this.remainTime.value = remainTime;
                currentCount.value = count;
                totalCount.value = total;
              },
          downloadComplete: () {
            debugPrint('Download completed');
            proxyDownloadSuccess = true;
            isDownloading.value = false;
            _closeDownloadDialog();
            onComplete?.call();
          },
          downloadFailed: (String reason) {
            debugPrint('Proxy download failed: $reason');
            proxyDownloadSuccess = false;
          },
          downloadTaskId: (int id) {
            debugPrint('Download task id: $id');
            _currentTaskId = id;
          },
          prepareWorking: (bool ret) {
            debugPrint('Prepare working: $ret');
          },
          downloadingLog: (String log) {
            debugPrint('Downloading log: $log');
          },
          workingMerge: (bool ret) {
            debugPrint('Working merge: $ret');
          },
        );
      } catch (e) {
        debugPrint('Proxy download error: $e');
        proxyDownloadSuccess = false;
      }

      // 如果代理下载失败，尝试普通下载
      if (!proxyDownloadSuccess && isDownloading.value) {
        debugPrint('Proxy download failed, attempting regular download: $url');
        try {
          await _hyperDownload.startDownload(
            url: url,
            savePath: savePath,
            threadCount: threadCount,
            downloadProgress:
                ({
                  required double progress,
                  required double speed,
                  required double remainTime,
                  required int count,
                  required int total,
                }) {
                  downloadProgress.value = progress;
                  downloadSpeed.value = speed;
                  this.remainTime.value = remainTime;
                  currentCount.value = count;
                  totalCount.value = total;
                },
            downloadComplete: () {
              debugPrint('Download completed');
              isDownloading.value = false;
              _closeDownloadDialog();
              onComplete?.call();
            },
            downloadFailed: (String reason) {
              debugPrint('Regular download failed: $reason');
              isDownloading.value = false;
              _closeDownloadDialog();
              onFailed?.call('代理和普通下载均失败: $reason');
            },
            downloadTaskId: (int id) {
              debugPrint('Download task id: $id');
              _currentTaskId = id;
            },
            prepareWorking: (bool ret) {
              debugPrint('Prepare working: $ret');
            },
            downloadingLog: (String log) {
              debugPrint('Downloading log: $log');
            },
            workingMerge: (bool ret) {
              debugPrint('Working merge: $ret');
            },
          );
        } catch (e) {
          debugPrint('Regular download error: $e');
          isDownloading.value = false;
          _closeDownloadDialog();
          onFailed?.call('下载失败: $e');
        }
      }
    } catch (e) {
      debugPrint('Download error: $e');
      isDownloading.value = false;
      _closeDownloadDialog();
      onFailed?.call(e.toString());
    }
  }

  /// 显示不可关闭的下载进度对话框
  void _showDownloadDialog() {
    Get.dialog(
      barrierDismissible: false,
      AlertDialog(
        title: const Text('文件下载中'),
        content: Obx(
          () => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: downloadProgress.value),
                const SizedBox(height: 16),
                Text(
                  '进度: ${(downloadProgress.value * 100).toStringAsFixed(2)}%',
                ),
                const SizedBox(height: 8),
                Text('速度: ${_formatSpeed(downloadSpeed.value)}'),
                const SizedBox(height: 8),
                Text('剩余时间: ${_formatTime(remainTime.value)}'),
                const SizedBox(height: 8),
                Text('已下载: ${currentCount.value} / ${totalCount.value}'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await cancelDownload();
            },
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 关闭下载对话框
  void _closeDownloadDialog() {
    try {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
    } catch (e) {
      debugPrint('Close download dialog error: $e');
    }
  }

  /// 格式化速度显示
  String _formatSpeed(double speed) {
    if (speed < 1024) {
      return '${speed.toStringAsFixed(2)} B/s';
    } else if (speed < 1024 * 1024) {
      return '${(speed / 1024).toStringAsFixed(2)} KB/s';
    } else {
      return '${(speed / 1024 / 1024).toStringAsFixed(2)} MB/s';
    }
  }

  /// 格式化时间显示
  String _formatTime(double seconds) {
    if (seconds < 0) {
      return '计算中...';
    }
    final int hours = seconds.toInt() ~/ 3600;
    final int minutes = (seconds.toInt() % 3600) ~/ 60;
    final int secs = seconds.toInt() % 60;

    if (hours > 0) {
      return '$hours小时$minutes分$secs秒';
    } else if (minutes > 0) {
      return '$minutes分$secs秒';
    } else {
      return '${secs}秒';
    }
  }

  /// 取消下载任务
  Future<void> cancelDownload() async {
    if (_currentTaskId != -1) {
      debugPrint('Cancelling download task: $_currentTaskId');
      try {
        // 取消下载任务
        _hyperDownload.stopDownload(id: _currentTaskId);
      } catch (e) {
        debugPrint('Stop download error: $e');
      }
    }
    isDownloading.value = false;
    _closeDownloadDialog();
    _currentTaskId = -1;
  }

  /// 重置下载状态
  void _resetDownloadState() {
    downloadProgress.value = 0.0;
    downloadSpeed.value = 0.0;
    remainTime.value = 0.0;
    currentCount.value = 0;
    totalCount.value = 0;
    _currentTaskId = -1;
  }

  @override
  void onClose() {
    isDownloading.value = false;
    super.onClose();
  }
}
