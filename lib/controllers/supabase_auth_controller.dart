import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_connect/http/src/utils/utils.dart';
import 'package:listen1_xuan/controllers/controllers.dart';
import 'package:listen1_xuan/controllers/play_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:listen1_xuan/models/UserProfile.dart';
import 'package:listen1_xuan/models/SupabasePlaylist.dart';
import 'package:listen1_xuan/models/SupaContinuePlay.dart';
import 'package:logger/logger.dart';
import 'package:listen1_xuan/settings.dart' as settings;
import 'package:uuid/uuid.dart';

import '../funcs.dart';
import '../settings.dart';

/// Supabase 认证控制器
/// 管理用户登录、登出、会话状态等
class SupabaseAuthController extends GetxController {
  final _supabase = Supabase.instance.client;
  final logger = Logger();

  /// 每个用户最大歌单数量
  static const int maxPlaylistsPerUser = 3;

  // 当前用户状态
  final Rx<User?> currentUser = Rx<User?>(null);

  // 登录状态xiu
  final RxBool isLoggedIn = false.obs;

  // 加载状态
  final RxBool isLoading = false.obs;

  // 用户信息
  final Rx<UserProfile?> userProfile = Rx<UserProfile?>(null);

  // 错误消息
  final RxString errorMessage = ''.obs;

  // 验证码发送倒计时
  final RxInt countdown = 0.obs;
  Timer? _countdownTimer;

  // Supabase 实时订阅相关
  RealtimeChannel? _continuePlayChannel;
  final isSubscribedToContinuePlay = false.obs;

  // Playlist 实时订阅相关
  RealtimeChannel? _playlistChannel;
  final isSubscribedToPlaylist = false.obs;

  @override
  void onInit() {
    super.onInit();
    // 监听认证状态变化
    _supabase.auth.onAuthStateChange.listen(
      (data) {
        final Session? session = data.session;

        if (session != null) {
          currentUser.value = session.user;
          isLoggedIn.value = true;
          _updateUserLoginTime();
          _loadUserProfile();
          // 认证成功后自动订阅 continue_play
          if (Get.find<SettingsController>().supabaseSubPlay) {
            subscribeToContinuePlay();
          }
          // 认证成功后自动订阅 playlist
          subscribeToPlaylist();
        }
        if (data.event.jsName == 'INITIAL_SESSION') {
          _tryReconnectWithSavedCredentials();
        } else if (data.event.jsName == 'SIGNED_OUT') {
          currentUser.value = null;
          isLoggedIn.value = false;
          userProfile.value = null;
          // 登出时自动取消订阅
          unsubscribeFromContinuePlay();
          unsubscribeFromPlaylist();
        }
      },
      onError: (error) {
        logger.e('认证状态监听错误: $error');
        // 尝试使用保存的账号密码进行自动重连
        _tryReconnectWithSavedCredentials();
      },
    );

    // 检查当前会话
    _checkCurrentSession();
  }

  @override
  void onClose() {
    _countdownTimer?.cancel();
    unsubscribeFromContinuePlay();
    unsubscribeFromPlaylist();
    super.onClose();
  }

  /// 使用保存的凭证尝试自动重连
  Future<void> _tryReconnectWithSavedCredentials() async {
    try {
      final settingsController = Get.find<SettingsController>();
      final savedEmail = settingsController.supabaseEmail;
      final savedPassword = settingsController.supabasePassword;

      // 如果没有保存的凭证，则跳过
      if (savedEmail.isEmpty || savedPassword.isEmpty) {
        logger.i('没有保存的账号密码，跳过自动重连');
        return;
      }

      logger.i('尝试使用保存的凭证进行自动重连...');

      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: savedEmail,
        password: savedPassword,
      );

      if (response.session != null) {
        currentUser.value = response.session!.user;
        isLoggedIn.value = true;
        await _updateUserLoginTime();
        logger.i('自动重连成功');
      } else {
        logger.w('自动重连失败：无法获取会话');
      }
    } catch (e) {
      logger.e('自动重连异常: $e');
    }
  }

  /// 检查当前会话
  Future<void> _checkCurrentSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        currentUser.value = session.user;
        isLoggedIn.value = true;
        await _loadUserProfile();
      }
    } catch (e) {
      print('检查会话失败: $e');
    }
  }

  /// 使用邮箱和密码进行注册
  Future<bool> signUpWithEmailAndPassword(String email, String password) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // 创建用户资料
        await _createOrUpdateUserProfile(response.user!.id);
        isLoading.value = false;
        return true;
      }

      isLoading.value = false;
      errorMessage.value = '注册失败';
      return false;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = '注册失败: ${e.toString()}';
      print('邮箱密码注册失败: $e');
      return false;
    }
  }

  /// 使用邮箱和密码进行登录
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session != null) {
        currentUser.value = response.session!.user;
        isLoggedIn.value = true;
        await _updateUserLoginTime();

        // 保存账号密码用于自动重连
        Get.find<SettingsController>().supabaseEmail = email;
        Get.find<SettingsController>().supabasePassword = password;

        isLoading.value = false;
        return true;
      }

      isLoading.value = false;
      errorMessage.value = '登录失败：邮箱或密码不正确';
      return false;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = '登录失败: ${e.toString()}';
      print('邮箱密码登录失败: $e');
      return false;
    }
  }

  /// 发送邮箱验证码
  Future<bool> sendEmailOtp(String email) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      await _supabase.auth.signInWithOtp(email: email, emailRedirectTo: null);

      _startCountdown();
      isLoading.value = false;
      return true;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = '发送验证码失败: ${e.toString()}';
      print('发送邮箱验证码失败: $e');
      return false;
    }
  }

  /// 使用邮箱验证码登录
  Future<bool> verifyEmailOtp(String email, String otp) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final AuthResponse response = await _supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email,
      );

      if (response.session != null) {
        currentUser.value = response.session!.user;
        isLoggedIn.value = true;
        await _createOrUpdateUserProfile(response.session!.user.id);
        await _updateUserLoginTime();
        isLoading.value = false;
        return true;
      }

      isLoading.value = false;
      errorMessage.value = '验证码无效';
      return false;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = '登录失败: ${e.toString()}';
      print('邮箱验证码登录失败: $e');
      return false;
    }
  }

  /// 登出
  Future<void> signOut() async {
    try {
      isLoading.value = true;
      await _supabase.auth.signOut();
      currentUser.value = null;
      isLoggedIn.value = false;
      userProfile.value = null;

      // 清除保存的账号密码
      Get.find<SettingsController>().supabaseEmail = '';
      Get.find<SettingsController>().supabasePassword = '';

      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = '登出失败: ${e.toString()}';
      showErrorSnackbar('登出失败', e.toString());
    }
  }

  /// 创建或更新用户资料
  Future<void> _createOrUpdateUserProfile(String userId) async {
    try {
      // 检查用户是否已存在
      final response = await _supabase
          .from('users')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // 创建新用户记录
        await _supabase.from('users').insert({
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
          'last_login_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('创建/更新用户资料失败: $e');
    }
  }

  /// 更新用户最后登录时间
  Future<void> _updateUserLoginTime() async {
    try {
      if (currentUser.value != null) {
        await _supabase
            .from('users')
            .update({'last_login_at': DateTime.now().toIso8601String()})
            .eq('user_id', currentUser.value!.id);
      }
    } catch (e) {
      print('更新登录时间失败: $e');
    }
  }

  /// 加载用户资料
  Future<void> _loadUserProfile() async {
    try {
      if (currentUser.value != null) {
        final response = await _supabase
            .from('users')
            .select()
            .eq('user_id', currentUser.value!.id)
            .single();

        userProfile.value = UserProfile.fromJson(response);
      }
    } catch (e) {
      print('加载用户资料失败: $e');
    }
  }

  /// 刷新用户资料
  Future<void> refreshUserProfile() async {
    await _loadUserProfile();
  }

  /// 开始倒计时
  void _startCountdown() {
    countdown.value = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (countdown.value > 0) {
        countdown.value--;
      } else {
        timer.cancel();
      }
    });
  }

  /// 获取用户显示名称
  String get displayName {
    return userProfile.value?.getDisplayName(currentUser.value?.email) ??
        '未知用户';
  }

  /// 获取用户昵称
  String? get userNickname {
    return userProfile.value?.nickname;
  }

  /// 更新用户昵称
  Future<bool> updateNickname(String nickname) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      if (currentUser.value == null) {
        errorMessage.value = '用户未登录';
        isLoading.value = false;
        return false;
      }

      await _supabase
          .from('users')
          .update({'nickname': nickname})
          .eq('user_id', currentUser.value!.id);

      // 刷新用户资料
      await _loadUserProfile();

      isLoading.value = false;
      return true;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = '更新昵称失败: ${e.toString()}';
      print('更新昵称失败: $e');
      return false;
    }
  }

  /// 获取用户创建时间
  DateTime? get userCreatedAt {
    return userProfile.value?.createdAt;
  }

  /// 获取用户最后登录时间
  DateTime? get userLastLoginAt {
    return userProfile.value?.lastLoginAt;
  }

  /// 获取用户是否为 Pro 用户
  bool get isPro {
    return userProfile.value?.isPro ?? false;
  }

  /// 刷新用户 Pro 状态
  Future<bool> checkProStatus() async {
    try {
      if (currentUser.value == null) {
        return false;
      }

      await _loadUserProfile();
      return isPro;
    } catch (e) {
      print('检查 Pro 状态失败: $e');
      return false;
    }
  }

  /// 创建播放列表
  /// 注意：isPro 验证在数据库层通过 RLS 策略完成
  /// 如果用户不是 Pro 用户，数据库会拒绝写入操作
  Future<SupabasePlaylist?> createPlaylist({
    required String name,
    required Map<String, dynamic> data,
    bool isShare = false,
  }) async {
    try {
      if (currentUser.value == null) {
        errorMessage.value = '用户未登录';
        return null;
      }

      isLoading.value = true;
      errorMessage.value = '';

      // 生成 UUID v4 作为 update_id
      final updateId = _generateUuidV4();

      final response = await _supabase
          .from('playlist')
          .insert({
            'user_id': currentUser.value!.id,
            'name': name,
            'data': data,
            'is_share': isShare,
            'update_id': updateId,
          })
          .select()
          .single();

      isLoading.value = false;
      return SupabasePlaylist.fromJson(response);
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = '创建播放列表失败: ${e.toString()}';
      print('创建播放列表失败: $e');
      return null;
    }
  }

  /// 更新播放列表
  /// 注意：isPro 验证在数据库层通过 RLS 策略完成
  Future<bool> updatePlaylist({
    required String playlistId,
    String? name,
    Map<String, dynamic>? data,
    bool? isShare,
  }) async {
    try {
      if (currentUser.value == null) {
        errorMessage.value = '用户未登录';
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      String updateId = _generateUuidV4();
      if (data != null) {
        updateData['data'] = data;
        // 当更新 data 时，生成新的 update_id
        updateData['update_id'] = updateId;
        if (Get.find<SettingsController>().supabaseBackupPlayListUpdateIdMap
            .containsKey(playlistId)) {
          Get.find<SettingsController>()
                  .supabaseBackupPlayListUpdateIdMap[playlistId] =
              updateId;
        }
      }
      if (isShare != null) updateData['is_share'] = isShare;

      if (updateData.isEmpty) {
        isLoading.value = false;
        return true;
      }

      await _supabase.from('playlist').update(updateData).eq('id', playlistId);

      isLoading.value = false;
      return true;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = '更新播放列表失败: ${e.toString()}';
      print('更新播放列表失败: $e');
      return false;
    }
  }

  /// 删除播放列表
  /// 注意：isPro 验证在数据库层通过 RLS 策略完成
  Future<bool> deletePlaylist(String playlistId) async {
    try {
      if (currentUser.value == null) {
        errorMessage.value = '用户未登录';
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      await _supabase.from('playlist').delete().eq('id', playlistId);

      isLoading.value = false;
      return true;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = '删除播放列表失败: ${e.toString()}';
      print('删除播放列表失败: $e');
      return false;
    }
  }

  /// 获取用户的所有播放列表
  /// excludeData: 是否排除 data 字段(用于列表展示,减少数据传输)
  Future<List<SupabasePlaylist>> getUserPlaylists({
    bool excludeData = true,
  }) async {
    try {
      if (currentUser.value == null) {
        return [];
      }

      // 列表查询时不包含 data 字段以提升性能，但始终包含 update_id
      final selectFields = excludeData
          ? 'id,user_id,name,is_share,created_at,updated_at,update_id'
          : '*';

      final response = await _supabase
          .from('playlist')
          .select(selectFields)
          .eq('user_id', currentUser.value!.id)
          .order('created_at', ascending: false);

      return (response as List)
          .map(
            (json) => SupabasePlaylist.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      print('获取播放列表失败: $e');
      return [];
    }
  }

  /// 获取用户歌单数量
  Future<int> getUserPlaylistCount() async {
    try {
      if (currentUser.value == null) {
        return 0;
      }

      final playlists = await getUserPlaylists();
      return playlists.length;
    } catch (e) {
      print('获取歌单数量失败: $e');
      return 0;
    }
  }

  /// 检查是否可以创建新歌单
  Future<bool> canCreatePlaylist() async {
    final count = await getUserPlaylistCount();
    return count < maxPlaylistsPerUser;
  }

  /// 获取单个播放列表
  Future<SupabasePlaylist?> getPlaylist(String playlistId) async {
    try {
      final response = await _supabase
          .from('playlist')
          .select()
          .eq('id', playlistId)
          .single();

      return SupabasePlaylist.fromJson(response);
    } catch (e) {
      print('获取播放列表失败: $e');
      return null;
    }
  }

  /// 获取公开分享的播放列表
  Future<List<SupabasePlaylist>> getSharedPlaylists() async {
    try {
      final response = await _supabase
          .from('playlist')
          .select()
          .eq('is_share', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map(
            (json) => SupabasePlaylist.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      print('获取公开播放列表失败: $e');
      return [];
    }
  }

  /// 订阅 continue_play 流
  /// 在用户登录后自动调用
  Future<void> subscribeToContinuePlay() async {
    try {
      // 如果已经订阅，先取消订阅
      if (_continuePlayChannel != null) {
        await unsubscribeFromContinuePlay();
      }

      final userId = currentUser.value?.id;
      if (userId == null) {
        logger.w('用户ID为空，无法订阅 continue_play');
        return;
      }

      // 创建 Realtime Channel
      _continuePlayChannel = _supabase
          .channel('continue_play_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'continue_play',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              _handleContinuePlayUpdate(payload);
            },
          )
          .subscribe();

      isSubscribedToContinuePlay.value = true;
      logger.i('成功订阅 continue_play 流');

      // 订阅成功后，手动查询并触发一次更新（如果数据存在）
      await _fetchAndTriggerInitialUpdate(userId);
    } catch (e) {
      logger.e('订阅 continue_play 失败: $e');
    }
  }

  /// 取消订阅 continue_play 流
  /// 在用户登出时自动调用
  Future<void> unsubscribeFromContinuePlay() async {
    try {
      if (_continuePlayChannel != null) {
        await _supabase.removeChannel(_continuePlayChannel!);
        _continuePlayChannel = null;
        isSubscribedToContinuePlay.value = false;
        logger.i('已取消订阅 continue_play 流');
      }
    } catch (e) {
      logger.e('取消订阅 continue_play 失败: $e');
    }
  }

  /// 处理 continue_play 更新事件
  /// [payload] Postgres 变更负载
  void _handleContinuePlayUpdate(PostgresChangePayload payload) {
    try {
      // 解析更新数据
      final continuePlay = SupaContinuePlay.fromJson(payload.newRecord);
      final updateDeviceId = payload.newRecord['device_id'] as String? ?? '';

      final playController = Get.find<PlayController>();
      playController.handleContinuePlayUpdate(continuePlay, updateDeviceId);
    } catch (e) {
      logger.e('处理 continue_play 更新失败: $e');
    }
  }

  /// 获取并触发初始更新
  /// 在订阅成功后调用，如果 continue_play 表中存在数据则手动触发一次更新
  Future<void> _fetchAndTriggerInitialUpdate(String userId) async {
    try {
      logger.d('查询 continue_play 初始数据...');

      // 查询当前用户的 continue_play 数据
      final response = await _supabase
          .from('continue_play')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        logger.i('发现 continue_play 数据，触发初始更新');

        // 解析数据并触发更新
        final continuePlay = SupaContinuePlay.fromJson(response);
        final updateDeviceId = response['device_id'] as String? ?? '';

        try {
          final playController = Get.find<PlayController>();
          playController.handleContinuePlayUpdate(continuePlay, updateDeviceId);
        } catch (e) {
          logger.w('PlayController 未就绪，跳过初始更新: $e');
        }
      } else {
        logger.d('未找到 continue_play 数据');
      }
    } catch (e) {
      logger.e('获取初始 continue_play 数据失败: $e');
    }
  }

  /// 手动重新订阅（用于调试或重连）
  Future<void> resubscribeToContinuePlay() async {
    if (isLoggedIn.value) {
      await subscribeToContinuePlay();
    } else {
      logger.w('用户未登录，无法订阅');
    }
  }

  /// 设置密码（用于 OTP 登录后的用户设置密码）
  Future<bool> setPassword(String newPassword) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      if (currentUser.value == null) {
        errorMessage.value = '用户未登录';
        isLoading.value = false;
        return false;
      }

      if (newPassword.length < 6) {
        errorMessage.value = '密码至少需要6个字符';
        isLoading.value = false;
        return false;
      }

      await _supabase.auth.updateUser(UserAttributes(password: newPassword));

      isLoading.value = false;
      return true;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = '设置密码失败: ${e.toString()}';
      print('设置密码失败: $e');
      return false;
    }
  }

  /// 修改密码
  Future<bool> updatePassword(String oldPassword, String newPassword) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      if (currentUser.value == null) {
        errorMessage.value = '用户未登录';
        isLoading.value = false;
        return false;
      }

      if (newPassword.length < 6) {
        errorMessage.value = '新密码至少需要6个字符';
        isLoading.value = false;
        return false;
      }

      // 先验证旧密码是否正确
      try {
        await _supabase.auth.signInWithPassword(
          email: currentUser.value!.email ?? '',
          password: oldPassword,
        );
      } catch (e) {
        errorMessage.value = '旧密码不正确';
        isLoading.value = false;
        return false;
      }

      // 更新密码
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));

      isLoading.value = false;
      return true;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = '修改密码失败: ${e.toString()}';
      print('修改密码失败: $e');
      return false;
    }
  }

  // ==================== Token 管理相关方法 ====================

  /// 上传指定平台的 token 到云端
  /// [platform] 平台代码 (bl, ne, qq, github)
  /// [token] token 值
  Future<bool> uploadPlatformToken(String platform, String token) async {
    try {
      if (currentUser.value == null) {
        errorMessage.value = '用户未登录';
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      // 检查用户是否已有 tokens 记录
      final existing = await _supabase
          .from('tokens')
          .select()
          .eq('user_id', currentUser.value!.id)
          .maybeSingle();

      if (existing == null) {
        // 创建新记录
        await _supabase.from('tokens').insert({
          'user_id': currentUser.value!.id,
          platform: token,
        });
      } else {
        // 更新现有记录
        await _supabase
            .from('tokens')
            .update({platform: token})
            .eq('user_id', currentUser.value!.id);
      }

      isLoading.value = false;
      return true;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = '上传 token 失败: ${e.toString()}';
      logger.e('上传 token 失败: $e');
      return false;
    }
  }

  /// 从云端下载指定平台的 token
  /// [platform] 平台代码 (bl, ne, qq, github)
  /// 返回 token 字符串，如果不存在则返回 null
  Future<String?> downloadPlatformToken(String platform) async {
    try {
      if (currentUser.value == null) {
        errorMessage.value = '用户未登录';
        return null;
      }

      isLoading.value = true;
      errorMessage.value = '';

      final response = await _supabase
          .from('tokens')
          .select(platform)
          .eq('user_id', currentUser.value!.id)
          .maybeSingle();

      isLoading.value = false;

      if (response == null) {
        return null;
      }

      return response[platform] as String?;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = '下载 token 失败: ${e.toString()}';
      logger.e('下载 token 失败: $e');
      return null;
    }
  }

  /// 删除云端指定平台的 token
  /// [platform] 平台代码 (bl, ne, qq, github)
  Future<bool> deletePlatformToken(String platform) async {
    try {
      if (currentUser.value == null) {
        errorMessage.value = '用户未登录';
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      // 将指定平台的 token 设置为 null
      await _supabase
          .from('tokens')
          .update({platform: null})
          .eq('user_id', currentUser.value!.id);

      isLoading.value = false;
      return true;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = '删除 token 失败: ${e.toString()}';
      logger.e('删除 token 失败: $e');
      return false;
    }
  }

  /// 获取云端所有平台的 token
  /// 返回一个 Map，key 为平台代码，value 为 token
  Future<Map<String, String?>> getAllCloudTokens() async {
    try {
      if (currentUser.value == null) {
        return {};
      }

      final response = await _supabase
          .from('tokens')
          .select('bl, ne, qq, github')
          .eq('user_id', currentUser.value!.id)
          .maybeSingle();

      if (response == null) {
        return {};
      }

      return {
        'bl': response['bl'] as String?,
        'ne': response['ne'] as String?,
        'qq': response['qq'] as String?,
        'github': response['github'] as String?,
      };
    } catch (e) {
      logger.e('获取云端 tokens 失败: $e');
      return {};
    }
  }

  /// 一键上传所有平台的 token 到云端
  Future<bool> uploadAllTokens() async {
    try {
      if (currentUser.value == null) {
        errorMessage.value = '用户未登录';
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      // 获取所有本地 token
      final tokens = <String, String?>{};
      for (var platform in ['bl', 'ne', 'qq', 'github']) {
        final token = await settings.outputPlatformToken(platform);
        if (token != null && token.isNotEmpty) {
          tokens[platform] = token;
        }
      }

      if (tokens.isEmpty) {
        errorMessage.value = '没有可上传的 token';
        isLoading.value = false;
        return false;
      }

      // 检查用户是否已有 tokens 记录
      final existing = await _supabase
          .from('tokens')
          .select()
          .eq('user_id', currentUser.value!.id)
          .maybeSingle();

      if (existing == null) {
        // 创建新记录
        tokens['user_id'] = currentUser.value!.id;
        await _supabase.from('tokens').insert(tokens);
      } else {
        // 更新现有记录
        await _supabase
            .from('tokens')
            .update(tokens)
            .eq('user_id', currentUser.value!.id);
      }

      isLoading.value = false;
      return true;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = '一键上传失败: ${e.toString()}';
      logger.e('一键上传失败: $e');
      return false;
    }
  }

  /// 一键下载所有平台的 token 到本地
  Future<bool> downloadAllTokens() async {
    try {
      if (currentUser.value == null) {
        errorMessage.value = '用户未登录';
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      final cloudTokens = await getAllCloudTokens();

      if (cloudTokens.isEmpty) {
        errorMessage.value = '云端没有可下载的 token';
        isLoading.value = false;
        return false;
      }

      // 将云端 token 保存到本地
      for (var entry in cloudTokens.entries) {
        if (entry.value != null && entry.value!.isNotEmpty) {
          await settings.savePlatformToken(
            entry.key,
            entry.value!,
            saveRightNow: false,
          );
        }
      }

      // 最后统一保存设置
      Get.find<SettingsController>().saveSettings();

      isLoading.value = false;
      return true;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = '一键下载失败: ${e.toString()}';
      logger.e('一键下载失败: $e');
      return false;
    }
  }

  // ==================== Playlist 订阅相关方法 ====================

  /// 订阅 playlist 流
  /// 在用户登录后可手动调用
  Future<void> subscribeToPlaylist() async {
    try {
      // 如果已经订阅，先取消订阅
      if (_playlistChannel != null) {
        await unsubscribeFromPlaylist();
      }

      final userId = currentUser.value?.id;
      if (userId == null) {
        logger.w('用户未登录，无法订阅 playlist');
        return;
      }

      logger.i('开始订阅 playlist 流，用户ID: $userId');

      // 创建 Realtime Channel
      _playlistChannel = _supabase
          .channel('playlist_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'playlist',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: _handlePlaylistUpdate,
          )
          .subscribe();

      isSubscribedToPlaylist.value = true;
      logger.i('成功订阅 playlist 流');

      // 订阅成功后，检查是否有需要更新的歌单
      await checkPlaylistUpdates();
    } catch (e) {
      logger.e('订阅 playlist 失败: $e');
    }
  }

  /// 取消订阅 playlist 流
  Future<void> unsubscribeFromPlaylist() async {
    try {
      if (_playlistChannel != null) {
        await _supabase.removeChannel(_playlistChannel!);
        _playlistChannel = null;
        isSubscribedToPlaylist.value = false;
        logger.i('已取消订阅 playlist 流');
      }
    } catch (e) {
      logger.e('取消订阅 playlist 失败: $e');
    }
  }

  /// 处理 playlist 更新事件
  void _handlePlaylistUpdate(PostgresChangePayload payload) {
    try {
      logger.d('收到 playlist 更新事件: ${payload.newRecord}');

      final playlistId = payload.newRecord['id'] as String?;
      final updateId = payload.newRecord['update_id'] as String?;

      if (playlistId == null || updateId == null) {
        logger.w(
          'playlist 更新事件数据不完整: playlistId=$playlistId, updateId=$updateId',
        );
        return;
      }

      final settingsController = Get.find<SettingsController>();
      final localUpdateIdMap =
          settingsController.supabaseBackupPlayListUpdateIdMap;

      logger.d('本地订阅的歌单: ${localUpdateIdMap.keys.toList()}');

      // 检查本地是否订阅了此歌单
      if (!localUpdateIdMap.containsKey(playlistId)) {
        logger.d('未订阅歌单 $playlistId，忽略更新');
        return;
      }

      final localUpdateId = localUpdateIdMap[playlistId];
      logger.d('本地 updateId: $localUpdateId, 云端 updateId: $updateId');

      // 如果 updateId 不同，说明有更新
      if (localUpdateId != updateId) {
        logger.i('检测到歌单 $playlistId 有更新: $localUpdateId -> $updateId');
        _onPlaylistUpdated(playlistId, payload.newRecord);
      } else {
        logger.d('歌单 $playlistId 的 updateId 相同，无需更新');
      }
    } catch (e) {
      logger.e('处理 playlist 更新失败: $e');
    }
  }

  Set<String> inupdateProcess = {};

  /// 歌单更新回调（暂为空，待实现）
  void _onPlaylistUpdated(String playlistId, Map<String, dynamic> newData) {
    if (inupdateProcess.contains(playlistId)) {
      logger.w('歌单 $playlistId 正在更新中，跳过重复通知');
      return;
    }
    inupdateProcess.add(playlistId);
    logger.i('歌单 $playlistId 已更新，新的 data: $newData');
    RxBool loading = false.obs;
    String dateStr = newData['updated_at'] ?? '';
    dateStr = dateStr.replaceAll('T', ' ').split('.').first;
    smoothSheetToast.showToast(
      icon: Obx(
        () => loading.value
            ? Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Get.theme.colorScheme.onPrimary,
                  ),
                ),
              )
            : Icon(Icons.playlist_play_rounded),
      ),
      onDismiss: () => inupdateProcess.remove(playlistId),
      builder: (context, controller) {
        return Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ListTile(
                contentPadding: EdgeInsets.only(left: 16),
                title: Text(
                  'Supabase歌单更新',
                  style: Get.theme.textTheme.titleMedium,
                ),
                subtitle: FittedBox(
                  child: Text(
                    '${newData['name']}更新于$dateStr',
                    maxLines: 1,
                    style: Get.theme.textTheme.bodyMedium,
                  ),
                ),
                trailing: IconButton(
                  onPressed: controller.peek,
                  icon: Icon(Icons.minimize_rounded),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(
                    () => TextButton(
                      onPressed: loading.value
                          ? null
                          : () {
                              Get.find<SettingsController>()
                                      .supabaseBackupPlayListUpdateIdMap[playlistId] =
                                  newData['update_id'] ?? '';
                              controller.hide();
                            },
                      child: Text(
                        '忽略本次更新',
                        style: TextStyle(color: Get.theme.colorScheme.primary),
                      ),
                    ),
                  ),
                  Obx(
                    () => ElevatedButton.icon(
                      onPressed: loading.value
                          ? null
                          : () async {
                              loading.value = true;
                              try {
                                if (await downloadSupabasePlaylist(
                                  SupabasePlaylist(
                                    id: playlistId,
                                    userId: newData['user_id'] ?? '',
                                    name: newData['name'],
                                  ),
                                )) {
                                  controller.hide();
                                }
                              } catch (e) {
                                showErrorSnackbar('更新歌单失败', e.toString());
                              } finally {
                                loading.value = false;
                              }
                            },
                      icon: loading.value
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Get.theme.colorScheme.onPrimary,
                              ),
                            )
                          : Icon(Icons.download_rounded),
                      label: Text('更新歌单'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 检查所有订阅的歌单是否有更新
  Future<void> checkPlaylistUpdates() async {
    try {
      final userId = currentUser.value?.id;
      if (userId == null) return;

      final settingsController = Get.find<SettingsController>();
      final localUpdateIdMap =
          settingsController.supabaseBackupPlayListUpdateIdMap;

      if (localUpdateIdMap.isEmpty) {
        logger.d('没有订阅的歌单，跳过检查');
        return;
      }

      // 获取所有订阅的歌单ID
      final subscribedIds = localUpdateIdMap.keys.toList();

      // 从 Supabase 查询这些歌单的最新 update_id
      final response = await _supabase
          .from('playlist')
          .select('id,update_id,name,updated_at')
          .eq('user_id', userId)
          .inFilter('id', subscribedIds);
      Set<String> idInClouds = {};
      for (var record in response as List) {
        final playlistId = record['id'] as String;
        final cloudUpdateId = record['update_id'] as String?;
        final localUpdateId = localUpdateIdMap[playlistId];
        idInClouds.add(playlistId);
        if (cloudUpdateId != null && localUpdateId != cloudUpdateId) {
          logger.i('检测到歌单 $playlistId 有更新: $localUpdateId -> $cloudUpdateId');
          _onPlaylistUpdated(playlistId, record);
        }
      }
      Get.find<SettingsController>().supabaseBackupPlayListUpdateIdMap
          .removeWhere((key, value) => !idInClouds.contains(key));
    } catch (e) {
      logger.e('检查歌单更新失败: $e');
    }
  }

  /// 手动重新订阅 Playlist（用于调试或重连）
  Future<void> resubscribeToPlaylist() async {
    if (isLoggedIn.value) {
      await subscribeToPlaylist();
    } else {
      logger.w('用户未登录，无法订阅');
    }
  }

  /// 生成 UUID v4
  String _generateUuidV4() {
    return Uuid().v4();
  }
}
