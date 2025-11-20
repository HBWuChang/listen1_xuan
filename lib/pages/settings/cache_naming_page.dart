import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/settings_controller.dart';
import 'package:listen1_xuan/controllers/cache_controller.dart';
import 'package:listen1_xuan/funcs.dart';

class CacheNamingPage extends StatelessWidget {
  const CacheNamingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsController>();

    return Scaffold(
      appBar: AppBar(title: const Text('缓存命名方式'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 命名方法 - ReorderableListView
            _buildNamedMethodSection(settingsController),
            const SizedBox(height: 24),

            // 命名连接符
            _buildConnectionSymbolSection(settingsController),
            const SizedBox(height: 16),

            // 字段为空替换符
            _buildEmptyReplacementSection(settingsController),
            const SizedBox(height: 16),

            // 不可用字符替换符
            _buildUnusableReplacementSection(settingsController),
            const SizedBox(height: 16),

            // 防止重名方式
            _buildDedupMethodSection(settingsController),
          ],
        ),
      ),
    );
  }

  /// 构建命名方法部分
  Widget _buildNamedMethodSection(SettingsController settingsController) {
    final cacheNamedMethod = settingsController.cacheNamedMethod.obs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('命名方法', style: Get.textTheme.titleLarge),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Obx(
            () => ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
                final item = cacheNamedMethod.removeAt(oldIndex);
                cacheNamedMethod.insert(newIndex, item);
                settingsController.cacheNamedMethod = List<int>.from(
                  cacheNamedMethod,
                );
              },
              itemCount: cacheNamedMethod.length,
              itemBuilder: (context, index) {
                final methodIndex = cacheNamedMethod[index];
                final method = NamedMethod.values[methodIndex];

                return ListTile(
                  key: ValueKey(index),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: Icon(Icons.drag_handle),
                  ),
                  title: Text(method.name),
                  trailing: IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () {
                      cacheNamedMethod.removeAt(index);
                      settingsController.cacheNamedMethod = List<int>.from(
                        cacheNamedMethod,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('添加更多字段', style: Get.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...NamedMethod.values.map((method) {
              return ElevatedButton(
                onPressed: () {
                  cacheNamedMethod.add(method.index);
                  settingsController.cacheNamedMethod = List<int>.from(
                    cacheNamedMethod,
                  );
                },
                child: Text('+ ${method.name}'),
              );
            }),
          ],
        ),
      ],
    );
  }

  /// 构建命名连接符部分
  Widget _buildConnectionSymbolSection(SettingsController settingsController) {
    return ListTile(
      title: const Text('命名连接符'),
      subtitle: Obx(
        () => Text(
          '当前: "${settingsController.cacheNamedConnection}"',
          style: TextStyle(fontSize: 12),
        ),
      ),
      trailing: Icon(Icons.edit),
      onTap: () async {
        await showInputDialog(
          title: '命名连接符',
          message: '用于连接不同的命名字段',
          initialValue: settingsController.cacheNamedConnection,
          onConfirm: (value) async {
            settingsController.cacheNamedConnection = value;
            return true;
          },
        );
      },
    );
  }

  /// 构建字段为空替换符部分
  Widget _buildEmptyReplacementSection(SettingsController settingsController) {
    return ListTile(
      title: const Text('字段为空替换符'),
      subtitle: Obx(
        () => Text(
          '当前: "${settingsController.cacheIfEmptyRep}"',
          style: TextStyle(fontSize: 12),
        ),
      ),
      trailing: Icon(Icons.edit),
      onTap: () async {
        await showInputDialog(
          title: '字段为空替换符',
          message: '当某个命名字段为空时，用此字符替换',
          initialValue: settingsController.cacheIfEmptyRep,
          onConfirm: (value) async {
            settingsController.cacheIfEmptyRep = value;
            return true;
          },
        );
      },
    );
  }

  /// 构建不可用字符替换符部分
  Widget _buildUnusableReplacementSection(
    SettingsController settingsController,
  ) {
    return ListTile(
      title: const Text('不可用字符替换符'),
      subtitle: Obx(
        () => Text(
          '当前: "${settingsController.cacheUnUseableRep}"',
          style: TextStyle(fontSize: 12),
        ),
      ),
      trailing: Icon(Icons.edit),
      onTap: () async {
        await showInputDialog(
          title: '不可用字符替换符',
          message: '文件名中的不可用字符将被替换为此字符',
          initialValue: settingsController.cacheUnUseableRep,
          onConfirm: (value) async {
            settingsController.cacheUnUseableRep = value;
            return true;
          },
        );
      },
    );
  }

  /// 构建防止重名方式部分
  Widget _buildDedupMethodSection(SettingsController settingsController) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('防止重名方式', style: Get.textTheme.titleLarge),
        const SizedBox(height: 12),
        ...DedupMethod.values.map((method) {
          return Obx(
            () => RadioListTile<int>(
              title: Text(method.name),
              value: method.index,
              groupValue: settingsController.cacheDedupMethod,
              onChanged: (value) {
                if (value != null) {
                  settingsController.cacheDedupMethod = value;
                }
              },
            ),
          );
        }).toList(),
      ],
    );
  }
}
