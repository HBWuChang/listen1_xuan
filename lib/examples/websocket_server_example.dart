import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/websocket_card_controller.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// WebSocket 服务器卡片组件
/// 提供简洁的服务器状态显示和快速操作
class WebSocketServerCard extends StatelessWidget {
  final String? tag;
  final VoidCallback? onTap;

  const WebSocketServerCard({super.key, this.tag, this.onTap});

  @override
  Widget build(BuildContext context) {
    // 确保控制器被创建
    return GestureDetector(
      onTap: onTap ?? () => WebSocketControlPanel.show(),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Obx(() {
                    final ctrl = Get.find<WebSocketCardController>(
                      tag: tag ?? 'websocket_card',
                    );
                    return Icon(
                      Icons.wifi_tethering,
                      color: ctrl.isServerRunning ? Colors.green : Colors.grey,
                    );
                  }),
                  const SizedBox(width: 8),
                  const Text(
                    'WebSocket 服务器',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Obx(() {
                    final ctrl = Get.find<WebSocketCardController>(
                      tag: tag ?? 'websocket_card',
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: ctrl.isServerRunning
                            ? Colors.green
                            : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        ctrl.statusMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 12),
              Obx(() {
                final ctrl = Get.find<WebSocketCardController>(
                  tag: tag ?? 'websocket_card',
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ctrl.isServerRunning
                          ? '服务地址: ${ctrl.serverUrl}'
                          : '点击卡片打开控制面板',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    if (ctrl.isServerRunning) ...[
                      const SizedBox(height: 4),
                      Text(
                        '连接数: ${ctrl.clientCount}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                );
              }),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Obx(() {
                      final ctrl = Get.find<WebSocketCardController>(
                        tag: tag ?? 'websocket_card',
                      );
                      return ElevatedButton(
                        onPressed: ctrl.isStarting || ctrl.isStopping
                            ? null
                            : ctrl.isServerRunning
                            ? ctrl.stopServer
                            : ctrl.startServer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ctrl.isServerRunning
                              ? Colors.red
                              : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          ctrl.isStarting
                              ? '启动中...'
                              : ctrl.isStopping
                              ? '停止中...'
                              : ctrl.isServerRunning
                              ? '停止'
                              : '启动',
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => WebSocketControlPanel.show(),
                    icon: const Icon(Icons.settings),
                    tooltip: '打开控制面板',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// WebSocket 控制面板
/// 提供详细的服务器配置和管理功能
class WebSocketControlPanel {
  static Future<void> show() async {
    await WoltModalSheet.show<void>(
      pageIndexNotifier: ValueNotifier(0),
      context: Get.context!,
      pageListBuilder: (modalSheetContext) {
        return [
          WoltModalSheetPage(
            child: WebSocketControlContent(),
            isTopBarLayerAlwaysVisible: true,
            topBarTitle: Obx(() {
              final ctrl = Get.find<WebSocketCardController>();
              return Row(
                children: [
                  Icon(
                    Icons.wifi_tethering,
                    color: ctrl.isServerRunning ? Colors.blue : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text('WebSocket 服务器控制面板'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ctrl.isServerRunning ? Colors.green : Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ctrl.statusMessage,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              );
            }),
          ),
        ];
      },
    );
  }
}

class WebSocketControlContent extends StatefulWidget {
  const WebSocketControlContent({super.key});

  @override
  State<WebSocketControlContent> createState() =>
      _WebSocketControlContentState();
}

class _WebSocketControlContentState extends State<WebSocketControlContent> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// 重启服务器
  Future<void> _restartServer(WebSocketCardController controller) async {
    await controller.stopServer();
    // 等待一小段时间确保端口释放
    await Future.delayed(const Duration(milliseconds: 500));
    await controller.startServer();
  }

  /// 显示二维码对话框
  void _showQrCodeDialog(WebSocketCardController controller) {
    final qrData = '${controller.host}:${controller.port}';

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 350),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题
              Row(
                children: [
                  const Icon(Icons.qr_code_2, color: Colors.blue, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'WebSocket服务器连接',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 二维码
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
              ),

              const SizedBox(height: 20),

              // 连接信息
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '连接地址',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      qrData,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: qrData));
                        Get.snackbar(
                          '成功',
                          '连接信息已复制到剪贴板',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.green.withOpacity(0.8),
                          colorText: Colors.white,
                          duration: const Duration(seconds: 2),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('复制地址'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('确定'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<WebSocketCardController>();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          // 服务器控制按钮行 (移到顶部)
          Container(
            padding: const EdgeInsets.all(16),
            child: Obx(() {
              final ctrl = Get.find<WebSocketCardController>();
              return Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: ctrl.isStarting || ctrl.isStopping
                          ? null
                          : ctrl.isServerRunning
                          ? ctrl.stopServer
                          : ctrl.startServer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ctrl.isServerRunning
                            ? Colors.red.withOpacity(0.9)
                            : Colors.green.withOpacity(0.9),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(
                        ctrl.isStarting
                            ? Icons.hourglass_empty
                            : ctrl.isStopping
                            ? Icons.hourglass_empty
                            : ctrl.isServerRunning
                            ? Icons.stop
                            : Icons.play_arrow,
                        size: 18,
                      ),
                      label: Text(
                        ctrl.isStarting
                            ? '启动中...'
                            : ctrl.isStopping
                            ? '停止中...'
                            : ctrl.isServerRunning
                            ? '停止服务器'
                            : '启动服务器',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 快速重启按钮
                  ElevatedButton.icon(
                    onPressed:
                        ctrl.isStarting ||
                            ctrl.isStopping ||
                            !ctrl.isServerRunning
                        ? null
                        : () => _restartServer(ctrl),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.withOpacity(0.9),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('重启', style: TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(width: 12),
                  // 二维码按钮
                  ElevatedButton.icon(
                    onPressed: () => _showQrCodeDialog(ctrl),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.withOpacity(0.9),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code, size: 18),
                    label: const Text('二维码', style: TextStyle(fontSize: 14)),
                  ),
                ],
              );
            }),
          ),

          // Tab 内容
          Expanded(child: _buildConfigTab(controller)),
        ],
      ),
    );
  }

  Widget _buildConfigTab(WebSocketCardController controller) {
    final portController = TextEditingController(
      text: controller.port.toString(),
    );
    final pingController = TextEditingController(
      text: controller.pingInterval.toString(),
    );
    final pongController = TextEditingController(
      text: controller.pongTimeout.toString(),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Obx(() {
        final ctrl = Get.find<WebSocketCardController>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ctrl.isServerRunning)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '服务器运行时不能修改配置',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),

            _buildConfigSection('网络配置', [
              // IP地址下拉选择框
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '主机地址',
                          style: TextStyle(
                            fontSize: 12,
                            color: ctrl.isServerRunning
                                ? Colors.grey
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: ctrl.isServerRunning
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade400,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value:
                                  ctrl.availableIpAddresses.contains(ctrl.host)
                                  ? ctrl.host
                                  : (ctrl.availableIpAddresses.isNotEmpty
                                        ? ctrl.availableIpAddresses.first
                                        : '127.0.0.1'),
                              isExpanded: true,
                              onChanged: ctrl.isServerRunning
                                  ? null
                                  : (String? newValue) {
                                      if (newValue != null) {
                                        ctrl.updateHost(newValue);
                                      }
                                    },
                              items: ctrl.availableIpAddresses
                                  .map<DropdownMenuItem<String>>((
                                    String value,
                                  ) {
                                    String displayText = value;
                                    String description = '';

                                    if (value == '127.0.0.1') {
                                      description = ' (本地回环)';
                                    } else if (value.startsWith('192.168.') ||
                                        value.startsWith('10.') ||
                                        value.startsWith('172.')) {
                                      description = ' (局域网)';
                                    } else {
                                      description = ' (公网)';
                                    }

                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        '$displayText$description',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: ctrl.isServerRunning
                                              ? Colors.grey
                                              : null,
                                        ),
                                      ),
                                    );
                                  })
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 刷新IP按钮
                  Tooltip(
                    message: '刷新IP地址列表',
                    child: Container(
                      margin: const EdgeInsets.only(top: 20),
                      child: IconButton(
                        onPressed: ctrl.isLoadingIpAddresses
                            ? null
                            : () async {
                                await ctrl.refreshIpAddresses();
                              },
                        icon: ctrl.isLoadingIpAddresses
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(Icons.refresh, size: 20),
                        iconSize: 20,
                        padding: EdgeInsets.all(8),
                        constraints: BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          foregroundColor: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: portController,
                label: '端口号',
                hint: '1024-65535',
                enabled: !ctrl.isServerRunning,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  final port = int.tryParse(value);
                  if (port != null) ctrl.updatePort(port);
                },
              ),
            ]),

            const SizedBox(height: 24),
            // 自动启动配置
            _buildConfigSection('启动配置', [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '应用启动时自动启动WebSocket服务器',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  Switch(
                    value: ctrl.wsServerAutoStart,
                    onChanged: ctrl.updateAutoStart,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '在主页中显示WebSocket服务器按钮',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  Switch(
                    value: ctrl.wsServerBtnShow,
                    onChanged: ctrl.updateBtnShow,
                  ),
                ],
              ),
            ]),

            const SizedBox(height: 24),

            _buildConfigSection('心跳配置', [
              _buildTextField(
                controller: pingController,
                label: 'Ping间隔 (秒)',
                hint: '5-300',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  final interval = int.tryParse(value);
                  if (interval != null) ctrl.updatePingInterval(interval);
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: pongController,
                label: 'Pong超时 (秒)',
                hint: '1-60',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  final timeout = int.tryParse(value);
                  if (timeout != null) ctrl.updatePongTimeout(timeout);
                },
              ),
            ]),
          ],
        );
      }),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Widget _buildConfigSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// 便捷调用方法
class WebSocketHelper {
  /// 显示 WebSocket 控制面板
  static Future<void> showControlPanel() async {
    await WebSocketControlPanel.show();
  }

  /// 获取或创建 WebSocket 卡片控制器
  static WebSocketCardController getController() {
    return Get.find<WebSocketCardController>();
  }

  /// 快速启动服务器
  static Future<void> quickStart({
    String host = '0.0.0.0',
    int port = 8080,
    String tag = 'websocket_card',
  }) async {
    final controller = Get.put(WebSocketCardController());
    controller.updateHost(host);
    controller.updatePort(port);
    await controller.startServer();
  }

  /// 创建响应式WebSocket按钮
  /// 根据服务器状态显示不同颜色的图标
  static Widget buildReactiveButton({
    String? tooltip,
    double iconSize = 24.0,
    EdgeInsets padding = const EdgeInsets.all(8.0),
    bool inMainPage = false,
  }) {
    return Obx(() {
      // 获取WebSocket控制器
      WebSocketCardController? controller;
      try {
        controller = Get.find<WebSocketCardController>();
      } catch (e) {
        // 如果控制器不存在，显示默认状态
        return IconButton(
          tooltip: tooltip ?? "WebSocket服务器",
          icon: Icon(
            Icons.connected_tv_rounded,
            color: Colors.grey,
            size: iconSize,
          ),
          padding: padding,
          onPressed: () async {
            await showControlPanel();
          },
        );
      }

      // 检查是否应该显示按钮
      if (inMainPage && !controller.wsServerBtnShow) {
        return const SizedBox.shrink();
      }

      // 根据服务器状态确定图标颜色和状态
      Color iconColor;
      Widget icon;
      String currentTooltip;

      if (controller.isStarting) {
        // 启动中 - 黄色
        iconColor = Colors.amber;
        currentTooltip = "WebSocket服务器 (启动中...)";
        icon = SizedBox(
          width: iconSize,
          height: iconSize,
          child: Stack(
            children: [
              Icon(
                Icons.connected_tv_rounded,
                color: iconColor,
                size: iconSize,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: iconSize * 0.3,
                  height: iconSize * 0.3,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                ),
              ),
            ],
          ),
        );
      } else if (controller.isStopping) {
        // 停止中 - 橙色
        iconColor = Colors.orange;
        currentTooltip = "WebSocket服务器 (停止中...)";
        icon = SizedBox(
          width: iconSize,
          height: iconSize,
          child: Stack(
            children: [
              Icon(
                Icons.connected_tv_rounded,
                color: iconColor,
                size: iconSize,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: iconSize * 0.3,
                  height: iconSize * 0.3,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
              ),
            ],
          ),
        );
      } else if (controller.isServerRunning) {
        // 运行中 - 绿色，显示客户端数量
        iconColor = Colors.green;
        currentTooltip = "WebSocket服务器 (运行中 - ${controller.clientCount}个客户端)";
        icon = SizedBox(
          width: iconSize,
          height: iconSize,
          child: Stack(
            children: [
              Icon(
                Icons.connected_tv_rounded,
                color: iconColor,
                size: iconSize,
              ),
              if (controller.clientCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: BoxConstraints(
                      minWidth: iconSize * 0.4,
                      minHeight: iconSize * 0.4,
                    ),
                    child: Text(
                      '${controller.clientCount}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: iconSize * 0.25,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      } else {
        // 未启动 - 灰色
        iconColor = Colors.grey;
        currentTooltip = "WebSocket服务器 (未启动)";
        icon = Icon(
          Icons.connected_tv_rounded,
          color: iconColor,
          size: iconSize,
        );
      }

      return IconButton(
        tooltip: tooltip ?? currentTooltip,
        icon: icon,
        padding: padding,
        onPressed: () async {
          await showControlPanel();
        },
      );
    });
  }

  /// 创建简化版响应式按钮（仅颜色变化）
  static Widget buildSimpleReactiveButton({
    String? tooltip,
    double iconSize = 24.0,
    EdgeInsets padding = const EdgeInsets.all(8.0),
  }) {
    return Obx(() {
      // 获取WebSocket控制器
      WebSocketCardController? controller;
      try {
        controller = Get.find<WebSocketCardController>();
      } catch (e) {
        // 如果控制器不存在，不显示按钮
        return const SizedBox.shrink();
      }

      // 检查是否应该显示按钮
      if (!controller.wsServerBtnShow) {
        return const SizedBox.shrink();
      }

      // 根据服务器状态确定图标颜色
      Color iconColor;
      String currentTooltip;

      if (controller.isStarting || controller.isStopping) {
        iconColor = Colors.amber;
        currentTooltip = controller.isStarting
            ? "WebSocket服务器 (启动中...)"
            : "WebSocket服务器 (停止中...)";
      } else if (controller.isServerRunning) {
        iconColor = Colors.green;
        currentTooltip = "WebSocket服务器 (运行中 - ${controller.clientCount}个客户端)";
      } else {
        iconColor = Colors.grey;
        currentTooltip = "WebSocket服务器 (未启动)";
      }

      return IconButton(
        tooltip: tooltip ?? currentTooltip,
        icon: Icon(
          Icons.connected_tv_rounded,
          color: iconColor,
          size: iconSize,
        ),
        padding: padding,
        onPressed: () async {
          await showControlPanel();
        },
      );
    });
  }
}
