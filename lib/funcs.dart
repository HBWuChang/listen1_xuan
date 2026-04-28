import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide CircularProgressIndicator;
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/settings.dart';
import '../widgets/progress_indicator_xuan.dart';

import 'controllers/appLinksController.dart';
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
  VoidCallback? onTap,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      // 计算最大宽度：屏幕宽度 - 两侧各64的margin
      final maxWidth = MediaQuery.of(context).size.width - 128;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
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
  VoidCallback? onTap,
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
        onTap: onTap,
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
  VoidCallback? onTap,
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
    onTap: onTap,
  );
}

void showWarningSnackbar(
  String? title,
  String? message, {
  SnackPosition snackPosition = SnackPosition.TOP,
  VoidCallback? onTap,
}) {
  debugPrint("Showing warning toast: $title - $message");
  _showCustomToast(
    icon: Icons.warning_amber_rounded,
    iconColor: Get.theme.colorScheme.secondary,
    title: title,
    message: message,
    backgroundColor: Get.theme.colorScheme.secondaryContainer,
    textColor: Get.theme.colorScheme.onSecondaryContainer,
    onTap: onTap,
  );
}

void showInfoSnackbar(
  String? title,
  String? message, {
  SnackPosition snackPosition = SnackPosition.TOP,
  VoidCallback? onTap,
}) {
  debugPrint("Showing info toast: $title - $message");
  _showCustomToast(
    icon: Icons.info_rounded,
    iconColor: Get.theme.colorScheme.primary,
    title: title,
    message: message,
    backgroundColor: Get.theme.colorScheme.primaryContainer,
    textColor: Get.theme.colorScheme.onPrimaryContainer,
    onTap: onTap,
  );
}

void showSuccessSnackbar(
  String? title,
  String? message, {
  SnackPosition snackPosition = SnackPosition.TOP,
  VoidCallback? onTap,
}) {
  debugPrint("Showing success toast: $title - $message");
  _showCustomToast(
    icon: Icons.check_circle_rounded,
    iconColor: Get.theme.colorScheme.tertiary,
    title: title,
    message: message,
    backgroundColor: Get.theme.colorScheme.tertiaryContainer,
    textColor: Get.theme.colorScheme.onTertiaryContainer,
    onTap: onTap,
  );
}

void showDebugSnackbar(
  String? title,
  String? message, {
  SnackPosition snackPosition = SnackPosition.TOP,
  VoidCallback? onTap,
}) {
  logger.d("Debug Toast - $title: $message");
  if (Get.find<SettingsController>().useDebugMode || kDebugMode) {
    Clipboard.setData(
      ClipboardData(
        text:
            '${title ?? ''}${(!isEmpty(title) && !isEmpty(message)) ? '：' : ''}${message ?? ''}',
      ),
    );
    _showCustomToast(
      icon: Icons.bug_report_rounded,
      iconColor: Get.theme.colorScheme.tertiary,
      title: title,
      message: message,
      backgroundColor: Get.theme.colorScheme.tertiaryContainer,
      textColor: Get.theme.colorScheme.onTertiaryContainer,
      onTap: onTap,
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
            globalLoadingAnime,
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

class _InputDialogWidget extends StatefulWidget {
  final String title;
  final String? message;
  final String? initialValue;
  final String? placeholder;
  final TextInputType keyboardType;
  final int maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;
  final Future<bool> Function(String value)? onConfirm;
  final String confirmText;
  final String cancelText;

  const _InputDialogWidget({
    required this.title,
    this.message,
    this.initialValue,
    this.placeholder,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
    this.onConfirm,
    required this.confirmText,
    required this.cancelText,
  });

  @override
  State<_InputDialogWidget> createState() => _InputDialogWidgetState();
}

class _InputDialogWidgetState extends State<_InputDialogWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final _errorMessage = RxnString();
  final _isProcessing = false.obs;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _focusNode.addListener(_focusListener);
  }

  void _focusListener() {
    if (_focusNode.hasFocus) {
      set_inapp_hotkey(false);
    } else {
      set_inapp_hotkey(true);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_focusListener);
    set_inapp_hotkey(true);
    _controller.dispose();
    _focusNode.dispose();
    _errorMessage.close();
    _isProcessing.close();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    final value = _controller.text;

    // 执行验证
    if (widget.validator != null) {
      final error = widget.validator!(value);
      if (error != null) {
        _errorMessage.value = error;
        return;
      }
    }

    // 执行确认回调
    if (widget.onConfirm != null) {
      try {
        _isProcessing.value = true;
        final canClose = await widget.onConfirm!(value);
        _isProcessing.value = false;

        if (canClose) {
          Get.back(result: value);
        }
        // 如果返回false，对话框保持打开状态
      } catch (e) {
        _isProcessing.value = false;
        _errorMessage.value = '处理失败: ${e.toString()}';
      }
    } else {
      // 没有回调函数，直接关闭
      Get.back(result: value);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async => !_isProcessing.value,
      child: AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null) ...[
              Text(
                widget.message!,
                style: TextStyle(
                  fontSize: 14,
                  color: Get.theme.textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Obx(
              () => TextField(
                controller: _controller,
                keyboardType: widget.keyboardType,
                maxLines: widget.maxLines,
                maxLength: widget.maxLength,
                focusNode: _focusNode,
                autofocus: true,
                enabled: !_isProcessing.value,
                decoration: InputDecoration(
                  hintText: widget.placeholder,
                  errorText: _errorMessage.value,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  counterText: widget.maxLength != null ? null : '',
                ),
                onChanged: (value) {
                  // 输入时清除错误消息
                  if (_errorMessage.value != null) {
                    _errorMessage.value = null;
                  }
                },
                onSubmitted: (value) async {
                  // 按回车键提交（仅限单行输入）
                  if (widget.maxLines == 1 && !_isProcessing.value) {
                    await _handleConfirm();
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          Obx(
            () => TextButton(
              onPressed: _isProcessing.value
                  ? null
                  : () => Get.back(result: null),
              child: Text(widget.cancelText),
            ),
          ),
          Obx(
            () => ElevatedButton(
              onPressed: _isProcessing.value
                  ? null
                  : () async {
                      await _handleConfirm();
                    },
              child: _isProcessing.value
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
                  : Text(widget.confirmText),
            ),
          ),
        ],
      ),
    );
  }
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
/// [disableBackgroundShadow] 是否禁用对话框背景遮罩阴影（默认 false）
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
  bool disableBackgroundShadow = false,
}) async {
  return Get.dialog<String>(
    _InputDialogWidget(
      title: title,
      message: message,
      initialValue: initialValue,
      placeholder: placeholder,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      onConfirm: onConfirm,
      confirmText: confirmText,
      cancelText: cancelText,
    ),
    barrierColor: disableBackgroundShadow ? Colors.transparent : null,
  );
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

bool isNotEmpty(dynamic str) => !isEmpty(str);

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
  bool autoRem = false,
  ConfirmLevel confirmLevel = ConfirmLevel.info,
}) async {
  // 如果当前值非 null，直接返回
  if (currentValue != null) {
    return currentValue;
  }

  final rememberChoice = autoRem ? true.obs : false.obs;

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

  if (isDesktop) {
    Get.find<Applinkscontroller>().xshow?.call();
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
