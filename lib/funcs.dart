import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

late FToast fToast;

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
        constraints: BoxConstraints(
          maxWidth: maxWidth,
        ),
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
            Obx(() => Text(message.value, style: const TextStyle(fontSize: 16))),
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
  );
  return result ?? false;
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
