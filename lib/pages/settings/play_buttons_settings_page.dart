import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/settings_controller.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/play.dart';

/// 播放按钮设置页面
class PlayButtonsSettingsPage extends StatelessWidget {
  const PlayButtonsSettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsController>();

    return Scaffold(
      appBar: AppBar(title: const Text('播放按钮设置'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 显示的两个按钮
            _buildShowButtonsSection(settingsController),
            const SizedBox(height: 24),

            // 所有按钮的顺序
            _buildAllButtonsOrderSection(settingsController),
          ],
        ),
      ),
    );
  }

  /// 构建显示按钮选择部分
  Widget _buildShowButtonsSection(SettingsController settingsController) {
    final showBtns = settingsController.playVShowBtns.obs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.visibility, color: Get.theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '显示的两个按钮',
              style: Get.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Obx(() {
            final selectedButtons = showBtns.toList();

            return Row(
              children: selectedButtons.asMap().entries.map((entry) {
                final btnIndex = entry.value;
                final btn = PlayVBtns.values[btnIndex];

                return Expanded(
                  child: ListTile(
                    title: Text(
                      btn.desc,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),

                    trailing: Icon(Icons.swap_horiz),
                    onTap: () => _showReplaceButtonDialog(
                      settingsController,
                      btnIndex,
                      showBtns,
                    ),
                    tileColor: Get.theme.colorScheme.primaryContainer
                        .withOpacity(0.3),
                  ),
                );
              }).toList(),
            );
          }),
        ),
      ],
    );
  }

  /// 显示替换按钮对话框
  Future<void> _showReplaceButtonDialog(
    SettingsController settingsController,
    int currentBtnIndex,
    RxSet<int> showBtns,
  ) async {
    final currentBtn = PlayVBtns.values[currentBtnIndex];

    // 获取未选中的按钮
    final hiddenButtons = PlayVBtns.values
        .where((btn) => !showBtns.contains(btn.index))
        .toList();

    if (hiddenButtons.isEmpty) {
      showInfoSnackbar('没有可替换的按钮', null);
      return;
    }

    await Get.dialog(
      AlertDialog(
        title: Text('替换 "${currentBtn.desc}"'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '选择要替换的按钮',
                style: Get.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: hiddenButtons.length,
                  itemBuilder: (context, index) {
                    final btn = hiddenButtons[index];

                    return ListTile(
                      leading: Icon(
                        Icons.radio_button_unchecked,
                        color: Get.theme.colorScheme.primary,
                      ),
                      title: Text(btn.desc),
                      subtitle: Text('索引: ${btn.index}'),
                      onTap: () {
                        final newSet = Set<int>.from(showBtns);
                        newSet.remove(currentBtnIndex);
                        newSet.add(btn.index);

                        try {
                          settingsController.playVShowBtns = newSet;
                          showBtns.clear();
                          showBtns.addAll(newSet);
                          Get.back();
                          showSuccessSnackbar(
                            '已替换',
                            '"${currentBtn.desc}" → "${btn.desc}"',
                          );
                        } catch (e) {
                          showErrorSnackbar('替换失败', e.toString());
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
        ],
      ),
    );
  }

  /// 构建所有按钮顺序部分
  Widget _buildAllButtonsOrderSection(SettingsController settingsController) {
    final btnOrder = settingsController.playVBtns.obs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.reorder, color: Get.theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '所有按钮的顺序',
              style: Get.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
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
                final newOrder = List<int>.from(btnOrder);
                final item = newOrder.removeAt(oldIndex);
                newOrder.insert(newIndex, item);

                try {
                  settingsController.playVBtns = newOrder;
                  btnOrder.value = newOrder;
                  showSuccessSnackbar('顺序已更新', null);
                } catch (e) {
                  showErrorSnackbar('更新失败', e.toString());
                }
              },
              itemCount: btnOrder.length,
              itemBuilder: (context, index) {
                final btnIndex = btnOrder[index];
                final btn = PlayVBtns.values[btnIndex];

                return Card(
                  key: ValueKey(btnIndex),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        Icons.drag_handle,
                        color: Get.theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      btn.desc,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 重置按钮
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                '确定要重置为默认顺序吗？',
                '重置按钮顺序',
                confirmLevel: ConfirmLevel.warning,
              );

              if (confirmed) {
                final defaultOrder = List.generate(
                  PlayVBtns.values.length,
                  (index) => index,
                );
                try {
                  settingsController.playVBtns = defaultOrder;
                  btnOrder.value = defaultOrder;
                  showSuccessSnackbar('已重置为默认顺序', null);
                } catch (e) {
                  showErrorSnackbar('重置失败', e.toString());
                }
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('重置为默认顺序'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Get.theme.colorScheme.secondaryContainer,
              foregroundColor: Get.theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}
