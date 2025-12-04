/// 邮箱密码登录使用示例
/// 
/// 此文件展示如何在您的应用中使用邮箱密码登录功能

import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/supabase_auth_controller.dart';

/// 示例 1: 在页面中使用登录功能
class LoginExample {
  final SupabaseAuthController authController = Get.find<SupabaseAuthController>();

  /// 注册新用户
  Future<void> exampleSignUp() async {
    const email = 'user@example.com';
    const password = 'securePassword123';

    // 调用注册方法
    final success = await authController.signUpWithEmailAndPassword(
      email,
      password,
    );

    if (success) {
      print('✓ 注册成功！用户ID: ${authController.currentUser.value?.id}');
      print('✓ 用户昵称: ${authController.userNickname}');
    } else {
      print('✗ 注册失败: ${authController.errorMessage.value}');
    }
  }

  /// 登录用户
  Future<void> exampleSignIn() async {
    const email = 'user@example.com';
    const password = 'securePassword123';

    // 调用登录方法
    final success = await authController.signInWithEmailAndPassword(
      email,
      password,
    );

    if (success) {
      print('✓ 登录成功！');
      print('✓ 用户邮箱: ${authController.currentUser.value?.email}');
      print('✓ 显示名称: ${authController.displayName}');
    } else {
      print('✗ 登录失败: ${authController.errorMessage.value}');
    }
  }

  /// 登出用户
  Future<void> exampleSignOut() async {
    await authController.signOut();
    print('✓ 已登出');
  }

  /// 监听登录状态变化
  void exampleListenAuthState() {
    // 使用 Obx 响应式监听
    // Obx(() {
    //   if (authController.isLoggedIn.value) {
    //     print('✓ 用户已登录');
    //   } else {
    //     print('✗ 用户未登录');
    //   }
    // });
  }

  /// 检查用户是否为 Pro 用户
  Future<void> exampleCheckProStatus() async {
    final isPro = await authController.checkProStatus();
    print('Pro 用户状态: $isPro');
  }
}

/// 示例 2: 在 Widget 中使用登录信息
class UserProfileExample {
  final SupabaseAuthController authController = Get.find<SupabaseAuthController>();

  /// 获取当前用户信息
  void exampleGetUserInfo() {
    // 获取用户ID
    final userId = authController.currentUser.value?.id;
    print('用户ID: $userId');

    // 获取用户邮箱
    final email = authController.currentUser.value?.email;
    print('用户邮箱: $email');

    // 获取显示名称
    final displayName = authController.displayName;
    print('显示名称: $displayName');

    // 获取用户昵称
    final nickname = authController.userNickname;
    print('用户昵称: $nickname');

    // 获取创建时间
    final createdAt = authController.userCreatedAt;
    print('创建时间: $createdAt');

    // 获取最后登录时间
    final lastLogin = authController.userLastLoginAt;
    print('最后登录: $lastLogin');
  }

  /// 更新用户昵称
  Future<void> exampleUpdateNickname() async {
    final success = await authController.updateNickname('我的新昵称');
    if (success) {
      print('✓ 昵称已更新');
    } else {
      print('✗ 更新失败: ${authController.errorMessage.value}');
    }
  }
}

/// 示例 3: 创建和管理播放列表（Pro 用户功能）
class PlaylistExample {
  final SupabaseAuthController authController = Get.find<SupabaseAuthController>();

  /// 创建新播放列表
  Future<void> exampleCreatePlaylist() async {
    // 检查是否可以创建播放列表
    final canCreate = await authController.canCreatePlaylist();
    if (!canCreate) {
      print('✗ 已达到最大歌单数量');
      return;
    }

    // 创建播放列表
    final playlist = await authController.createPlaylist(
      name: '我的最爱',
      data: {
        'description': '我喜欢的歌曲',
        'songs': [],
      },
      isShare: false,
    );

    if (playlist != null) {
      print('✓ 播放列表已创建: ${playlist.name}');
    } else {
      print('✗ 创建失败: ${authController.errorMessage.value}');
    }
  }

  /// 获取用户所有播放列表
  Future<void> exampleGetPlaylists() async {
    final playlists = await authController.getUserPlaylists(excludeData: true);
    print('✓ 获取到 ${playlists.length} 个播放列表');
    for (var playlist in playlists) {
      print('  - ${playlist.name} (${playlist.id})');
    }
  }

  /// 获取用户歌单数量
  Future<void> exampleGetPlaylistCount() async {
    final count = await authController.getUserPlaylistCount();
    print('歌单数量: $count/${SupabaseAuthController.maxPlaylistsPerUser}');
  }

  /// 获取单个播放列表
  Future<void> exampleGetPlaylist() async {
    const playlistId = 'your-playlist-id';
    final playlist = await authController.getPlaylist(playlistId);
    if (playlist != null) {
      print('✓ 播放列表: ${playlist.name}');
      print('  数据: ${playlist.data}');
    }
  }

  /// 更新播放列表
  Future<void> exampleUpdatePlaylist() async {
    const playlistId = 'your-playlist-id';
    final success = await authController.updatePlaylist(
      playlistId: playlistId,
      name: '更新的名称',
      data: {
        'description': '更新的描述',
        'songs': ['song1', 'song2'],
      },
      isShare: true,
    );

    if (success) {
      print('✓ 播放列表已更新');
    } else {
      print('✗ 更新失败: ${authController.errorMessage.value}');
    }
  }

  /// 删除播放列表
  Future<void> exampleDeletePlaylist() async {
    const playlistId = 'your-playlist-id';
    final success = await authController.deletePlaylist(playlistId);

    if (success) {
      print('✓ 播放列表已删除');
    } else {
      print('✗ 删除失败: ${authController.errorMessage.value}');
    }
  }

  /// 获取公开分享的播放列表
  Future<void> exampleGetSharedPlaylists() async {
    final playlists = await authController.getSharedPlaylists();
    print('✓ 获取到 ${playlists.length} 个公开播放列表');
  }
}

/// 示例 4: 处理常见错误情况
class ErrorHandlingExample {
  final SupabaseAuthController authController = Get.find<SupabaseAuthController>();

  /// 使用 try-catch 处理错误
  Future<void> exampleErrorHandling() async {
    try {
      // 尝试登录
      final success = await authController.signInWithEmailAndPassword(
        'invalid@example.com',
        'wrongpassword',
      );

      if (!success) {
        // 处理特定的错误
        final errorMsg = authController.errorMessage.value;
        if (errorMsg.contains('邮箱或密码不正确')) {
          print('邮箱或密码不正确');
        } else if (errorMsg.contains('用户未登录')) {
          print('用户未登录');
        } else {
          print('其他错误: $errorMsg');
        }
      }
    } catch (e) {
      print('异常: $e');
    }
  }

  /// 监听加载状态
  void exampleListenLoadingState() {
    // 使用 Obx 监听加载状态
    // Obx(() {
    //   if (authController.isLoading.value) {
    //     // 显示加载指示器
    //     print('正在加载...');
    //   }
    // });
  }

  /// 监听错误信息
  void exampleListenErrorMessages() {
    // 使用 Obx 监听错误消息
    // Obx(() {
    //   if (authController.errorMessage.value.isNotEmpty) {
    //     print('错误: ${authController.errorMessage.value}');
    //   }
    // });
  }
}

/// 示例 5: 使用验证码登录（旧方法）
class OtpExample {
  final SupabaseAuthController authController = Get.find<SupabaseAuthController>();

  /// 发送邮箱验证码
  Future<void> exampleSendOtp() async {
    const email = 'user@example.com';
    final success = await authController.sendEmailOtp(email);

    if (success) {
      print('✓ 验证码已发送');
      print('倒计时: ${authController.countdown.value} 秒');
    } else {
      print('✗ 发送失败: ${authController.errorMessage.value}');
    }
  }

  /// 验证邮箱验证码
  Future<void> exampleVerifyOtp() async {
    const email = 'user@example.com';
    const otp = '123456';

    final success = await authController.verifyEmailOtp(email, otp);

    if (success) {
      print('✓ 验证成功，已登录');
    } else {
      print('✗ 验证失败: ${authController.errorMessage.value}');
    }
  }
}

/// 使用说明：
/// 
/// 1. 在您的 Widget 中获取 SupabaseAuthController:
///    ```dart
///    final authController = Get.find<SupabaseAuthController>();
///    ```
/// 
/// 2. 在 initState 或 onInit 中监听状态：
///    ```dart
///    ever(authController.isLoggedIn, (isLogged) {
///      if (isLogged) {
///        // 用户已登录，刷新UI
///      }
///    });
///    ```
/// 
/// 3. 处理异步操作：
///    ```dart
///    onPressed: () async {
///      final success = await authController.signInWithEmailAndPassword(
///        email,
///        password,
///      );
///      if (success) {
///        // 导航到下一页
///        Get.off(() => HomePage());
///      }
///    }
///    ```
