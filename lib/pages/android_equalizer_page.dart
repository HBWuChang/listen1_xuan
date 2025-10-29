import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/play_controller.dart';
import '../controllers/routeController.dart';
import '../controllers/settings_controller.dart';
import '../funcs.dart';
import '../global_settings_animations.dart';

class AndroidEqualizerPage extends StatelessWidget {
  const AndroidEqualizerPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final PlayController playController = Get.find<PlayController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('音效调节'),
        centerTitle: true,
        actions: playController.androidEQEnabled
            ? [
                // 保存方案按钮
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: () =>
                      _showSavePresetDialog(context, playController),
                  tooltip: '保存当前方案',
                ),
                // 重置按钮
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _showResetDialog(context, playController),
                  tooltip: '重置所有频段',
                ),
              ]
            : [],
      ),
      body: playController.androidEQEnabled
          ? Obx(() {
              // 检查是否初始化完成
              if (!playController.androidEQInited.value) {
                return globalLoadingAnime;
              }

              final bands = playController.bands;
              if (bands.isEmpty) {
                return const Center(child: Text('无可用的均衡器频段'));
              }

              return SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // 频段滑条列表
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildBandsVisualizer(playController, theme),
                    ),
                    const SizedBox(height: 20),
                    // 已保存的方案列表
                    _buildSavedPresets(playController, theme, context),
                    const SizedBox(height: 20),
                    // 关闭均衡器按钮
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final confirm = await showConfirmDialog(
                              '关闭均衡器',
                              '确定要关闭均衡器并重启应用吗？',
                              confirmLevel: ConfirmLevel.danger,
                            );
                            if (confirm != true) return;

                            // 禁用均衡器
                            Get.find<SettingsController>()
                                    .settings[PlayController
                                    .androidEQEnabledKey] =
                                false;

                            closeApp();
                          },
                          icon: const Icon(Icons.power_settings_new),
                          label: const Text('关闭均衡器并重启应用'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            })
          : Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  // 启用均衡器
                  Get.find<SettingsController>().settings[PlayController
                          .androidEQEnabledKey] =
                      true;
                  closeApp();
                },
                icon: const Icon(Icons.power_settings_new),
                label: const Text(
                  '启用均衡器并重启应用\n均衡器可能在某些设备上不起作用（如小米14A16）',
                  maxLines: 3,
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ),
    );
  }

  // 构建均衡器可视化界面
  Widget _buildBandsVisualizer(PlayController playController, ThemeData theme) {
    final bands = playController.bands;
    final sortedBands = bands.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: sortedBands.map((entry) {
        final bandIndex = entry.key;
        final band = entry.value;
        return Expanded(
          child: _buildBandSlider(playController, bandIndex, band, theme),
        );
      }).toList(),
    );
  }

  // 构建单个频段滑条
  Widget _buildBandSlider(
    PlayController playController,
    int bandIndex,
    AndroidEQBand band,
    ThemeData theme,
  ) {
    // 获取频段参数
    final minGain = playController.minGain;
    final maxGain = playController.maxGain;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 增益值显示
          Container(
            height: 40,
            alignment: Alignment.center,
            child: Obx(() {
              final currentGain = playController.bands[bandIndex]?.gain ?? 0.0;
              return Text(
                '${(currentGain).toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: currentGain == 0
                      ? theme.textTheme.bodyMedium?.color?.withOpacity(0.5)
                      : theme.primaryColor,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // 垂直滑条
          SizedBox(
            height: 200,
            child: Obx(() {
              final currentGain = playController.bands[bandIndex]?.gain ?? 0.0;
              return RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                  ),
                  child: Slider(
                    value: currentGain.clamp(minGain, maxGain),
                    min: minGain,
                    max: maxGain,
                    divisions: 100,
                    onChanged: (value) async {
                      playController.setBandGain(bandIndex, value);
                    },
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // 频率显示
          SizedBox(
            height: 50,
            child: Column(
              children: [
                Text(
                  _formatFrequency(band.centerFrequency),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hz',
                  style: TextStyle(
                    fontSize: 9,
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建已保存的方案列表
  Widget _buildSavedPresets(
    PlayController playController,
    ThemeData theme,
    BuildContext context,
  ) {
    final settingsController = Get.find<SettingsController>();
    final savedPresets =
        settingsController.settings['android_equalizer_saves'] as List? ?? [];

    if (savedPresets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '已保存的方案',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleMedium?.color,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor, width: 1),
              ),
              child: Center(
                child: Text(
                  '暂无保存的方案\n点击右上角保存按钮保存当前设置',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '已保存的方案',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleMedium?.color,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: savedPresets.length,
          itemBuilder: (context, index) {
            final preset = savedPresets[index] as Map<String, dynamic>;
            final name = preset['name'] as String;
            final gains = (preset['gains'] as List).cast<double>();

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor, width: 1),
                ),
                child: ListTile(
                  leading: Icon(Icons.equalizer, color: theme.primaryColor),
                  title: Text(name),
                  subtitle: Text(_generatePresetSummary(gains)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            _deletePreset(context, playController, index, name),
                        tooltip: '删除',
                      ),
                    ],
                  ),
                  onTap: () => _applyPreset(playController, gains, name),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // 生成方案摘要（显示增益情况）
  String _generatePresetSummary(List<double> gains) {
    if (gains.isEmpty) return '无数据';
    final avgGain = gains.reduce((a, b) => a + b) / gains.length;
    final maxGain = gains.reduce((a, b) => a > b ? a : b);

    if (avgGain.abs() < 0.1) {
      return '平衡音效';
    } else if (maxGain > 2 && gains.indexOf(maxGain) < gains.length ~/ 2) {
      return '低音增强';
    } else if (maxGain > 2 && gains.indexOf(maxGain) > gains.length ~/ 2) {
      return '高音增强';
    } else {
      return '自定义音效';
    }
  }

  // 显示保存方案对话框
  void _showSavePresetDialog(
    BuildContext context,
    PlayController playController,
  ) {
    final TextEditingController nameController = TextEditingController();
    final RxBool isSaving = false.obs;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存当前方案'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '方案名称',
            hintText: '例如：低音增强、人声突出等',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          Obx(() {
            if (isSaving.value) {
              // 保存中显示加载动画
              return TextButton(
                onPressed: null, // 禁用按钮
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor.withOpacity(0.6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('保存中...'),
                  ],
                ),
              );
            } else {
              // 正常状态
              return TextButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    showInfoSnackbar('提示', '请输入方案名称');
                    return;
                  }

                  // 开始保存
                  isSaving.value = true;

                  try {
                    await _saveCurrentPreset(playController, name);
                    Navigator.pop(context);
                  } catch (e) {
                    showInfoSnackbar('保存失败', e.toString());
                  } finally {
                    isSaving.value = false;
                  }
                },
                child: const Text('保存'),
              );
            }
          }),
        ],
      ),
    );
  }

  // 保存当前方案
  Future<void> _saveCurrentPreset(
    PlayController playController,
    String name,
  ) async {
    final bands = playController.bands;
    final sortedBands = bands.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final gains = sortedBands.map((e) => e.value.gain).toList();

    final settingsController = Get.find<SettingsController>();
    final savedPresets =
        (settingsController.settings['android_equalizer_saves'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    // 检查是否已存在同名方案
    final existingIndex = savedPresets.indexWhere(
      (preset) => preset['name'] == name,
    );

    if (existingIndex != -1) {
      // 更新现有方案
      savedPresets[existingIndex] = {
        'name': name,
        'gains': gains,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      showInfoSnackbar('已更新', '方案 "$name" 已更新');
    } else {
      // 添加新方案
      savedPresets.add({
        'name': name,
        'gains': gains,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      showInfoSnackbar('已保存', '方案 "$name" 已保存');
    }

    settingsController.settings['android_equalizer_saves'] = savedPresets;
    await settingsController.saveSettings();
  }

  // 删除方案
  Future<void> _deletePreset(
    BuildContext context,
    PlayController playController,
    int index,
    String name,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除方案'),
        content: Text('确定要删除方案 "$name" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final settingsController = Get.find<SettingsController>();
    final savedPresets =
        (settingsController.settings['android_equalizer_saves'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    savedPresets.removeAt(index);
    settingsController.settings['android_equalizer_saves'] = savedPresets;
    await settingsController.saveSettings();

    showInfoSnackbar('已删除', '方案 "$name" 已删除');
  }

  // 格式化频率显示
  String _formatFrequency(double? frequency) {
    if (frequency == null) return '0';
    if (frequency >= 1000) {
      return '${(frequency / 1000).toStringAsFixed(1)}k';
    }
    return frequency.toInt().toString();
  }

  // 应用预设方案
  Future<void> _applyPreset(
    PlayController playController,
    List<double> gains,
    String presetName,
  ) async {
    final bands = playController.bands;
    final sortedBands = bands.keys.toList()..sort();

    for (int i = 0; i < sortedBands.length && i < gains.length; i++) {
      final bandIndex = sortedBands[i];
      playController.setBandGain(bandIndex, gains[i]);
    }

    showInfoSnackbar('已应用方案', presetName);
  }

  // 显示重置确认对话框
  void _showResetDialog(BuildContext context, PlayController playController) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置均衡器'),
        content: const Text('确定要将所有频段重置为 0 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _resetAllBands(playController);
              showInfoSnackbar('已重置', '所有频段已恢复默认值');
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 重置所有频段
  Future<void> _resetAllBands(PlayController playController) async {
    final bands = playController.bands;
    for (final bandIndex in bands.keys) {
      playController.setBandGain(bandIndex, 0.0);
    }
  }
}
