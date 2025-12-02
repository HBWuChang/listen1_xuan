part of '../../settings.dart';

/// 构建 Supabase 登录面板
Widget _buildSupabasePanel() {
  final authController = Get.find<SupabaseAuthController>();

  return Obx(() {
    if (authController.isLoggedIn.value) {
      // 已登录状态
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              authController.displayName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Card(
                            color: authController.isPro
                                ? Get.theme.colorScheme.primary
                                : Get.theme.colorScheme.secondary,
                            margin: EdgeInsets.only(left: 8.0),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                                vertical: 2.0,
                              ),
                              child: Text(
                                authController.isPro ? 'unLimited用户' : '普通用户',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: authController.isPro
                                      ? Get.theme.colorScheme.onPrimary
                                      : Get.theme.colorScheme.onSecondary,
                                ),
                              ),
                            ),
                          ),
                          Obx(
                            () => Card(
                              color:
                                  authController
                                      .isSubscribedToContinuePlay
                                      .value
                                  ? Get.theme.colorScheme.primary
                                  : Get.theme.disabledColor,
                              margin: EdgeInsets.only(left: 8.0),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0,
                                  vertical: 2.0,
                                ),
                                child: Text(
                                  authController
                                          .isSubscribedToContinuePlay
                                          .value
                                      ? '已订阅播放状态'
                                      : '未订阅播放状态',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        authController
                                            .isSubscribedToContinuePlay
                                            .value
                                        ? Get.theme.colorScheme.onPrimary
                                        : Get.theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (authController.userCreatedAt != null)
                        Text(
                          '注册时间: ${authController.userCreatedAt}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      if (authController.userLastLoginAt != null)
                        Text(
                          '上次登录: ${authController.userLastLoginAt}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              runAlignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8.0,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _showEditNicknameDialog(authController);
                  },
                  icon: Icon(Icons.edit),
                  label: Text('修改昵称'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final userId = authController.currentUser.value?.id ?? '';
                    if (userId.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: userId));
                      showSuccessSnackbar('已复制', '用户ID已复制到剪贴板');
                    } else {
                      showErrorSnackbar('复制失败', '无法获取用户ID');
                    }
                  },
                  icon: Icon(Icons.copy),
                  label: Text('复制ID'),
                ),
                Obx(
                  () => ElevatedButton.icon(
                    onPressed: authController.isLoading.value
                        ? null
                        : () async {
                            await authController.signOut();
                            showSuccessSnackbar(null, '已退出登录');
                          },
                    icon: Icon(Icons.logout),
                    label: Text('退出登录'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Get.theme.colorScheme.errorContainer,
                      foregroundColor: Get.theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            Obx(
              () => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('同步播放状态'),
                subtitle: Text('开启后可在多设备间同步播放状态'),
                value: Get.find<SettingsController>().supabaseSubPlay,
                onChanged: (bool value) {
                  Get.find<SettingsController>().supabaseSubPlay = value;
                },
              ),
            ),
            Obx(
              () => ListTile(
                leading: Icon(Icons.timelapse_rounded),
                title: const Text('退出应用同步播放超时时间'),
                subtitle: Text(
                  '${Get.find<SettingsController>().supabaseUploadTimeoutDurationOnExit} 毫秒',
                ),
                trailing: Icon(Icons.edit),
                onTap: () async {
                  await showInputDialog(
                    title: '退出应用同步播放超时时间',
                    message: '单位为毫秒',
                    initialValue: Get.find<SettingsController>()
                        .supabaseUploadTimeoutDurationOnExit
                        .toString(),
                    onConfirm: (value) async {
                      if (isEmpty(value)) return false;
                      int? intValue = int.tryParse(value);
                      if (intValue == null || intValue < 0) {
                        throw '请输入有效的非负整数';
                      }
                      Get.find<SettingsController>()
                              .supabaseUploadTimeoutDurationOnExit =
                          intValue;
                      showSuccessSnackbar('设置成功', null);
                      return true;
                    },
                    keyboardType: TextInputType.number,
                  );
                },
              ),
            ),
          ],
        ),
      );
    } else {
      // 未登录状态
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              '使用 Supabase 账号可以同步您的数据',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Get.toNamed('/supabase_login', id: 1);
              },
              icon: Icon(Icons.login),
              label: Text('登录 / 注册'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 45),
              ),
            ),
          ],
        ),
      );
    }
  });
}

Widget _buildThirdPartyLoginPanel(
  BuildContext context,
  open_bl_login,
  open_netease_login,
  open_qq_login,
) {
  final settingsController = Get.find<SettingsController>();
  return Column(
    children: <Widget>[
      IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Iconify(
                  Ri.bilibili_fill,
                  color: AdaptiveTheme.of(Get.context!).theme.iconTheme.color,
                ),

                ExtendedImage.network(
                  "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/28469918905/0dfc/b6c0/d913/713572367ec9d917628e41266a39a67f.png",
                  width: 18,
                  height: 18,
                  cache: true,
                ),

                ExtendedImage.network(
                  "https://ts2.cn.mm.bing.net/th?id=ODLS.07d947f8-8fdd-4949-8b9a-be5283268438&w=32&h=32&qlt=90&pcl=fffffa&o=6&pid=1.2",
                  cache: true,
                  width: 18,
                  height: 18,
                ),

                Iconify(
                  Mdi.github,
                  color: AdaptiveTheme.of(Get.context!).theme.iconTheme.color,
                ),
              ].map((e) => Center(child: e)).toList(),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Obx(() {
                  bool isLoading = settingsController.loginDataLoading.contains(
                    PlantformCodes.bl,
                  );
                  final data = settingsController.loginData[PlantformCodes.bl];
                  if (isLoading) {
                    return globalLoadingAnime;
                  } else {
                    if (data == '') {
                      return const Text('cookie未设置或失效');
                    } else {
                      return Text(data ?? 'Loading...');
                    }
                  }
                }),
                Obx(() {
                  bool isLoading = settingsController.loginDataLoading.contains(
                    PlantformCodes.ne,
                  );
                  final data = settingsController.loginData[PlantformCodes.ne];
                  if (isLoading) {
                    return globalLoadingAnime;
                  } else {
                    if (data == '') {
                      return const Text('cookie未设置或失效');
                    } else {
                      return Text(data?['result']?['nickname'] ?? '未知用户');
                    }
                  }
                }),
                Obx(() {
                  bool isLoading = settingsController.loginDataLoading.contains(
                    PlantformCodes.qq,
                  );
                  final data = settingsController.loginData[PlantformCodes.qq];
                  if (isLoading) {
                    return globalLoadingAnime;
                  } else {
                    if (data == '') {
                      return const Text('cookie未设置或失效');
                    } else {
                      return Text(data?['data']?['nickname'] ?? '未知用户');
                    }
                  }
                }),
                Obx(() {
                  bool isLoading = settingsController.loginDataLoading.contains(
                    PlantformCodes.github,
                  );
                  final data =
                      settingsController.loginData[PlantformCodes.github];
                  if (isLoading) {
                    return globalLoadingAnime;
                  } else {
                    if (data == '') {
                      return const Text('cookie未设置或失效');
                    } else {
                      return Text(Github.getStatusText());
                    }
                  }
                }),
              ].map((e) => Center(child: e)).toList(),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children:
                  [
                        ElevatedButton(
                          onPressed: () => open_bl_login(),
                          child: const Text('设置bilibili cookie'),
                        ),
                        ElevatedButton(
                          onPressed: () => open_netease_login(),
                          child: const Text('登录网易云'),
                        ),
                        ElevatedButton(
                          onPressed: () => open_qq_login(),
                          child: const Text('登录QQ音乐'),
                        ),
                        ElevatedButton(
                          onPressed: () => Github.openAuthUrl(context),
                          child: const Text('登录Github(建议使用魔法'),
                        ),
                      ]
                      .map((e) => Center(child: e))
                      .map(
                        (e) => Padding(
                          padding: EdgeInsets.symmetric(vertical: 4.0),
                          child: e,
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),

      Obx(() {
        WebSocketClientController wscc = Get.find<WebSocketClientController>();
        return ElevatedButton(
          onPressed: !wscc.isConnected
              ? null
              : () {
                  wscc.sendGetCookieMessage();
                },
          child: Text('从WebSocket服务器获取登录信息'),
        );
      }),
    ].map((e) => Padding(padding: EdgeInsets.all(8.0), child: e)).toList(),
  );
}

/// 显示修改昵称对话框
void _showEditNicknameDialog(SupabaseAuthController authController) async {
  await showInputDialog(
    title: '修改昵称',
    placeholder: '请输入新昵称',
    initialValue: authController.userNickname ?? '',
    maxLength: 20,
    validator: (value) {
      if (value == null || value.trim().isEmpty) {
        return '昵称不能为空';
      }
      return null;
    },
    onConfirm: (nickname) async {
      final success = await authController.updateNickname(nickname);
      if (success) {
        showSuccessSnackbar(null, '昵称修改成功');
        return true;
      } else {
        throw authController.errorMessage.value;
      }
    },
  );
}

/// 显示不透明度调整对话框
void _showOpacityDialog() {
  final themeController = Get.find<ThemeController>();

  Get.dialog(
    StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text('调整背景不透明度'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 16),
              Row(
                children: [
                  Text('透明'),
                  Expanded(
                    child: Slider(
                      value: themeController.desktopOpacity.toDouble(),
                      min: 0,
                      max: 255,
                      divisions: 255,
                      label: themeController.desktopOpacity.toString(),
                      onChanged: (value) {
                        setState(() {
                          themeController.desktopOpacity = value.toInt();
                        });
                      },
                    ),
                  ),
                  Text('不透明'),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '提示: 255为完全不透明，0为完全透明',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Get.back(), child: Text('关闭'))],
        );
      },
    ),
  );
}

List<Widget> get cacheSettingsTiles => [
  Obx(() {
    WebSocketClientController wscc = Get.find<WebSocketClientController>();
    return ElevatedButton(
      onPressed: !wscc.isConnected
          ? null
          : () {
              Get.toNamed(RouteName.downloadPage, id: 1);
            },
      child: Text('从WebSocket服务器获取缓存文件'),
    );
  }),
  ElevatedButton(
    onPressed: () => clean_local_cache(),
    child: const Text('清除未在配置文件中的歌曲缓存'),
  ),
  ElevatedButton(
    onPressed: () async {
      final result = await showConfirmDialog(
        '确认清除所有歌曲缓存？此操作不可恢复',
        '清除所有缓存',
        confirmLevel: ConfirmLevel.danger,
      );
      if (!result) return;
      clean_local_cache(true);
    },
    child: const Text('清除所有歌曲缓存'),
  ),
  ListTile(
    leading: Icon(Icons.edit),
    title: const Text('缓存命名方式'),
    subtitle: Obx(() {
      return Text(
        Get.find<SettingsController>().cacheNamedMethod.fold<String>('', (
          previousValue,
          element,
        ) {
          final method = NamedMethod.values.firstWhere(
            (m) => m.index == element,
            orElse: () => NamedMethod.id,
          );
          if (previousValue.isEmpty) {
            return method.name;
          } else {
            return '$previousValue${Get.find<SettingsController>().cacheNamedConnection}${method.name}';
          }
        }),
        style: TextStyle(fontSize: 12),
      );
    }),
    onTap: () => Get.toNamed(RouteName.cacheNamingPage, id: 1),
  ),
].map((e) => Padding(padding: EdgeInsets.all(8.0), child: e)).toList();

Widget desktopSettingsTiles(
  BuildContext context,
  FocusNode _focusNode2,
  FocusNode _focusNode3,
) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children:
        [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceAround,

                children: create_hotkey_btns(context),
              ),
              TextField(
                focusNode: _focusNode2,
                controller: TextEditingController(
                  text: Get.find<SettingsController>().windowsProxyAddr,
                ),
                decoration: InputDecoration(
                  labelText: '代理地址,仅适用于Github,例如：localhost:7890,留空表示不使用,回车以保存',
                ),
                onSubmitted: (value) async {
                  Get.find<SettingsController>().windowsProxyAddr = value;
                  Get.find<DioController>().loadProxy();
                  showInfoSnackbar('设置成功$value', '立即生效');
                },
              ),
              if (isWindows)
                Obx(
                  () => SwitchListTile(
                    title: const Text('在右侧页面中键时隐藏/最小化主页面'),
                    value: Get.find<SettingsController>().hideOrMinimize,
                    onChanged: (bool value) {
                      Get.find<SettingsController>().hideOrMinimize = value;
                      // _msg('设置成功', 1.0);
                      showSuccessSnackbar('设置成功', null);
                    },
                  ),
                ),
              Obx(
                () => SwitchListTile(
                  title: const Text('记住窗口大小'),
                  value: Get.find<SettingsController>()
                      .rememberWindowsSizeAndPosition,
                  onChanged: (bool value) {
                    Get.find<SettingsController>()
                            .rememberWindowsSizeAndPosition =
                        value;
                    // _msg('设置成功', 1.0);
                    showSuccessSnackbar('设置成功', null);
                  },
                ),
              ),
            ]
            .map(
              (e) => Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: e,
              ),
            )
            .toList(),
  );
}

enum AudioServiceButtonActions {
  playPause(0, '播放/暂停'),
  skipToNext(1, '下一首'),
  skipToPrevious(2, '上一首');

  final int code;
  final String displayName;

  const AudioServiceButtonActions(this.code, this.displayName);

  static String getDisplayNameByCode(int code) {
    return AudioServiceButtonActions.values
        .firstWhere(
          (action) => action.code == code,
          orElse: () => AudioServiceButtonActions.playPause,
        )
        .displayName;
  }
}

Widget get androidSettingsTiles => Column(
  children: [
    Obx(
      () => SwitchListTile(
        title: const Text('尝试在通知中显示歌词'),
        value: Get.find<SettingsController>().tryShowLyricInNotification,
        onChanged: (bool value) {
          Get.find<SettingsController>().tryShowLyricInNotification = value;
        },
      ),
    ),
    OpenContainer(
      closedBuilder: (context, _) => ListTile(
        title: const Text('通知按钮顺序调整'),
        trailing: Icon(Icons.unfold_more_rounded),
      ),
      openBuilder: (context, _) {
        final settingsController = Get.find<SettingsController>();
        return Scaffold(
          appBar: AppBar(title: const Text('通知按钮顺序调整')),
          body: Obx(
            () => ReorderableListView(
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
                List<int> items = settingsController.androidActionSort;
                int item = items.removeAt(oldIndex);
                items.insert(newIndex, item);
                settingsController.androidActionSort = items;
              },
              children: settingsController.androidActionSort
                  .asMap()
                  .entries
                  .map(
                    (entry) => ListTile(
                      key: ValueKey(entry.value),
                      title: Text(
                        AudioServiceButtonActions.getDisplayNameByCode(
                          entry.value,
                        ),
                      ),
                      leading: Icon(Icons.drag_handle),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    ),
  ],
);

Widget get themeSettingsTiles => Column(
  children: [
    ListTile(
      leading: Icon(Icons.color_lens),
      title: Text('主题颜色设置'),
      trailing: ThemeToggleButton(
        iconSize: 24.0, // 可选：自定义图标大小
        padding: EdgeInsets.all(0), // 可选：自定义内边距
      ),

      onTap: () {
        showThemeDialog();
      },
    ),
    if (isDesktop)
      ListTile(
        leading: Icon(Icons.opacity_rounded),
        title: Text('横屏播放栏背景不透明度'),
        subtitle: Obx(() {
          return Text(
            '${Get.find<ThemeController>().desktopOpacity} (值越小越透明，255为不透明)',
          );
        }),
        onTap: () async {
          _showOpacityDialog();
        },
      ),
    ListTile(
      leading: Icon(Icons.timelapse_rounded),
      title: Text('播放按钮旋转时间'),
      subtitle: Obx(() {
        return Text(
          '${Get.find<SettingsController>().playVPlayBtnProcessControllerDuration.toString()}ms',
        );
      }),
      onTap: () async {
        await showInputDialog(
          title: '播放按钮旋转时间 ms',
          placeholder: '请输入播放按钮旋转时间，单位ms',
          initialValue: Get.find<SettingsController>()
              .playVPlayBtnProcessControllerDuration
              .toString(),
          onConfirm: (value) async {
            if (isEmpty(value)) return false;
            int? intValue = int.tryParse(value);
            if (intValue == null || intValue < 100) {
              throw '请输入有效的正整数.且不能小于100';
            }
            Get.find<SettingsController>()
                    .playVPlayBtnProcessControllerDuration =
                intValue;
            showSuccessSnackbar('设置成功', '重启生效');
            return true;
          },
          keyboardType: TextInputType.number,
        );
      },
    ),
    ListTile(
      leading: Iconify(
        Mdi.chart_bell_curve,
        color: AdaptiveTheme.of(Get.context!).theme.iconTheme.color,
        size: 18,
      ),
      title: Text('播放按钮旋转曲线'),
      subtitle: Obx(() {
        final playController = Get.find<PlayController>();
        return Text(
          CurveUtils.getDisplayName(
            playController.playButtonRotationCurve.value,
          ),
        );
      }),
      onTap: () async {
        String? res = await showCurveSelectorDialog(
          Get.context!,
          currentCurveName:
              Get.find<PlayController>().playButtonRotationCurve.value,
        );
        if (isEmpty(res)) return;
        Get.find<PlayController>().playButtonRotationCurve.value = res!;
      },
    ),
    ListTile(
      leading: Icon(Icons.blur_on),
      title: Text('歌词背景高斯模糊距离'),
      subtitle: Obx(() {
        return Text(
          Get.find<SettingsController>().lyricBackgroundBlurRadius.toString(),
        );
      }),
      onTap: () async {
        await showInputDialog(
          title: '歌词背景高斯模糊距离',
          message: '数值越大,模糊效果越明显',
          initialValue: Get.find<SettingsController>().lyricBackgroundBlurRadius
              .toString(),
          onConfirm: (value) async {
            if (isEmpty(value)) return false;
            double? intValue = double.tryParse(value);
            if (intValue == null || intValue < 0) {
              throw '请输入有效的数值';
            }
            Get.find<SettingsController>().lyricBackgroundBlurRadius = intValue
                .toDouble();
            showSuccessSnackbar('设置成功', null);
            return true;
          },
          keyboardType: TextInputType.number,
        );
      },
    ),
    ListTile(
      leading: Icon(Icons.border_outer_rounded),
      title: Text('底部播放栏及歌词页顶部圆角/竖'),
      subtitle: Obx(() {
        return Text(
          Get.find<SettingsController>().lyricBorderRadiusV.toString(),
        );
      }),
      onTap: () async {
        await showInputDialog(
          title: '底部播放栏及歌词页顶部圆角/竖',
          initialValue: Get.find<SettingsController>().lyricBorderRadiusV
              .toString(),
          onConfirm: (value) async {
            if (isEmpty(value)) return false;
            double? intValue = double.tryParse(value);
            if (intValue == null || intValue < 0) {
              throw '请输入有效的数值';
            }
            Get.find<SettingsController>().lyricBorderRadiusV = intValue
                .toDouble();
            showSuccessSnackbar('设置成功', '重启生效');
            return true;
          },
          keyboardType: TextInputType.number,
        );
      },
    ),
    ListTile(
      leading: Icon(Icons.border_top_rounded),
      title: Text('歌词页顶部圆角/横'),
      subtitle: Obx(() {
        return Text(
          Get.find<SettingsController>().lyricBorderRadiusH.toString(),
        );
      }),
      onTap: () async {
        await showInputDialog(
          title: '歌词页顶部圆角/横',
          initialValue: Get.find<SettingsController>().lyricBorderRadiusH
              .toString(),
          onConfirm: (value) async {
            if (isEmpty(value)) return false;
            double? intValue = double.tryParse(value);
            if (intValue == null || intValue < 0) {
              throw '请输入有效的数值';
            }
            Get.find<SettingsController>().lyricBorderRadiusH = intValue
                .toDouble();
            showSuccessSnackbar('设置成功', null);
            return true;
          },
          keyboardType: TextInputType.number,
        );
      },
    ),
  ],
);
