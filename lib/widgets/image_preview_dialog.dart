import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/settings_controller.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/global_settings_animations.dart';
import 'package:listen1_xuan/widgets/ext/ext_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// 条件导入：仅桌面端引入 super_drag_and_drop
import 'image_preview_drag_stub.dart'
    if (dart.library.ffi) 'image_preview_drag_desktop.dart'
    as drag_impl;

/// 图片预览 Dialog
/// 桌面端支持拖拽导出图片（virtual file），移动端仅预览
class ImagePreviewDialog extends StatelessWidget {
  final Uint8List imageData;
  final VoidCallback onConfirm;
  final String? fileName;

  /// 缓存图片在本地的路径，供外部读取
  final String? cachedFilePath;

  const ImagePreviewDialog({
    super.key,
    required this.imageData,
    required this.onConfirm,
    this.fileName,
    this.cachedFilePath,
  });

  /// 固定的缓存文件名，每次 show 时覆盖写入
  static const _cacheFileName = 'paste_preview_image.png';

  /// 单例控制：当前正在显示的 Dialog 的 Navigator state
  static BuildContext? _currentDialogContext;

  /// 关闭当前已显示的 Dialog（如果有）
  static void _dismissCurrent() {
    if (_currentDialogContext != null) {
      Navigator.of(_currentDialogContext!).pop(false);
      _currentDialogContext = null;
    }
  }

  /// 将图片数据保存到系统缓存目录（临时目录）
  /// 使用固定文件名，每次覆盖，确保系统清理缓存时会清理该文件。
  /// 返回保存后的文件路径。
  static Future<String?> _saveImageToCache(Uint8List imageData) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final filePath = p.join(cacheDir.path, _cacheFileName);
      final file = File(filePath);
      await file.writeAsBytes(imageData, flush: true);
      debugPrint('[ImagePreviewDialog] 图片已缓存到: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('[ImagePreviewDialog] 保存图片到缓存失败: $e');
      return null;
    }
  }

  /// 显示图片预览 Dialog
  /// 返回 true 表示用户点击了确认按钮（执行粘贴操作）
  ///
  /// [saveToCache] 为 true 时，将图片保存到临时目录，拖拽时使用真实文件；
  /// 为 false 时不写入磁盘，拖拽使用虚拟文件从内存导出。
  static Future<bool> show(
    BuildContext context, {
    required Uint8List imageData,
    required VoidCallback onConfirm,
    String? fileName,
    bool saveToCache = true,
  }) async {
    // 单例：关闭之前的 Dialog
    _dismissCurrent();

    // 根据参数决定是否写入缓存目录
    final String? cachedPath = saveToCache
        ? await _saveImageToCache(imageData)
        : null;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) {
        // 记录当前 dialog 的 context 用于后续关闭
        _currentDialogContext = ctx;
        return ImagePreviewDialog(
          imageData: imageData,
          onConfirm: onConfirm,
          fileName: fileName,
          cachedFilePath: cachedPath,
        );
      },
    );

    // Dialog 关闭后清理引用
    _currentDialogContext = null;
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final maxW = screenSize.width * 0.8;
    final maxH = screenSize.height * 0.8;
    const minW = 120.0;
    const minH = 100.0;

    // 根据图片宽高比计算 dialog 尺寸
    final dialogSize = _computeDialogSize(maxW, maxH, minW, minH);

    final body = _buildDialogBody(context, dialogSize.width, dialogSize.height);

    // 桌面端包裹 DragItemWidget 实现拖出
    if (isDesktop) {
      return Center(
        child: drag_impl.wrapWithDrag(
          imageData: imageData,
          fileName: fileName ?? 'paste_image.png',
          filePath: cachedFilePath,
          child: body,
        ),
      );
    }

    return Center(child: body);
  }

  /// 根据图片实际宽高比，在约束范围内计算 dialog 最终尺寸
  Size _computeDialogSize(double maxW, double maxH, double minW, double minH) {
    // 尝试解码图片尺寸
    final decoded = _decodeImageDimensions(imageData);
    if (decoded == null) {
      // 无法解码时使用最大约束
      return Size(maxW.clamp(minW, maxW), maxH.clamp(minH, maxH));
    }

    final imgW = decoded.width;
    final imgH = decoded.height;
    final aspectRatio = imgW / imgH;

    // 先尝试按最大宽度适配
    double w = maxW;
    double h = w / aspectRatio;

    // 如果高度超出则按最大高度适配
    if (h > maxH) {
      h = maxH;
      w = h * aspectRatio;
    }

    // 应用最小约束
    if (w < minW) {
      w = minW;
      h = w / aspectRatio;
    }
    if (h < minH) {
      h = minH;
      w = h * aspectRatio;
    }

    // 最终再次 clamp 确保不超出最大值
    w = w.clamp(minW, maxW);
    h = h.clamp(minH, maxH);

    return Size(w, h);
  }

  /// 从 PNG/JPEG/GIF/BMP 头部快速解码图片宽高，避免完整解码
  static Size? _decodeImageDimensions(Uint8List data) {
    if (data.length < 24) return null;

    // PNG: 前 8 字节为 signature, IHDR chunk 在 offset 16 处包含宽高
    if (data[0] == 0x89 &&
        data[1] == 0x50 &&
        data[2] == 0x4E &&
        data[3] == 0x47) {
      final w =
          (data[16] << 24) | (data[17] << 16) | (data[18] << 8) | data[19];
      final h =
          (data[20] << 24) | (data[21] << 16) | (data[22] << 8) | data[23];
      return Size(w.toDouble(), h.toDouble());
    }

    // JPEG: SOI=FFD8, 查找 SOF0/SOF2 marker
    if (data[0] == 0xFF && data[1] == 0xD8) {
      int offset = 2;
      while (offset < data.length - 9) {
        if (data[offset] != 0xFF) break;
        final marker = data[offset + 1];
        if (marker == 0xC0 || marker == 0xC2) {
          final h = (data[offset + 5] << 8) | data[offset + 6];
          final w = (data[offset + 7] << 8) | data[offset + 8];
          return Size(w.toDouble(), h.toDouble());
        }
        final segLen = (data[offset + 2] << 8) | data[offset + 3];
        offset += 2 + segLen;
      }
    }

    // GIF: GIF87a / GIF89a
    if (data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46) {
      final w = data[6] | (data[7] << 8);
      final h = data[8] | (data[9] << 8);
      return Size(w.toDouble(), h.toDouble());
    }

    // BMP: "BM" header
    if (data[0] == 0x42 && data[1] == 0x4D && data.length >= 26) {
      final w =
          data[18] | (data[19] << 8) | (data[20] << 16) | (data[21] << 24);
      final h =
          data[22] | (data[23] << 8) | (data[24] << 16) | (data[25] << 24);
      return Size(w.toDouble(), h.abs().toDouble());
    }

    return null;
  }

  Widget _buildDialogBody(
    BuildContext context,
    double dialogWidth,
    double dialogHeight,
  ) {
    return Material(
      color: Colors.transparent,
      child:
          Stack(
                children: [
                  // 图片内容
                  Positioned.fill(
                    child: Image.memory(imageData, fit: BoxFit.contain),
                  ),
                  // 右上角操作按钮
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 确认发送按钮
                        _ActionButton(
                          icon: Icons.send_rounded,
                          tooltip: '通过WebSocket发送',
                          onPressed: () {
                            onConfirm();
                          },
                          onLongPress: () {
                            Get.find<SettingsController>()
                                    .sendImgWhenOpenImgDialog =
                                !Get.find<SettingsController>()
                                    .sendImgWhenOpenImgDialog;
                            if (Get.find<SettingsController>()
                                .sendImgWhenOpenImgDialog) {
                              showInfoSnackbar('在展示该Dialog时立刻尝试发送图片', null);
                            } else {
                              showInfoSnackbar('在展示该Dialog时不再自动发送图片', null);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  // 底部提示
                  if (isDesktop)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '可直接拖拽图片到桌面或其他应用',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              )
              .sbwh(dialogWidth, dialogHeight)
              .clipSmoothRectSize(min(dialogWidth, dialogHeight)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
