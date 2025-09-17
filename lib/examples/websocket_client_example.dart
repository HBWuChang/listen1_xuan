import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/controllers.dart';
import 'package:listen1_xuan/controllers/websocket_client_controller.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';
import 'package:extended_image/extended_image.dart';
import 'package:listen1_xuan/pages/qr_scanner_page.dart';

import '../bodys.dart';

/// WebSocket 客户端控制面板
/// 提供详细的客户端配置和管理功能
class WebSocketClientControlPanel {
  static Future<void> show() async {
    await WoltModalSheet.show<void>(
      pageIndexNotifier: ValueNotifier(0),
      context: Get.context!,
      pageListBuilder: (modalSheetContext) {
        return [
          WoltModalSheetPage(
            child: WebSocketClientControlContent(),
            isTopBarLayerAlwaysVisible: true,
            topBarTitle: Obx(() {
              final ctrl = Get.find<WebSocketClientController>();
              return Row(
                children: [
                  Icon(
                    Icons.cast_connected,
                    color: ctrl.isConnected ? Colors.blue : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text('WebSocket 客户端控制面板'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ctrl.isConnected ? Colors.blue : Colors.grey,
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

class WebSocketClientControlContent extends StatefulWidget {
  const WebSocketClientControlContent({super.key});

  @override
  State<WebSocketClientControlContent> createState() =>
      _WebSocketClientControlContentState();
}

class _WebSocketClientControlContentState
    extends State<WebSocketClientControlContent>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<WebSocketClientController>();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          // 客户端控制按钮行
          Container(
            padding: const EdgeInsets.all(16),
            child: Obx(() {
              final ctrl = Get.find<WebSocketClientController>();
              return Column(
                children: [
                  // 连接控制按钮
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: ctrl.isConnecting || ctrl.isDisconnecting
                              ? null
                              : ctrl.isConnected
                              ? ctrl.disconnect
                              : ctrl.connect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ctrl.isConnected
                                ? Colors.red.withOpacity(0.9)
                                : Colors.blue.withOpacity(0.9),
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: Icon(
                            ctrl.isConnecting
                                ? Icons.hourglass_empty
                                : ctrl.isDisconnecting
                                ? Icons.hourglass_empty
                                : ctrl.isConnected
                                ? Icons.link_off
                                : Icons.link,
                            size: 18,
                          ),
                          label: Text(
                            ctrl.isConnecting
                                ? '连接中...'
                                : ctrl.isDisconnecting
                                ? '断开中...'
                                : ctrl.isConnected
                                ? '断开连接'
                                : '连接服务器',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),

                  if (ctrl.autoReconnect && ctrl.isReconnecting) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.autorenew,
                          color: Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '自动重连已启用',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => ctrl.updateAutoReconnect(false),
                          child: const Text(
                            '取消重连',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            }),
          ),

          // Tab 导航
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '状态', icon: Icon(Icons.info)),
              Tab(text: '配置', icon: Icon(Icons.settings)),
            ],
          ),

          // Tab 内容
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStatusTab(controller),
                _buildConfigTab(controller),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(WebSocketClientController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Obx(() {
        final ctrl = Get.find<WebSocketClientController>();
        final playStatus = ctrl.lastPlayStatus;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // 歌曲信息卡片
            if (playStatus?.currentTrack != null) ...[
              Card(
                clipBehavior: Clip.hardEdge,
                child: InkWell(
                  onTap: () {
                    Track? track = playStatus.currentTrack;
                    if (track != null) {
                      try {
                        song_dialog(Get.context!, track);
                      } catch (e) {
                        debugPrint(e.toString());
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '当前歌曲',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // 封面图片
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[200],
                              ),
                              child:
                                  playStatus!.currentTrack!.img_url != null &&
                                      playStatus
                                          .currentTrack!
                                          .img_url!
                                          .isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: ExtendedImage.network(
                                        playStatus.currentTrack!.img_url!,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        cache: true,
                                        loadStateChanged:
                                            (ExtendedImageState state) {
                                              switch (state
                                                  .extendedImageLoadState) {
                                                case LoadState.loading:
                                                  return Container(
                                                    width: 80,
                                                    height: 80,
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[200],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: const Center(
                                                      child: SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                      ),
                                                    ),
                                                  );
                                                case LoadState.failed:
                                                  return Container(
                                                    width: 80,
                                                    height: 80,
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[300],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.music_note,
                                                      color: Colors.grey,
                                                      size: 40,
                                                    ),
                                                  );
                                                case LoadState.completed:
                                                  return null;
                                              }
                                            },
                                      ),
                                    )
                                  : Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.music_note,
                                        color: Colors.grey,
                                        size: 40,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 16),
                            // 歌曲信息
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    playStatus.currentTrack!.title ?? '未知标题',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    playStatus.currentTrack!.artist ?? '未知艺术家',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (playStatus.currentTrack!.album != null &&
                                      playStatus
                                          .currentTrack!
                                          .album!
                                          .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      playStatus.currentTrack!.album!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 音源信息
                        if (playStatus.currentTrack!.source != null) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.audiotrack,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '音源: ${playStatus.currentTrack!.source}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              // 无歌曲信息时显示的卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.music_off, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        '暂无播放曲目',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ctrl.isConnected ? '正在获取播放状态...' : '请先连接到WebSocket服务器',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (ctrl.isConnected)
              // 播放控制按钮卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // 播放控制按钮行
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            onPressed: () =>
                                ctrl.sendControlMessage('previous'),
                            icon: const Icon(Icons.skip_previous),
                            tooltip: '上一首',
                            iconSize: 32,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.grey.withOpacity(0.1),
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              final playStatus = ctrl.lastPlayStatus;
                              if (playStatus?.isPlaying == true) {
                                ctrl.sendControlMessage('pause');
                              } else {
                                ctrl.sendControlMessage('play');
                              }
                            },
                            icon: Icon(
                              playStatus?.isPlaying == true
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                            tooltip: '播放/暂停',
                            iconSize: 36,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.blue.withOpacity(0.1),
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                          IconButton(
                            onPressed: () => ctrl.sendControlMessage('next'),
                            icon: const Icon(Icons.skip_next),
                            tooltip: '下一首',
                            iconSize: 32,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.grey.withOpacity(0.1),
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // 连接信息卡片
            _buildInfoCard('连接信息', [
              _buildInfoRow('连接状态', ctrl.statusMessage),
              if (ctrl.isConnected) ...[
                _buildInfoRow('服务器地址', ctrl.serverAddress),
                _buildInfoRow('连接地址', ctrl.serverUrl),
              ],
            ]),
          ],
        );
      }),
    );
  }

  /// 格式化时间戳
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}秒前';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildConfigTab(WebSocketClientController controller) {
    final addressController = TextEditingController(
      text: controller.serverAddress,
    );
    final reconnectController = TextEditingController(
      text: controller.reconnectInterval.toString(),
    );
    final heartbeatController = TextEditingController(
      text: controller.heartbeatInterval.toString(),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Obx(() {
        final ctrl = Get.find<WebSocketClientController>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ctrl.isConnected)
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
                        '连接时不能修改配置',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),

            // 自动启动配置
            _buildConfigSection('启动配置', [
              Row(
                children: [
                  Expanded(
                    child: Text('应用启动时自动连接', style: TextStyle(fontSize: 16)),
                  ),
                  Switch(
                    value: ctrl.wsClientAutoStart,
                    onChanged: ctrl.updateAutoStart,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '在主页中显示WebSocket客户端按钮',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  Switch(
                    value: ctrl.wsClientBtnShow,
                    onChanged: ctrl.updateBtnShow,
                  ),
                ],
              ),
            ]),

            const SizedBox(height: 24),

            _buildConfigSection('连接配置', [
              Column(
                children: [
                  _buildTextField(
                    controller: addressController,
                    label: '服务器地址',
                    hint: 'IP:端口 (例如: 192.168.1.100:8080)',
                    enabled: !ctrl.isConnected,
                    onChanged: ctrl.updateServerAddress,
                  ),
                  const SizedBox(height: 12),
                  // 扫描二维码按钮（仅在Android显示）
                  if (Platform.isAndroid)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: ctrl.isConnected ? null : _scanQRCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.withOpacity(0.1),
                          foregroundColor: Colors.orange,
                          elevation: 0,
                          side: BorderSide(color: Colors.orange.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.qr_code_scanner, size: 20),
                        label: const Text('扫描服务器二维码'),
                      ),
                    ),
                ],
              ),
            ]),

            const SizedBox(height: 24),

            _buildConfigSection('重连配置', [
              Row(
                children: [
                  Expanded(child: Text('自动重连', style: TextStyle(fontSize: 16))),
                  Switch(
                    value: ctrl.autoReconnect,
                    onChanged: ctrl.updateAutoReconnect,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: reconnectController,
                label: '重连间隔 (秒)',
                hint: '1-60',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  final interval = int.tryParse(value);
                  if (interval != null) ctrl.updateReconnectInterval(interval);
                },
              ),
            ]),

            const SizedBox(height: 24),

            _buildConfigSection('心跳配置', [
              _buildTextField(
                controller: heartbeatController,
                label: '心跳间隔 (秒)',
                hint: '5-300',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  final interval = int.tryParse(value);
                  if (interval != null) ctrl.updateHeartbeatInterval(interval);
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

  /// 扫描二维码获取服务器地址
  Future<void> _scanQRCode() async {
    try {
      final result = await Get.to<String>(
        () => const QRScannerPage(),
        transition: Transition.rightToLeft,
      );
      
      if (result != null && result.isNotEmpty) {
        // 更新服务器地址
        final controller = Get.find<WebSocketClientController>();
        controller.updateServerAddress(result);
        
        // 显示成功提示
        Get.snackbar(
          '扫描成功',
          '服务器地址已更新为: $result',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      Get.snackbar(
        '扫描失败',
        '无法打开摄像头或扫描过程出错',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }
}

/// 便捷调用方法
class WebSocketClientHelper {
  /// 显示 WebSocket 客户端控制面板
  static Future<void> showControlPanel() async {
    try {
      // 获取控制器
      final controller = Get.find<WebSocketClientController>();

      // 启动状态轮询（如果已连接）
      if (controller.isConnected) {
        controller.startStatusPolling();
      }

      // 显示控制面板
      await WebSocketClientControlPanel.show();

      // 控制面板关闭后，停止状态轮询
      controller.stopStatusPolling();
    } catch (e) {
      // 如果控制器不存在，仅显示控制面板
      await WebSocketClientControlPanel.show();
    }
  }

  /// 获取或创建 WebSocket 客户端控制器
  static WebSocketClientController getController() {
    return Get.find<WebSocketClientController>();
  }

  /// 创建响应式WebSocket客户端按钮
  /// 根据连接状态显示不同颜色的图标
  static Widget buildReactiveButton({
    String? tooltip,
    double iconSize = 24.0,
    EdgeInsets padding = const EdgeInsets.all(8.0),
    bool inMainPage = false,
  }) {
    return Obx(() {
      // 获取WebSocket客户端控制器
      WebSocketClientController? controller;
      try {
        controller = Get.find<WebSocketClientController>();
      } catch (e) {
        return IconButton(
          tooltip: tooltip ?? "WebSocket客户端",
          icon: Icon(Icons.cast_connected, color: Colors.grey, size: iconSize),
          padding: padding,
          onPressed: () async {
            await showControlPanel();
          },
        );
      }

      // 检查是否应该显示按钮
      if (inMainPage && !controller.wsClientBtnShow) {
        return const SizedBox.shrink();
      }

      // 根据连接状态确定图标颜色和状态
      Color iconColor;
      String currentTooltip;

      if (controller.isConnecting || controller.isDisconnecting) {
        iconColor = Colors.amber;
        currentTooltip = controller.isConnecting
            ? "WebSocket客户端 (连接中...)"
            : "WebSocket客户端 (断开中...)";
      } else if (controller.isConnected) {
        iconColor = Colors.blue;
        currentTooltip = "WebSocket客户端 (已连接)";
      } else if (controller.isReconnecting) {
        iconColor = Colors.orange;
        currentTooltip = "WebSocket客户端 (重连中...)";
      } else {
        iconColor = Colors.grey;
        currentTooltip = "WebSocket客户端 (未连接)";
      }

      return IconButton(
        tooltip: tooltip ?? currentTooltip,
        icon: Icon(Icons.cast_connected, color: iconColor, size: iconSize),
        padding: padding,
        onPressed: () async {
          await showControlPanel();
        },
      );
    });
  }

  /// 发送播放指定歌曲的消息
  static void sendTrack(dynamic trackData) {
    try {
      final controller = Get.find<WebSocketClientController>();
      controller.sendTrackMessage(trackData);
    } catch (e) {
      print('发送歌曲播放请求失败: $e');
    }
  }
}
