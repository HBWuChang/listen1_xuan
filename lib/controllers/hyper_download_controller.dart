import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hyper_thread_downloader/hyper_thread_downloader.dart';

/// 下载进度信息
class DownloadProgressInfo {
  final double progress;
  final double speed;
  final double remainTime;
  final int currentCount;
  final int totalCount;

  DownloadProgressInfo({
    required this.progress,
    required this.speed,
    required this.remainTime,
    required this.currentCount,
    required this.totalCount,
  });
}

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
  /// [context] BuildContext，仅在 [showDialog] 为 true 时需要
  /// [threadCount] 线程数
  /// [showDialog] 是否显示下载进度对话框，默认为 true
  /// [onComplete] 下载完成回调
  /// [onFailed] 下载失败回调
  /// [onProgress] 下载进度回调，返回进度信息
  Future<void> downloadFile({
    required String url,
    required String savePath,
    BuildContext? context,
    int threadCount = 8,
    bool showDialog = true,
    VoidCallback? onComplete,
    Function(String)? onFailed,
    Function(DownloadProgressInfo)? onProgress,
  }) async {
    try {
      // 重置下载状态
      _resetDownloadState();
      if (File(savePath).existsSync()) {
        await File(savePath).delete();
      }
      isDownloading.value = true;

      // 如果需要显示对话框，则显示下载进度对话框
      if (showDialog && context != null) {
        _showDownloadDialog();
      }

      // 首先尝试使用代理地址下载
      final proxyUrl = url.replaceAll(
        'https://',
        'https://h3.040905.xyz/default/https/',
      );
      debugPrint('Attempting download with proxy URL: $proxyUrl');

      // 使用 Completer 等待下载完成或失败
      final completer = Completer<bool>();
      
      try {
        _hyperDownload.startDownload(
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
                // 调用进度回调
                onProgress?.call(
                  DownloadProgressInfo(
                    progress: progress,
                    speed: speed,
                    remainTime: remainTime,
                    currentCount: count,
                    totalCount: total,
                  ),
                );
              },
          downloadComplete: () {
            debugPrint('Proxy download completed');
            isDownloading.value = false;
            _closeDownloadDialog();
            onComplete?.call();
            if (!completer.isCompleted) completer.complete(true);
          },
          downloadFailed: (String reason) {
            debugPrint('Proxy download failed: $reason');
            if (!completer.isCompleted) completer.complete(false);
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
        
        // 等待代理下载完成或失败
        final proxySuccess = await completer.future;
        
        // 如果代理下载成功，直接返回
        if (proxySuccess) {
          return;
        }
      } catch (e) {
        debugPrint('Proxy download error: $e');
        if (!completer.isCompleted) completer.complete(false);
      }

      // 如果代理下载失败，尝试普通下载
      if (isDownloading.value) {
        debugPrint('Proxy download failed, attempting regular download: $url');
        final regularCompleter = Completer<void>();
        
        try {
          _hyperDownload.startDownload(
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
                  // 调用进度回调
                  onProgress?.call(
                    DownloadProgressInfo(
                      progress: progress,
                      speed: speed,
                      remainTime: remainTime,
                      currentCount: count,
                      totalCount: total,
                    ),
                  );
                },
            downloadComplete: () {
              debugPrint('Regular download completed');
              isDownloading.value = false;
              _closeDownloadDialog();
              onComplete?.call();
              if (!regularCompleter.isCompleted) regularCompleter.complete();
            },
            downloadFailed: (String reason) {
              debugPrint('Regular download failed: $reason');
              isDownloading.value = false;
              _closeDownloadDialog();
              onFailed?.call('代理和普通下载均失败: $reason');
              if (!regularCompleter.isCompleted) regularCompleter.complete();
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
          
          // 等待普通下载完成
          await regularCompleter.future;
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
