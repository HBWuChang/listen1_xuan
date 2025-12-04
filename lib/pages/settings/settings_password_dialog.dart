import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/supabase_auth_controller.dart';
import 'package:listen1_xuan/funcs.dart';

/// 设置密码对话框
class SetPasswordDialog extends StatefulWidget {
  /// 是否为修改模式（true=修改，false=设置）
  final bool isUpdateMode;

  const SetPasswordDialog({
    Key? key,
    this.isUpdateMode = false,
  }) : super(key: key);

  @override
  State<SetPasswordDialog> createState() => _SetPasswordDialogState();
}

class _SetPasswordDialogState extends State<SetPasswordDialog> {
  final SupabaseAuthController _authController =
      Get.find<SupabaseAuthController>();

  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final RxBool _isOldPasswordVisible = false.obs;
  final RxBool _isNewPasswordVisible = false.obs;
  final RxBool _isConfirmPasswordVisible = false.obs;

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isUpdateMode ? '修改密码' : '设置密码',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 旧密码输入框（仅修改模式）
              if (widget.isUpdateMode)
                Column(
                  children: [
                    Obx(
                      () => TextFormField(
                        controller: _oldPasswordController,
                        obscureText: !_isOldPasswordVisible.value,
                        decoration: InputDecoration(
                          labelText: '旧密码',
                          hintText: '请输入当前密码',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isOldPasswordVisible.value
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              _isOldPasswordVisible.toggle();
                            },
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入旧密码';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              // 新密码输入框
              Obx(
                () => TextFormField(
                  controller: _newPasswordController,
                  obscureText: !_isNewPasswordVisible.value,
                  decoration: InputDecoration(
                    labelText: '新密码',
                    hintText: '请设置新密码（至少6位）',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isNewPasswordVisible.value
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        _isNewPasswordVisible.toggle();
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入新密码';
                    }
                    if (value.length < 6) {
                      return '密码至少需要6个字符';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              // 确认密码输入框
              Obx(
                () => TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible.value,
                  decoration: InputDecoration(
                    labelText: '确认密码',
                    hintText: '请再次输入新密码',
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
                      return '请确认密码';
                    }
                    if (value != _newPasswordController.text) {
                      return '两次密码输入不一致';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              // 错误提示
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Get.back();
            _authController.errorMessage.value = '';
          },
          child: const Text('取消'),
        ),
        Obx(
          () => ElevatedButton(
            onPressed: _authController.isLoading.value ? null : _handleSubmit,
            child: _authController.isLoading.value
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : Text(widget.isUpdateMode ? '修改' : '设置'),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      bool success;

      if (widget.isUpdateMode) {
        // 修改密码模式
        success = await _authController.updatePassword(
          _oldPasswordController.text,
          _newPasswordController.text,
        );
      } else {
        // 设置密码模式
        success = await _authController.setPassword(
          _newPasswordController.text,
        );
      }

      if (success) {
        showSuccessSnackbar(null, '${widget.isUpdateMode ? '修改' : '设置'}密码成功');
        Get.back();
        _authController.errorMessage.value = '';
      }
    }
  }
}

/// 显示设置密码对话框
void showSetPasswordDialog({bool isUpdateMode = false}) {
  Get.dialog(
    SetPasswordDialog(isUpdateMode: isUpdateMode),
    barrierDismissible: false,
  );
}
