import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Supabase 认证控制器
/// 管理用户登录、登出、会话状态等
class SupabaseAuthController extends GetxController {
  final _supabase = Supabase.instance.client;
  
  // 当前用户状态
  final Rx<User?> currentUser = Rx<User?>(null);
  
  // 登录状态
  final RxBool isLoggedIn = false.obs;
  
  // 加载状态
  final RxBool isLoading = false.obs;
  
  // 用户信息
  final RxMap<String, dynamic> userProfile = <String, dynamic>{}.obs;
  
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
        userProfile.clear();
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
      userProfile.clear();
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
        
        userProfile.value = response;
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
    // 优先显示昵称
    if (userProfile['nickname'] != null && userProfile['nickname'].toString().isNotEmpty) {
      return userProfile['nickname'];
    }
    if (currentUser.value?.email != null) {
      return currentUser.value!.email!;
    }
    return '未知用户';
  }
  
  /// 获取用户昵称
  String? get userNickname {
    return userProfile['nickname'];
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
  String? get userCreatedAt {
    return userProfile['created_at'];
  }
  
  /// 获取用户最后登录时间
  String? get userLastLoginAt {
    return userProfile['last_login_at'];
  }
}
