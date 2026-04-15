import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/controllers.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:media_kit/media_kit.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../controllers/settings_controller.dart';
import '../models/Equalizer/AEqualizer.dart';
import '../models/Equalizer/EqSetting.dart';
import '../models/Equalizer/Equalizer.dart';
import '../models/Equalizer/a.dart' as eq_a;
import '../models/Equalizer/r.dart' as eq_r;
import '../models/Equalizer/t.dart';
import '../settings.dart';

class AndroidEqualizerPage extends StatefulWidget {
  const AndroidEqualizerPage({super.key});

  @override
  State<AndroidEqualizerPage> createState() => _AndroidEqualizerPageState();
}

class _IndexedBand {
  final int index;
  final Equalizer band;

  const _IndexedBand(this.index, this.band);
}

const double _bandCardHeight = 712;

class _AndroidEqualizerPageState extends State<AndroidEqualizerPage> {
  final SettingsController _settingsController = Get.find<SettingsController>();
  late EqSetting _draftEqSetting;
  final PlayController _playController = Get.find<PlayController>();

  @override
  void initState() {
    super.initState();
    _draftEqSetting = _cloneEqSetting(_settingsController.eqSettingRx.value);
  }

  EqSetting _cloneEqSetting(EqSetting source) {
    return EqSetting.fromJson(
      jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>,
    );
  }

  List<Equalizer> _cloneBands(List<Equalizer> source) {
    return source
        .map(
          (e) => Equalizer.fromJson(
            jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  void _commitEqSetting(EqSetting next) {
    _settingsController.eqSetting = next;
    _settingsController.eqSettingRx.value = next;
  }

  void _updateEqSetting(void Function(EqSetting next) updater) {
    final next = _cloneEqSetting(_draftEqSetting);
    updater(next);
    setState(() {
      _draftEqSetting = next;
    });
  }

  Future<void> _applyDraftEqSetting() async {
    _commitEqSetting(_cloneEqSetting(_draftEqSetting));
    try {
      await _playController.setEq();
      showSuccessSnackbar('应用成功', '均衡器设置已应用');
    } catch (e) {
      showErrorSnackbar('应用失败', '应用均衡器设置失败');
    }
  }

  void _updateCurrentPreset(void Function(AEqualizer preset) updater) {
    _updateEqSetting((next) {
      final selectedKey = next.nowSelected;
      if (selectedKey == null) return;
      final preset = next.equalizers[selectedKey];
      if (preset == null) return;
      updater(preset);
    });
  }

  void _updateBandByActualIndex(
    int actualIndex,
    Equalizer Function(Equalizer old) updater,
  ) {
    _updateCurrentPreset((preset) {
      if (actualIndex < 0 || actualIndex >= preset.equalizers.length) return;
      preset.equalizers[actualIndex] = updater(preset.equalizers[actualIndex]);
    });
  }

  Future<String?> _showNameDialog({
    required String title,
    String initialValue = '',
    String hintText = '请输入名称',
  }) async {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hintText),
          onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<double?> _showDoubleDialog({
    required String title,
    required double current,
    String hintText = '',
  }) async {
    final controller = TextEditingController(text: current.toString());
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: hintText),
          onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (text == null || text.trim().isEmpty) return null;
    return double.tryParse(text.trim());
  }

  Future<int?> _showIntDialog({
    required String title,
    required int current,
    String hintText = '',
  }) async {
    final controller = TextEditingController(text: current.toString());
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          decoration: InputDecoration(hintText: hintText),
          onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (text == null || text.trim().isEmpty) return null;
    return int.tryParse(text.trim());
  }

  Future<void> _addBandWithHzInput() async {
    final hz = await _showIntDialog(
      title: '添加频段 (Hz)',
      current: 1000,
      hintText: '请输入正整数 Hz',
    );
    if (hz == null || hz <= 0) return;

    _updateEqSetting((next) {
      final selected = next.nowSelected;
      if (selected == null) return;
      final preset = next.equalizers[selected];
      if (preset == null) return;
      preset.equalizers.add(Equalizer(f: hz));
    });
  }

  Future<void> _createPresetFromSource(List<Equalizer> sourceBands) async {
    final name = await _showNameDialog(title: '新建预设');
    if (name == null || name.isEmpty) return;

    _updateEqSetting((next) {
      if (next.equalizers.containsKey(name)) return;
      next.equalizers[name] = AEqualizer(equalizers: _cloneBands(sourceBands));
      next.nowSelected = name;
    });
  }

  Future<void> _renamePreset(String oldName) async {
    final newName = await _showNameDialog(
      title: '重命名预设',
      initialValue: oldName,
    );
    if (newName == null || newName.isEmpty || newName == oldName) return;

    _updateEqSetting((next) {
      if (!next.equalizers.containsKey(oldName) ||
          next.equalizers.containsKey(newName)) {
        return;
      }
      final preset = next.equalizers.remove(oldName);
      if (preset == null) return;
      next.equalizers[newName] = preset;
      if (next.nowSelected == oldName) {
        next.nowSelected = newName;
      }
    });
  }

  Future<void> _copyPreset(String sourceName) async {
    final copyName = await _showNameDialog(
      title: '复制预设',
      initialValue: '${sourceName}_copy',
      hintText: '请输入新名称',
    );
    if (copyName == null || copyName.isEmpty) return;

    _updateEqSetting((next) {
      if (next.equalizers.containsKey(copyName)) return;
      final source = next.equalizers[sourceName];
      if (source == null) return;
      next.equalizers[copyName] = AEqualizer(
        equalizers: _cloneBands(source.equalizers),
      );
      next.nowSelected = copyName;
    });
  }

  Future<void> _deletePreset(String name) async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除预设'),
            content: Text('确定删除预设 "$name" 吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;

    _updateEqSetting((next) {
      next.equalizers.remove(name);
      if (next.equalizers.isEmpty) {
        next.equalizers['flat'] = AEqualizer(equalizers: [Equalizer(f: 1000)]);
      }
      if (next.nowSelected == name) {
        next.nowSelected = null;
      }
    });
  }

  Future<void> _showPresetActions(String name) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('重命名'),
              onTap: () async {
                Navigator.pop(context);
                await _renamePreset(name);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制'),
              onTap: () async {
                Navigator.pop(context);
                await _copyPreset(name);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                '删除',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _deletePreset(name);
              },
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  List<_IndexedBand> _sortedBands(AEqualizer preset) {
    final indexed = preset.equalizers
        .asMap()
        .entries
        .map((e) => _IndexedBand(e.key, e.value))
        .toList();
    indexed.sort((a, b) => a.band.f.compareTo(b.band.f));
    return indexed;
  }

  Widget _buildPresetWrap(EqSetting eqSetting) {
    final keys = eqSetting.equalizers.keys.toList();
    final selected = eqSetting.nowSelected;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: keys.map((name) {
        final isSelected = selected == name;
        return GestureDetector(
          onLongPress: () => _showPresetActions(name),
          child: ChoiceChip(
            label: Text(name),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) {
              _updateEqSetting((next) {
                if (next.nowSelected == name) {
                  next.nowSelected = null;
                } else {
                  next.nowSelected = name;
                }
              });
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAConfig(dynamic intOrDouble, String label, {bool? isMod2}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
      width: 48,
      decoration: BoxDecoration(
        color: isMod2 != true
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainer.withAlpha(128),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              intOrDouble is int
                  ? '$intOrDouble'
                  : (intOrDouble as double?)?.toStringAsFixed(2) ?? '-',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSelectConfig<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool? isMod2,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
      decoration: BoxDecoration(
        color: isMod2 != true
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainer.withAlpha(128),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 30,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: value,
                  isDense: true,
                  iconSize: 16,
                  onChanged: onChanged,
                  items: items,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBandColumn(_IndexedBand item, {bool isMod2 = false}) {
    final band = item.band;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 48,
      height: _bandCardHeight,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isMod2 != true
            ? colorScheme.surfaceContainer.withAlpha(128)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final value = await _showIntDialog(
                title: '设置 f (Hz)',
                current: band.f,
                hintText: '请输入正整数',
              );
              if (value == null || value <= 0) return;
              _updateBandByActualIndex(
                item.index,
                (old) => old.copyWith(f: value),
              );
            },
            child: _buildAConfig(
              band.f,
              'f (Hz)',
              isMod2: !isMod2 ? false : true,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: RotatedBox(
              quarterTurns: 3,
              child: Slider(
                padding: const EdgeInsets.all(0),
                activeColor: colorScheme.secondaryContainer,
                inactiveColor: colorScheme.surfaceContainer,
                value: band.g.clamp(-12.0, 12.0),
                min: -12,
                max: 12,
                onChanged: (v) {
                  _updateBandByActualIndex(
                    item.index,
                    (old) => old.copyWith(g: v),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final value = await _showDoubleDialog(
                title: '设置 g (dB)',
                current: band.g,
              );
              if (value == null) return;
              _updateBandByActualIndex(
                item.index,
                (old) => old.copyWith(g: value),
              );
            },
            child: _buildAConfig(
              band.g,
              'g (dB)',
              isMod2: isMod2 ? false : true,
            ),
          ),
          const SizedBox(height: 8),
          _buildCompactSelectConfig<WidthType>(
            label: 't',
            value: band.t,
            isMod2: isMod2,
            items: WidthType.values
                .map(
                  (type) => DropdownMenuItem<WidthType>(
                    value: type,
                    child: Text(type.value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              _updateBandByActualIndex(
                item.index,
                (old) => old.copyWith(t: value),
              );
            },
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final value = await _showDoubleDialog(
                title: '设置 w (width)',
                current: band.w,
              );
              if (value == null || value <= 0) return;
              _updateBandByActualIndex(
                item.index,
                (old) => old.copyWith(w: value),
              );
            },
            child: _buildAConfig(
              band.w,
              'w (width)',
              isMod2: isMod2 ? false : true,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final current = band.m ?? 1.0;
              final value = await _showDoubleDialog(
                title: '设置 m (mix)',
                current: current,
                hintText: '输入 0~1',
              );
              if (value == null) return;
              _updateBandByActualIndex(
                item.index,
                (old) => old.copyWith(m: value.clamp(0.0, 1.0).toDouble()),
              );
            },
            child: _buildAConfig(
              band.m,
              'm (mix)',
              isMod2: !isMod2 ? false : true,
            ),
          ),
          const SizedBox(height: 8),
          _buildCompactSelectConfig<eq_a.Transform?>(
            label: 'a',
            value: band.a,
            isMod2: isMod2 ? false : true,

            items: <DropdownMenuItem<eq_a.Transform?>>[
              const DropdownMenuItem<eq_a.Transform?>(
                value: null,
                child: Text('-'),
              ),
              ...eq_a.Transform.values.map(
                (type) => DropdownMenuItem<eq_a.Transform?>(
                  value: type,
                  child: Text(type.value),
                ),
              ),
            ],
            onChanged: (value) {
              _updateBandByActualIndex(item.index, (old) {
                old.a = value;
                return old;
              });
            },
          ),
          const SizedBox(height: 8),
          _buildCompactSelectConfig<eq_r.Precision?>(
            label: 'r',
            value: band.r,
            isMod2: !isMod2 ? false : true,

            items: <DropdownMenuItem<eq_r.Precision?>>[
              const DropdownMenuItem<eq_r.Precision?>(
                value: null,
                child: Text('-'),
              ),
              ...eq_r.Precision.values.map(
                (type) => DropdownMenuItem<eq_r.Precision?>(
                  value: type,
                  child: Text(type.value),
                ),
              ),
            ],
            onChanged: (value) {
              _updateBandByActualIndex(item.index, (old) {
                old.r = value;
                return old;
              });
            },
          ),
          const SizedBox(height: 8),
          IconButton.filledTonal(
            onPressed: () {
              _updateCurrentPreset((preset) {
                if (preset.equalizers.length <= 1) return;
                preset.equalizers.removeAt(item.index);
              });
            },
            icon: const Icon(Icons.delete_outline),
            color: colorScheme.error,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('均衡器设置'),
        actions: [
          IconButton(
            onPressed: () {
              showConfirmDialog(
                '重置均衡器',
                '确定要重置均衡器设置吗？',
                confirmLevel: ConfirmLevel.danger,
              ).then((confirmed) {
                if (confirmed) {
                  setState(() {
                    _draftEqSetting = EqSetting();
                  });
                  _applyDraftEqSetting();
                }
              });
            },
            icon: const Icon(Icons.restart_alt_rounded),
          ),
          IconButton(
            onPressed: () {
              g_launchURL(
                Uri.parse('https://ffmpeg.org/ffmpeg-filters.html#equalizer'),
              );
            },
            icon: const Icon(Icons.help_outline_rounded),
          ),
          IconButton(
            onPressed: _applyDraftEqSetting,
            icon: const Icon(Icons.check),
          ),
        ],
      ),

      body: Builder(
        builder: (context) {
          final eqSetting = _draftEqSetting;

          return SuperListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              Text(
                '当前设置',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              Card(
                margin: const EdgeInsets.only(top: 8),
                child: Obx(() => Text(_playController.nowEq.value)),
              ),
              const SizedBox(height: 10),
              Text(
                '预设',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              _buildPresetWrap(eqSetting),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () {
                  final selected = eqSetting.nowSelected;
                  final source = selected == null
                      ? null
                      : eqSetting.equalizers[selected];
                  final bands = source?.equalizers ?? [Equalizer(f: 1000)];
                  _createPresetFromSource(bands);
                },
                icon: const Icon(Icons.library_add_outlined),
                label: const Text('新建预设'),
              ),
              if (eqSetting.nowSelected != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '当前预设参数',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addBandWithHzInput,
                      icon: const Icon(Icons.add),
                      label: const Text('添加频段'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final selected = eqSetting.nowSelected;
                    if (selected == null) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('未选中预设。点击上方预设即可进入编辑，点击已选中预设可取消选中。'),
                      );
                    }

                    final preset = eqSetting.equalizers[selected];
                    if (preset == null) {
                      return const Text('当前选中预设不存在');
                    }
                    final sorted = _sortedBands(preset);
                    return SizedBox(
                      height: _bandCardHeight,
                      child: SuperListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final item = sorted[index];
                          return _buildBandColumn(item, isMod2: index % 2 == 0);
                        },
                        itemCount: sorted.length,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  '命令预览',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    eqSetting.toFilterStringOfNowSelected() ?? '未选中预设',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
