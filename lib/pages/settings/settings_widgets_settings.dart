part of '../../settings.dart';

Widget settingsWidget(BuildContext context) {
  return Padding(
    padding: EdgeInsets.all(10),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButtonIcon(
                onPressed: () async => outputAllSettingsToFile(false),
                icon: Icon(Icons.save),
                label: Text('保存配置到文件'),
              ),
            ),
            10.sbw,
            Expanded(
              child: ElevatedButtonIcon(
                onPressed: importSettingsFromFile,
                icon: Icon(Icons.upload),
                label: Text('导入配置文件'),
              ),
            ),
          ],
        ),
        10.sbh,
        Row(
          children: [
            Expanded(
              child: ElevatedButtonIcon(
                onPressed: outputPlaylistToGithubGist,
                icon: Icon(Icons.playlist_play),
                label: Text('导出歌单到Github Gist'),
              ),
            ),
            10.sbw,
            Expanded(
              child: ElevatedButtonIcon(
                onPressed: () async {
                  if (Github.status != 2) {
                    await Github.updateStatus();
                    if (Github.status != 2) {
                      showInfoSnackbar('请先登录Github', '');
                      return;
                    }
                  }
                  var playlists = await Github.listExistBackup();
                  print(playlists);

                  try {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('从Github Gist导入歌单'),
                          content: Container(
                            width: double.maxFinite,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: playlists.length,
                              itemBuilder: (BuildContext context, int index) {
                                final playlist = playlists[index];
                                return ListTile(
                                  title: Text(playlist['id']),
                                  subtitle: Text(playlist['description']),
                                  onTap: () async {
                                    try {
                                      // showInfoSnackbar('正在导入', null);
                                      final msg =
                                          '正在导入歌单 ${playlist['id']}\n正在从Github Gist获取配置文件'
                                              .obs;
                                      showLoadingDialog(msg);
                                      final jsfile =
                                          await Github.importMySettingsFromGist(
                                            playlist['id'],
                                          );
                                      msg.value =
                                          '正在导入歌单 ${playlist['id']}\n解析配置文件';
                                      final settings = await Github.gist2json(
                                        jsfile,
                                      );
                                      msg.value =
                                          '正在导入歌单 ${playlist['id']}\n应用配置文件';
                                      await importSettingsFromFile(
                                        true,
                                        settings,
                                      );
                                      Get.back();
                                      Navigator.of(context).pop();
                                      showSuccessSnackbar('导入成功', null);
                                    } catch (e) {
                                      showErrorSnackbar('导入失败', e.toString());
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('取消'),
                            ),
                          ],
                        );
                      },
                    );
                  } catch (e) {
                    showErrorSnackbar('添加失败', e.toString());
                  }
                },

                icon: Icon(Icons.playlist_add),
                label: Text('从Github Gist导入歌单'),
              ),
            ),
          ],
        ),
        10.sbh,
        ElevatedButton.icon(
          onPressed: Get.find<SupabaseAuthController>().isLoggedIn.value
              ? () {
                  if (Get.find<SupabaseAuthController>().isPro) {
                    _showSupabasePlaylistManager(context);
                  } else {
                    // 显示赞助弹窗
                    _showSponsorDialog(context);
                  }
                }
              : null,
          icon: Icon(Icons.cloud_queue),
          label: Text(
            (!Get.find<SupabaseAuthController>().isPro) &&
                    Get.find<SupabaseAuthController>().isLoggedIn.value
                ? '解锁 Supabase 歌单管理功能'
                : 'Supabase 歌单管理',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Get.theme.colorScheme.primaryContainer,
            foregroundColor: Get.theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ],
    ),
  );
}

/// 显示 Pro 申请弹窗
void _showSponsorDialog(BuildContext context) {
  const markdownContent = '''
### 由于 Supabase 免费账号的存储空间有限，部分功能需要 Pro 资格。

### 目前受限制的功能
- **Supabase 歌单管理**：普通用户最多保存 3 条记录，获得 Pro 资格后可解锁此限制。

### 预计实现的功能
- **自动歌单同步**：未来计划支持在多设备间自动同步歌单。

## 申请 Pro 资格
点击下方“发送申请”，将进入“在线反馈”中的申请问题，并自动提及超级管理员、填入“申请成为Pro用户”。您可以补充说明后发送，无需复制用户 ID 或发送邮件。

申请消息和问题中的讨论均公开可见，请勿填写隐私信息。管理员审核后会手动授予 Pro 资格，还请耐心等待。

### 请注意
- 根据 Supabase 存储空间的使用情况，未来可能调整受限功能范围、取消资格或停止 Supabase 功能。
- 请勿使用多个账号反复申请。
- Pro 资格由数据库控制，不包含在线反馈的管理权限。
- 如您觉得本应用对您有帮助，请考虑赞助。感谢您的支持！
''';

  Get.dialog(
    AlertDialog(
      title: Row(children: [Icon(Icons.lock_open), 8.sbw, Text('解锁受限功能')]),
      content: SingleChildScrollView(
        child: MarkdownBody(data: markdownContent, selectable: true),
      ).sbw(double.maxFinite),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text('关闭'),
        ),
        TextButton.icon(
          onPressed: () {
            Get.back();
            Get.toNamed(RouteName.settingsReadmePage, id: 1);
          },
          icon: Icon(Icons.book),
          label: Text('查看 README'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Get.back();
            final args = FeedbackPageArgs.issues(proApplication: true);
            Get.toNamed(args.path, arguments: args, id: 1);
          },
          icon: Icon(Icons.send),
          label: Text('发送申请'),
        ),
      ],
    ),
  );
}

/// 显示 Supabase 歌单管理 Modal Sheet
Future<void> _showSupabasePlaylistManager(BuildContext context) async {
  await WoltModalSheet.show<void>(
    pageIndexNotifier: ValueNotifier(0),
    context: context,
    pageListBuilder: (modalSheetContext) {
      return [
        WoltModalSheetPage(
          hasTopBarLayer: false,

          child: _SupabasePlaylistContent(),
        ),
      ];
    },
  );
}

/// Supabase 歌单管理内容
class _SupabasePlaylistContent extends StatelessWidget {
  final authController = Get.find<SupabaseAuthController>();
  final playlists = <PlaylistModel.SupabasePlaylist>[].obs;
  final isLoading = true.obs;

  _SupabasePlaylistContent() {
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    isLoading.value = true;
    final result = await loadSupabasePlaylists();
    playlists.value = result;
    isLoading.value = false;
  }

  Future<void> _createNewPlaylist() async {
    final playlist = await createSupabasePlaylist();
    if (playlist != null) {
      _loadPlaylists(); // 刷新列表
    }
  }

  Future<void> _renamePlaylist(PlaylistModel.SupabasePlaylist playlist) async {
    final success = await renameSupabasePlaylist(playlist);
    if (success) {
      _loadPlaylists(); // 刷新列表
    }
  }

  Future<void> _deletePlaylist(PlaylistModel.SupabasePlaylist playlist) async {
    final success = await deleteSupabasePlaylist(playlist);
    if (success) {
      _loadPlaylists(); // 刷新列表
    }
  }

  Future<void> _downloadPlaylist(
    PlaylistModel.SupabasePlaylist playlist,
  ) async {
    await downloadSupabasePlaylist(playlist);
  }

  Future<void> _overwritePlaylist(
    PlaylistModel.SupabasePlaylist playlist,
  ) async {
    final success = await overwriteSupabasePlaylist(playlist);
    if (success) {
      _loadPlaylists(); // 刷新列表
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 刷新按钮
        Padding(
          padding: EdgeInsets.all(8),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _loadPlaylists,
              icon: Icon(Icons.refresh),
              label: Text('刷新'),
            ),
          ),
        ),
        // 内容区域 - 使用 AnimatedSize 实现平滑高度变化
        Obx(
          () => AnimatedSize(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _buildContent(),
          ),
        ),
        // 新建按钮
        Padding(
          padding: EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _createNewPlaylist,
            icon: Icon(Icons.add),
            label: Text('新建歌单'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ).sbw(double.infinity),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (isLoading.value)
      return Container(height: 300, child: Center(child: globalLoadingAnime));

    if (playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            16.sbh,
            Text('暂无歌单', style: TextStyle(fontSize: 16, color: Colors.grey)),
            8.sbh,
            Text(
              '点击下方按钮新建歌单',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ).sbh(300);
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: playlists.length,
      padding: EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        final settingsController = Get.find<SettingsController>();

        return Card(
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(child: Icon(Icons.library_music)),
                title: Text(
                  playlist.name,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '创建于: ${playlist.createdAt?.toString().substring(0, 19) ?? "未知"}\n'
                      '更新于: ${playlist.updatedAt?.toString().substring(0, 19) ?? "未知"}',
                    ),
                    4.sbh,
                    // 订阅开关
                    Obx(() {
                      final isSubscribed = isPlaylistSubscribed(playlist.id);

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSubscribed
                                ? Icons.notifications_active
                                : Icons.notifications_off,
                            size: 16,
                            color: isSubscribed
                                ? Get.theme.colorScheme.primary
                                : Colors.grey,
                          ),
                          4.sbw,
                          Text(
                            isSubscribed ? '已订阅' : '未订阅',
                            style: TextStyle(
                              fontSize: 12,
                              color: isSubscribed
                                  ? Get.theme.colorScheme.primary
                                  : Colors.grey,
                            ),
                          ),
                          8.sbw,
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: isSubscribed,
                              onChanged: (value) {
                                togglePlaylistSubscription(
                                  playlistId: playlist.id,
                                  updateId: playlist.updateId,
                                  subscribe: value,
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'download':
                        await _downloadPlaylist(playlist);
                        break;
                      case 'overwrite':
                        await _overwritePlaylist(playlist);
                        break;
                      case 'rename':
                        await _renamePlaylist(playlist);
                        break;
                      case 'delete':
                        await _deletePlaylist(playlist);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'download',
                      child: Row(
                        children: [
                          Icon(Icons.download, size: 20),
                          8.sbw,
                          Text('下载'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'overwrite',
                      child: Row(
                        children: [
                          Icon(Icons.upload, size: 20),
                          8.sbw,
                          Text('覆盖'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          8.sbw,
                          Text('重命名'),
                        ],
                      ),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete,
                            size: 20,
                            color: Get.theme.colorScheme.error,
                          ),
                          8.sbw,
                          Text(
                            '删除',
                            style: TextStyle(
                              color: Get.theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget Function(Widget, Animation<double>) get setSubTitleTextTra =>
    (Widget child, Animation<double> animation) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInCirc),

        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          ),
          child: child,
        ),
      );
    };
Widget Function(Widget? currentChild, List<Widget> previousChildren)
get centerLeftLayoutBuilder =>
    (Widget? currentChild, List<Widget> previousChildren) {
      return Stack(
        alignment: Alignment.centerLeft,
        children: [...previousChildren, if (currentChild != null) currentChild],
      );
    };
AnimatedSwitcher setSubTitleTextAniSwi(Widget child) {
  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 200),
    transitionBuilder: setSubTitleTextTra,
    layoutBuilder: centerLeftLayoutBuilder,
    child: child,
  );
}

// AnimatedSwitcher(
//   duration: const Duration(milliseconds: 200),
//   transitionBuilder: setSubTitleTextTra,
//   layoutBuilder: centerLeftLayoutBuilder,
//   child:
// ),
