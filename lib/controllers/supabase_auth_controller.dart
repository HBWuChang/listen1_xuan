import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:listen1_xuan/models/UserProfile.dart';
import 'package:listen1_xuan/models/Playlist.dart';

/// Supabase 认证控制器
/// 管理用户登录、登出、会话状态等
class SupabaseAuthController extends GetxController {
  final _supabase = Supabase.instance.client;
  
  /// 每个用户最大歌单数量
  static const int maxPlaylistsPerUser = 3;
  
  // 当前用户状态
  final Rx<User?> currentUser = Rx<User?>(null);
  
  // 登录状态
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
  
  @override
  void onInit() {
    super.onInit();
    // 监听认证状态变化
    _supabase.auth.onAuthStateChange.listen((data) {
      final Session? session = data.session;
      
      if (session != null) {
        currentUser.value = session.user;
        isLoggedIn.value = true;
        _updateUserLoginTime();
        _loadUserProfile();
      } else {
        currentUser.value = null;
        isLoggedIn.value = false;
        userProfile.value = null;
      }
    });
    
    // 检查当前会话
    _checkCurrentSession();
  }
  
  @override
  void onClose() {
    _countdownTimer?.cancel();
    super.onClose();
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
  
  /// 发送邮箱验证码
  Future<bool> sendEmailOtp(String email) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      await _supabase.auth.signInWithOtp(
        email: email,
        emailRedirectTo: null,
      );
      
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
      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = '登出失败: ${e.toString()}';
      print('登出失败: $e');
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
        await _supabase.from('users').update({
          'last_login_at': DateTime.now().toIso8601String(),
        }).eq('user_id', currentUser.value!.id);
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
    return userProfile.value?.getDisplayName(currentUser.value?.email) ?? '未知用户';
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
      
      await _supabase.from('users').update({
        'nickname': nickname,
      }).eq('user_id', currentUser.value!.id);
      
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
  Future<Playlist?> createPlaylist({
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
      
      final response = await _supabase
          .from('playlist')
          .insert({
            'user_id': currentUser.value!.id,
            'name': name,
            'data': data,
            'is_share': isShare,
          })
          .select()
          .single();
      
      isLoading.value = false;
      return Playlist.fromJson(response);
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
      if (data != null) updateData['data'] = data;
      if (isShare != null) updateData['is_share'] = isShare;
      
      if (updateData.isEmpty) {
        isLoading.value = false;
        return true;
      }
      
      await _supabase
          .from('playlist')
          .update(updateData)
          .eq('id', playlistId);
      
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
      
      await _supabase
          .from('playlist')
          .delete()
          .eq('id', playlistId);
      
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
  Future<List<Playlist>> getUserPlaylists({bool excludeData = true}) async {
    try {
      if (currentUser.value == null) {
        return [];
      }
      
      // 列表查询时不包含 data 字段以提升性能
      final selectFields = excludeData
          ? 'id,user_id,name,is_share,created_at,updated_at'
          : '*';
      
      final response = await _supabase
          .from('playlist')
          .select(selectFields)
          .eq('user_id', currentUser.value!.id)
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((json) => Playlist.fromJson(json as Map<String, dynamic>))
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
  Future<Playlist?> getPlaylist(String playlistId) async {
    try {
      final response = await _supabase
          .from('playlist')
          .select()
          .eq('id', playlistId)
          .single();
      
      return Playlist.fromJson(response);
    } catch (e) {
      print('获取播放列表失败: $e');
      return null;
    }
  }
  
  /// 获取公开分享的播放列表
  Future<List<Playlist>> getSharedPlaylists() async {
    try {
      final response = await _supabase
          .from('playlist')
          .select()
          .eq('is_share', true)
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((json) => Playlist.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('获取公开播放列表失败: $e');
      return [];
    }
  }
}
