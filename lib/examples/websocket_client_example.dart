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
    extends State<WebSocketClientControlContent> {
  late TextEditingController _reconnectController;
  late TextEditingController _heartbeatController;

  @override
  void initState() {
    super.initState();

    // 初始化TextEditingController
    final controller = Get.find<WebSocketClientController>();
    _reconnectController = TextEditingController(
      text: controller.reconnectInterval.toString(),
    );
    _heartbeatController = TextEditingController(
      text: controller.heartbeatInterval.toString(),
    );
  }

  @override
  void dispose() {
    _reconnectController.dispose();
    _heartbeatController.dispose();
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
                      const SizedBox(width: 12), // 扫描二维码按钮（仅在Android显示）
                      if (Platform.isAndroid)
                        SizedBox(
                          width: 100,
                          child: ElevatedButton.icon(
                            onPressed: ctrl.isConnected ? null : _scanQRCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.withOpacity(0.1),
                              foregroundColor: Colors.orange,
                              elevation: 0,
                              side: BorderSide(
                                color: Colors.orange.withOpacity(0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.qr_code_scanner, size: 20),
                            label: const Text('扫码'),
                          ),
                        ),
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
          // Tab 内容
          Expanded(child: _buildStatusTab(controller)),
        ],
      ),
    );
  }

  Widget _buildStatusTab(WebSocketClientController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Obx(() {
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
                                      playStatus!.currentTrack!.img_url !=
                                              null &&
                                          playStatus
                                              .currentTrack!
                                              .img_url!
                                              .isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: ExtendedImage.network(
                                            playStatus.currentTrack!.img_url!,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                            cache: true,
                                            loadStateChanged: (ExtendedImageState state) {
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
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        playStatus.currentTrack!.title ??
                                            '未知标题',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        playStatus.currentTrack!.artist ??
                                            '未知艺术家',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (playStatus.currentTrack!.album !=
                                              null &&
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
                              const SizedBox(height: 8),
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
                          Icon(
                            Icons.music_off,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '暂无播放曲目',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ctrl.isConnected
                                ? '正在获取播放状态...'
                                : '请先连接到WebSocket服务器',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
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
                                onPressed: () =>
                                    ctrl.sendControlMessage('next'),
                                icon: const Icon(Icons.skip_next),
                                tooltip: '下一首',
                                iconSize: 32,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.grey.withOpacity(0.1),
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    ctrl.sendChangePlayModeMessage(),
                                icon: Icon(
                                  _getPlayModeIcon(playStatus?.playMode ?? 0),
                                ),
                                tooltip:
                                    '播放模式: ${_getPlayModeText(playStatus?.playMode ?? 0)}',
                                iconSize: 32,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.orange.withOpacity(
                                    0.1,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                            ],
                          ),

                          // 音量控制滑块
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.volume_down),
                              Expanded(
                                child: Slider(
                                  value: ctrl.volume,
                                  min: 0.0,
                                  max: 1.0,
                                  divisions: 100,
                                  label: '${(ctrl.volume * 100).round()}%',
                                  onChangeStart: (value) {
                                    ctrl.startDraggingVolume();
                                  },
                                  onChanged: (value) {
                                    ctrl.updateVolume(value);
                                  },
                                  onChangeEnd: (value) {
                                    ctrl.stopDraggingVolume();
                                  },
                                ),
                              ),
                              const Icon(Icons.volume_up),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 48,
                                child: Text(
                                  '${(ctrl.volume * 100).round()}%',
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),
              ],
            );
          }),
          Obx(() {
            final ctrl = Get.find<WebSocketClientController>();

            // 更新控制器文本以反映当前值
            if (_reconnectController.text !=
                ctrl.reconnectInterval.toString()) {
              _reconnectController.text = ctrl.reconnectInterval.toString();
            }
            if (_heartbeatController.text !=
                ctrl.heartbeatInterval.toString()) {
              _heartbeatController.text = ctrl.heartbeatInterval.toString();
            }

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

                _buildConfigSection('连接配置', [
                  Column(
                    children: [
                      // 服务器地址历史列表和管理
                      _buildServerAddressSection(ctrl),
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
                              side: BorderSide(
                                color: Colors.orange.withOpacity(0.3),
                              ),
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
                // 自动启动配置
                _buildConfigSection('启动配置', [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '应用启动时自动连接',
                          style: TextStyle(fontSize: 16),
                        ),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text('显示悬浮按钮', style: TextStyle(fontSize: 16)),
                      ),
                      Switch(
                        value: ctrl.wsClientBtnShowFloating,
                        onChanged: ctrl.updateBtnShowFloating,
                      ),
                    ],
                  ),
                ]),

                const SizedBox(height: 24),

                _buildConfigSection('重连配置', [
                  Row(
                    children: [
                      Expanded(
                        child: Text('自动重连', style: TextStyle(fontSize: 16)),
                      ),
                      Switch(
                        value: ctrl.autoReconnect,
                        onChanged: ctrl.updateAutoReconnect,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _reconnectController,
                    label: '重连间隔 (秒)',
                    hint: '1-60',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      final interval = int.tryParse(value);
                      if (interval != null)
                        ctrl.updateReconnectInterval(interval);
                    },
                  ),
                ]),

                const SizedBox(height: 24),

                _buildConfigSection('心跳配置', [
                  _buildTextField(
                    controller: _heartbeatController,
                    label: '心跳间隔 (秒)',
                    hint: '5-300',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      final interval = int.tryParse(value);
                      if (interval != null)
                        ctrl.updateHeartbeatInterval(interval);
                    },
                  ),
                ]),
              ],
            );
          }),
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

  /// 构建服务器地址部分
  Widget _buildServerAddressSection(WebSocketClientController controller) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '服务器地址',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!controller.isConnected)
                TextButton.icon(
                  onPressed: () => _showAddAddressDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() {
            final historyAddresses = controller.historyAddresses;
            
            return Column(
              children: [
                // 下拉选择框
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: controller.serverAddress.isEmpty ? null : controller.serverAddress,
                    decoration: const InputDecoration(
                      hintText: '选择或输入服务器地址',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    isExpanded: true,
                    items: [
                      // 当前选中的地址（如果不在历史列表中）
                      if (controller.serverAddress.isNotEmpty && 
                          !historyAddresses.contains(controller.serverAddress))
                        DropdownMenuItem<String>(
                          value: controller.serverAddress,
                          child: Text(controller.serverAddress),
                        ),
                      // 历史地址列表
                      ...historyAddresses.map((address) => 
                        DropdownMenuItem<String>(
                          value: address,
                          child: Row(
                            children: [
                              Expanded(child: Text(address)),
                              if (!controller.isConnected) ...[
                                IconButton(
                                  onPressed: () => _showEditAddressDialog(
                                    historyAddresses.indexOf(address), 
                                    address
                                  ),
                                  icon: const Icon(Icons.edit, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                  tooltip: '编辑',
                                ),
                                IconButton(
                                  onPressed: () => _showDeleteAddressDialog(
                                    historyAddresses.indexOf(address), 
                                    address
                                  ),
                                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                  tooltip: '删除',
                                ),
                              ],
                            ],
                          ),
                        ),
                      ).toList(),
                    ],
                    onChanged: controller.isConnected ? null : (String? value) {
                      if (value != null) {
                        controller.updateServerAddress(value);
                      }
                    },
                  ),
                ),
                // 如果没有历史地址，显示提示
                if (historyAddresses.isEmpty && controller.serverAddress.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '暂无历史连接地址，请点击添加按钮添加地址',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// 显示添加地址对话框
  Future<void> _showAddAddressDialog() async {
    final controller = Get.find<WebSocketClientController>();
    final textController = TextEditingController();

    final result = await Get.dialog<String>(
      AlertDialog(
        title: const Text('添加服务器地址'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: '例如: 192.168.1.100:8080',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            const Text(
              '格式: IP地址:端口号 或 域名:端口号',
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
              final address = textController.text.trim();
              if (address.isNotEmpty) {
                Get.back(result: address);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      controller.addHistoryAddress(result);
    }
  }

  /// 显示编辑地址对话框
  Future<void> _showEditAddressDialog(int index, String currentAddress) async {
    final controller = Get.find<WebSocketClientController>();
    final textController = TextEditingController(text: currentAddress);

    final result = await Get.dialog<String>(
      AlertDialog(
        title: const Text('编辑服务器地址'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: '例如: 192.168.1.100:8080',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            const Text(
              '格式: IP地址:端口号 或 域名:端口号',
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
              final address = textController.text.trim();
              if (address.isNotEmpty) {
                Get.back(result: address);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      controller.editHistoryAddress(index, result);
    }
  }

  /// 显示删除地址确认对话框
  Future<void> _showDeleteAddressDialog(int index, String address) async {
    final controller = Get.find<WebSocketClientController>();

    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('删除地址'),
        content: Text('确定要删除地址 "$address" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (result == true) {
      controller.deleteHistoryAddress(index);
    }
  }

  /// 获取播放模式文本描述
  String _getPlayModeText(int playMode) {
    switch (playMode) {
      case 0:
        return '循环播放';
      case 1:
        return '随机播放';
      case 2:
        return '单曲循环';
      default:
        return '未知模式';
    }
  }

  /// 获取播放模式图标
  IconData _getPlayModeIcon(int playMode) {
    switch (playMode) {
      case 0:
        return Icons.repeat;
      case 1:
        return Icons.shuffle;
      case 2:
        return Icons.repeat_one;
      default:
        return Icons.help_outline;
    }
  }

  /// 扫描二维码获取服务器地址
  Future<void> _scanQRCode() async {
    try {
      final result = await Get.to<String>(
        () => const QRScannerPage(),
        transition: Transition.rightToLeft,
      );

      if (result != null && result.isNotEmpty) {
        final controller = Get.find<WebSocketClientController>();
        
        // 检查地址是否已存在于历史列表中
        if (controller.historyAddresses.contains(result)) {
          // 如果地址已存在，直接选中
          controller.updateServerAddress(result);
          
          // 显示成功提示
          Get.snackbar(
            '扫描成功',
            '已选中历史地址: $result',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.blue.withOpacity(0.8),
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        } else {
          // 如果地址不存在，添加到历史列表并选中
          controller.addHistoryAddress(result);
          
          // 显示成功提示
          Get.snackbar(
            '扫描成功',
            '已添加并选中新地址: $result',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.green.withOpacity(0.8),
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
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

/// 服务器地址编辑对话框
class _ServerAddressEditDialog extends StatefulWidget {
  final String initialAddress;

  const _ServerAddressEditDialog({required this.initialAddress});

  @override
  State<_ServerAddressEditDialog> createState() =>
      _ServerAddressEditDialogState();
}

class _ServerAddressEditDialogState extends State<_ServerAddressEditDialog> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialAddress);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool _isValidServerAddress(String address) {
    if (address.isEmpty) return false;

    final RegExp addressRegex = RegExp(
      r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?):(?:[0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$',
    );

    // 也支持主机名格式
    final RegExp hostnameRegex = RegExp(
      r'^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*:[0-9]{1,5}$',
    );

    return addressRegex.hasMatch(address) || hostnameRegex.hasMatch(address);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑服务器地址'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _textController,
            decoration: const InputDecoration(
              labelText: '服务器地址',
              hintText: 'IP:端口 (例如: 192.168.1.100:8080)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.text,
            autofocus: true,
          ),
          const SizedBox(height: 8),
          const Text(
            '格式: IP地址:端口号',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            final address = _textController.text.trim();
            if (_isValidServerAddress(address)) {
              Get.back(result: address);
            } else {
              Get.snackbar(
                '输入错误',
                '无效的服务器地址格式',
                snackPosition: SnackPosition.TOP,
                backgroundColor: Colors.red.withOpacity(0.8),
                colorText: Colors.white,
                duration: const Duration(seconds: 2),
              );
            }
          },
          child: const Text('保存'),
        ),
      ],
    );
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
