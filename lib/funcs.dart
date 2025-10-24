import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

void showLoadingDialog(RxString message) {
  Get.dialog(
    WillPopScope(
      onWillPop: () async => false, // 禁止关闭对话框
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(strokeWidth: 4.w),
            SizedBox(width: 20.w),
            Obx(() => Text(message.value, style: TextStyle(fontSize: 16.sp))),
          ],
        ),
      ),
    ),
    barrierDismissible: false, // 点击外部不关闭对话框
  );
}

void showErrorSnackbar(
  String title,
  String message, {
  SnackPosition snackPosition = SnackPosition.TOP,
}) {
  try {
    Get.closeAllSnackbars();
    Get.snackbar(
      title,
      message,
      snackPosition: snackPosition,
      backgroundColor: Colors.red[100],
      colorText: Colors.red[800],
    );
  } catch (e) {
    debugPrint("Error showing snackbar: $e");
  }
}

void showWarningSnackbar(
  String title,
  String message, {
  SnackPosition snackPosition = SnackPosition.TOP,
}) {
  try {
    Get.closeAllSnackbars();
    Get.snackbar(
      title,
      message,
      snackPosition: snackPosition,
      backgroundColor: Colors.yellow[100],
      colorText: Colors.yellow[800],
    );
  } catch (e) {
    debugPrint("Error showing snackbar: $e");
  }
}

void showInfoSnackbar(
  String title,
  String message, {
  SnackPosition snackPosition = SnackPosition.TOP,
}) {
  try {
    Get.closeAllSnackbars();
    Get.snackbar(
      title,
      message,
      snackPosition: snackPosition,
      backgroundColor: Colors.blue[100],
      colorText: Colors.blue[800],
    );
  } catch (e) {
    debugPrint("Error showing snackbar: $e");
  }
}

void showSuccessSnackbar(
  String title,
  String message, {
  SnackPosition snackPosition = SnackPosition.TOP,
}) {
  try {
    Get.closeAllSnackbars();
    Get.snackbar(
      title,
      message,
      snackPosition: snackPosition,
      backgroundColor: Colors.green[100],
      colorText: Colors.green[800],
    );
  } catch (e) {
    debugPrint("Error showing snackbar: $e");
  }
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
