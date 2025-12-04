import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/supabase_auth_controller.dart';
import 'package:listen1_xuan/controllers/routeController.dart';
import 'package:listen1_xuan/funcs.dart';

import '../../global_settings_animations.dart';

/// Supabase 邮箱密码登录/注册页面
class SupabasePasswordLoginPage extends StatefulWidget {
  const SupabasePasswordLoginPage({Key? key}) : super(key: key);

  @override
  State<SupabasePasswordLoginPage> createState() =>
      _SupabasePasswordLoginPageState();
}

class _SupabasePasswordLoginPageState extends State<SupabasePasswordLoginPage> {
  final SupabaseAuthController _authController =
      Get.find<SupabaseAuthController>();

  // 邮箱密码登录控制器
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // 表单验证
  final _formKey = GlobalKey<FormState>();

  // 是否为注册模式
  final RxBool _isSignUpMode = false.obs;

  // 密码可见性
  final RxBool _isPasswordVisible = false.obs;
  final RxBool _isConfirmPasswordVisible = false.obs;

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _emailFocusNode.addListener(() {
      if (_emailFocusNode.hasFocus) {
        set_inapp_hotkey(false);
      } else {
        set_inapp_hotkey(true);
      }
    });
    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus) {
        set_inapp_hotkey(false);
      } else {
        set_inapp_hotkey(true);
      }
    });
    _confirmPasswordFocusNode.addListener(() {
      if (_confirmPasswordFocusNode.hasFocus) {
        set_inapp_hotkey(false);
      } else {
        set_inapp_hotkey(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(_isSignUpMode.value ? '注册账户' : '邮箱密码登录')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(id: 1),
        ),
      ),
      body: _buildPasswordLoginTab(),
    );
  }

  /// 构建邮箱密码登录标签页
  Widget _buildPasswordLoginTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Icon(
                _isSignUpMode.value ? Icons.person_add : Icons.email,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 40),
              // 邮箱输入框
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                focusNode: _emailFocusNode,
                decoration: const InputDecoration(
                  labelText: '邮箱地址',
                  hintText: '请输入邮箱地址',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入邮箱地址';
                  }
                  // 简单的邮箱格式验证
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value)) {
                    return '请输入有效的邮箱地址';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // 密码输入框
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                obscureText: !_isPasswordVisible.value,
                decoration: InputDecoration(
                  labelText: '密码',
                  hintText: _isSignUpMode.value ? '请设置密码（至少6位）' : '请输入密码',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible.value
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      _isPasswordVisible.toggle();
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入密码';
                  }
                  if (_isSignUpMode.value) {
                    if (value.length < 6) {
                      return '密码至少需要6个字符';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // 确认密码输入框（仅注册模式显示）
              if (_isSignUpMode.value)
                Column(
                  children: [
                    TextFormField(
                      controller: _confirmPasswordController,
                      focusNode: _confirmPasswordFocusNode,
                      obscureText: !_isConfirmPasswordVisible.value,
                      decoration: InputDecoration(
                        labelText: '确认密码',
                        hintText: '请再次输入密码',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordVisible.value
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            _isConfirmPasswordVisible.toggle();
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请再次输入密码';
                        }
                        if (value != _passwordController.text) {
                          return '两次密码输入不一致';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              // 登录/注册按钮
              Obx(
                () => ElevatedButton(
                  onPressed: _authController.isLoading.value
                      ? null
                      : () => _isSignUpMode.value
                          ? _signUp()
                          : _signIn(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: _authController.isLoading.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isSignUpMode.value ? '注册' : '登录',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              // 切换模式
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSignUpMode.value ? '已有账户？' : '没有账户？',
                  ),
                  TextButton(
                    onPressed: () {
                      _isSignUpMode.toggle();
                      _clearForm();
                      _authController.errorMessage.value = '';
                    },
                    child: Text(
                      _isSignUpMode.value ? '立即登录' : '立即注册',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 分隔线
              const Divider(
                thickness: 1,
              ),
             
              // 错误消息
              Obx(
                () => _authController.errorMessage.value.isNotEmpty
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(top: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          _authController.errorMessage.value,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 登录
  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      final success = await _authController.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (success) {
        showSuccessSnackbar(null, '登录成功');
        Get.back(id: 1);
      }
    }
  }

  /// 注册
  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      final success = await _authController.signUpWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (success) {
        showSuccessSnackbar(null, '注册成功，请登录');
        _clearForm();
        _isSignUpMode.value = false;
      }
    }
  }

  /// 清空表单
  void _clearForm() {
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
  }
}
