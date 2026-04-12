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
            SizedBox(width: 10),
            Expanded(
              child: ElevatedButtonIcon(
                onPressed: importSettingsFromFile,
                icon: Icon(Icons.upload),
                label: Text('导入配置文件'),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButtonIcon(
                onPressed: outputPlaylistToGithubGist,
                icon: Icon(Icons.playlist_play),
                label: Text('导出歌单到Github Gist'),
              ),
            ),
            SizedBox(width: 10),
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
        SizedBox(height: 10),
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

/// 显示赞助弹窗
void _showSponsorDialog(BuildContext context) {
  final authController = Get.find<SupabaseAuthController>();
  final userId = authController.currentUser.value?.id ?? '';

  final markdownContent = '''
### 由于免费版 Supabase 账号的500MB 存储空间限制，我决定对部分占用空间较大功能进行限制。
### 目前实现的会进行限制的功能：
- **Supabase 歌单管理**：可以将您的歌单保存到 Supabase 中,但限制最多3条记录；这实际上与使用Github Gist完全相同，唯一的优点只有受国内网络影响较小，速度通常较快。
### 预计实现的会进行限制的功能：
- **自动歌单同步**：未来计划实现自动在多设备间同步歌单功能。

## 如果您想使用受限制功能请：

### 1️⃣ 复制您的用户 ID

您的用户 ID：

''';

  final markdownContent2 = '''

### 2️⃣ 向我发送邮件
### 发送邮件至：**[bian_xie@qq.com](mailto:bian_xie@qq.com)** 并包含您的用户ID



在收到您的邮件后，我会手动更改您的账号以解锁受限功能，之后会给您回邮件，还请您耐心等待。
### 但请注意：
- 视Supabase 免费账号的存储空间的使用情况，未来可能会调整受限功能的范围，也可能取消您的权限，甚至整个Supabase功能均会被删除。
- 请勿使用多个账号反复申请解锁，以免造成不必要的麻烦。
- 若您有任何疑问，请随时通过邮件与我联系。
- 受限用户的判断是通过users表中的“isPro”字段进行的。虽然本应用开源了全部的代码，但由于限制条件位于Supabase的配置中，您并不能通过fork此项目修改源代码来绕过限制。
- 如您觉得本应用对您有帮助，请考虑赞助
💡 感谢您的支持！
''';

  Get.dialog(
    AlertDialog(
      title: Row(
        children: [Icon(Icons.lock_open), SizedBox(width: 8), Text('解锁受限功能')],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MarkdownBody(data: markdownContent),
              // 用户 ID 展示框
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Get.theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Get.theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        userId,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Get.theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: userId));
                        showSuccessSnackbar('已复制', '用户ID已复制到剪贴板');
                      },
                      tooltip: '复制ID',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              MarkdownBody(
                data: markdownContent2,
                selectable: true,
                onTapLink: (text, href, title) {
                  if (href != null) {
                    g_launchURL(Uri.parse(href));
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Get.back();
          },
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
            Clipboard.setData(ClipboardData(text: userId));
            showSuccessSnackbar('已复制', '用户ID已复制到剪贴板');
          },
          icon: Icon(Icons.copy),
          label: Text('复制ID'),
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
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _createNewPlaylist,
              icon: Icon(Icons.add),
              label: Text('新建歌单'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (isLoading.value)
      return Container(height: 300, child: Center(child: globalLoadingAnime));

    if (playlists.isEmpty)
      return Container(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('暂无歌单', style: TextStyle(fontSize: 16, color: Colors.grey)),
              SizedBox(height: 8),
              Text(
                '点击下方按钮新建歌单',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );

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
                    SizedBox(height: 4),
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
                          SizedBox(width: 4),
                          Text(
                            isSubscribed ? '已订阅' : '未订阅',
                            style: TextStyle(
                              fontSize: 12,
                              color: isSubscribed
                                  ? Get.theme.colorScheme.primary
                                  : Colors.grey,
                            ),
                          ),
                          SizedBox(width: 8),
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
                          SizedBox(width: 8),
                          Text('下载'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'overwrite',
                      child: Row(
                        children: [
                          Icon(Icons.upload, size: 20),
                          SizedBox(width: 8),
                          Text('覆盖'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
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
                          SizedBox(width: 8),
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
