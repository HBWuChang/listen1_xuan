import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/settings.dart';

import 'controllers/settings_controller.dart';
import 'global_settings_animations.dart';
import 'widgets/smooth_sheet_toast.dart';

late FToast fToast;
late SmoothSheetToast smoothSheetToast;

/// 创建统一的自定义 Toast 组件
Widget _buildCustomToast({
  required IconData icon,
  required Color iconColor,
  required String? title,
  required String? message,
  required Color backgroundColor,
  required Color textColor,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      // 计算最大宽度：屏幕宽度 - 两侧各64的margin
      final maxWidth = MediaQuery.of(context).size.width - 128;

      return Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
          color: backgroundColor,
        ),
        child: IntrinsicWidth(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  "${title ?? ''}${(!isEmpty(title) && !isEmpty(message)) ? '：' : ''}${message ?? ''}",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: null,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 显示自定义 Toast 的通用方法
void _showCustomToast({
  required IconData icon,
  required Color iconColor,
  required String? title,
  required String? message,
  required Color backgroundColor,
  required Color textColor,
}) {
  try {
    fToast.removeCustomToast();
    if (Get.context != null) {
      Widget toast = _buildCustomToast(
        icon: icon,
        iconColor: iconColor,
        title: title,
        message: message,
        backgroundColor: backgroundColor,
        textColor: textColor,
      );

      fToast.showToast(
        child: toast,
        gravity: ToastGravity.TOP,
        toastDuration: const Duration(seconds: 3),
      );
    } else {
      // 降级到基础 Toast
      Fluttertoast.showToast(
        msg: "$title: $message",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.TOP,
        backgroundColor: backgroundColor,
        textColor: textColor,
        fontSize: 16.0,
      );
    }
  } catch (e) {
    debugPrint("Error showing toast: $e");
  }
}

void showErrorSnackbar(
  String? title,
  String? message, {
  SnackPosition snackPosition = SnackPosition.TOP,
}) {
  Clipboard.setData(ClipboardData(text: message ?? title ?? ''));
  debugPrint("Showing error toast: $title - $message");
  _showCustomToast(
    icon: Icons.cancel,
    iconColor: Get.theme.colorScheme.error,
    title: title,
    message: message,
    backgroundColor: Get.theme.colorScheme.errorContainer,
    textColor: Get.theme.colorScheme.onErrorContainer,
  );
}

void showWarningSnackbar(
  String? title,
  String? message, {
  SnackPosition snackPosition = SnackPosition.TOP,
}) {
  debugPrint("Showing warning toast: $title - $message");
  _showCustomToast(
    icon: Icons.warning_amber_rounded,
    iconColor: Get.theme.colorScheme.secondary,
    title: title,
    message: message,
    backgroundColor: Get.theme.colorScheme.secondaryContainer,
    textColor: Get.theme.colorScheme.onSecondaryContainer,
  );
}

void showInfoSnackbar(
  String? title,
  String? message, {
  SnackPosition snackPosition = SnackPosition.TOP,
}) {
  debugPrint("Showing info toast: $title - $message");
  _showCustomToast(
    icon: Icons.info_rounded,
    iconColor: Get.theme.colorScheme.primary,
    title: title,
    message: message,
    backgroundColor: Get.theme.colorScheme.primaryContainer,
    textColor: Get.theme.colorScheme.onPrimaryContainer,
  );
}

void showSuccessSnackbar(
  String? title,
  String? message, {
  SnackPosition snackPosition = SnackPosition.TOP,
}) {
  debugPrint("Showing success toast: $title - $message");
  _showCustomToast(
    icon: Icons.check_circle_rounded,
    iconColor: Get.theme.colorScheme.tertiary,
    title: title,
    message: message,
    backgroundColor: Get.theme.colorScheme.tertiaryContainer,
    textColor: Get.theme.colorScheme.onTertiaryContainer,
  );
}

void showDebugSnackbar(
  String? title,
  String? message, {
  SnackPosition snackPosition = SnackPosition.TOP,
}) {
  logger.d("Debug Toast - $title: $message");
  if (Get.find<SettingsController>().useDebugMode || kDebugMode) {
    _showCustomToast(
      icon: Icons.bug_report_rounded,
      iconColor: Get.theme.colorScheme.tertiary,
      title: title,
      message: message,
      backgroundColor: Get.theme.colorScheme.tertiaryContainer,
      textColor: Get.theme.colorScheme.onTertiaryContainer,
    );
  }
}

void showLoadingDialog(RxString message) {
  Get.dialog(
    WillPopScope(
      onWillPop: () async => false, // 禁止关闭对话框
      child: AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 4),
            const SizedBox(width: 20),
            Obx(
              () => Text(message.value, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    ),
    barrierDismissible: false, // 点击外部不关闭对话框
  );
}

enum ConfirmLevel { info, warning, danger }

Future<bool> showConfirmDialog(
  String message,
  String title, {
  ConfirmLevel confirmLevel = ConfirmLevel.info,
  String confirmText = '确认',
  String cancelText = '取消',
  bool barrierDismissible = true,
}) async {
  ButtonStyle style;
  switch (confirmLevel) {
    case ConfirmLevel.info:
      style = ElevatedButton.styleFrom(
        foregroundColor: Get.theme.colorScheme.primary,
        backgroundColor: Get.theme.colorScheme.onPrimary,
      );
      break;
    case ConfirmLevel.warning:
      style = ElevatedButton.styleFrom(
        foregroundColor: Get.theme.colorScheme.onSecondary,
        backgroundColor: Get.theme.colorScheme.secondary,
      );
      break;
    case ConfirmLevel.danger:
      style = ElevatedButton.styleFrom(
        foregroundColor: Get.theme.colorScheme.onError,
        backgroundColor: Get.theme.colorScheme.error,
      );
      break;
  }
  bool? result = await Get.dialog<bool>(
    AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: Text(cancelText),
        ),
        ElevatedButton(
          style: style,
          onPressed: () => Get.back(result: true),
          child: Text(confirmText),
        ),
      ],
    ),
    barrierDismissible: barrierDismissible,
  );
  return result ?? false;
}

/// 显示文本输入对话框
///
/// [title] 对话框标题
/// [message] 提示消息（可选）
/// [initialValue] 初始文本值
/// [placeholder] 占位符文本
/// [keyboardType] 键盘类型（text, number, email, url等）
/// [maxLines] 最大行数，1为单行，大于1为多行
/// [maxLength] 最大字符长度限制（可选）
/// [validator] 验证函数，返回错误消息或null表示验证通过
/// [onConfirm] 确认回调函数，返回true表示可以关闭对话框，false表示保持打开
/// [confirmText] 确认按钮文本
/// [cancelText] 取消按钮文本
///
/// 返回用户输入的文本，如果取消则返回null
Future<String?> showInputDialog({
  required String title,
  String? message,
  String? initialValue,
  String? placeholder,
  TextInputType keyboardType = TextInputType.text,
  int maxLines = 1,
  int? maxLength,
  String? Function(String?)? validator,
  Future<bool> Function(String value)? onConfirm,
  String confirmText = '确定',
  String cancelText = '取消',
}) async {
  final controller = TextEditingController(text: initialValue);
  final errorMessage = RxnString();
  final isProcessing = false.obs;
  final focusNode = FocusNode();

  // 定义焦点监听器
  void focusListener() {
    if (focusNode.hasFocus) {
      set_inapp_hotkey(false);
    } else {
      set_inapp_hotkey(true);
    }
  }

  focusNode.addListener(focusListener);

  try {
    String? result = await Get.dialog<String>(
      WillPopScope(
        onWillPop: () async => !isProcessing.value,
        child: AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message != null) ...[
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Get.theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Obx(
                () => TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  maxLength: maxLength,
                  focusNode: focusNode,
                  autofocus: true,
                  enabled: !isProcessing.value,
                  decoration: InputDecoration(
                    hintText: placeholder,
                    errorText: errorMessage.value,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    counterText: maxLength != null ? null : '',
                  ),
                  onChanged: (value) {
                    // 输入时清除错误消息
                    if (errorMessage.value != null) {
                      errorMessage.value = null;
                    }
                  },
                  onSubmitted: (value) async {
                    // 按回车键提交（仅限单行输入）
                    if (maxLines == 1 && !isProcessing.value) {
                      await _handleConfirm(
                        controller,
                        validator,
                        onConfirm,
                        errorMessage,
                        isProcessing,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            Obx(
              () => TextButton(
                onPressed: isProcessing.value
                    ? null
                    : () => Get.back(result: null),
                child: Text(cancelText),
              ),
            ),
            Obx(
              () => ElevatedButton(
                onPressed: isProcessing.value
                    ? null
                    : () async {
                        await _handleConfirm(
                          controller,
                          validator,
                          onConfirm,
                          errorMessage,
                          isProcessing,
                        );
                      },
                child: isProcessing.value
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Get.theme.colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : Text(confirmText),
              ),
            ),
          ],
        ),
      ),
    );

    return result;
  } finally {
    // 先移除监听器，再 dispose，避免 "used after being disposed" 错误
    focusNode.removeListener(focusListener);
    set_inapp_hotkey(true);

    // 延迟 dispose，确保对话框动画完成
    await Future.delayed(Duration(milliseconds: 100));
    controller.dispose();
    focusNode.dispose();
  }
}

/// 处理输入确认逻辑
Future<void> _handleConfirm(
  TextEditingController controller,
  String? Function(String?)? validator,
  Future<bool> Function(String value)? onConfirm,
  RxnString errorMessage,
  RxBool isProcessing,
) async {
  final value = controller.text;

  // 执行验证
  if (validator != null) {
    final error = validator(value);
    if (error != null) {
      errorMessage.value = error;
      return;
    }
  }

  // 执行确认回调
  if (onConfirm != null) {
    try {
      isProcessing.value = true;
      final canClose = await onConfirm(value);
      isProcessing.value = false;

      if (canClose) {
        Get.back(result: value);
      }
      // 如果返回false，对话框保持打开状态
    } catch (e) {
      isProcessing.value = false;
      errorMessage.value = '处理失败: ${e.toString()}';
    }
  } else {
    // 没有回调函数，直接关闭
    Get.back(result: value);
  }
}

bool isEmpty(dynamic str) {
  if (str == null) return true;
  if (str is String) {
    return str.trim().isEmpty;
  }
  if (str is List) {
    return str.isEmpty;
  }
  if (str is int) {
    return str <= 0;
  }
  // if (str is double) {
  //   return str <= 0.0;
  // }
  return str == null;
}

/// 将字节数格式化为可读的字符串
///
/// [bytes] 字节数
/// [decimals] 小数位数，默认为2
/// 返回格式化后的字符串，如 "1.25 MB"
String formatBytes(int bytes, {int decimals = 2}) {
  if (bytes <= 0) return '0 B';

  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  int index = 0;
  double size = bytes.toDouble();

  while (size >= 1024 && index < suffixes.length - 1) {
    size /= 1024;
    index++;
  }

  if (decimals < 0) decimals = 0;

  return '${size.toStringAsFixed(decimals)} ${suffixes[index]}';
}

/// 从assets读取markdown文件并使用Get的dialog展示
Future<void> showInfoDialogFromMarkdown(String assetsPath) async {
  try {
    // 从assets读取markdown文本
    final markdownContent = await rootBundle.loadString(assetsPath);

    // 使用Get的dialog展示
    Get.dialog(
      Dialog(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: MarkdownBody(data: markdownContent, selectable: true),
        ),
      ),
    );
  } catch (e) {
    showErrorSnackbar('无法加载文件', '加载 $assetsPath 失败: $e');
  }
}

/// 显示三态确认对话框
///
/// 如果 [currentValue] 非 null，直接返回该值
/// 否则弹出对话框让用户选择，并支持"记住选择"功能
///
/// [title] 对话框标题
/// [message] 提示消息
/// [currentValue] 当前设置值，如果非 null 则直接返回
/// [onRemember] 当用户勾选"记住选择"时的回调，接收用户选择的值
/// [confirmText] 确认按钮文本，默认为"确定"
/// [rejectText] 拒绝按钮文本，默认为"拒绝"
/// [cancelText] 取消按钮文本，默认为"取消"
/// [rememberText] "记住选择"复选框文本，默认为"记住我的选择"
/// [confirmLevel] 确认按钮的级别样式
///
/// 返回 true/false/null，分别对应确定/拒绝/取消
Future<bool?> showTriStateConfirmDialog({
  required String title,
  required String message,
  bool? currentValue,
  void Function(bool? value)? onRemember,
  String confirmText = '确定',
  String rejectText = '拒绝',
  String cancelText = '取消',
  String rememberText = '记住我的选择',
  bool autoRem=false,
  ConfirmLevel confirmLevel = ConfirmLevel.info,
}) async {
  // 如果当前值非 null，直接返回
  if (currentValue != null) {
    return currentValue;
  }

  final rememberChoice =autoRem ? true.obs : false.obs;

  ButtonStyle getButtonStyle(ConfirmLevel level) {
    switch (level) {
      case ConfirmLevel.info:
        return ElevatedButton.styleFrom(
          foregroundColor: Get.theme.colorScheme.primary,
          backgroundColor: Get.theme.colorScheme.onPrimary,
        );
      case ConfirmLevel.warning:
        return ElevatedButton.styleFrom(
          foregroundColor: Get.theme.colorScheme.onSecondary,
          backgroundColor: Get.theme.colorScheme.secondary,
        );
      case ConfirmLevel.danger:
        return ElevatedButton.styleFrom(
          foregroundColor: Get.theme.colorScheme.onError,
          backgroundColor: Get.theme.colorScheme.error,
        );
    }
  }

  bool? result = await Get.dialog<bool?>(
    AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 16),
          Obx(
            () => CheckboxListTile(
              title: Text(rememberText),
              value: rememberChoice.value,
              onChanged: (value) {
                rememberChoice.value = value ?? false;
              },
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: null),
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () {
            final choice = false;
            if (rememberChoice.value && onRemember != null) {
              onRemember(choice);
            }
            Get.back(result: choice);
          },
          child: Text(rejectText),
        ),
        ElevatedButton(
          style: getButtonStyle(confirmLevel),
          onPressed: () {
            final choice = true;
            if (rememberChoice.value && onRemember != null) {
              onRemember(choice);
            }
            Get.back(result: choice);
          },
          child: Text(confirmText),
        ),
      ],
    ),
    barrierDismissible: true,
  );

  return result;
}
