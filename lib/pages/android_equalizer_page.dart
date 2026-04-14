import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/settings_controller.dart';
import '../models/Equalizer/AEqualizer.dart';
import '../models/Equalizer/EqSetting.dart';
import '../models/Equalizer/Equalizer.dart';
import '../models/Equalizer/a.dart' as eq_a;
import '../models/Equalizer/r.dart' as eq_r;
import '../models/Equalizer/t.dart';

class AndroidEqualizerPage extends StatefulWidget {
  const AndroidEqualizerPage({super.key});

  @override
  State<AndroidEqualizerPage> createState() => _AndroidEqualizerPageState();
}

class _AndroidEqualizerPageState extends State<AndroidEqualizerPage> {
  final SettingsController _settingsController = Get.find<SettingsController>();

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
    final next = _cloneEqSetting(_settingsController.eqSettingRx.value);
    updater(next);
    _commitEqSetting(next);
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

  void _updateBand(int index, Equalizer Function(Equalizer old) updater) {
    _updateCurrentPreset((preset) {
      if (index < 0 || index >= preset.equalizers.length) return;
      preset.equalizers[index] = updater(preset.equalizers[index]);
    });
  }

  Future<void> _showCreatePresetDialog(List<Equalizer> sourceBands) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建预设'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '请输入预设名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    _updateEqSetting((next) {
      if (next.equalizers.containsKey(name)) {
        return;
      }
      next.equalizers[name] = AEqualizer(equalizers: _cloneBands(sourceBands));
      next.nowSelected = name;
    });
  }

  Future<void> _showRenamePresetDialog(String oldName) async {
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名预设'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '请输入新名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
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
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldDelete) return;

    _updateEqSetting((next) {
      if (next.equalizers.length <= 1) return;
      next.equalizers.remove(name);
      if (next.nowSelected == name) {
        next.nowSelected = next.equalizers.keys.first;
      }
    });
  }

  Widget _buildNumberField({
    required String label,
    required String value,
    required String hint,
    required ValueChanged<String> onSubmitted,
  }) {
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onFieldSubmitted: onSubmitted,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('均衡器设置'),
      ),
      body: Obx(() {
        final eqSetting = _settingsController.eqSettingRx.value;
        final keys = eqSetting.equalizers.keys.toList();
        if (keys.isEmpty) {
          return const Center(child: Text('暂无可用预设'));
        }

        final selectedKey = eqSetting.nowSelected ?? keys.first;
        final selectedPreset = eqSetting.equalizers[selectedKey];
        if (selectedPreset == null) {
          return const Center(child: Text('当前预设不存在'));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '预设管理',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedKey,
                    decoration: const InputDecoration(
                      labelText: '当前预设',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: keys
                        .map(
                          (key) => DropdownMenuItem<String>(
                            value: key,
                            child: Text(key),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      _updateEqSetting((next) {
                        next.nowSelected = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '新建预设',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _showCreatePresetDialog(selectedPreset.equalizers),
                ),
                IconButton(
                  tooltip: '重命名预设',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showRenamePresetDialog(selectedKey),
                ),
                IconButton(
                  tooltip: '删除预设',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: keys.length <= 1
                      ? null
                      : () => _deletePreset(selectedKey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              eqSetting.toFilterStringOfNowSelected() ?? '',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  '频段参数',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    _updateCurrentPreset((preset) {
                      preset.equalizers.add(Equalizer(f: 1000));
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('添加频段'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(selectedPreset.equalizers.length, (index) {
              final band = selectedPreset.equalizers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '频段 #${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: selectedPreset.equalizers.length <= 1
                                ? null
                                : () {
                                    _updateCurrentPreset((preset) {
                                      preset.equalizers.removeAt(index);
                                    });
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildNumberField(
                        label: 'f (Hz)',
                        value: band.f.toString(),
                        hint: '中心频率',
                        onSubmitted: (text) {
                          final value = int.tryParse(text);
                          if (value == null || value <= 0) return;
                          _updateBand(index, (old) => old.copyWith(f: value));
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<WidthType>(
                        value: band.t,
                        decoration: const InputDecoration(
                          labelText: 't (width_type)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: WidthType.values
                            .map(
                              (type) => DropdownMenuItem<WidthType>(
                                value: type,
                                child: Text('${type.value}  ${type.description}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          _updateBand(index, (old) => old.copyWith(t: value));
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildNumberField(
                        label: 'w (width)',
                        value: band.w.toString(),
                        hint: '带宽值',
                        onSubmitted: (text) {
                          final value = double.tryParse(text);
                          if (value == null || value <= 0) return;
                          _updateBand(index, (old) => old.copyWith(w: value));
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildNumberField(
                        label: 'g (dB)',
                        value: band.g.toString(),
                        hint: '增益/衰减，单位 dB',
                        onSubmitted: (text) {
                          final value = double.tryParse(text);
                          if (value == null) return;
                          _updateBand(index, (old) => old.copyWith(g: value));
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('启用 m (mix 0~1)'),
                        value: band.m != null,
                        onChanged: (enabled) {
                          _updateBand(
                            index,
                            (old) => old.copyWith(m: enabled ? (old.m ?? 1.0) : null),
                          );
                        },
                      ),
                      if (band.m != null)
                        _buildNumberField(
                          label: 'm (mix)',
                          value: band.m!.toString(),
                          hint: '0 到 1',
                          onSubmitted: (text) {
                            final value = double.tryParse(text);
                            if (value == null) return;
                            final clampedValue = value.clamp(0.0, 1.0).toDouble();
                            _updateBand(
                              index,
                              (old) => old.copyWith(m: clampedValue),
                            );
                          },
                        ),
                      if (band.m != null) const SizedBox(height: 8),
                      DropdownButtonFormField<eq_a.Transform?>(
                        value: band.a,
                        decoration: const InputDecoration(
                          labelText: 'a (transform)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: <DropdownMenuItem<eq_a.Transform?>>[
                          const DropdownMenuItem<eq_a.Transform?>(
                            value: null,
                            child: Text('不设置'),
                          ),
                          ...eq_a.Transform.values.map(
                            (type) => DropdownMenuItem<eq_a.Transform?>(
                              value: type,
                              child: Text(type.value),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          _updateBand(index, (old) => old.copyWith(a: value));
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<eq_r.Precision?>(
                        value: band.r,
                        decoration: const InputDecoration(
                          labelText: 'r (precision)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: <DropdownMenuItem<eq_r.Precision?>>[
                          const DropdownMenuItem<eq_r.Precision?>(
                            value: null,
                            child: Text('不设置'),
                          ),
                          ...eq_r.Precision.values.map(
                            (type) => DropdownMenuItem<eq_r.Precision?>(
                              value: type,
                              child: Text('${type.value}  ${type.description}'),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          _updateBand(index, (old) => old.copyWith(r: value));
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      }),
    );
  }
}
