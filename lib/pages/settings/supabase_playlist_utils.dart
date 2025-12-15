part of '../../settings.dart';

/// Supabase 歌单管理工具类
/// 包含歌单的加载、创建、删除、下载、覆盖等操作

/// 加载用户的歌单列表
Future<List<PlaylistModel.SupabasePlaylist>> loadSupabasePlaylists() async {
  final authController = Get.find<SupabaseAuthController>();
  try {
    final result = await authController.getUserPlaylists();
    return result;
  } catch (e) {
    showErrorSnackbar('加载失败', e.toString());
    return [];
  }
}

/// 创建新歌单
/// 返回创建的歌单对象，失败返回 null
Future<PlaylistModel.SupabasePlaylist?> createSupabasePlaylist() async {
  final authController = Get.find<SupabaseAuthController>();

  // 检查是否可以创建新歌单
  final canCreate = await authController.canCreatePlaylist();
  if (!canCreate) {
    showWarningSnackbar(
      '歌单数量已达上限',
      '每个用户最多只能创建 ${SupabaseAuthController.maxPlaylistsPerUser} 个歌单',
    );
    return null;
  }

  // 弹出输入框获取歌单名称
  final name = await showInputDialog(
    title: '新建歌单',
    placeholder: '请输入歌单名称',
    maxLength: 50,
    validator: (value) {
      if (value == null || value.trim().isEmpty) {
        return '歌单名称不能为空';
      }
      return null;
    },
  );

  if (name == null) return null;

  try {
    final msg = '正在保存歌单到 Supabase'.obs;
    showLoadingDialog(msg);

    // 获取当前歌单设置
    final settings = await outputAllSettingsToFile(true);

    // 保存到 Supabase
    final playlist = await authController.createPlaylist(
      name: name,
      data: settings,
      isShare: false,
    );

    Get.back(); // 关闭加载对话框

    if (playlist != null) {
      showSuccessSnackbar('保存成功', '歌单已保存到 Supabase');
      return playlist;
    } else {
      showErrorSnackbar('保存失败', authController.errorMessage.value);
      return null;
    }
  } catch (e) {
    Get.back(); // 关闭加载对话框
    showErrorSnackbar('保存失败', e.toString());
    return null;
  }
}

/// 重命名歌单
/// 返回是否成功
Future<bool> renameSupabasePlaylist(
  PlaylistModel.SupabasePlaylist playlist,
) async {
  final authController = Get.find<SupabaseAuthController>();

  bool success = false;
  await showInputDialog(
    title: '重命名歌单',
    placeholder: '请输入新名称',
    initialValue: playlist.name,
    maxLength: 50,
    validator: (value) {
      if (value == null || value.trim().isEmpty) {
        return '歌单名称不能为空';
      }
      return null;
    },
    onConfirm: (name) async {
      final result = await authController.updatePlaylist(
        playlistId: playlist.id,
        name: name,
      );
      if (result) {
        showSuccessSnackbar('重命名成功', null);
        success = true;
        return true;
      } else {
        throw authController.errorMessage.value;
      }
    },
  );

  return success;
}

/// 删除歌单
/// 返回是否成功
Future<bool> deleteSupabasePlaylist(
  PlaylistModel.SupabasePlaylist playlist,
) async {
  final authController = Get.find<SupabaseAuthController>();

  final confirm = await showConfirmDialog(
    '确定要删除歌单 "${playlist.name}" 吗？',
    '删除歌单',
    confirmLevel: ConfirmLevel.danger,
  );

  if (!confirm) return false;

  final success = await authController.deletePlaylist(playlist.id);
  if (success) {
    showSuccessSnackbar('删除成功', null);
    return true;
  } else {
    showErrorSnackbar('删除失败', authController.errorMessage.value);
    return false;
  }
}

/// 下载歌单并应用到当前设置
/// 返回是否成功
Future<bool> downloadSupabasePlaylist(
  PlaylistModel.SupabasePlaylist playlist,
) async {
  final authController = Get.find<SupabaseAuthController>();

  try {
    final msg = '正在下载歌单 ${playlist.name}\n获取歌单数据'.obs;
    showLoadingDialog(msg);

    // 获取完整的歌单数据(包含 data 字段)
    final fullPlaylist = await authController.getPlaylist(playlist.id);

    if (fullPlaylist == null) {
      Get.back();
      showErrorSnackbar('下载失败', '无法获取歌单数据');
      return false;
    }

    msg.value = '正在下载歌单 ${playlist.name}\n应用配置文件';
    await importSettingsFromFile(true, fullPlaylist.data);
    if (Get.find<SettingsController>().supabaseBackupPlayListUpdateIdMap
        .containsKey(playlist.id)) {
      Map<String, String?> t =
          Get.find<SettingsController>().supabaseBackupPlayListUpdateIdMap;
      t[playlist.id] = fullPlaylist.updateId;
      Get.find<SettingsController>().supabaseBackupPlayListUpdateIdMap = t;
    }
    Get.back();
    showSuccessSnackbar('下载成功', '歌单已应用到当前设置');
    return true;
  } catch (e) {
    Get.back();
    showErrorSnackbar('下载失败', e.toString());
    return false;
  }
}

/// 用当前设置覆盖歌单
/// 返回是否成功
Future<bool> overwriteSupabasePlaylist(
  PlaylistModel.SupabasePlaylist playlist,
) async {
  final authController = Get.find<SupabaseAuthController>();

  final confirm = await showConfirmDialog(
    '确定要用当前设置覆盖歌单 "${playlist.name}" 吗？',
    '覆盖歌单',
    confirmLevel: ConfirmLevel.warning,
  );

  if (!confirm) return false;

  try {
    final msg = '正在覆盖歌单 ${playlist.name}'.obs;
    showLoadingDialog(msg);

    // 获取当前歌单设置
    final settings = await outputAllSettingsToFile(true);

    // 更新到 Supabase
    final success = await authController.updatePlaylist(
      playlistId: playlist.id,
      data: settings,
    );

    Get.back(); // 关闭加载对话框

    if (success) {
      showSuccessSnackbar('覆盖成功', '歌单已更新');
      return true;
    } else {
      showErrorSnackbar('覆盖失败', authController.errorMessage.value);
      return false;
    }
  } catch (e) {
    Get.back(); // 关闭加载对话框
    showErrorSnackbar('覆盖失败', e.toString());
    return false;
  }
}

/// 切换歌单订阅状态
/// [playlistId] 歌单 ID
/// [updateId] 歌单的 update_id
/// [subscribe] true 为订阅，false 为取消订阅
void togglePlaylistSubscription({
  required String playlistId,
  String? updateId,
  required bool subscribe,
}) {
  final settingsController = Get.find<SettingsController>();
  final updateIdMap = settingsController.supabaseBackupPlayListUpdateIdMap;
  final newMap = Map<String, String?>.from(updateIdMap);

  if (subscribe) {
    // 订阅：添加到 map
    newMap[playlistId] = updateId ?? '';
  } else {
    // 取消订阅：从 map 中移除
    newMap.remove(playlistId);
  }

  settingsController.supabaseBackupPlayListUpdateIdMap = newMap;
}

/// 检查歌单是否已订阅
bool isPlaylistSubscribed(String playlistId) {
  final settingsController = Get.find<SettingsController>();
  return settingsController.supabaseBackupPlayListUpdateIdMap.containsKey(
    playlistId,
  );
}
