import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../controllers/DownloadController.dart';
import '../controllers/play_controller.dart';
import '../controllers/cache_controller.dart';
import '../controllers/websocket_client_controller.dart';

class DownloadPage extends StatelessWidget {
  const DownloadPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final DownloadController downloadController =
        Get.find<DownloadController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('下载管理'),
        actions: [
          Obx(
            () => IconButton(
              onPressed: downloadController.isLoading.value
                  ? null
                  : () => _fetchServerCacheList(downloadController),
              icon: downloadController.isLoading.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_download),
              tooltip: '获取服务器已缓存的当前播放列表',
            ),
          ),
        ],
      ),
      body: Obx(
        () => SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ExpansionPanelList(
            expansionCallback: (int index, bool isExpanded) {
              downloadController.togglePanelExpansion(index);
            },
            children: [
              _buildExpansionPanel(
                context,
                downloadController,
                title: '下载中 (${downloadController.downloadingList.length})',
                items: downloadController.downloadingList,
                isExpanded: downloadController.panelExpanded[0],
                index: 0,
                showProgress: true,
              ),
              _buildExpansionPanel(
                context,
                downloadController,
                title: '待下载 (${downloadController.toDownloadList.length})',
                items: downloadController.toDownloadList,
                isExpanded: downloadController.panelExpanded[1],
                index: 1,
              ),

              _buildExpansionPanel(
                context,
                downloadController,
                title: '已完成 (${downloadController.downloadedList.length})',
                items: downloadController.downloadedList,
                isExpanded: downloadController.panelExpanded[2],
                index: 2,
              ),
              _buildExpansionPanel(
                context,
                downloadController,
                title: '下载失败 (${downloadController.failedList.length})',
                items: downloadController.failedList,
                isExpanded: downloadController.panelExpanded[3],
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 获取服务器已缓存的当前播放列表
  Future<void> _fetchServerCacheList(
    DownloadController downloadController,
  ) async {
    downloadController.isLoading.value = true;

    try {
      // 构建请求 URI
      final webSocketClientController = Get.find<WebSocketClientController>();
      final serverAddress = webSocketClientController.serverAddress;

      final uri = Uri(
        scheme: 'http',
        host: serverAddress.split(':')[0],
        port: int.parse(serverAddress.split(':')[1]),
        path: '/allCacheList',
      );

      // 发送 GET 请求
      final dio = Dio();
      final response = await dio.get(uri.toString());

      if (response.statusCode == 200) {
        final Map<String, dynamic> serverCacheData =
            response.data as Map<String, dynamic>;
        final Map<String, String> serverCacheMap = serverCacheData
            .cast<String, String>();

        // 获取当前播放列表的 ID
        final playController = Get.find<PlayController>();
        final playingIds = playController.playingIds;

        // 筛选出在当前播放列表中的缓存项
        final Map<String, String> filteredCacheMap = {};
        serverCacheMap.forEach((id, fileName) {
          if (playingIds.contains(id)) {
            filteredCacheMap[id] = fileName;
          }
        });

        if (filteredCacheMap.isNotEmpty) {
          // 获取本地缓存列表
          final cacheController = Get.find<CacheController>();
          final localCacheMap = await cacheController.localCacheList();
          // 调用 addToDownloadList 方法
          downloadController.addToDownloadList(
            filteredCacheMap,
            localFiles: localCacheMap,
          );

          // 显示成功消息
          Get.snackbar(
            '成功',
            '已添加 ${filteredCacheMap.length} 个文件到下载列表',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        } else {
          Get.snackbar(
            '提示',
            '当前播放列表中没有服务器缓存的文件',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      } else {
        throw Exception('服务器响应错误: ${response.statusCode}');
      }
    } catch (e) {
      Get.snackbar(
        '错误',
        '获取服务器缓存列表失败: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      downloadController.isLoading.value = false;
    }
  }

  /// 构建 ExpansionPanel
  ExpansionPanel _buildExpansionPanel(
    BuildContext context,
    DownloadController downloadController, {
    required String title,
    required RxMap<String, String> items,
    required bool isExpanded,
    required int index,
    bool showProgress = false,
  }) {
    return ExpansionPanel(
      canTapOnHeader: true,
      headerBuilder: (BuildContext context, bool isExpanded) {
        return ListTile(
          title: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      },
      body: items.isEmpty
          ? const Padding(padding: EdgeInsets.all(16.0), child: Text('暂无数据'))
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, itemIndex) {
                final entry = items.entries.elementAt(itemIndex);
                return _buildListItem(
                  context,
                  downloadController,
                  key: entry.key,
                  title: entry.value,
                  showProgress: showProgress,
                );
              },
            ),
      isExpanded: isExpanded,
    );
  }

  /// 构建单个列表项
  Widget _buildListItem(
    BuildContext context,
    DownloadController downloadController, {
    required String key,
    required String title,
    bool showProgress = false,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            if (showProgress) ...[
              const SizedBox(height: 8.0),
              Obx(() {
                final progress = downloadController.downloadProcess[key];
                if (progress != null &&
                    progress is List &&
                    progress.length >= 2) {
                  final received = progress[0] as int;
                  final total = progress[1] as int;
                  final percentage = total > 0 ? received / total : 0.0;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(
                        value: percentage,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(percentage * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '${_formatBytes(received)} / ${_formatBytes(total)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  );
                } else {
                  return const LinearProgressIndicator();
                }
              }),
            ],
          ],
        ),
      ),
    );
  }

  /// 格式化字节数显示
  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
    }
  }
}
