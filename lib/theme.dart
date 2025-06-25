import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:listen1_xuan/settings.dart';

class ThemeController extends GetxController {
  // 主题颜色选项
  final Map<String, Color> themeColors = {
    '默认蓝色': Colors.blue,
    '绿色': Colors.green,
    '紫色': Colors.purple,
    '橙色': Colors.orange,
    '红色': Colors.red,
    '青色': Colors.cyan,
    '粉色': Colors.pink,
    '靛蓝': Colors.indigo,
  };

  var selectedThemeColor = (Colors.purple as Color).obs;
  RxBool useDynamicColor = false.obs;
  var themeMode = AdaptiveThemeMode.system.obs;
  @override
  void onInit() {
    super.onInit();
    loadThemeSettings();
  }

  // 加载主题设置
  Future<void> loadThemeSettings() async {
    final settings = await settings_getsettings();
    // 加载主题颜色
    final colorValue = settings['theme_color'];
    if (colorValue != null && colorValue is int) {
      try {
        selectedThemeColor.value = Color(colorValue);
      } catch (e) {
        print('加载主题颜色失败: $e');
        selectedThemeColor.value = Colors.purple; // 使用默认颜色
      }
    }
    // 加载主题模式
    final mode = settings['theme_mode'];
    if (mode != null && mode is String) {
      switch (mode) {
        case 'light':
          themeMode.value = AdaptiveThemeMode.light;
          break;
        case 'dark':
          themeMode.value = AdaptiveThemeMode.dark;
          break;
        case 'system':
          themeMode.value = AdaptiveThemeMode.system;
          break;
        default:
          themeMode.value = AdaptiveThemeMode.system; // 默认使用系统模式
      }
    } else {
      themeMode.value = AdaptiveThemeMode.system; // 默认使用系统模式
    }
    // 加载动态颜色设置
    useDynamicColor.value = settings['use_dynamic_color'] ?? false;
    // 应用主题
    await _applyTheme();
  }

  // 保存主题设置
  Future<void> saveThemeSettings() async {
    String themeModeString;
    switch (themeMode.value) {
      case AdaptiveThemeMode.light:
        themeModeString = 'light';
        break;
      case AdaptiveThemeMode.dark:
        themeModeString = 'dark';
        break;
      case AdaptiveThemeMode.system:
        themeModeString = 'system';
        break;
    }
    final settings = {
      'theme_color': selectedThemeColor.value.value,
      'use_dynamic_color': useDynamicColor.value,
      'theme_mode': themeModeString,
    };
    await settings_setsettings(settings);
  }

  // 设置主题颜色
  Future<void> setThemeColor(Color color) async {
    selectedThemeColor.value = color;
    await saveThemeSettings();
    await _applyTheme();
  }

  // 设置是否使用动态颜色
  Future<void> setUseDynamicColor(bool value) async {
    useDynamicColor.value = value;
    await saveThemeSettings();
    await _applyTheme();
  }

  // 应用主题
  Future<void> _applyTheme() async {
    final lightTheme = _buildTheme(Brightness.light);
    final darkTheme = _buildTheme(Brightness.dark);

    AdaptiveTheme.of(Get.context!).setTheme(
      light: lightTheme,
      dark: darkTheme,
    );
  }

  // 构建主题
  ThemeData _buildTheme(Brightness brightness) {
    if (useDynamicColor.value) {
      return ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorSchemeSeed: selectedThemeColor.value,
      );
    } else {
      return ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: selectedThemeColor.value,
          brightness: brightness,
        ),
      );
    }
  }

  // 切换主题模式
  void toggleThemeMode() {
    final currentMode = themeMode.value;
    switch (currentMode) {
      case AdaptiveThemeMode.light:
        themeMode.value = AdaptiveThemeMode.dark;
        AdaptiveTheme.of(Get.context!).setDark();
        break;
      case AdaptiveThemeMode.dark:
        themeMode.value = AdaptiveThemeMode.system;
        AdaptiveTheme.of(Get.context!).setSystem();
        break;
      case AdaptiveThemeMode.system:
        themeMode.value = AdaptiveThemeMode.light;
        AdaptiveTheme.of(Get.context!).setLight();
        break;
    }
    saveThemeSettings();
  }

  // 获取当前主题模式文本
  String getCurrentThemeModeText() {
    final currentMode = themeMode.value;
    switch (currentMode) {
      case AdaptiveThemeMode.light:
        return '亮色主题';
      case AdaptiveThemeMode.dark:
        return '暗色主题';
      case AdaptiveThemeMode.system:
        return '跟随系统';
    }
  }
}

ThemeController creatThemeController() {
  if (Get.isRegistered<ThemeController>()) {
    return Get.find<ThemeController>();
  } else {
    return Get.put(ThemeController());
  }
}

class ThemeToggleButton extends StatelessWidget {
  final double? iconSize;
  final EdgeInsetsGeometry? padding;

  const ThemeToggleButton({
    Key? key,
    this.iconSize,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeController = creatThemeController();

    return GestureDetector(
        onLongPress: () {
          _showThemeDialog(context);
        },
        child: IconButton(
          tooltip: GetPlatform.isWindows ? '长按打开主题设置' : null,
          icon: Obx(() {
            final currentMode = themeController.themeMode.value;
            return Icon(
              currentMode == AdaptiveThemeMode.light
                  ? Icons.light_mode
                  : currentMode == AdaptiveThemeMode.dark
                      ? Icons.dark_mode
                      : Icons.brightness_auto,
              size: iconSize ?? 24.0,
            );
          }),
          padding: padding ?? const EdgeInsets.all(8.0),
          onPressed: () {
            themeController.toggleThemeMode();
          },
        ));
  }

  void _showThemeDialog(BuildContext context) {
    Get.dialog(
      ThemeSettingsDialog(),
      barrierDismissible: true,
    );
  }
}

class ThemeSettingsDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: 600,
        ),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '主题设置',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 主题模式选择
            Text(
              '主题模式',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildThemeModeChip(
                  context,
                  '亮色',
                  Icons.light_mode,
                  AdaptiveThemeMode.light,
                  themeController,
                ),
                _buildThemeModeChip(
                  context,
                  '暗色',
                  Icons.dark_mode,
                  AdaptiveThemeMode.dark,
                  themeController,
                ),
                _buildThemeModeChip(
                  context,
                  '系统',
                  Icons.brightness_auto,
                  AdaptiveThemeMode.system,
                  themeController,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 动态颜色开关
            Obx(() => SwitchListTile(
                  title: Text('使用动态颜色'),
                  subtitle: Text('根据壁纸自动调整颜色（Android 12+）'),
                  value: themeController.useDynamicColor.value,
                  onChanged: (value) {
                    themeController.setUseDynamicColor(value);
                  },
                  contentPadding: EdgeInsets.zero,
                )),
            const SizedBox(height: 16),

            // 主题颜色选择
            Text(
              '主题颜色',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Obx(() => Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: themeController.themeColors.entries.map((entry) {
                    final isSelected =
                        themeController.selectedThemeColor.value ==
                            entry.value as Color;
                    return GestureDetector(
                      onTap: () {
                        themeController.setThemeColor(entry.value as Color);
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: entry.value as Color,
                          borderRadius: BorderRadius.circular(30),
                          border: isSelected
                              ? Border.all(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  width: 3,
                                )
                              : null,
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 24,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                )),
            const SizedBox(height: 24),

            // 底部按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: Text('取消'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Get.back();
                    Get.snackbar(
                      '主题设置',
                      '设置已保存',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  },
                  child: Text('确定'),
                ),
              ],
            ),
          ],
        )),
      ),
    );
  }

  Widget _buildThemeModeChip(
    BuildContext context,
    String label,
    IconData icon,
    AdaptiveThemeMode mode,
    ThemeController controller,
  ) {
    final currentMode = AdaptiveTheme.of(context).mode;
    final isSelected = currentMode == mode;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          switch (mode) {
            case AdaptiveThemeMode.light:
              AdaptiveTheme.of(context).setLight();
              break;
            case AdaptiveThemeMode.dark:
              AdaptiveTheme.of(context).setDark();
              break;
            case AdaptiveThemeMode.system:
              AdaptiveTheme.of(context).setSystem();
              break;
          }
        }
      },
    );
  }
}
