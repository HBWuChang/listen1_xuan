import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
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

  // 自定义颜色的RGB值 - 使用getter/setter模式
  static const String customColorRKey = 'custom_color_r';
  static const String customColorGKey = 'custom_color_g';
  static const String customColorBKey = 'custom_color_b';

  double get customColorR {
    final settings = Get.find<SettingsController>().settings;
    return (settings[customColorRKey] ?? 156.0).toDouble();
  }

  set customColorR(double value) {
    Get.find<SettingsController>().setSetting(customColorRKey, value);
  }

  double get customColorG {
    final settings = Get.find<SettingsController>().settings;
    return (settings[customColorGKey] ?? 39.0).toDouble();
  }

  set customColorG(double value) {
    Get.find<SettingsController>().setSetting(customColorGKey, value);
  }

  double get customColorB {
    final settings = Get.find<SettingsController>().settings;
    return (settings[customColorBKey] ?? 176.0).toDouble();
  }

  set customColorB(double value) {
    Get.find<SettingsController>().setSetting(customColorBKey, value);
  }

  // 获取自定义颜色
  Color get customColor => Color.fromARGB(
    255,
    customColorR.toInt(),
    customColorG.toInt(),
    customColorB.toInt(),
  );
  static const String desktopOpKey = 'desktop_opacity';
  int get desktopOpacity {
    final settings = Get.find<SettingsController>().settings;
    return (settings[desktopOpKey] ?? 175).toInt();
  }

  set desktopOpacity(int value) {
    Get.find<SettingsController>().setSetting(desktopOpKey, value);
    if (value == 255) {
      playHBackgroundColor.value = null;
    } else {
      playHBackgroundColor.value = AdaptiveTheme.of(
        Get.context!,
      ).theme.scaffoldBackgroundColor.withAlpha(desktopOpacity);
    }
  }

  // 从Color更新RGB滑块值
  void updateCustomColorFromColor(Color color) {
    customColorR = color.red.toDouble();
    customColorG = color.green.toDouble();
    customColorB = color.blue.toDouble();
  }

  @override
  void onInit() {
    super.onInit();
    loadThemeSettings();
    ever(themeMode, (callback) {
      didChangePlatformBrightnessOrManual();
    });
    ever(toUpd, (callback) {
      didChangePlatformBrightnessOrManual();
    });
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
        updateCustomColorFromColor(selectedThemeColor.value);
      } catch (e) {
        print('加载主题颜色失败: $e');
        selectedThemeColor.value = Colors.purple; // 使用默认颜色
        updateCustomColorFromColor(selectedThemeColor.value);
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
    updateCustomColorFromColor(color);
    await saveThemeSettings();
    await applyTheme();
  }

  // 从RGB滑块设置主题颜色
  Future<void> setThemeColorFromRGB() async {
    selectedThemeColor.value = customColor;
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

  bool get isLightMode {
    final currentMode = themeMode.value;
    if (currentMode == AdaptiveThemeMode.light) {
      return true;
    } else if (currentMode == AdaptiveThemeMode.dark) {
      return false;
    } else {
      return WidgetsBinding.instance.window.platformBrightness ==
          Brightness.light;
    }
  }

  Rx<Color?> playHBackgroundColor = Rx<Color?>(null);
  bool firstDidChangePlatformBrightnessOrManual = true;
  Future<void> didChangePlatformBrightnessOrManual({bool once = false}) async {
    if (isMobile) return;
    if (once && firstDidChangePlatformBrightnessOrManual) {
      firstDidChangePlatformBrightnessOrManual = false;
      await Window.setEffect(effect: WindowEffect.acrylic);
    }
    bool isLight =
        themeMode.value == AdaptiveThemeMode.light ||
        (themeMode.value == AdaptiveThemeMode.system &&
            WidgetsBinding.instance.window.platformBrightness ==
                Brightness.light);
    Color t = isLight
        ? AdaptiveTheme.of(Get.context!).lightTheme.scaffoldBackgroundColor
        : AdaptiveTheme.of(Get.context!).darkTheme.scaffoldBackgroundColor;
    playHBackgroundColor.value = t.withAlpha(desktopOpacity);
    playHBackgroundColor.refresh();
    await Window.setEffect(
      effect: WindowEffect.acrylic,
      dark: !isLight,
      color: t,
    );
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

class ThemeSettingsDialog extends StatefulWidget {
  @override
  State<ThemeSettingsDialog> createState() => _ThemeSettingsDialogState();
}

class _ThemeSettingsDialogState extends State<ThemeSettingsDialog> {
  final themeController = Get.find<ThemeController>();
  late TextEditingController _colorCodeController;

  @override
  void initState() {
    super.initState();
    _colorCodeController = TextEditingController(
      text: themeController.selectedThemeColor.value.value
          .toRadixString(16)
          .padLeft(8, '0')
          .substring(2)
          .toUpperCase(),
    );
    // 监听selectedThemeColor变化，自动更新输入框
    ever(themeController.selectedThemeColor, (color) {
      if (mounted) {
        _colorCodeController.text = color.value
            .toRadixString(16)
            .padLeft(8, '0')
            .substring(2)
            .toUpperCase();
      }
    });
  }

  @override
  void dispose() {
    _colorCodeController.dispose();
    super.dispose();
  }

  // 从颜色代码设置颜色
  void _setColorFromCode(String code) {
    try {
      // 移除可能的#前缀
      code = code.replaceAll('#', '').trim();
      if (code.length == 6) {
        final colorValue = int.parse('FF$code', radix: 16);
        themeController.setThemeColor(Color(colorValue));
      }
    } catch (e) {
      // 输入无效，不做处理
    }
  }

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

              // 主题颜色选择
              Text(
                '主题颜色',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8), // 动态颜色开关
              Obx(
                () => SwitchListTile(
                  title: Text('使用动态颜色'),
                  subtitle: InkWell(
                    onTap: () => g_launchURL(
                      Uri.parse('https://pub.dev/packages/dynamic_color'),
                    ),
                    child: Text('不支持IOS,@dynamic_color'),
                  ),
                  value: themeController.useDynamicColor.value,
                  onChanged: (value) {
                    themeController.setUseDynamicColor(value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 16),
              Obx(
                () => IgnorePointer(
                  ignoring: themeController.useDynamicColor.value,
                  child: Opacity(
                    opacity: themeController.useDynamicColor.value ? 0.5 : 1.0,
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: themeController.themeColors.entries.map((
                        entry,
                      ) {
                        final isSelected =
                            themeController.selectedThemeColor.value ==
                            entry.value;
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
                                ? Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 24,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 自定义颜色
              Text(
                '自定义颜色',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              Obx(
                () => IgnorePointer(
                  ignoring: themeController.useDynamicColor.value,
                  child: Opacity(
                    opacity: themeController.useDynamicColor.value ? 0.5 : 1.0,
                    child: Column(
                      children: [
                        // 颜色代码输入框
                        TextField(
                          controller: _colorCodeController,
                          decoration: InputDecoration(
                            labelText: '颜色代码 (HEX)',
                            hintText: 'RRGGBB',
                            prefixText: '#',
                            border: OutlineInputBorder(),
                            suffixIcon: Obx(
                              () => Container(
                                margin: EdgeInsets.all(8),
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color:
                                      themeController.selectedThemeColor.value,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          maxLength: 6,
                          onSubmitted: _setColorFromCode,
                        ),
                        const SizedBox(height: 16),

                        // RGB滑块
                        Column(
                          children: [
                            // Red
                            Row(
                              children: [
                                SizedBox(
                                  width: 30,
                                  child: Text(
                                    'R',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: themeController.customColorR,
                                    min: 0,
                                    max: 255,
                                    divisions: 255,
                                    activeColor: Colors.red,
                                    label: themeController.customColorR
                                        .toInt()
                                        .toString(),
                                    onChanged: (value) {
                                      themeController.customColorR = value;
                                      setState(() {}); // 触发UI更新
                                    },
                                    onChangeEnd: (value) {
                                      themeController.setThemeColorFromRGB();
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    themeController.customColorR
                                        .toInt()
                                        .toString(),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                            // Green
                            Row(
                              children: [
                                SizedBox(
                                  width: 30,
                                  child: Text(
                                    'G',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: themeController.customColorG,
                                    min: 0,
                                    max: 255,
                                    divisions: 255,
                                    activeColor: Colors.green,
                                    label: themeController.customColorG
                                        .toInt()
                                        .toString(),
                                    onChanged: (value) {
                                      themeController.customColorG = value;
                                      setState(() {}); // 触发UI更新
                                    },
                                    onChangeEnd: (value) {
                                      themeController.setThemeColorFromRGB();
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    themeController.customColorG
                                        .toInt()
                                        .toString(),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                            // Blue
                            Row(
                              children: [
                                SizedBox(
                                  width: 30,
                                  child: Text(
                                    'B',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: themeController.customColorB,
                                    min: 0,
                                    max: 255,
                                    divisions: 255,
                                    activeColor: Colors.blue,
                                    label: themeController.customColorB
                                        .toInt()
                                        .toString(),
                                    onChanged: (value) {
                                      themeController.customColorB = value;
                                      setState(() {}); // 触发UI更新
                                    },
                                    onChangeEnd: (value) {
                                      themeController.setThemeColorFromRGB();
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    themeController.customColorB
                                        .toInt()
                                        .toString(),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
