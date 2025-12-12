import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/bodys.dart';
import 'package:listen1_xuan/controllers/play_controller.dart';
import 'package:listen1_xuan/controllers/settings_controller.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

import '../const.dart';
import '../controllers/myPlaylist_controller.dart';
import '../funcs.dart';
import '../settings.dart';

/// 歌曲替换设置页面
class SongReplacePage extends StatefulWidget {
  const SongReplacePage({super.key});

  @override
  State<SongReplacePage> createState() => _SongReplacePageState();
}

class _SongReplacePageState extends State<SongReplacePage> {
  final PlayController _playController = Get.find<PlayController>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('歌曲替换设置'),
        actions: [
          Card(
            child: Padding(
              padding: EdgeInsetsGeometry.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              child: Obx(
                () => Text(
                  '已使用歌曲数量:${_playController.songReplaceSettings.value.trackDetails.length}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: _showFabLocationSettings,
          ),
          IconButton(
            icon: const Icon(Icons.help_rounded),
            onPressed: () =>
                showInfoDialogFromMarkdown(HelpMarkdownFiles.songReplacePage),
          ),
        ],
      ),
      body: Column(
        children: [
          // 固定标题行
          _buildHeaderRow(),
          // 可滚动内容
          Expanded(
            child: CustomScrollView(
              slivers: [
                // 解释信息行（可滚动隐藏）
                SliverToBoxAdapter(child: _buildExplanationRow()),
                SliverToBoxAdapter(child: _buildAddArea()),
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: Obx(() {
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

                    return ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: mappings.length,

                      itemBuilder: (context, index) {
                        final entry = mappings.entries.elementAt(index);
                        final originalId = entry.key;
                        final replacementId = entry.value;

                        // 从 trackDetails 获取歌曲信息
                        final originalTrack = settings.getTrackDetails(
                          originalId,
                        );
                        final replacementTrack = settings.getTrackDetails(
                          replacementId,
                        );

                        return _buildSongReplaceItem(
                          originalId: originalId,
                          originalTrack: originalTrack,
                          replacementId: replacementId,
                          replacementTrack: replacementTrack,
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建固定标题行
  Widget _buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      decoration: BoxDecoration(color: Get.theme.cardColor),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '源歌曲',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Get.theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 60), // 中间箭头区域的宽度
          Expanded(
            child: Text(
              '替换歌曲',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Get.theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48), // 右侧按钮区域的宽度
        ],
      ),
    );
  }

  /// 构建解释信息行
  Widget _buildExplanationRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      decoration: BoxDecoration(color: Get.theme.cardColor.withOpacity(0.5)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '歌曲信息及歌词来源',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 60),
          Expanded(
            child: Text(
              '音频数据来源',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  /// 构建添加区域
  Widget _buildAddArea() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // 左侧：源歌曲选择
            Expanded(
              child: Obx(() {
                final sourceTrack =
                    _playController.songReplaceSourceTrack.value;
                final isEditing =
                    _playController.songReplaceAdding.value &&
                    _playController.isSongReplacingSource.value;
                Widget t = sourceTrack == null
                    ? _buildAddButtonContent(
                        label: '选择源歌曲',
                        isActive: isEditing,
                      )
                    : Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: _buildTrackInfo(
                          track: sourceTrack,
                          trackId: sourceTrack.id,
                          allowTap: false,
                        ),
                      );
                return InkWell(
                  onTap: _selectSourceTrack,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      border: isEditing
                          ? null
                          : Border.all(
                              color: Theme.of(
                                context,
                              ).disabledColor.withOpacity(0.3),
                              width: 2,
                            ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isEditing
                        ? DottedBorder(
                            options: RoundedRectDottedBorderOptions(
                              radius: Radius.circular(8),
                              color: Get.theme.colorScheme.primary,
                              strokeWidth: 2,
                              dashPattern: [6, 4],
                            ),
                            child: t,
                          )
                        : t,
                  ),
                );
              }),
            ),
            // 中间：分割和箭头
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: const Icon(Icons.arrow_forward, size: 24),
            ),
            // 右侧：替换歌曲选择
            Expanded(
              child: Obx(() {
                final targetTrack =
                    _playController.songReplaceTargetTrack.value;
                final isEditing =
                    _playController.songReplaceAdding.value &&
                    !_playController.isSongReplacingSource.value;
                Widget t = targetTrack == null
                    ? _buildAddButtonContent(
                        label: '选择替换歌曲',
                        isActive: isEditing,
                      )
                    : Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: _buildTrackInfo(
                          track: targetTrack,
                          trackId: targetTrack.id,
                          allowTap: false,
                        ),
                      );
                return InkWell(
                  onTap: _selectTargetTrack,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      border: isEditing
                          ? null
                          : Border.all(
                              color: Theme.of(
                                context,
                              ).disabledColor.withOpacity(0.3),
                              width: 2,
                            ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isEditing
                        ? DottedBorder(
                            options: RoundedRectDottedBorderOptions(
                              radius: Radius.circular(8),
                              color: Get.theme.colorScheme.primary,
                              strokeWidth: 2,
                              dashPattern: [6, 4],
                            ),
                            child: t,
                          )
                        : t,
                  ),
                );
              }),
            ),
            // 操作按钮
            Obx(() {
              bool canConfirm =
                  _playController.songReplaceSourceTrack.value != null &&
                  _playController.songReplaceTargetTrack.value != null &&
                  _playController.songReplaceSourceTrack.value!.id !=
                      _playController.songReplaceTargetTrack.value!.id;
              return IconButton(
                icon: Icon(
                  Icons.recycling_rounded,
                  color: canConfirm
                      ? Get.theme.colorScheme.secondary
                      : Get.theme.disabledColor,
                ),
                tooltip: '快捷替换',
                onPressed: canConfirm
                    ? () => repTrack(
                        _playController.songReplaceSourceTrack.value!,
                        _playController.songReplaceTargetTrack.value!.id,
                      )
                    : null,
              );
            }),
            Obx(() {
              bool canConfirm =
                  _playController.songReplaceSourceTrack.value != null &&
                  _playController.songReplaceTargetTrack.value != null &&
                  _playController.songReplaceSourceTrack.value!.id !=
                      _playController.songReplaceTargetTrack.value!.id;
              return IconButton(
                icon: Icon(
                  Icons.check,
                  color: canConfirm
                      ? Get.theme.colorScheme.primary
                      : Get.theme.disabledColor,
                ),
                tooltip: '确认添加',
                onPressed: canConfirm ? _confirmAddReplacement : null,
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 构建添加按钮内容
  Widget _buildAddButtonContent({
    required String label,
    bool isActive = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: Center(
        child: Icon(
          Icons.add,
          size: 32,
          color: isActive
              ? Get.theme.colorScheme.primary
              : Theme.of(context).disabledColor,
        ),
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
              child: _buildTrackInfo(track: originalTrack, trackId: originalId),
            ),
            // 中间：分割和箭头
            const Icon(Icons.arrow_forward, size: 24),

            // 右侧：替换歌曲信息
            Expanded(
              child: _buildTrackInfo(
                track: replacementTrack,
                trackId: replacementId,
              ),
            ),
            // 操作按钮
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: '删除此替换',
              onPressed: () => _removeReplacement(originalId),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: '编辑此替换',
              onPressed: () async {
                if (_playController.songReplaceSourceTrack.value != null ||
                    _playController.songReplaceTargetTrack.value != null) {
                  if (!(await showConfirmDialog(
                    '覆盖当前正在编辑的替换设置吗？',
                    '当前修改不会被保存',
                    confirmLevel: ConfirmLevel.warning,
                    confirmText: '覆盖',
                  ))) {
                    return;
                  }
                }
                // 预设选择的源和替换歌曲
                final settings = _playController.songReplaceSettings.value;
                final sourceTrack = settings.getTrackDetails(originalId);
                final targetTrack = settings.getTrackDetails(replacementId);
                _playController.songReplaceSourceTrack.value = sourceTrack;
                _playController.songReplaceTargetTrack.value = targetTrack;
              },
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
    bool allowTap = true,
  }) {
    if (track == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '未找到歌曲信息',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'ID: $trackId',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return InkWell(
      onTap: allowTap ? () => song_dialog(context, track) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            track.title ?? '未知歌名',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            track.artist ?? '未知歌手',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 选择源歌曲
  void _selectSourceTrack() {
    // 如果正在编辑源歌曲，取消编辑
    if (_playController.songReplaceAdding.value &&
        _playController.isSongReplacingSource.value) {
      _playController.songReplaceAdding.value = false;
      return;
    }

    // 开始编辑源歌曲
    _playController.isSongReplacingSource.value = true;
    _playController.songReplaceAdding.value = true;
    showInfoSnackbar('请“点击”选择源歌曲', '作为歌曲信息及歌词来源');
  }

  /// 选择替换歌曲
  void _selectTargetTrack() {
    // 如果正在编辑替换歌曲，取消编辑
    if (_playController.songReplaceAdding.value &&
        !_playController.isSongReplacingSource.value) {
      _playController.songReplaceAdding.value = false;
      return;
    }

    // 开始编辑替换歌曲
    _playController.isSongReplacingSource.value = false;
    _playController.songReplaceAdding.value = true;
    showInfoSnackbar('请“点击”选择替换歌曲', '作为音频数据来源');
  }

  /// 确认添加替换
  void _confirmAddReplacement() {
    final sourceTrack = _playController.songReplaceSourceTrack.value;
    final targetTrack = _playController.songReplaceTargetTrack.value;

    if (sourceTrack == null || targetTrack == null) {
      showInfoSnackbar('请先选择源歌曲和替换歌曲', null);
      return;
    }

    // 创建新的设置对象并添加映射
    final newSettings = _playController.songReplaceSettings.value.copyWith();
    newSettings.setMapping(sourceTrack.id, targetTrack.id, track: targetTrack);

    // 如果源歌曲信息也需要保存
    if (newSettings.getTrackDetails(sourceTrack.id) == null) {
      newSettings.trackDetails[sourceTrack.id] = sourceTrack;
    }

    // 更新 PlayController
    _playController.songReplaceSettings.value = newSettings;

    // 清空选择
    _playController.songReplaceSourceTrack.value = null;
    _playController.songReplaceTargetTrack.value = null;

    showSuccessSnackbar('已添加替换设置', null);
    _cleanupUnusedTracks();
    showTriStateConfirmDialog(
      title: '自动替换歌单中的歌曲？',
      message: '是否将所有歌单及正在播放列表中的“替换歌曲”都替换为“源歌曲”？\n\n（可在设置中修改此选项的默认值）',
      currentValue: Get.find<SettingsController>()
          .songReplaceAutoRepTragetTrackInAllPlaylist,
      onRemember: (value) {
        // 用户勾选"记住选择"时保存设置
        Get.find<SettingsController>()
                .songReplaceAutoRepTragetTrackInAllPlaylist =
            value;
      },
    ).then((value) async {
      if (value == true) {
        await repTrack(sourceTrack, targetTrack.id);
      }
    });
  }

  Future<void> repTrack(Track sourceTrack, String targetTrackId) async {
    try {
      _playController.replaceTrack(sourceTrack, targetTrackId);
      await Get.find<MyPlayListController>().replaceTrack(
        sourceTrack,
        targetTrackId,
      );
      showSuccessSnackbar('已替换所有歌单中的对应歌曲', null);
    } catch (e) {
      showErrorSnackbar('替换歌单中的歌曲时出错', e.toString());
      return;
    }
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
              showSuccessSnackbar('已删除替换设置', null);
              _cleanupUnusedTracks();
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
    }
  }

  /// 显示浮动按钮位置及大小设置
  void _showFabLocationSettings() {
    final settingsController = Get.find<SettingsController>();

    WoltModalSheet.show<void>(
      pageIndexNotifier: ValueNotifier(0),
      context: context,
      pageListBuilder: (modalSheetContext) {
        return [
          WoltModalSheetPage(
            hasTopBarLayer: false,
            child: _FabLocationSettingsContent(
              settingsController: settingsController,
            ),
          ),
        ];
      },
    );
  }
}

/// 浮动按钮位置及大小设置内容
class _FabLocationSettingsContent extends StatelessWidget {
  final SettingsController settingsController;

  const _FabLocationSettingsContent({required this.settingsController});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 位置选择
          Text('浮动按钮位置', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12.0),
          Obx(() {
            final currentLocation = settingsController.songReplaceFabLocation;
            return Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: SongReplaceFabLocation.values.map((location) {
                final isSelected = currentLocation == location;
                return FilterChip(
                  label: Text(location.desc),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      settingsController.songReplaceFabLocation = location;
                    }
                  },
                  backgroundColor: Colors.transparent,
                  selectedColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.2),
                  side: BorderSide(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                );
              }).toList(),
            );
          }),
          const SizedBox(height: 24.0),
          // 大小选择
          Text('浮动按钮大小', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12.0),
          Obx(() {
            final isMini = settingsController.songReplaceFabMini;
            return Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('标准')),
                      ButtonSegment(value: true, label: Text('迷你')),
                    ],
                    selected: {isMini},
                    onSelectionChanged: (selected) {
                      settingsController.songReplaceFabMini = selected.first;
                    },
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 24.0),
          Obx(
            () => TriStateSettingTile(
              title: '自动替换歌单中的歌曲',
              subtitle: '在添加新的歌曲替换后，自动将所有歌单及正在播放列表中的“替换歌曲”都替换为“源歌曲”',
              value:
                  settingsController.songReplaceAutoRepTragetTrackInAllPlaylist,
              onChanged: (value) {
                settingsController.songReplaceAutoRepTragetTrackInAllPlaylist =
                    value;
              },
            ),
          ),
        ],
      ),
    );
  }
}
