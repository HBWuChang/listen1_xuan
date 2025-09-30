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
            CircularProgressIndicator(
              strokeWidth: 4.w,
            ),
            SizedBox(width: 20.w),
            Obx(() => Text(message.value, style: TextStyle(fontSize: 16.sp))),
          ],
        ),
      ),
    ),
    barrierDismissible: false, // 点击外部不关闭对话框
  );
}

void showErrorSnackbar(String title, String message,
    {SnackPosition snackPosition = SnackPosition.TOP}) {
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

void showWarningSnackbar(String title, String message,
    {SnackPosition snackPosition = SnackPosition.TOP}) {
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

void showInfoSnackbar(String title, String message,
    {SnackPosition snackPosition = SnackPosition.TOP}) {
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

void showSuccessSnackbar(String title, String message,
    {SnackPosition snackPosition = SnackPosition.TOP}) {
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
