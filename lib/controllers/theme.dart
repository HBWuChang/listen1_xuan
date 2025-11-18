import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:listen1_xuan/settings.dart';
import 'package:dynamic_color/dynamic_color.dart';
import '../global_settings_animations.dart';
import 'settings_controller.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

class ThemeController extends GetxController {
  // ColorScheme? _light;
  final _light = Rx<ColorScheme?>(null);
  // ColorScheme? _dark;
  final _dark = Rx<ColorScheme?>(null);

  // Windows主题变化监听的MethodChannel
  static const MethodChannel _themeChannel = MethodChannel('theme_monitor');

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
  RxBool useDynamicColor = true.obs;
  var themeMode = AdaptiveThemeMode.system.obs;

  @override
  void onInit() {
    super.onInit();
    loadThemeSettings();
    if (isWindows) _setupWindowsThemeListener();
  }

  @override
  void onClose() {
    // No cleanup needed for MethodChannel
    super.onClose();
  }

  // 设置Windows主题变化监听
  void _setupWindowsThemeListener() {
    try {
      // 设置MethodChannel的消息处理器
      _themeChannel.setMethodCallHandler((MethodCall call) async {
        if (call.method == 'themeChanged') {
          debugPrint('收到来自C++的主题更新消息: ${call.arguments}');
          // 在下一帧中更新主题
          Future.microtask(() {
            debugPrint('正在重新应用主题...');
            applyTheme();
          });
        }
      });
      debugPrint('Windows主题变化监听已设置');
    } catch (e) {
      debugPrint('设置Windows主题变化监听失败: $e');
    }
  }

  // 加载主题设置
  Future<void> loadThemeSettings() async {
    final settings = settings_getsettings();
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
    useDynamicColor.value = settings['use_dynamic_color'] ?? true;
    // 应用主题
    await applyTheme();
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
    Get.find<SettingsController>().setSettings(settings);
  }

  // 设置主题颜色
  Future<void> setThemeColor(Color color) async {
    selectedThemeColor.value = color;
    await saveThemeSettings();
    await applyTheme();
  }

  // 设置是否使用动态颜色
  Future<void> setUseDynamicColor(bool value) async {
    useDynamicColor.value = value;
    await saveThemeSettings();
    await applyTheme();
  }

  final toUpd = 0.obs;
  // 应用主题
  Future<void> applyTheme() async {
    if (useDynamicColor.value) {
      await initPlatformState();
    }
    final lightTheme = _buildTheme(Brightness.light);
    final darkTheme = _buildTheme(Brightness.dark);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 确保在框架渲染后应用主题
      AdaptiveTheme.of(
        Get.context!,
      ).setTheme(light: lightTheme, dark: darkTheme);
      toUpd.value = (toUpd.value + 1) % 2;
    });
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      CorePalette? corePalette = await DynamicColorPlugin.getCorePalette();

      // If the widget was removed from the tree while the asynchronous platform
      // message was in flight, we want to discard the reply rather than calling
      // setState to update our non-existent appearance.

      if (corePalette != null) {
        if (kDebugMode) {
          debugPrint('dynamic_color: Core palette detected.');
        }
        _light.value = corePalette.toColorScheme();
        _dark.value = corePalette.toColorScheme(brightness: Brightness.dark);
        return;
      }
    } on PlatformException {
      if (kDebugMode) {
        debugPrint('dynamic_color: Failed to obtain core palette.');
      }
    }

    try {
      final Color? accentColor = await DynamicColorPlugin.getAccentColor();

      if (accentColor != null) {
        if (kDebugMode) {
          debugPrint('dynamic_color: Accent color detected.');
        }
        _light.value = ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.light,
        );
        _dark.value = ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.dark,
        );
        return;
      }
    } on PlatformException {
      if (kDebugMode) {
        debugPrint('dynamic_color: Failed to obtain accent color.');
      }
    }
    if (kDebugMode) {
      debugPrint('dynamic_color: Dynamic color not detected on this device.');
    }
  }

  // 构建主题
  ThemeData _buildTheme(Brightness brightness) {
    if (useDynamicColor.value) {
      return ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: brightness == Brightness.light
            ? _light.value
            : _dark.value,
        useSystemColors: true,
        appBarTheme: AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: brightness,
            systemNavigationBarColor: Get.theme.colorScheme.surface,
          ),
        ),
      );
    } else {
      return ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: selectedThemeColor.value,
          brightness: brightness,
        ),
        appBarTheme: AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: brightness,
            systemNavigationBarColor: Get.theme.colorScheme.surface,
          ),
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

  // 设置主题模式
  void setThemeMode(AdaptiveThemeMode mode) {
    themeMode.value = mode;
    switch (mode) {
      case AdaptiveThemeMode.light:
        AdaptiveTheme.of(Get.context!).setLight();
        break;
      case AdaptiveThemeMode.dark:
        AdaptiveTheme.of(Get.context!).setDark();
        break;
      case AdaptiveThemeMode.system:
        AdaptiveTheme.of(Get.context!).setSystem();
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

ThemeController createThemeController() {
  if (Get.isRegistered<ThemeController>()) {
    return Get.find<ThemeController>();
  } else {
    return Get.put(ThemeController());
  }
}

class ThemeToggleButton extends StatelessWidget {
  final double? iconSize;
  final EdgeInsetsGeometry? padding;

  const ThemeToggleButton({Key? key, this.iconSize, this.padding})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeController = createThemeController();

    return GestureDetector(
      onLongPress: () {
        showThemeDialog();
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
      ),
    );
  }
}

void showThemeDialog() {
  Get.dialog(ThemeSettingsDialog(), barrierDismissible: true);
}

class ThemeSettingsDialog extends StatelessWidget {
  final themeController = Get.find<ThemeController>();
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Container(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: 600),
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
              Obx(
                () => SwitchListTile(
                  title: Text('使用动态颜色'),
                  subtitle: Text('根据壁纸自动调整颜色'),
                  value: themeController.useDynamicColor.value,
                  onChanged: (value) {
                    themeController.setUseDynamicColor(value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 16),

              // 主题颜色选择
              Text(
                '主题颜色',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Obx(
                () => Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: themeController.themeColors.entries.map((entry) {
                    final isSelected =
                        themeController.selectedThemeColor.value == entry.value;
                    return GestureDetector(
                      onTap: () {
                        themeController.setThemeColor(entry.value);
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: entry.value,
                          borderRadius: BorderRadius.circular(30),
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  width: 3,
                                )
                              : null,
                        ),
                        child: isSelected
                            ? Icon(Icons.check, color: Colors.white, size: 24)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
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
        children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(label)],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          switch (mode) {
            case AdaptiveThemeMode.light:
              themeController.setThemeMode(AdaptiveThemeMode.light);
              break;
            case AdaptiveThemeMode.dark:
              themeController.setThemeMode(AdaptiveThemeMode.dark);
              break;
            case AdaptiveThemeMode.system:
              themeController.setThemeMode(AdaptiveThemeMode.system);
              break;
          }
        }
      },
    );
  }
}
