import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/receiveSharingIntentController.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/main.dart';
import 'package:listen1_xuan/widgets/motor_progress_indicator_xuan.dart';
import 'package:listen1_xuan/widgets/draggable_toast/draggable_toast.dart';
import 'package:logger/logger.dart';
import 'package:listen1_xuan/services/app_logger.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:punycode/punycode.dart';

import '../utils/websocket_address.dart';
import '../global_settings_animations.dart';
import '../models/websocket_message.dart';
import '../settings.dart';
import '../utils/platform_credentials.dart';
import 'controllers.dart';

/// WebSocket 客户端控制器
/// 管理WebSocket客户端的连接状态和UI交互
class WebSocketClientController extends GetxController {
  static const String _tag = 'WebSocketClientController';
  final Logger _logger = createAppLogger();

  /// WebSocket 客户端实例
  WebSocket? _webSocket;

  /// UI状态
  final RxBool _isExpanded = false.obs;
  final RxString _statusMessage = '未连接'.obs;
  final RxBool i_isConnecting = false.obs;
  final RxBool _isDisconnecting = false.obs;
  final RxBool i_isConnected = false.obs;
  final RxString _serverUrl = ''.obs;

  /// WebSocket客户端是否自动启动的标志位
  final RxBool _wsClientAutoStart = false.obs;
  final RxBool _wsClientBtnShow = false.obs;
  final RxBool _wsClientBtnShowFloating = false.obs;

  /// 客户端配置
  final RxString _serverAddress = '127.0.0.1:25917'.obs;
  final RxBool _autoReconnect = false.obs;
  final RxInt _reconnectInterval = 5.obs; // 秒
  final RxInt _heartbeatInterval = 30.obs; // 秒

  /// 历史地址管理
  final RxList<String> _historyAddresses = <String>[].obs;
  final RxString lastConnectedDeviceId = ''.obs;
  final RxString lastConnectedDeviceNewAddr = ''.obs;

  final RxSet<String> canAddAddr = <String>{}.obs;

  /// 连接管理
  final RxBool _isReconnecting = false.obs;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _statusPollingTimer;

  /// 连接取消控制
  bool _connectionCancelled = false;

  /// 每次连接尝试的序号，取消/新连接后旧尝试的结果直接丢弃
  int _connectAttemptId = 0;

  /// 当前连接尝试使用的 HttpClient（取消时强制中断 DNS/TCP/HTTP 升级）
  HttpClient? _connectingHttpClient;

  /// 让 connect() 立即从等待中返回，不必依赖底层 socket 超时
  Completer<void>? _connectAbortCompleter;

  /// 已连接 WebSocket 的订阅，断开时取消，避免旧连接回调污染新状态
  StreamSubscription<dynamic>? _wsSubscription;

  /// 手动断开标记，避免 onDone/onError 触发自动重连
  bool _manualClosing = false;

  /// 建连超时，避免地址不可达时长时间卡在“连接中”
  static const Duration _connectTimeout = Duration(seconds: 10);

  /// 音量控制
  final RxDouble _volume = 0.5.obs;
  final RxBool _isDraggingVolume = false.obs;

  /// 进度控制
  final RxDouble setProcessTime = 0.0.obs;
  final Rx<Duration> processTime = Duration.zero.obs;
  final Rx<Duration> totalTime = Duration(minutes: 1).obs;
  final RxBool _isDraggingProcess = false.obs;

  /// 播放状态数据
  final Rx<PlayStatusData?> _lastPlayStatus = Rx<PlayStatusData?>(null);

  /// Getters (返回响应式值)
  RxBool get isExpandedRx => _isExpanded;
  RxString get statusMessageRx => _statusMessage;
  RxBool get isConnectingRx => i_isConnecting;
  RxBool get isDisconnectingRx => _isDisconnecting;
  RxString get serverAddressRx => _serverAddress;
  RxBool get autoReconnectRx => _autoReconnect;
  RxInt get reconnectIntervalRx => _reconnectInterval;
  RxInt get heartbeatIntervalRx => _heartbeatInterval;
  RxBool get isConnectedRx => i_isConnected;
  RxString get serverUrlRx => _serverUrl;
  RxBool get wsClientAutoStartRx => _wsClientAutoStart;
  RxBool get wsClientBtnShowRx => _wsClientBtnShow;
  RxBool get wsClientBtnShowFloatingRx => _wsClientBtnShowFloating;
  RxBool get isReconnectingRx => _isReconnecting;
  Rx<PlayStatusData?> get lastPlayStatusRx => _lastPlayStatus;
  RxDouble get volumeRx => _volume;
  RxBool get isDraggingVolumeRx => _isDraggingVolume;
  RxList<String> get historyAddressesRx => _historyAddresses;

  // 保留原有的getter用于非响应式访问
  bool get isExpanded => _isExpanded.value;
  String get statusMessage => _statusMessage.value;
  bool get isConnecting => i_isConnecting.value;
  bool get isDisconnecting => _isDisconnecting.value;
  String get serverAddress => _serverAddress.value;
  bool get autoReconnect => _autoReconnect.value;
  int get reconnectInterval => _reconnectInterval.value;
  int get heartbeatInterval => _heartbeatInterval.value;
  bool get isConnected => i_isConnected.value;
  String get serverUrl => _serverUrl.value;
  bool get wsClientAutoStart => _wsClientAutoStart.value;
  bool get wsClientBtnShow => _wsClientBtnShow.value;
  bool get wsClientBtnShowFloating => _wsClientBtnShowFloating.value;
  bool get isReconnecting => _isReconnecting.value;
  PlayStatusData? get lastPlayStatus => _lastPlayStatus.value;
  double get volume => _volume.value;
  bool get isDraggingVolume => _isDraggingVolume.value;
  List<String> get historyAddresses => _historyAddresses;

  /// 从设置控制器加载WebSocket客户端配置
  void loadWebSocketClientSettings() {
    try {
      final settingsController = Get.find<SettingsController>();
      final settings = settingsController.settings;

      // 读取WebSocket客户端配置
      _wsClientAutoStart.value = settings['wsClientAutoStart'] ?? false;
      _wsClientBtnShow.value = settings['wsClientBtnShow'] ?? globalHorizon
          ? true
          : false;
      _wsClientBtnShowFloating.value =
          settings['wsClientBtnShowFloating'] ?? false;
      final address = settings['wsClientAddress'] as String?;
      final autoReconn = settings['wsClientAutoReconnect'] as bool?;
      final reconnInterval = settings['wsClientReconnectInterval'] as int?;
      final heartInterval = settings['wsClientHeartbeatInterval'] as int?;

      if (address != null && address.isNotEmpty) {
        _serverAddress.value = address;
      }

      if (autoReconn != null) {
        _autoReconnect.value = autoReconn;
      }

      if (reconnInterval != null &&
          reconnInterval >= 1 &&
          reconnInterval <= 60) {
        _reconnectInterval.value = reconnInterval;
      }

      if (heartInterval != null && heartInterval >= 5 && heartInterval <= 300) {
        _heartbeatInterval.value = heartInterval;
      }

      // 加载历史地址列表
      final historyList =
          settings['wsClientHistoryAddresses'] as List<dynamic>?;
      if (historyList != null) {
        _historyAddresses.value = historyList.map((e) => e.toString()).toList();
      } else {
        _historyAddresses.value = [];
      }
      lastConnectedDeviceId.value = settings['lastConnectedDeviceId'] ?? '';
      _logger.i('$_tag 客户端配置加载完成: 自动启动=$wsClientAutoStart, 地址=$serverAddress');
    } catch (e) {
      _logger.w('$_tag 客户端配置加载失败: $e');
    }
  }

  /// 保存WebSocket客户端配置到Settings
  void saveWebSocketClientSettings() {
    try {
      final settingsController = Get.find<SettingsController>();
      final settings = settingsController.settings;

      // 保存WebSocket客户端配置
      settings['wsClientAutoStart'] = _wsClientAutoStart.value;
      settings['wsClientBtnShow'] = _wsClientBtnShow.value;
      settings['wsClientAddress'] = _serverAddress.value;
      settings['wsClientBtnShowFloating'] = _wsClientBtnShowFloating.value;
      settings['wsClientAutoReconnect'] = _autoReconnect.value;
      settings['wsClientReconnectInterval'] = _reconnectInterval.value;
      settings['wsClientHeartbeatInterval'] = _heartbeatInterval.value;

      // 保存历史地址列表
      settings['wsClientHistoryAddresses'] = _historyAddresses.toList();

      // 触发设置保存
      settingsController.setSettings(settings);

      _logger.i('$_tag 客户端配置保存完成: 自动启动=$wsClientAutoStart, 地址=$serverAddress');
    } catch (e) {
      _logger.w('$_tag 客户端配置保存失败: $e');
    }
  }

  /// 更新自动启动设置
  void updateAutoStart(bool enabled) {
    _wsClientAutoStart.value = enabled;
    saveWebSocketClientSettings();
  }

  /// 更新客户端按钮显示设置
  void updateBtnShow(bool enabled) {
    _wsClientBtnShow.value = enabled;
    saveWebSocketClientSettings();
  }

  void updateBtnShowFloating(bool enabled) {
    _wsClientBtnShowFloating.value = enabled;
    saveWebSocketClientSettings();
  }

  /// 如果设置了自动启动，则连接WebSocket服务器
  Future<void> autoConnectIfNeeded() async {
    if (isAndroid) Get.find<ReceiveSharingIntentController>().regController();
    if (_wsClientAutoStart.value) {
      _logger.i('$_tag 自动连接WebSocket服务器');
      await connect();
    }
  }

  @override
  void onInit() {
    super.onInit();
    // 加载设置
    _updateStatusMessage();
    _logger.i('$_tag 初始化完成');
    interval(_volume, (value) {
      if (isConnected) {
        sendVolumeControlMessage(value);
      }
    }, time: const Duration(milliseconds: 100));
    interval(setProcessTime, (value) {
      if (isConnected) {
        sendProgressControlMessage(value);
      }
    }, time: const Duration(milliseconds: 100));
    ever(lastConnectedDeviceId, (value) {
      Get.find<SettingsController>().settings['lastConnectedDeviceId'] = value;
    });
  }

  @override
  void onClose() {
    // 清理进行中的连接尝试
    _connectionCancelled = true;
    _connectAttemptId++;
    final abortCompleter = _connectAbortCompleter;
    _connectAbortCompleter = null;
    if (abortCompleter != null && !abortCompleter.isCompleted) {
      abortCompleter.complete();
    }
    _connectingHttpClient?.close(force: true);
    _connectingHttpClient = null;
    _wsSubscription?.cancel();
    _wsSubscription = null;

    stopStatusPolling();
    _disconnect(manual: true);
    super.onClose();
  }

  /// 切换卡片展开状态
  void toggleExpanded() {
    _isExpanded.value = !_isExpanded.value;
  }

  /// 更新服务器地址
  void updateServerAddress(String newAddress) {
    if (isConnected) {
      _showError('连接时不能更改配置');
      return;
    }
    _serverAddress.value = newAddress.trim();
    saveWebSocketClientSettings();
    _logger.i('$_tag 服务器地址已更新为: $newAddress');
  }

  /// 更新自动重连设置
  void updateAutoReconnect(bool enabled) {
    _autoReconnect.value = enabled;
    saveWebSocketClientSettings();

    if (!enabled) {
      _stopReconnectTimer();
      _isReconnecting.value = false;
    }
  }

  /// 更新重连间隔
  void updateReconnectInterval(int seconds) {
    if (seconds < 1 || seconds > 60) {
      _showError('重连间隔必须在 1-60 秒之间');
      return;
    }
    _reconnectInterval.value = seconds;
    saveWebSocketClientSettings();
  }

  /// 更新心跳间隔
  void updateHeartbeatInterval(int seconds) {
    if (seconds < 5 || seconds > 300) {
      _showError('心跳间隔必须在 5-300 秒之间');
      return;
    }
    _heartbeatInterval.value = seconds;
    saveWebSocketClientSettings();

    // 如果已连接，重启心跳定时器
    if (isConnected) {
      _startHeartbeatTimer();
    }
  }

  /// 历史地址管理方法

  /// 添加地址到历史列表（连接成功后自动调用）
  void _addToHistoryAddresses(String address) {
    if (address.isEmpty) return;

    // 移除已存在的相同地址
    _historyAddresses.removeWhere((item) => item == address);

    // 将新地址添加到列表开头
    _historyAddresses.insert(0, address);

    // 限制历史记录数量（最多保存20个）
    if (_historyAddresses.length > 20) {
      _historyAddresses.removeRange(20, _historyAddresses.length);
    }

    // 保存到设置
    saveWebSocketClientSettings();
    _logger.i('$_tag 地址已添加到历史列表: $address');
  }

  /// 手动添加地址到历史列表
  void addHistoryAddress(String address) {
    if (address.isEmpty) {
      // _showError('地址不能为空');
      throw '地址不能为空';
    }

    _addToHistoryAddresses(address);

    // 自动选中新添加的地址
    _serverAddress.value = address;
    saveWebSocketClientSettings();
  }

  /// 编辑历史地址
  void editHistoryAddress(int index, String newAddress) {
    if (index < 0 || index >= _historyAddresses.length) {
      _showError('索引超出范围');
      return;
    }

    if (newAddress.isEmpty) {
      _showError('地址不能为空');
      return;
    }

    final oldAddress = _historyAddresses[index];

    // 移除新地址的其他实例
    _historyAddresses.removeWhere((item) => item == newAddress);

    // 更新指定位置的地址
    if (index < _historyAddresses.length) {
      _historyAddresses[index] = newAddress;
    } else {
      _historyAddresses.add(newAddress);
    }

    // 如果当前选中的是被编辑的地址，则自动更新
    if (_serverAddress.value == oldAddress) {
      _serverAddress.value = newAddress;
    }

    // 保存到设置
    saveWebSocketClientSettings();
    _logger.i('$_tag 历史地址已更新: $oldAddress -> $newAddress');
  }

  /// 删除历史地址
  void deleteHistoryAddress(int index) {
    if (index < 0 || index >= _historyAddresses.length) {
      _showError('索引超出范围');
      return;
    }

    final address = _historyAddresses[index];
    _historyAddresses.removeAt(index);

    // 保存到设置
    saveWebSocketClientSettings();
    _logger.i('$_tag 历史地址已删除: $address');
    _showSuccess('地址已删除');
  }

  /// 开始拖动进度
  void startDraggingProcess() {
    _isDraggingProcess.value = true;
  }

  /// 结束拖动进度
  void stopDraggingProcess(double newProcess) {
    updateProcess(newProcess);
    _isDraggingProcess.value = false;
    // 拖动结束后发送最终的进度值
    if (isConnected) {
      sendProgressControlMessage(setProcessTime.value);
    }
  }

  /// 更新进度值
  void updateProcess(double newProcess) {
    processTime.value = Duration(
      milliseconds: (newProcess * totalTime.value.inMilliseconds).round(),
    );
    setProcessTime.value = newProcess;
  }

  /// 开始拖动音量
  void startDraggingVolume() {
    _isDraggingVolume.value = true;
  }

  /// 结束拖动音量
  void stopDraggingVolume() {
    _isDraggingVolume.value = false;
    // 拖动结束后发送最终的音量值
    if (isConnected) {
      sendVolumeControlMessage(_volume.value);
    }
  }

  /// 更新音量值
  void updateVolume(double newVolume) {
    _volume.value = newVolume;
  }

  /// 发送音量控制消息
  void sendVolumeControlMessage(double volume) {
    if (!isConnected) return;

    try {
      final message = WebSocketMessage(
        type: 'ctrl',
        content: volume.toString(),
      );
      _webSocket!.add(message.toJsonString());
      _logger.i('$_tag 发送音量控制命令: $volume');
    } catch (e) {
      _logger.e('$_tag 发送音量控制消息失败', error: e);
    }
  }

  /// 发送进度控制消息
  void sendProgressControlMessage(double progress) {
    if (!isConnected) return;

    try {
      final message = WebSocketMessage(
        type: 'ctrl',
        content: 'process_${progress.toString()}',
      );
      _webSocket!.add(message.toJsonString());
      _logger.i('$_tag 发送进度控制命令: $progress');
    } catch (e) {
      _logger.e('$_tag 发送进度控制消息失败', error: e);
    }
  }

  /// 从地址字符串解析出 host 和 port
  /// 支持格式: "host:port", "[IPv6]:port"
  static (String host, int port) parseAddress(String address) {
    final parsed = WebSocketAddress.parse(address);
    return (parsed.host, parsed.port);
  }

  /// IPv6 地址自动加方括号。
  static String formatAddress(String host, int port) =>
      WebSocketAddress(host, port).address;

  static String _buildWsUri(String host, int port) =>
      WebSocketAddress(host, port).uri().toString();

  /// 连接到WebSocket服务器
  Future<void> connect() async {
    if (isConnected || i_isConnecting.value) return;

    final attemptId = ++_connectAttemptId;
    bool cancelled() =>
        _connectionCancelled || attemptId != _connectAttemptId;
    // 已被新的连接尝试取代（不能覆盖新尝试的状态文案）
    bool superseded() => attemptId != _connectAttemptId;

    HttpClient? httpClient;
    Completer<void>? abortCompleter;

    try {
      i_isConnecting.value = true;
      _connectionCancelled = false; // 重置取消标志
      _manualClosing = false;
      _updateStatusMessage('正在连接...');

      // 解析服务器地址（支持 IPv4/IPv6）
      final (parsedHost, parsedPort) = parseAddress(_serverAddress.value);

      String host = parsedHost;
      final port = parsedPort;

      // 如果主机名包含非 ASCII 字符，转换为 Punycode 编码
      if (_containsNonAscii(host)) {
        final originalHost = host;
        host = _encodeToPunycode(host);
        _logger.i('$_tag 检测到非 ASCII 主机名，转换为 Punycode: $originalHost -> $host');
      }

      final uri = _buildWsUri(host, port);
      _serverUrl.value = uri;

      // 检查是否已取消连接
      if (cancelled()) {
        if (!superseded()) _updateStatusMessage('连接已取消');
        return;
      }

      // 自建 HttpClient：可设建连超时，也可在取消时强制中断握手
      httpClient = HttpClient()..connectionTimeout = _connectTimeout;
      _connectingHttpClient = httpClient;

      abortCompleter = Completer<void>();
      _connectAbortCompleter = abortCompleter;

      final connectFuture = WebSocket.connect(uri, customClient: httpClient);

      // 取消后底层握手若仍成功，立即关闭，避免遗留连接
      connectFuture.then<void>((ws) {
        if (cancelled()) {
          unawaited(ws.close().catchError((_) {}));
        }
      }, onError: (_) {});

      // 与取消信号赛跑：取消时不必等底层 DNS/TCP 超时
      final ws = await Future.any<WebSocket?>([
        connectFuture,
        abortCompleter.future.then<WebSocket?>((_) => null),
      ]);

      // 再次检查是否已取消连接
      if (ws == null || cancelled()) {
        if (ws != null) {
          unawaited(ws.close().catchError((_) {}));
        }
        if (!superseded()) _updateStatusMessage('连接已取消');
        return;
      }

      _webSocket = ws;
      i_isConnected.value = true;
      _updateStatusMessage('已连接');
      _showSuccess('WebSocket 客户端连接成功');
      _logger.i('$_tag WebSocket客户端连接成功: $uri');

      // 连接成功后添加到历史地址列表
      _addToHistoryAddresses(_serverAddress.value);

      // 停止重连定时器
      _stopReconnectTimer();
      _isReconnecting.value = false;

      // 启动心跳定时器
      _startHeartbeatTimer();

      // 启动状态轮询（如果未启动）
      if (_statusPollingTimer == null || !_statusPollingTimer!.isActive) {
        startStatusPolling();
      }

      // 监听消息
      _wsSubscription?.cancel();
      _wsSubscription = _webSocket!.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: _onError,
      );
    } catch (e) {
      if (cancelled()) {
        // 已取消的连接尝试，不再提示错误，也不触发自动重连
        _logger.i('$_tag 已取消的连接尝试结束: $e');
        return;
      }

      i_isConnected.value = false;
      _serverUrl.value = '';
      _updateStatusMessage('连接失败');
      _showError('连接失败: $e');
      _logger.e('$_tag 连接失败', error: e);

      // 如果启用了自动重连，开始重连
      if (_autoReconnect.value && !_isReconnecting.value) {
        _startReconnectTimer();
      }
    } finally {
      if (identical(_connectingHttpClient, httpClient)) {
        _connectingHttpClient = null;
      }
      if (identical(_connectAbortCompleter, abortCompleter)) {
        _connectAbortCompleter = null;
      }
      // 握手完成后 socket 已 detach，HttpClient 可安全关闭
      httpClient?.close(force: true);

      // 只清理自己这一次尝试的状态，避免影响后续新连接
      if (attemptId == _connectAttemptId) {
        i_isConnecting.value = false;
      }
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _disconnect(manual: true);
  }

  /// 取消正在进行的连接（立即生效，不等待底层 socket 超时）
  void cancelConnection() {
    final wasConnecting = i_isConnecting.value;
    final wasReconnecting = _isReconnecting.value;
    if (!wasConnecting && !wasReconnecting) return;

    _connectionCancelled = true;
    _connectAttemptId++; // 作废当前尝试的结果

    // 停止重连定时器
    _stopReconnectTimer();
    _isReconnecting.value = false;

    if (wasConnecting) {
      // 立即结束 connect() 中的等待
      final abortCompleter = _connectAbortCompleter;
      _connectAbortCompleter = null;
      if (abortCompleter != null && !abortCompleter.isCompleted) {
        abortCompleter.complete();
      }

      // 强制中断进行中的 DNS/TCP/HTTP 升级
      final httpClient = _connectingHttpClient;
      _connectingHttpClient = null;
      httpClient?.close(force: true);

      // 立即恢复 UI 状态
      i_isConnecting.value = false;
      _serverUrl.value = '';
      _updateStatusMessage('已取消连接');
      _showInfo('已取消连接');
      _logger.i('$_tag 用户取消连接');
    } else {
      _updateStatusMessage('重连已取消');
      _showInfo('重连已取消');
      _logger.i('$_tag 用户取消重连');
    }
  }

  Future<void> _disconnect({bool manual = false}) async {
    if (!isConnected || _isDisconnecting.value) return;

    try {
      _isDisconnecting.value = true;
      _manualClosing = true;
      _updateStatusMessage('正在断开...');

      // 停止定时器
      _stopHeartbeatTimer();
      stopStatusPolling();
      if (manual) {
        _stopReconnectTimer();
        _isReconnecting.value = false;
      }

      // 关闭WebSocket连接：不等待关闭握手（对端无响应时 close() 最多卡 5 秒）
      final ws = _webSocket;
      _webSocket = null;
      _wsSubscription?.cancel();
      _wsSubscription = null;
      if (ws != null) {
        unawaited(ws.close().catchError((_) {}));
      }

      i_isConnected.value = false;
      _serverUrl.value = '';
      _updateStatusMessage(manual ? '已断开' : '连接中断');

      if (manual) {
        _showSuccess('WebSocket 客户端已断开');
      }
      _logger.i('$_tag WebSocket客户端已断开');
    } catch (e) {
      _showError('断开连接时发生错误: $e');
      _logger.e('$_tag 断开连接失败', error: e);
    } finally {
      _isDisconnecting.value = false;
    }
  }

  /// 发送消息
  bool sendMessage(WebSocketMessage msg) {
    if (!isConnected) {
      _showError('未连接到服务器');
      return false;
    }
    try {
      _webSocket!.add(msg.toJsonString());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 发送心跳
  void sendHeartbeat() {
    if (!isConnected) {
      _showError('未连接到服务器');
      return;
    }

    try {
      final pingMessage = WebSocketMessageBuilder.createPingMessage();
      _webSocket!.add(pingMessage.toJsonString());
      _showInfo('心跳已发送');
      _logger.i('$_tag 心跳已发送');
    } catch (e) {
      _showError('发送心跳失败: $e');
      _logger.e('$_tag 发送心跳失败', error: e);
    }
  }

  /// 请求播放状态
  void requestPlayStatus() {
    if (!isConnected) {
      _showError('未连接到服务器');
      return;
    }

    try {
      final statusRequest = WebSocketMessageBuilder.createGetStatusRequest();
      _webSocket!.add(statusRequest.toJsonString());
      _showInfo('已请求播放状态');
      _logger.i('$_tag 已请求播放状态');
    } catch (e) {
      _showError('请求播放状态失败: $e');
      _logger.e('$_tag 请求播放状态失败', error: e);
    }
  }

  /// 发送播放控制消息
  void sendControlMessage(String command) {
    if (!isConnected) {
      _showError('未连接到服务器');
      return;
    }

    try {
      final controlMessage = WebSocketMessageBuilder.createControlMessage(
        command,
      );
      _webSocket!.add(controlMessage.toJsonString());
      _logger.i('$_tag 发送播放控制命令: $command');
    } catch (e) {
      _showError('发送控制命令失败: $e');
      _logger.e('$_tag 发送控制命令失败', error: e);
    }
  }

  void sendChangePlayModeMessage() {
    sendControlMessage('changePlayMode');
  }

  /// 发送播放指定歌曲消息
  void sendTrackMessage(Track trackData) {
    if (!isConnected) {
      _showError('未连接到服务器');
      return;
    }

    try {
      final trackMessage = WebSocketMessageBuilder.createTrackMessage(
        trackData,
      );
      _webSocket!.add(trackMessage.toJsonString());

      // 根据歌曲信息显示提示
      String trackInfo = '歌曲';
      if (trackData is Map<String, dynamic>) {
        final title = trackData.title ?? '未知标题';
        final artist = trackData.artist ?? '未知艺术家';
        trackInfo = '$title - $artist';
      }

      _showInfo('已发送播放请求: $trackInfo');
      _logger.i('$_tag 发送播放歌曲命令: $trackInfo');
    } catch (e) {
      _showError('发送播放歌曲命令失败: $e');
      _logger.e('$_tag 发送播放歌曲命令失败', error: e);
    }
  }

  void sendTrackNextMessage(Track trackData) {
    if (!isConnected) {
      _showError('未连接到服务器');
      return;
    }

    try {
      final trackMessage = WebSocketMessageBuilder.createTrackNextMessage(
        trackData,
      );
      _webSocket!.add(trackMessage.toJsonString());

      _logger.i('$_tag 发送播放下一首歌曲命令');
    } catch (e) {
      _showError('发送播放歌曲命令失败: $e');
      _logger.e('$_tag 发送播放歌曲命令失败', error: e);
    }
  }

  /// 发送获取指定平台cookie信息
  void sendGetCookieMessage() async {
    if (!isConnected) {
      _showError('未连接到服务器');
      return;
    }
    Get.dialog(
      AlertDialog(
        title: const Text('获取服务器保存的Cookie'),
        actions: [
          ...getCookieCommandsMap.entries.map((entry) {
            return TextButton(
              onPressed: () {
                final message = WebSocketMessage(
                  type: WebSocketMessageType.getCookie,
                  content: entry.value,
                );
                _webSocket!.add(message.toJsonString());
                Get.back();
                _showInfo('已请求获取 ${entry.key} 的 Cookie');
                _logger.i('$_tag 请求获取 ${entry.key} 的 Cookie');
              },
              child: Text(entry.key),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// 启动状态轮询
  void startStatusPolling({int intervalSeconds = 3}) {
    if (_statusPollingTimer != null) {
      return; // 已经在轮询中
    }

    if (!isConnected) {
      _logger.w('$_tag 未连接到服务器，无法启动状态轮询');
      return;
    }

    _logger.i('$_tag 启动状态轮询，间隔: ${intervalSeconds}秒');

    // 立即发送一次状态请求
    requestPlayStatus();

    // 启动定时器
    _statusPollingTimer = Timer.periodic(Duration(seconds: intervalSeconds), (
      timer,
    ) {
      if (isConnected) {
        try {
          final statusRequest =
              WebSocketMessageBuilder.createGetStatusRequest();
          _webSocket!.add(statusRequest.toJsonString());
          _logger.d('$_tag 定时请求播放状态');
        } catch (e) {
          _logger.e('$_tag 定时请求播放状态失败', error: e);
        }
      } else {
        // 如果连接断开，停止轮询
        stopStatusPolling();
      }
    });
  }

  /// 停止状态轮询
  void stopStatusPolling() {
    if (_statusPollingTimer != null) {
      _statusPollingTimer!.cancel();
      _statusPollingTimer = null;
      _logger.i('$_tag 停止状态轮询');
    }
  }

  /// 处理接收到的消息
  void _onMessage(dynamic data) {
    try {
      // 尝试解析为新的 WebSocketMessage 格式
      WebSocketMessage message;
      try {
        message = WebSocketMessage.fromJsonString(data.toString());
      } catch (e) {
        // 如果解析失败，作为普通文本处理

        _logger.d('$_tag 收到文本消息: $data');
        return;
      }

      // 根据消息类型进行特殊处理
      switch (message.type) {
        case WebSocketMessageType.status:
          // 处理播放状态消息
          try {
            final statusData = message.parseContent<PlayStatusData>(
              PlayStatusData.fromJson,
            );
            // 保存最新的播放状态
            _lastPlayStatus.value = statusData;
            _lastPlayStatus.refresh();

            // 如果没有在拖动音量条，则更新音量值
            if (!_isDraggingVolume.value) {
              _volume.value = statusData.volume;
            }
            if (!_isDraggingProcess.value) {
              processTime.value = statusData.processTime;
              totalTime.value = statusData.totalTime;
            }
            _logger.i('$_tag 收到播放状态: $statusData');
          } catch (e) {
            _logger.w('$_tag 状态消息解析失败', error: e);
          }
          break;
        case WebSocketMessageType.setCookie:
          Future.microtask(() async {
            try {
              final contentMap = message.parseContentAsMap();
              if (contentMap != null) {
                for (var k in PlantformCodes.values) {
                  if (contentMap.containsKey(k)) {
                    await savePlatformToken(
                      PlatformCredentials(
                        platform: k,
                        credentials: contentMap[k]!,
                      ),
                      saveRightNow: false,
                    );
                  }
                }
                // 保存设置
                await Get.find<SettingsController>().saveSettings();
                await Get.find<SettingsController>().refreshLoginData();

                showSuccessSnackbar('Cookie 设置成功', null);
              } else {
                throw '内容格式错误，无法解析为 Map';
              }
            } catch (e) {
              _logger.e('$_tag 处理设置 Cookie 消息失败', error: e);
              showErrorSnackbar('Cookie 设置失败', e.toString());
            }
          });
          break;
        case WebSocketMessageType.sendPasteText:
          unawaited(
            Get.find<PasteController>().onReceivedPasteText(message.content),
          );
          break;
        case WebSocketMessageType.reqToGetFile:
          try {
            final fileNames = (jsonDecode(message.content) as List<dynamic>)
                .map((e) => e.toString())
                .toList();
            unawaited(
              Get.find<PasteController>().onReceivedReqToGetFile(fileNames),
            );
          } catch (e) {
            _logger.e('$_tag 处理 reqToGetFile 消息失败', error: e);
          }
          break;
        case WebSocketMessageType.reqToGetImage:
          try {
            final fileName = message.content;
            unawaited(
              Get.find<PasteController>().onReceivedReqToGetImage(fileName),
            );
          } catch (e) {
            _logger.e('$_tag 处理 reqToGetImage 消息失败', error: e);
          }
          break;
        case WebSocketMessageType.welcome:
          // 处理欢迎消息
          if (message.content.isNotEmpty) {
            String deviceId = jsonDecode(message.content)['deviceId'] ?? '';
            if (!isEmpty(deviceId)) {
              lastConnectedDeviceId.value = deviceId;
            }
          }
          break;
        case WebSocketMessageType.error:
          // 处理错误消息
          break;
        case WebSocketMessageType.pong:
          // 处理 pong 消息
          break;
        default:
          // 处理其他类型消息
          break;
      }

      _logger.d('$_tag 收到消息: ${message.type}');
    } catch (e) {
      _logger.e('$_tag 消息处理失败', error: e);
    }
  }

  /// 处理连接断开
  void _onDisconnected() {
    _logger.i('$_tag WebSocket连接已断开');
    if (_manualClosing) {
      _logger.i('$_tag 手动断开，忽略断开回调');
      return;
    }
    i_isConnected.value = false;
    _serverUrl.value = '';
    _stopHeartbeatTimer();
    stopStatusPolling();

    if (_autoReconnect.value && !_isReconnecting.value) {
      _updateStatusMessage('连接中断，准备重连...');
      _startReconnectTimer();
    } else {
      _updateStatusMessage('连接中断');
    }
  }

  /// 处理连接错误
  void _onError(dynamic error) {
    _logger.e('$_tag WebSocket连接错误', error: error);
    if (_manualClosing) {
      _logger.i('$_tag 手动断开，忽略错误回调');
      return;
    }
    i_isConnected.value = false;
    _serverUrl.value = '';
    _stopHeartbeatTimer();
    stopStatusPolling();
    _updateStatusMessage('连接错误');

    if (_autoReconnect.value && !_isReconnecting.value) {
      _startReconnectTimer();
    }
  }

  /// 启动重连定时器
  void _startReconnectTimer() {
    if (!_autoReconnect.value || _isReconnecting.value) return;

    _isReconnecting.value = true;
    _updateStatusMessage('将在 ${_reconnectInterval.value} 秒后重连...');

    _reconnectTimer = Timer(
      Duration(seconds: _reconnectInterval.value),
      () async {
        if (_autoReconnect.value &&
            !i_isConnected.value &&
            !_connectionCancelled) {
          _logger.i('$_tag 尝试自动重连...');
          await connect();
        }
      },
    );
  }

  /// 停止重连定时器
  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// 启动心跳定时器
  void _startHeartbeatTimer() {
    _stopHeartbeatTimer();

    _heartbeatTimer = Timer.periodic(
      Duration(seconds: _heartbeatInterval.value),
      (timer) {
        if (i_isConnected.value) {
          try {
            final pingMessage = WebSocketMessageBuilder.createPingMessage();
            _webSocket!.add(pingMessage.toJsonString());
            _logger.d('$_tag 自动心跳已发送');
          } catch (e) {
            _logger.e('$_tag 自动心跳发送失败', error: e);
          }
        } else {
          timer.cancel();
        }
      },
    );
  }

  /// 停止心跳定时器
  void _stopHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 更新状态消息
  void _updateStatusMessage([String? message]) {
    if (message != null) {
      _statusMessage.value = message;
    } else {
      if (isConnected) {
        _statusMessage.value = '已连接';
      } else if (isConnecting) {
        _statusMessage.value = '连接中...';
      } else if (isReconnecting) {
        _statusMessage.value = '重连中...';
      } else {
        _statusMessage.value = '未连接';
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

  /// 检查字符串是否包含非 ASCII 字符（用于检测中文等字符）
  bool _containsNonAscii(String text) {
    for (int i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) > 127) {
        return true;
      }
    }
    return false;
  }

  /// 将包含非 ASCII 字符的主机名转换为 Punycode 编码
  /// 例如: "神山識.local" -> "xn--rhtz68drkm.local"
  String _encodeToPunycode(String host) {
    try {
      // 使用 punycode 包来编码主机名
      // 需要对每个域名部分分别编码

      final parts = host.split('.');
      final encodedParts = <String>[];

      for (final part in parts) {
        if (_containsNonAscii(part)) {
          // 使用 punycode 包编码这个部分
          try {
            final encoded = punycodeEncode(part);
            encodedParts.add('xn--$encoded');
            _logger.d('$_tag Punycode 编码: $part -> xn--$encoded');
          } catch (e) {
            _logger.w('$_tag 无法对部分 "$part" 进行 Punycode 编码: $e');
            // 如果编码失败，保持原样（虽然可能会导致连接失败）
            encodedParts.add(part);
          }
        } else {
          // ASCII 部分直接使用
          encodedParts.add(part);
        }
      }

      final result = encodedParts.join('.');
      return result;
    } catch (e) {
      _logger.e('$_tag Punycode 编码失败: $e');
      return host; // 编码失败时返回原主机名
    }
  }
}
