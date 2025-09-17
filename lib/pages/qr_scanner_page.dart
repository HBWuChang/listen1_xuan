import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:get/get.dart';

/// 二维码扫描页面
class QRScannerPage extends StatefulWidget {
  const QRScannerPage({Key? key}) : super(key: key);

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates, // 避免重复扫描
    facing: CameraFacing.back, // 使用后置摄像头
    torchEnabled: false, // 闪光灯
  );
  
  bool isFlashOn = false;
  bool isScanned = false; // 防止重复处理

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描服务器二维码'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          // 闪光灯切换按钮
          IconButton(
            icon: Icon(isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              cameraController.toggleTorch();
              setState(() {
                isFlashOn = !isFlashOn;
              });
            },
          ),
          // 切换摄像头按钮
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 摄像头预览
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (isScanned) return; // 防止重复处理
              
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null && code.isNotEmpty) {
                  _handleScanResult(code);
                  break;
                }
              }
            },
          ),
          
          // 扫描框和引导UI
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.red,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  // 四个角的装饰
                  Positioned(
                    top: -3,
                    left: -3,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(12)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.only(topRight: Radius.circular(12)),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -3,
                    left: -3,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12)),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -3,
                    right: -3,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.only(bottomRight: Radius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 提示文字
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '将服务器二维码对准扫描框',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      '格式: IP地址:端口号',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 手动输入按钮
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton.icon(
                onPressed: () {
                  _showManualInputDialog();
                },
                icon: const Icon(Icons.edit, color: Colors.white),
                label: const Text(
                  '手动输入',
                  style: TextStyle(color: Colors.white),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.7),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleScanResult(String result) {
    if (isScanned) return;
    isScanned = true;
    
    // 验证扫描结果格式
    if (_isValidServerAddress(result)) {
      Get.back(result: result);
    } else {
      // 显示错误提示
      Get.snackbar(
        '扫描失败',
        '无效的服务器地址格式\n期望格式: IP地址:端口号',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      
      // 重新允许扫描
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            isScanned = false;
          });
        }
      });
    }
  }

  void _showManualInputDialog() {
    final TextEditingController inputController = TextEditingController();
    
    Get.dialog(
      AlertDialog(
        title: const Text('手动输入服务器地址'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: inputController,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: '例如: 192.168.1.100:8080',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '格式: IP地址:端口号',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final address = inputController.text.trim();
              if (_isValidServerAddress(address)) {
                Get.back();
                Get.back(result: address);
              } else {
                Get.snackbar(
                  '输入错误',
                  '无效的服务器地址格式',
                  snackPosition: SnackPosition.TOP,
                  backgroundColor: Colors.red.withOpacity(0.8),
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 验证服务器地址格式
  bool _isValidServerAddress(String address) {
    final RegExp addressRegex = RegExp(
      r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?):(?:[1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$',
    );
    return addressRegex.hasMatch(address);
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}