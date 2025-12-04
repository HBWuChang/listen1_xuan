import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/supabase_auth_controller.dart';
import 'package:listen1_xuan/controllers/routeController.dart';
import 'package:listen1_xuan/funcs.dart';

import '../../global_settings_animations.dart';

/// Supabase 登录页面
/// 支持邮箱验证码登录
class SupabaseLoginPage extends StatefulWidget {
  const SupabaseLoginPage({Key? key}) : super(key: key);

  @override
  State<SupabaseLoginPage> createState() => _SupabaseLoginPageState();
}

class _SupabaseLoginPageState extends State<SupabaseLoginPage> {
  final SupabaseAuthController _authController =
      Get.find<SupabaseAuthController>();

  // 邮箱登录控制器
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _emailOtpController = TextEditingController();

  // 表单验证
  final _emailFormKey = GlobalKey<FormState>();

  // 是否显示验证码输入框
  final RxBool _showEmailOtpInput = false.obs;

  final FocusNode _focusNode = FocusNode();
  final FocusNode _focusNode2 = FocusNode();
  @override
  void dispose() {
    _focusNode.dispose(); // 释放 FocusNode
    _focusNode2.dispose(); // 释放 FocusNode
    _emailController.dispose();
    _emailOtpController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        set_inapp_hotkey(false);
      } else {
        set_inapp_hotkey(true);
      }
    });
    _focusNode2.addListener(() {
      if (_focusNode2.hasFocus) {
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
        title: const Text('邮箱登录'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(id: 1),
        ),
      ),
      body: _buildEmailLoginTab(),
    );
  }

  /// 构建邮箱登录标签页
  Widget _buildEmailLoginTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _emailFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.email, size: 80, color: Colors.blue),
            const SizedBox(height: 40),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              focusNode: _focusNode,
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
            Obx(
              () => _showEmailOtpInput.value
                  ? Column(
                      children: [
                        TextFormField(
                          controller: _emailOtpController,
                          keyboardType: TextInputType.number,
                          focusNode: _focusNode2,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: '验证码',
                            hintText: '请输入6位验证码',
                            prefixIcon: Icon(Icons.security),
                            border: OutlineInputBorder(),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入验证码';
                            }
                            if (value.length != 6) {
                              return '请输入6位验证码';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        Obx(
                          () => ElevatedButton(
                            onPressed: _authController.isLoading.value
                                ? null
                                : () => _verifyEmailOtp(),
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
                                : const Text(
                                    '验证并登录',
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Obx(
                          () => _authController.countdown.value > 0
                              ? Text(
                                  '${_authController.countdown.value}秒后可重新发送',
                                  style: const TextStyle(color: Colors.grey),
                                )
                              : TextButton(
                                  onPressed: () => _sendEmailOtp(),
                                  child: const Text('重新发送验证码'),
                                ),
                        ),
                      ],
                    )
                  : Obx(
                      () => ElevatedButton(
                        onPressed: _authController.isLoading.value
                            ? null
                            : () => _sendEmailOtp(),
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
                            : const Text(
                                '发送验证码',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            Obx(
              () => _authController.errorMessage.value.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.all(12),
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
            const SizedBox(height: 20),
            // 分隔线
            const Divider(thickness: 1),
            // 提示信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 提示：',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '通过验证码登录后，可在"Supabase 账号"设置中点击"密码管理"来设置密码，之后即可使用邮箱密码直接登录。',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 发送邮箱验证码
  Future<void> _sendEmailOtp() async {
    // 只验证邮箱字段，不验证验证码字段
    final emailValue = _emailController.text.trim();

    // 手动验证邮箱
    if (emailValue.isEmpty) {
      _authController.errorMessage.value = '请输入邮箱地址';
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailValue)) {
      _authController.errorMessage.value = '请输入有效的邮箱地址';
      return;
    }

    // 清空之前的错误信息
    _authController.errorMessage.value = '';

    final success = await _authController.sendEmailOtp(emailValue);
    if (success) {
      _showEmailOtpInput.value = true;
      showSuccessSnackbar(null, '验证码已发送到您的邮箱');
    }
  }

  /// 验证邮箱验证码
  Future<void> _verifyEmailOtp() async {
    if (_emailFormKey.currentState!.validate()) {
      final success = await _authController.verifyEmailOtp(
        _emailController.text.trim(),
        _emailOtpController.text.trim(),
      );
      if (success) {
        showSuccessSnackbar(null, '登录成功');
        Get.back(id: 1);
      }
    }
  }
}
