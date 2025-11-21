import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:logger/logger.dart';
import 'package:listen1_xuan/controllers/controllers.dart';

void broadcastWs() {
  try {
    final wsServerController =
        Get.find<WebSocketCardController>().wsServerController;
    wsServerController?.broadcastStatus();
  } catch (e) {
    debugPrint('No WebSocketCardController found: ${e.toString()}');
  }
}

/// WebSocket 卡片控制器
/// 管理WebSocket服务器的状态和UI交互
class WebSocketCardController extends GetxController {
  static const String _tag = 'WebSocketCardController';
  final Logger _logger = Logger();

  /// WebSocket 服务器控制器实例
  WebSocketServerController? wsServerController;

  /// UI状态
  final RxBool _isExpanded = false.obs;
  final RxString _statusMessage = '未启动'.obs;
  final RxBool _isStarting = false.obs;
  final RxBool _isStopping = false.obs;
  final RxBool _isServerRunning = false.obs;
  final RxInt _clientCount = 0.obs;
  final RxString _serverUrl = ''.obs;

  /// WebSocket服务器是否自动启动的标志位
  final RxBool _wsServerAutoStart = false.obs;
  final RxBool _wsServerBtnShow = true.obs;

  /// 服务器配置
  final RxString _host = '0.0.0.0'.obs; // 固定使用0.0.0.0监听所有地址
  final RxInt _port = 25917.obs;
  final RxInt _pingInterval = 30.obs; // 秒
  final RxInt _pongTimeout = 5.obs; // 秒

  /// 广播消息控制器
  final TextEditingController messageController = TextEditingController();

  /// Getters (返回响应式值)
  RxBool get isExpandedRx => _isExpanded;
  RxString get statusMessageRx => _statusMessage;
  RxBool get isStartingRx => _isStarting;
  RxBool get isStoppingRx => _isStopping;
  RxString get hostRx => _host;
  RxInt get portRx => _port;
  RxInt get pingIntervalRx => _pingInterval;
  RxInt get pongTimeoutRx => _pongTimeout;
  RxBool get isServerRunningRx => _isServerRunning;
  RxInt get clientCountRx => _clientCount;
  RxString get serverUrlRx => _serverUrl;
  RxBool get wsServerAutoStartRx => _wsServerAutoStart;
  RxBool get wsServerBtnShowRx => _wsServerBtnShow;

  // 保留原有的getter用于非响应式访问
  bool get isExpanded => _isExpanded.value;
  String get statusMessage => _statusMessage.value;
  bool get isStarting => _isStarting.value;
  bool get isStopping => _isStopping.value;
  String get host => _host.value;
  int get port => _port.value;
  int get pingInterval => _pingInterval.value;
  int get pongTimeout => _pongTimeout.value;

  bool get isServerRunning => _isServerRunning.value;
  int get clientCount => _clientCount.value;
  String get serverUrl => _serverUrl.value;
  bool get wsServerAutoStart => _wsServerAutoStart.value;
  bool get wsServerBtnShow => _wsServerBtnShow.value;

  /// 从设置控制器加载WebSocket配置
  void loadWebSocketSettings() {
    try {
      final settingsController = Get.find<SettingsController>();
      final settings = settingsController.settings;

      // 读取WebSocket服务器配置
      _wsServerAutoStart.value = settings['wsServerAutoStart'] ?? false;
      _wsServerBtnShow.value = settings['wsServerBtnShow'] ?? true;
      final serverPort = settings['wsServerPort'] as int?;

      // 固定使用0.0.0.0地址，不再从设置中读取
      _host.value = '0.0.0.0';

      if (serverPort != null && serverPort >= 1024 && serverPort <= 65535) {
        _port.value = serverPort;
      }

      _logger.i('$_tag 配置加载完成: 自动启动=$wsServerAutoStart, 地址=$host:$port');
    } catch (e) {
      _logger.w('$_tag 配置加载失败: $e');
    }
  }

  /// 保存WebSocket配置到Settings
  void saveWebSocketSettings() {
    try {
      final settingsController = Get.find<SettingsController>();
      final settings = settingsController.settings;

      // 保存WebSocket服务器配置
      settings['wsServerAutoStart'] = _wsServerAutoStart.value;
      settings['wsServerBtnShow'] = _wsServerBtnShow.value;
      // 不再保存地址配置，固定使用0.0.0.0
      settings['wsServerPort'] = _port.value;

      // 触发设置保存
      settingsController.setSettings(settings);

      _logger.i('$_tag 配置保存完成: 自动启动=$wsServerAutoStart, 地址=$host:$port');
    } catch (e) {
      _logger.w('$_tag 配置保存失败: $e');
    }
  }

  /// 更新自动启动设置
  void updateAutoStart(bool enabled) {
    _wsServerAutoStart.value = enabled;
    saveWebSocketSettings();
  }

  /// 更新服务器按钮显示设置
  void updateBtnShow(bool enabled) {
    _wsServerBtnShow.value = enabled;
    saveWebSocketSettings();
  }

  /// 如果设置了自动启动，则启动WebSocket服务器
  Future<void> autoStartServerIfNeeded() async {
    if (_wsServerAutoStart.value) {
      _logger.i('$_tag 自动启动WebSocket服务器');

      // 直接尝试启动服务器（使用固定的0.0.0.0地址）
      await _tryStartServer();
    }
  }

  final RxList<String> availableIpAddresses = <String>[].obs;
  final RxBool isLoadingIpAddresses = false.obs;
  RxString selectBestAvailableAddress = '127.0.0.1'.obs;

  /// 刷新本地IP地址列表
  Future<void> refreshIpAddresses() async {
    if (isLoadingIpAddresses.value) return;

    try {
      isLoadingIpAddresses.value = true;
      _logger.i('$_tag 正在获取本地IP地址...');

      final List<String> ipList = <String>[]; // 不包含默认的0.0.0.0

      // 获取网络接口列表
      List<NetworkInterface> interfaces = await NetworkInterface.list(
        includeLoopback: true, // 是否包含回环接口
        includeLinkLocal: true, // 是否包含链路本地接口（例如IPv6的自动配置地址）。
        type: InternetAddressType.any,
      );

      // 筛选IPv4地址，并按优先级排序
      final List<String> localAreaNetworkIps = <String>[];
      final List<String> otherIps = <String>[];
      final List<String> loopbackIps = <String>[];

      for (NetworkInterface interface in interfaces) {
        for (InternetAddress address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4) {
            final ip = address.address;
            if (ip == '127.0.0.1') {
              // 回环地址优先级最低
              if (!loopbackIps.contains(ip)) {
                loopbackIps.add(ip);
              }
            } else if (ip.startsWith('192.168.') ||
                ip.startsWith('10.') ||
                ip.startsWith('172.')) {
              // 局域网地址优先级较高
              if (!localAreaNetworkIps.contains(ip)) {
                localAreaNetworkIps.add(ip);
              }
            } else {
              // 其他地址（可能是公网地址）
              if (!otherIps.contains(ip)) {
                otherIps.add(ip);
              }
            }
          }
        }
      }

      // 按优先级顺序添加：局域网地址 > 其他地址 > 回环地址
      ipList.addAll(localAreaNetworkIps);
      ipList.addAll(otherIps);
      ipList.addAll(loopbackIps);

      availableIpAddresses.value = ipList;
      _logger.i('$_tag 获取到IP地址: $ipList');

      // 检查当前选中的地址是否在列表中，如果不在则自动选择最优地址
      if (!ipList.contains(selectBestAvailableAddress.value)) {
        if (ipList.isNotEmpty) {
          selectBestAvailableAddress.value = ipList.first;
          _logger.i('$_tag 选择新的最佳IP地址: ${selectBestAvailableAddress.value}');
        }
      }
    } catch (e) {
      _logger.e('$_tag 获取IP地址失败', error: e);
      _showError('获取IP地址失败: $e');
      // 设置默认值（仅包含回环地址）
      availableIpAddresses.value = ['127.0.0.1'];
    } finally {
      isLoadingIpAddresses.value = false;
    }
  }

  /// 尝试启动服务器的内部方法
  Future<bool> _tryStartServer() async {
    if (isServerRunning || _isStarting.value) return true;

    try {
      _isStarting.value = true;
      _updateStatusMessage('正在启动...');

      // 创建新的服务器实例
      wsServerController = WebSocketServerController(
        host: _host.value,
        port: _port.value,
        pingInterval: Duration(seconds: _pingInterval.value),
        pongTimeout: Duration(seconds: _pongTimeout.value),
      );

      // 启动服务器
      final success = await wsServerController!.startServer();

      if (success) {
        _isServerRunning.value = true;
        _serverUrl.value = wsServerController!.serverUrl;
        _updateStatusMessage('运行中');
        _logger.i('$_tag WebSocket服务器启动成功: $serverUrl');

        // 启动状态监听
        _startStatusMonitoring();
        return true;
      } else {
        wsServerController = null;
        _isServerRunning.value = false;
        _serverUrl.value = '';
        _clientCount.value = 0;
        _updateStatusMessage('启动失败');
        _showError('服务器启动失败，请检查端口 $_port 是否被占用或其他资源冲突');
        _logger.e('$_tag 启动服务器失败: 服务器返回 false');
        return false;
      }
    } catch (e) {
      wsServerController = null;
      _isServerRunning.value = false;
      _serverUrl.value = '';
      _clientCount.value = 0;
      _updateStatusMessage('启动失败');
      final errorMsg = '启动服务器异常: $e';
      _showError(errorMsg);
      _logger.e('$_tag $errorMsg', error: e);
      return false;
    } finally {
      _isStarting.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    // 加载设置
    loadWebSocketSettings();
    _updateStatusMessage();
    // 初始化时加载IP地址列表
    _logger.i('$_tag 初始化完成');
  }

  @override
  void onClose() {
    messageController.dispose();
    _stopServer();
    super.onClose();
  }

  /// 切换卡片展开状态
  void toggleExpanded() {
    _isExpanded.value = !_isExpanded.value;
  }

  /// 更新端口
  void updatePort(int newPort) {
    if (isServerRunning) {
      _showError('服务器运行时不能更改配置');
      return;
    }
    if (newPort < 1024 || newPort > 65535) {
      _showError('端口号必须在 1024-65535 之间');
      return;
    }
    _port.value = newPort;
    saveWebSocketSettings();
  }

  /// 更新心跳间隔
  void updatePingInterval(int seconds) {
    if (seconds < 5 || seconds > 300) {
      _showError('心跳间隔必须在 5-300 秒之间');
      return;
    }
    _pingInterval.value = seconds;
  }

  /// 更新Pong超时
  void updatePongTimeout(int seconds) {
    if (seconds < 1 || seconds > 60) {
      _showError('Pong超时必须在 1-60 秒之间');
      return;
    }
    _pongTimeout.value = seconds;
  }

  /// 启动WebSocket服务器（手动启动，显示提示消息）
  Future<void> startServer() async {
    if (isServerRunning || _isStarting.value) return;

    // 直接尝试启动服务器（使用固定的0.0.0.0地址）
    final success = await _tryStartServer();

    if (success) {
      _showSuccess('WebSocket 服务器启动成功');
    }
    // 错误消息已在 _tryStartServer 中显示，不重复弹出
  }

  /// 停止WebSocket服务器
  Future<void> stopServer() async {
    await _stopServer();
  }

  Future<void> _stopServer() async {
    if (!isServerRunning || _isStopping.value) return;

    try {
      _isStopping.value = true;
      _updateStatusMessage('正在停止...');

      await wsServerController?.stopServer();
      wsServerController = null;

      _isServerRunning.value = false;
      _serverUrl.value = '';
      _clientCount.value = 0;
      _updateStatusMessage('已停止');
      _showSuccess('WebSocket 服务器已停止');
      _logger.i('$_tag WebSocket服务器已停止');
    } catch (e) {
      _showError('停止服务器时发生错误: $e');
      _logger.e('$_tag 停止服务器失败', error: e);
    } finally {
      _isStopping.value = false;
    }
  }

  /// 广播消息
  void broadcastMessage() {
    if (!isServerRunning) {
      _showError('服务器未运行');
      return;
    }

    final message = messageController.text.trim();
    if (message.isEmpty) {
      _showError('请输入要广播的消息');
      return;
    }

    if (clientCount == 0) {
      _showError('没有连接的客户端');
      return;
    }

    try {
      wsServerController?.broadcastMessage({
        'type': 'broadcast',
        'message': message,
        'from': 'flutter_app',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      messageController.clear();
      _showSuccess('消息已广播到 $clientCount 个客户端');
      _logger.i('$_tag 广播消息成功: $message');
    } catch (e) {
      _showError('广播消息失败: $e');
      _logger.e('$_tag 广播消息失败', error: e);
    }
  }

  /// 测试连接
  Future<void> testConnection() async {
    if (!isServerRunning) {
      _showError('请先启动服务器');
      return;
    }

    try {
      _showInfo('正在测试连接...');
      await WebSocketClientTester.testConnection(
        host: _host.value == '0.0.0.0' ? 'localhost' : _host.value,
        port: _port.value,
      );
      _showSuccess('测试连接已发起，请查看控制台日志');
    } catch (e) {
      _showError('测试连接失败: $e');
    }
  }

  /// 启动状态监听
  void _startStatusMonitoring() {
    // 定期更新状态
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (wsServerController == null) {
        timer.cancel();
        return;
      }
      // 更新响应式状态
      _isServerRunning.value = wsServerController!.isRunning;
      _clientCount.value = wsServerController!.clientCount;
      _serverUrl.value = wsServerController!.serverUrl;
      _updateStatusMessage();
    });
  }

  /// 更新状态消息
  void _updateStatusMessage([String? message]) {
    if (message != null) {
      _statusMessage.value = message;
    } else {
      if (isServerRunning) {
        _statusMessage.value = '运行中 ($clientCount 个连接)';
      } else {
        _statusMessage.value = '未启动';
      }
    }
  }

  /// 显示成功消息
  void _showSuccess(String message) {
    showSuccessSnackbar(message, null);
  }

  /// 显示错误消息
  void _showError(String message) {
    showErrorSnackbar(message, null);
  }

  /// 显示信息消息
  void _showInfo(String message) {
    showInfoSnackbar(message, null);
  }
}

/// WebSocket 客户端测试工具
class WebSocketClientTester {
  /// 创建一个简单的客户端连接来测试服务器
  static Future<void> testConnection({
    String host = 'localhost',
    int port = 8080,
  }) async {
    try {
      final uri = 'ws://$host:$port';
      print('正在连接到: $uri');

      final webSocket = await WebSocket.connect(uri);
      print('连接成功！');

      // 监听消息
      webSocket.listen(
        (data) {
          print('收到服务器消息: $data');
        },
        onDone: () {
          print('连接已关闭');
        },
        onError: (error) {
          print('连接错误: $error');
        },
      );

      // 发送测试消息
      webSocket.add(
        '{"type": "message", "content": "Hello from test client!", "timestamp": ${DateTime.now().millisecondsSinceEpoch}}',
      );

      // 5秒后关闭连接
      Future.delayed(const Duration(seconds: 5), () {
        webSocket.close();
      });
    } catch (e) {
      print('连接失败: $e');
    }
  }
}
