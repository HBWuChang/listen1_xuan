import 'dart:convert';
import 'dart:ui';
import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart';
import 'package:listen1_xuan/widgets/ext/ext_widget.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:listen1_xuan/controllers/controllers.dart';
import 'package:listen1_xuan/play.dart';
import 'package:logger/logger.dart';
import 'controllers/search_controller.dart';
import 'controllers/upd_controller.dart';
import 'provider/base.dart';
import 'provider/loweb.dart' as music_providers;
import 'models/GitHubRelease.dart';
import 'models/SupabasePlaylist.dart' as PlaylistModel;
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'controllers/DioController.dart';
import 'controllers/cache_controller.dart';
import 'controllers/myPlaylist_controller.dart';
import 'controllers/play_controller.dart';
import 'controllers/settings_controller.dart';
import 'services/ffmpeg_config.dart';
import 'controllers/routeController.dart';
import 'controllers/supabase_auth_controller.dart';
import 'controllers/websocket_client_controller.dart';
import 'pages/settings/play_buttons_settings_page.dart';
import 'pages/settings/settings_password_dialog.dart';
import 'pages/settings/select_audio_quality_of_bl_dialog.dart';
import 'examples/websocket_client_example.dart';
import 'examples/websocket_server_example.dart';
import 'funcs.dart';
import 'models/websocket_message.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'package:system_info3/system_info3.dart';
import 'global_settings_animations.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:charset_converter/charset_converter.dart';
import 'package:get/get.dart' hide Response;
import 'package:adaptive_theme/adaptive_theme.dart';
import 'controllers/theme.dart';
import 'package:iconify_flutter_plus/iconify_flutter_plus.dart';
import 'package:iconify_flutter_plus/icons/octicon.dart';
import 'package:iconify_flutter_plus/icons/mdi.dart';
import 'package:iconify_flutter_plus/icons/fa_solid.dart';
import 'package:path/path.dart' as p;
import 'utils/curve_utils.dart';
import 'utils/platform_credentials.dart';
import 'widgets/curve_selector_dialog.dart';
import 'package:flutter/material.dart' hide SearchController;
import 'widgets/elevated_button_icon.dart';
part 'pages/settings/settings_utils.dart';
part 'pages/settings/settings_github.dart';
part 'pages/settings/settings_widgets.dart';
part 'pages/settings/settings_widgets_upd.dart';
part 'pages/settings/settings_widgets_settings.dart';
part 'pages/settings/supabase_playlist_utils.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

Logger logger = Logger(
  printer: PrettyPrinter(
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.dateAndTime,
  ),
  level: Level.debug,
);

late String apkfile_name;
Future<void> init_apkfilepath() async {
  if (!isAndroid) return;
  // 确保路径存在
  switch (SysInfo.kernelArchitecture.name) {
    case "ARM64":
      apkfile_name = await xuanGetdownloadDirectory(
        path: 'app-arm64-v8a-release.apk',
      );
    case "ARM":
      apkfile_name = await xuanGetdownloadDirectory(
        path: 'app-armeabi-v7a-release.apk',
      );
    case "X86_64":
      apkfile_name = await xuanGetdownloadDirectory(
        path: 'app-x86_64-release.apk',
      );
    default:
      apkfile_name = await xuanGetdownloadDirectory(path: 'app-release.apk');
  }
}

class _SettingsPageState extends State<SettingsPage> {
  var useHttpOverrides = false.obs;
  final FocusNode _focusNode2 = FocusNode();
  final FocusNode _focusNode3 = FocusNode();
  late final TextEditingController _windowsProxyAddrController;
  @override
  void dispose() {
    _focusNode2.dispose(); // 释放 FocusNode
    _focusNode3.dispose(); // 释放 FocusNode
    _windowsProxyAddrController.dispose();
    super.dispose();
  }

  void get_useHttpOverrides() async {
    Map<String, dynamic> settings = lengcyGetSettings();
    if (settings["useHttpOverrides"] != null) {
      useHttpOverrides.value = settings["useHttpOverrides"];
    }
  }

  void set_useHttpOverrides(bool value) async {
    Get.find<SettingsController>().setSettings({'useHttpOverrides': value});
    showWarningSnackbar('重启应用后生效', null);
  }

  @override
  void initState() {
    super.initState();
    _windowsProxyAddrController = TextEditingController(
      text: Get.find<SettingsController>().windowsProxyAddr,
    );
    get_useHttpOverrides();
    // 监听焦点变化
    _focusNode2.addListener(() {
      if (_focusNode2.hasFocus) {
        setInAppHotKeyEnable(false);
      } else {
        setInAppHotKeyEnable(true);
      }
    });
    _focusNode3.addListener(() {
      if (_focusNode3.hasFocus) {
        setInAppHotKeyEnable(false);
      } else {
        setInAppHotKeyEnable(true);
      }
    });
  }

  SettingsController settingsController = Get.find<SettingsController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            leading: BackButton(onPressed: routerPop),
            actions: [
              WebSocketHelper.buildReactiveButton(tooltip: "WebSocket服务器"),
              WebSocketClientHelper.buildReactiveButton(
                tooltip: "WebSocket客户端",
              ),
            ],
            expandedHeight: 120.0,
            flexibleSpace: FlexibleSpaceBar(title: const Text('Settings')),
          ),
          SliverToBoxAdapter(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Obx(
                  () => ExpansionPanelList(
                    expansionCallback: (int index, bool isExpanded) {
                      if (isExpanded) {
                        settingsController.settingsPageExpansion.add(index);
                      } else {
                        settingsController.settingsPageExpansion.remove(index);
                      }
                    },
                    children: [
                      // Supabase 登录面板
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: Icon(Icons.person),
                            title: const Text('Supabase 账号'),
                            trailing: IconButton(
                              onPressed: () async {
                                Get.find<SupabaseAuthController>()
                                    .refreshUserProfile();
                              },
                              icon: Icon(Icons.refresh),
                            ),
                          );
                        },
                        canTapOnHeader: true,
                        isExpanded: settingsController.settingsPageExpansion
                            .contains(0),
                        body: _buildSupabasePanel(),
                      ),
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: Icon(Icons.login),
                            title: const Text('第三方平台登录'),
                            trailing: IconButton(
                              onPressed: () async {
                                settingsController.refreshLoginData();
                              },
                              icon: Icon(Icons.refresh),
                            ),
                          );
                        },
                        canTapOnHeader: true,
                        isExpanded: settingsController.settingsPageExpansion
                            .contains(1),
                        body: _buildThirdPartyLoginPanel(context),
                      ),
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: Icon(Icons.save),
                            title: const Text('歌单/配置文件'),
                          );
                        },
                        canTapOnHeader: true,
                        isExpanded: settingsController.settingsPageExpansion
                            .contains(2),
                        body: settingsWidget(context),
                      ),
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          final theme = Theme.of(context);
                          final resolvedIconColor =
                              ListTileTheme.of(context).iconColor ??
                              theme.listTileTheme.iconColor ??
                              theme.colorScheme.onSurfaceVariant;
                          final resolvedIconSize =
                              IconTheme.of(context).size ?? 24.0;
                          return ListTile(
                            leading: Iconify(
                              Octicon.cache_16,
                              color: resolvedIconColor,
                              size: resolvedIconSize,
                            ),
                            title: Text('缓存'),
                          );
                        },
                        canTapOnHeader: true,
                        isExpanded: settingsController.settingsPageExpansion
                            .contains(3),
                        body: Wrap(
                          alignment: WrapAlignment.center,
                          children: [...cacheSettingsTiles],
                        ),
                      ),
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: Icon(
                              isDesktop
                                  ? Icons.keyboard_alt
                                  : isAndroid
                                  ? Icons.notifications
                                  : Icons.device_unknown,
                            ),
                            title: Text(
                              isDesktop
                                  ? '热键、代理及其它Desktop设置'
                                  : isAndroid
                                  ? "安卓通知设置"
                                  : "未知平台设置",
                            ),
                          );
                        },
                        canTapOnHeader: true,
                        isExpanded: settingsController.settingsPageExpansion
                            .contains(4),
                        body: isDesktop
                            ? desktopSettingsTiles(
                                context,
                                _focusNode2,
                                _focusNode3,
                                _windowsProxyAddrController,
                              )
                            : isAndroid
                            ? androidSettingsTiles
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: notificationSettingsTiles,
                              ),
                      ),
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: Icon(Icons.system_update),
                            title: Text('更新版本'),
                            trailing: Text(
                              '当前构建hash：${UpdController.buildGitHash}\n${isAndroid ? 'cronetHttpNoPlay：${UpdController.cronetHttpNoPlay.toString()}；' : ''}${isFfmpegEnabled ? 'FFmpeg已启用' : '无FFmpeg'}',
                            ),
                            onTap: () {
                              if (settingsController.settingsPageExpansion
                                  .contains(5)) {
                                settingsController.settingsPageExpansion.remove(
                                  5,
                                );
                              } else {
                                settingsController.settingsPageExpansion.add(5);
                              }
                            },
                            onLongPress: () {
                              showInfoSnackbar(
                                '@DustDot',
                                'https://github.com/HBWuChang/listen1_xuan/pull/43',
                                onTap: () {
                                  g_launchURL(
                                    Uri.parse(
                                      'https://github.com/HBWuChang/listen1_xuan/pull/43',
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                        canTapOnHeader: true,
                        isExpanded: settingsController.settingsPageExpansion
                            .contains(5),
                        body: updSettingsTile(context),
                      ),
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          final theme = Theme.of(context);
                          final resolvedIconColor =
                              ListTileTheme.of(context).iconColor ??
                              theme.listTileTheme.iconColor ??
                              theme.colorScheme.onSurfaceVariant;

                          return ListTile(
                            leading: Iconify(
                              FaSolid.tshirt,
                              color: resolvedIconColor,
                              size: 18,
                            ),
                            title: Text('外观设置'),
                          );
                        },
                        canTapOnHeader: true,
                        isExpanded: settingsController.settingsPageExpansion
                            .contains(6),
                        body: themeSettingsTiles,
                      ),
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: Icon(Icons.play_circle_fill_rounded),
                            title: Text('播放设置'),
                          );
                        },
                        canTapOnHeader: true,
                        isExpanded: settingsController.settingsPageExpansion
                            .contains(7),
                        body: Column(
                          children: [
                            ListTile(
                              leading: Icon(Icons.equalizer),
                              title: const Text('均衡器设置'),
                              trailing: Icon(Icons.chevron_right),
                              onTap: () =>
                                  Get.toNamed(RouteName.equalizerPage, id: 1),
                            ),
                            ListTile(
                              leading: Icon(Icons.audiotrack),
                              title: const Text('默认音频质量'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => DefaultQualitySettingsSheet.show(),
                            ),
                            Obx(
                              () => SwitchListTile(
                                title: const Text('音量跟随系统'),
                                value: Get.find<SettingsController>()
                                    .volumnFollowSystem,
                                onChanged:
                                    Get.find<SettingsController>()
                                        .volumnFollowSystemChanging
                                        .value
                                    ? null
                                    : (bool value) async {
                                        Get.find<SettingsController>()
                                                .volumnFollowSystemChanging
                                                .value =
                                            true;
                                        Get.find<SettingsController>()
                                                .volumnFollowSystem =
                                            value;
                                        await Get.find<PlayController>()
                                            .updSysVolAndSet();
                                        Get.find<SettingsController>()
                                                .volumnFollowSystemChanging
                                                .value =
                                            false;
                                      },
                              ),
                            ),
                            Obx(
                              () => SwitchListTile(
                                title: const Text('下一首播放模式'),
                                subtitle: Obx(
                                  () => setSubTitleTextAniSwi(
                                    Text(
                                      Get.find<SettingsController>()
                                              .nextTrackQueueOrStackMethod
                                          ? '队列：先添加的曲目将先播放'
                                          : '栈：后添加的曲目将先播放',
                                      key: ValueKey<bool>(
                                        Get.find<SettingsController>()
                                            .nextTrackQueueOrStackMethod,
                                      ),
                                    ),
                                  ),
                                ),
                                value: Get.find<SettingsController>()
                                    .nextTrackQueueOrStackMethod,
                                onChanged: (bool value) {
                                  Get.find<SettingsController>()
                                          .nextTrackQueueOrStackMethod =
                                      value;
                                },
                              ),
                            ),
                            Obx(
                              () => SwitchListTile(
                                title: const Text('在“循环播放”模式下列表播放完成时停止播放'),

                                value: Get.find<SettingsController>()
                                    .stopOnPlayListEnd,
                                onChanged: (bool value) {
                                  Get.find<SettingsController>()
                                          .stopOnPlayListEnd =
                                      value;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: Icon(Icons.miscellaneous_services),
                            title: Text('杂项'),
                          );
                        },
                        canTapOnHeader: true,
                        isExpanded: settingsController.settingsPageExpansion
                            .contains(8),
                        body: Column(
                          children: [
                            ListTile(
                              leading: Icon(Icons.width_normal),
                              title: const Text('当左边栏大于一定宽度时隐藏搜索页面的搜索框'),
                              subtitle: Obx(
                                () => setSubTitleTextAniSwi(
                                  Text(
                                    '当前宽度：${Get.find<XSearchController>().leftBarWidth.value.toStringAsFixed(2)}, 设置宽度：${Get.find<SettingsController>().showSearchAreaWidth.toStringAsFixed(2)}',
                                    key: ValueKey<double>(
                                      Get.find<XSearchController>()
                                          .leftBarWidth
                                          .value,
                                    ),
                                  ),
                                ),
                              ),
                              onTap: showShowSearchAreaWidthInputDialog,
                              onLongPress: () => showInfoSnackbar(
                                '@zhiquanchi',
                                'https://github.com/HBWuChang/listen1_xuan/issues/33',
                              ),
                            ),

                            Obx(
                              () => SwitchListTile(
                                title: const Text('搜索源选择方式'),
                                subtitle: Obx(
                                  () => setSubTitleTextAniSwi(
                                    Text(
                                      Get.find<SettingsController>()
                                              .searchUseLastSource
                                          ? '记忆上次搜索源'
                                          : '默认搜索源',
                                      key: ValueKey<bool>(
                                        Get.find<SettingsController>()
                                            .searchUseLastSource,
                                      ),
                                    ),
                                  ),
                                ),
                                value: Get.find<SettingsController>()
                                    .searchUseLastSource,
                                onChanged: (bool value) {
                                  Get.find<SettingsController>()
                                          .searchUseLastSource =
                                      value;
                                },
                              ),
                            ),
                            Obx(
                              () => SwitchListTile(
                                title: const Text('复制错误信息到剪贴板'),
                                value: Get.find<SettingsController>()
                                    .copyErrorMessage,
                                onChanged: (bool value) {
                                  Get.find<SettingsController>()
                                          .copyErrorMessage =
                                      value;
                                },
                              ),
                            ),
                            AnimatedSize(
                              duration: Duration(milliseconds: 300),
                              child: Obx(
                                () =>
                                    Get.find<SettingsController>()
                                        .searchUseLastSource
                                    ? SizedBox.shrink()
                                    : ListTile(
                                        leading: Icon(Icons.search),
                                        title: const Text('选择默认搜索源'),
                                        trailing: DropdownButton<BaseProvider>(
                                          value: Get.find<XSearchController>()
                                              .providerFromNameOrAlias(
                                                Get.find<SettingsController>()
                                                    .searchLastSource,
                                              ),
                                          icon: Icon(Icons.arrow_downward),
                                          onChanged: (BaseProvider? newValue) {
                                            if (newValue == null) return;
                                            setState(() {
                                              Get.find<SettingsController>()
                                                      .searchLastSource =
                                                  newValue.name;
                                            });
                                          },
                                          items: Get.find<XSearchController>()
                                              .searchProviders
                                              .map<DropdownMenuItem<BaseProvider>>((
                                                BaseProvider provider,
                                              ) {
                                                return DropdownMenuItem<
                                                    BaseProvider>(
                                                  value: provider,
                                                  child: Text(
                                                    provider.shortDisplayName,
                                                  ),
                                                );
                                              })
                                              .toList(),
                                        ),
                                      ),
                              ),
                            ),

                            Obx(
                              () => SwitchListTile(
                                title: const Text('禁用ssl证书验证'),
                                value: useHttpOverrides.value,
                                onChanged: (bool value) {
                                  set_useHttpOverrides(value);
                                  useHttpOverrides.value = value;
                                },
                              ),
                            ),
                            Obx(
                              () => SwitchListTile(
                                title: const Text('debugToast'),
                                value:
                                    Get.find<SettingsController>().useDebugMode,
                                onChanged: (bool value) {
                                  Get.find<SettingsController>().useDebugMode =
                                      value;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                ListTile(
                  leading: Icon(Icons.book),
                  title: Text('查看README'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {
                    Get.toNamed(RouteName.settingsReadmePage, id: 1);
                  },
                ),
                0.3.sh.sbh,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
