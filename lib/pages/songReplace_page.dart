import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/play_controller.dart';
import 'package:listen1_xuan/models/SongReplaceSettings.dart';
import 'package:listen1_xuan/models/Track.dart';

/// 歌曲替换设置页面
class SongReplacePage extends StatefulWidget {
  const SongReplacePage({super.key});

  @override
  State<SongReplacePage> createState() => _SongReplacePageState();
}

class _SongReplacePageState extends State<SongReplacePage> {
  final PlayController _playController = Get.find<PlayController>();
  late SongReplaceSettings _settings;

  @override
  void initState() {
    super.initState();
    // 从 PlayController 获取设置数据
    _settings = _playController.songReplaceSettings.value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('歌曲替换设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            tooltip: '清理未使用的歌曲数据',
            onPressed: _cleanupUnusedTracks,
          ),
        ],
      ),
      body: Obx(() {
        // 监听 songReplaceSettings 变化
        final settings = _playController.songReplaceSettings.value;
        final mappings = settings.idMappings;

        if (mappings.isEmpty) {
          return const Center(
            child: Text(
              '暂无歌曲替换设置',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(8.0),
          itemCount: mappings.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final entry = mappings.entries.elementAt(index);
            final originalId = entry.key;
            final replacementId = entry.value;

            // 从 trackDetails 获取歌曲信息
            final originalTrack = settings.getTrackDetails(originalId);
            final replacementTrack = settings.getTrackDetails(replacementId);

            return _buildSongReplaceItem(
              originalId: originalId,
              originalTrack: originalTrack,
              replacementId: replacementId,
              replacementTrack: replacementTrack,
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: _addReplacement,
        tooltip: '添加替换',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 构建单个歌曲替换项
  Widget _buildSongReplaceItem({
    required String originalId,
    required Track? originalTrack,
    required String replacementId,
    required Track? replacementTrack,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // 左侧：源歌曲信息
            Expanded(
              child: _buildTrackInfo(
                track: originalTrack,
                trackId: originalId,
                label: '源歌曲',
              ),
            ),
            // 中间：分割和箭头
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_forward, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    '替换为',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            // 右侧：替换歌曲信息
            Expanded(
              child: _buildTrackInfo(
                track: replacementTrack,
                trackId: replacementId,
                label: '替换歌曲',
              ),
            ),
            // 操作按钮
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: '删除此替换',
              onPressed: () => _removeReplacement(originalId),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建歌曲信息展示
  Widget _buildTrackInfo({
    required Track? track,
    required String trackId,
    required String label,
  }) {
    if (track == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '未找到歌曲信息',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'ID: $trackId',
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          track.title ?? '未知歌名',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          track.artist ?? '未知歌手',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// 添加替换（占位方法）
  void _addReplacement() {
    // TODO: 实现添加替换功能
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('添加替换功能待实现')));
  }

  /// 删除替换
  void _removeReplacement(String originalId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除此歌曲替换设置吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // 创建新的设置对象并删除映射
              final newSettings = _playController.songReplaceSettings.value
                  .copyWith();
              newSettings.removeMapping(originalId);

              // 更新 PlayController
              _playController.songReplaceSettings.value = newSettings;

              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已删除替换设置')));
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 清理未使用的歌曲数据
  void _cleanupUnusedTracks() {
    final newSettings = _playController.songReplaceSettings.value.copyWith();
    final removedCount = newSettings.refreshTrackDetails();

    if (removedCount > 0) {
      _playController.songReplaceSettings.value = newSettings;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已清理 $removedCount 条未使用的歌曲数据')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有需要清理的数据')));
    }
  }
}
