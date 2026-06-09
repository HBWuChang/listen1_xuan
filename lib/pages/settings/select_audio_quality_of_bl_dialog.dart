import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/bl.dart';
import 'package:listen1_xuan/constants/const.dart';
import 'package:listen1_xuan/controllers/settings_controller.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// 平台默认音频质量设置页面导航控制器
class _QualitySheetController extends GetxController {
  final pageIndexNotifier = ValueNotifier(0);

  int get pageIndex => pageIndexNotifier.value;
  set pageIndex(int value) => pageIndexNotifier.value = value;

  @override
  void onClose() {
    pageIndexNotifier.dispose();
    super.onClose();
  }
}

/// 平台默认音频质量设置入口
class DefaultQualitySettingsSheet {
  static Future<void> show({PlatformSource? platformSource}) async {
    final ctrl = Get.put(_QualitySheetController(), tag: 'quality_sheet');
    try {
      final hasPlatform = platformSource != null;
      if (hasPlatform) {
        ctrl.pageIndex = 1;
      }
      await WoltModalSheet.show<void>(
        pageIndexNotifier: ctrl.pageIndexNotifier,
        context: Get.context!,
        pageListBuilder: (modalSheetContext) {
          return [
            _buildPlatformListPage(ctrl),
            _buildBLQualityPage(ctrl),
          ];
        },
      );
    } finally {
      Get.delete<_QualitySheetController>(tag: 'quality_sheet');
    }
  }

  static SliverWoltModalSheetPage _buildPlatformListPage(
    _QualitySheetController ctrl,
  ) {
    return SliverWoltModalSheetPage(
      hasTopBarLayer: false,
      isTopBarLayerAlwaysVisible: false,
      enableDrag: false,
      mainContentSliversBuilder: (context) => [
        SliverToBoxAdapter(
          child: _buildHeader(
            context,
            title: '平台默认音频质量',
            showBack: false,
            onClose: () => Get.back(),
          ),
        ),
        const SliverToBoxAdapter(child: Divider(height: 1)),
        SliverList(
          delegate: SliverChildListDelegate([
            ListTile(
              leading: const Icon(Icons.tv),
              title: const Text('B站'),
              subtitle: const Text('选择B站默认音频质量'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => ctrl.pageIndex = 1,
            ),
          ]),
        ),
      ],
    );
  }

  static SliverWoltModalSheetPage _buildBLQualityPage(
    _QualitySheetController ctrl, {
    bool showBack = true,
  }) {
    final qualities = AudioQualityOfBL.values.reversed.toList();
    final settingsController = Get.find<SettingsController>();

    return SliverWoltModalSheetPage(
      hasTopBarLayer: false,
      isTopBarLayerAlwaysVisible: false,
      enableDrag: false,
      mainContentSliversBuilder: (context) => [
        SliverToBoxAdapter(
          child: _buildHeader(
            context,
            title: '选择B站默认音频质量',
            showBack: showBack,
            onBack: () => ctrl.pageIndex = 0,
            onClose: () => Get.back(),
          ),
        ),
        const SliverToBoxAdapter(child: Divider(height: 1)),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final quality = qualities[index];
            return Obx(() {
              final isSelected =
                  settingsController.selectAudioQualityOfBLRx.value ==
                  quality.code;

              return ListTile(
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(
                  quality.description,
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                selected: isSelected,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.primary.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () {
                  settingsController.selectAudioQualityOfBLRx.value =
                      quality.code;
                  Get.back();
                },
              );
            });
          }, childCount: qualities.length),
        ),
      ],
    );
  }

  static Widget _buildHeader(
    BuildContext context, {
    required String title,
    required bool showBack,
    VoidCallback? onBack,
    required VoidCallback onClose,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (showBack) ...[
            BackButton(onPressed: onBack),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: onClose),
        ],
      ),
    );
  }
}
