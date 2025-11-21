import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/global_settings_animations.dart';
import 'package:logger/logger.dart';
import 'package:listen1_xuan/models/Track.dart';

import '../models/websocket_message.dart';
import '../settings.dart';
import 'BroadcastWsController.dart';
import 'play_controller.dart';
import '../play.dart';
import 'settings_controller.dart';
import 'cache_controller.dart';

/// WebSocket 服务器控制器
/// 支持 IPv4/IPv6 配置，包含 ping/pong 心跳机制和资源释放
class WebSocketServerController extends GetxController {
  static const String _tag = 'WebSocketServerController';
  final Logger _logger = Logger();

  /// 服务器实例
  HttpServer? _server;

  /// 所有活跃的 WebSocket 连接
  final List<WebSocketConnection> _connections = <WebSocketConnection>[];

  /// 心跳定时器
  Timer? _pingTimer;

  /// 服务器运行状态
  final RxBool _isRunning = false.obs;

  /// 连接客户端数量
  final RxInt _clientCount = 0.obs;

  /// 服务器配置
  late final String _host;
  late final int _port;
  final Duration _pingInterval;
  final Duration _pongTimeout;

  /// Getters
  bool get isRunning => _isRunning.value;
  int get clientCount => _clientCount.value;
  String get serverUrl => 'ws://$_host:$_port/ws';

  WebSocketServerController({
    required String host,
    required int port,
    InternetAddressType addressType = InternetAddressType.any,
    Duration pingInterval = const Duration(seconds: 30),
    Duration pongTimeout = const Duration(seconds: 5),
  }) : _host = host,
       _port = port,
       _pingInterval = pingInterval,
       _pongTimeout = pongTimeout;

  @override
  void onInit() {
    super.onInit();
    _logger.i('$_tag 初始化完成');
  }

  /// 启动 WebSocket 服务器
  Future<bool> startServer() async {
    if (_isRunning.value) {
      _logger.w('$_tag 服务器已在运行');
      return true;
    }

    try {
      // 创建 HTTP 服务器
      _server = await HttpServer.bind(_host, _port, shared: true);

      _isRunning.value = true;
      _logger.i('$_tag WebSocket 服务器启动成功: $serverUrl');
      Get.find<BroadcastWsController>().startBroadcast(_port);
      // 监听请求
      _server!.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          // 升级为 WebSocket 连接
          try {
            final webSocket = await WebSocketTransformer.upgrade(request);
            _handleNewConnection(webSocket);
          } catch (e) {
            _logger.e('$_tag WebSocket 升级失败', error: e);
            try {
              if (!request.response.headers.chunkedTransferEncoding) {
                request.response.statusCode = HttpStatus.badRequest;
                await request.response.close();
              }
            } catch (closeError) {
              _logger.e('$_tag 关闭响应失败', error: closeError);
            }
          }
        } else {
          // 处理普通 HTTP 请求
          _handleHttpRequest(request);
        }
      });

      // 启动心跳检测
      _startPingTimer();

      return true;
    } catch (e, stackTrace) {
      _logger.e('$_tag 启动服务器失败', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 停止 WebSocket 服务器
  Future<void> stopServer() async {
    try {
      Get.find<BroadcastWsController>().stopBroadcast();
    } catch (e) {
      showErrorSnackbar('停止地址广播失败', e.toString());
    }
    if (!_isRunning.value) {
      return;
    }

    try {
      // 停止心跳检测
      _stopPingTimer();

      // 关闭所有连接
      await _closeAllConnections();

      // 关闭服务器
      await _server?.close(force: true);
      _server = null;

      _isRunning.value = false;
      _clientCount.value = 0;

      _logger.i('$_tag WebSocket 服务器已停止');
    } catch (e, stackTrace) {
      _logger.e('$_tag 停止服务器时出错', error: e, stackTrace: stackTrace);
    }
  }

  /// 处理新的 WebSocket 连接
  void _handleNewConnection(WebSocket webSocket) {
    final connection = WebSocketConnection(
      webSocket: webSocket,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      connectedAt: DateTime.now(),
    );

    _connections.add(connection);
    _clientCount.value = _connections.length;

    _logger.i('$_tag 新客户端连接: ${connection.id}, 总连接数: ${_connections.length}');

    // 发送欢迎消息
    final welcomeMessage = WebSocketMessageBuilder.createWelcomeMessage(
      connection.id,
    );
    _sendMessage(connection, welcomeMessage);

    // 监听消息
    webSocket.listen(
      (data) => _handleMessage(connection, data),
      onDone: () => _handleConnectionClosed(connection),
      onError: (error) => _handleConnectionError(connection, error),
    );
  }

  /// 处理收到的消息
  Future<void> _handleMessage(
    WebSocketConnection connection,
    dynamic data,
  ) async {
    try {
      // 尝试解析为新的 WebSocketMessage 格式
      WebSocketMessage message;
      try {
        message = WebSocketMessage.fromJsonString(data.toString());
      } catch (e) {
        // 如果解析失败，尝试解析为旧格式
        final oldMessage = json.decode(data.toString());
        final messageType = oldMessage['type'] ?? 'unknown';

        // 转换为新格式
        message = WebSocketMessage(
          type: messageType,
          content: json.encode(oldMessage),
        );
      }

      _logger.d('$_tag 收到消息: ${message.type} from ${connection.id}');

      switch (message.type) {
        case WebSocketMessageType.getStatus:
          _handleGetStatusRequest(connection);
          break;
        case WebSocketMessageType.ctrl:
          await _handleControlMessage(connection, message);
          break;
        case WebSocketMessageType.track:
          _handleTrackMessage(connection, message);
          break;
        case WebSocketMessageType.trackNext:
          _handleTrackNextMessage(connection, message);
          break;
        case WebSocketMessageType.pong:
          connection.lastPong = DateTime.now();
          _logger.d('$_tag 收到 pong from ${connection.id}');
          break;
        case WebSocketMessageType.ping:
          // 响应客户端的 ping
          final pongMessage = WebSocketMessageBuilder.createPongMessage();
          _sendMessage(connection, pongMessage);
          break;
        case WebSocketMessageType.broadcast:
          // 广播消息给所有客户端
          final contentMap = message.parseContentAsMap();
          final broadcastMessage = contentMap?['message'] ?? message.content;
          final broadcastMsg = WebSocketMessageBuilder.createBroadcastMessage(
            broadcastMessage,
            from: connection.id,
          );
          _broadcastMessage(broadcastMsg, excludeClient: connection.id);
          break;
        case WebSocketMessageType.getCookie:
          Set<String> toOpr = {};
          if (message.content == PlantformCodes.all) {
            toOpr.addAll(PlantformCodes.values);
          } else {
            toOpr.add(message.content);
          }
          Map<String, String> cookiesMap = {};
          for (var k in toOpr) {
            final token = await outputPlatformToken(k);
            if (token != null) {
              cookiesMap[k] = token;
            }
          }
          _sendMessage(
            connection,
            WebSocketMessage(
              type: WebSocketMessageType.setCookie,
              content: jsonEncode(cookiesMap),
            ),
          );
          break;

        case WebSocketMessageType.message:
          // 处理普通消息（可以根据需要添加逻辑）
          _logger.d('$_tag 收到普通消息: ${message.content}');
          break;
        default:
          _logger.d('$_tag 未知消息类型: ${message.type}');
      }
    } catch (e) {
      _logger.e('$_tag 处理消息失败', error: e);
      // 发送错误消息给客户端
      final errorMessage = WebSocketMessageBuilder.createErrorMessage(
        '消息处理失败: $e',
      );
      _sendMessage(connection, errorMessage);
    }
  }

  /// 处理获取状态请求
  void _handleGetStatusRequest(WebSocketConnection connection) {
    try {
      // 获取 PlayController 实例
      final playController = Get.find<PlayController>();

      // 创建状态数据
      final statusData = PlayStatusData.fromPlayController(playController);

      // 创建状态响应消息
      final statusMessage = WebSocketMessageBuilder.createStatusResponse(
        statusData,
      );

      // 发送状态消息给请求的客户端
      _sendMessage(connection, statusMessage);

      _logger.i(
        '$_tag 发送播放状态给客户端 ${connection.id}: isPlaying=${statusData.isPlaying}, track=${statusData.currentTrack?.title ?? "None"}',
      );
    } catch (e) {
      _logger.e('$_tag 处理获取状态请求失败', error: e);

      // 发送错误消息
      final errorMessage = WebSocketMessageBuilder.createErrorMessage(
        '无法获取播放状态: $e',
      );
      _sendMessage(connection, errorMessage);
    }
  }

  /// 处理播放控制消息
  Future<void> _handleControlMessage(
    WebSocketConnection connection,
    WebSocketMessage message,
  ) async {
    try {
      final command = message.content.trim();
      _logger.i('$_tag 收到播放控制命令: $command from ${connection.id}');

      switch (command) {
        case PlayControlCommands.play:
          globalPlay();
          _logger.i('$_tag 执行播放命令');
          break;
        case PlayControlCommands.pause:
        case PlayControlCommands.stop:
          globalPause();
          _logger.i('$_tag 执行暂停命令');
          break;
        case PlayControlCommands.next:
          globalSkipToNext();
          _logger.i('$_tag 执行下一首命令');
          break;
        case PlayControlCommands.previous:
          globalSkipToPrevious();
          _logger.i('$_tag 执行上一首命令');
          break;
        default:
          // 检查是否为changePlayMode命令
          if (command == 'changePlayMode') {
            try {
              final newPlayMode = await globalChangePlayMode();
              _logger.i('$_tag 播放模式已切换为: $newPlayMode');

              // 发送成功响应
              final successMessage = WebSocketMessageBuilder.createMessage(
                '播放模式已切换: ${_getPlayModeText(newPlayMode)}',
              );
              _sendMessage(connection, successMessage);
              return;
            } catch (e) {
              _logger.e('$_tag 切换播放模式失败', error: e);
              final errorMessage = WebSocketMessageBuilder.createErrorMessage(
                '切换播放模式失败: $e',
              );
              _sendMessage(connection, errorMessage);
              return;
            }
          }
          if (command.startsWith('process_')) {
            final processValue = double.tryParse(command.substring(8));
            if (processValue != null &&
                processValue >= 0.0 &&
                processValue <= 1.0) {
              // 这是进度控制命令
              _logger.i('$_tag 收到进度控制命令: $processValue');
              try {
                globalSeek(null, process: processValue);
                return;
              } catch (e) {
                _logger.e('$_tag 进度控制失败', error: e);
                final errorMessage = WebSocketMessageBuilder.createErrorMessage(
                  '设置进度失败: $e',
                );
                _sendMessage(connection, errorMessage);
                return;
              }
            }
          }
          // 尝试解析为音量控制命令
          final volumeValue = double.tryParse(command);
          if (volumeValue != null &&
              volumeValue >= 0.0 &&
              volumeValue <= 100.0) {
            // 这是音量控制命令
            try {
              final playController = Get.find<PlayController>();
              playController.currentVolume = volumeValue;
              _logger.i('$_tag 设置音量: ${volumeValue.toInt()}%');

              // 发送成功响应
              final successMessage = WebSocketMessageBuilder.createMessage(
                '音量已设置为: ${volumeValue.toInt()}%',
              );
              _sendMessage(connection, successMessage);
              return;
            } catch (e) {
              _logger.e('$_tag 设置音量失败', error: e);
              final errorMessage = WebSocketMessageBuilder.createErrorMessage(
                '设置音量失败: $e',
              );
              _sendMessage(connection, errorMessage);
              return;
            }
          }

          _logger.w('$_tag 未知播放控制命令: $command');
          final errorMessage = WebSocketMessageBuilder.createErrorMessage(
            '未知播放控制命令: $command',
          );
          _sendMessage(connection, errorMessage);
          return;
      }

      // 发送成功响应
      final successMessage = WebSocketMessageBuilder.createMessage(
        '播放控制命令已执行: $command',
      );
      _sendMessage(connection, successMessage);
    } catch (e) {
      _logger.e('$_tag 处理播放控制消息失败', error: e);
      final errorMessage = WebSocketMessageBuilder.createErrorMessage(
        '播放控制失败: $e',
      );
      _sendMessage(connection, errorMessage);
    }
  }

  /// 处理播放指定歌曲消息
  void _handleTrackMessage(
    WebSocketConnection connection,
    WebSocketMessage message,
  ) {
    try {
      _logger.i('$_tag 收到播放歌曲请求 from ${connection.id}');

      // 解析歌曲数据
      final trackData = json.decode(message.content);

      // 将Map转换为Track对象
      final track = Track.fromJson(trackData);

      _logger.i('$_tag 准备播放歌曲: ${track.title} - ${track.artist}');

      // 调用playsong方法播放歌曲
      try {
        playsong(track, isByClick: true);

        // 发送成功响应
        final successMessage = WebSocketMessageBuilder.createMessage(
          '开始播放歌曲: ${track.title} - ${track.artist}',
        );
        _sendMessage(connection, successMessage);

        _logger.i('$_tag 播放歌曲命令已执行: ${track.title}');
      } catch (e) {
        _logger.e('$_tag 播放歌曲执行失败', error: e);
        final errorMessage = WebSocketMessageBuilder.createErrorMessage(
          '播放歌曲失败: $e',
        );
        _sendMessage(connection, errorMessage);
      }
    } catch (e) {
      _logger.e('$_tag 处理播放歌曲消息失败 (解析阶段)', error: e);
      final errorMessage = WebSocketMessageBuilder.createErrorMessage(
        '解析歌曲数据失败: $e',
      );
      _sendMessage(connection, errorMessage);
    }
  }

  void _handleTrackNextMessage(
    WebSocketConnection connection,
    WebSocketMessage message,
  ) {
    try {
      _logger.i('$_tag 收到播放下一首请求 from ${connection.id}');

      // 解析歌曲数据
      final trackData = json.decode(message.content);

      // 将Map转换为Track对象
      final track = Track.fromJson(trackData);

      _logger.i('$_tag 准备设置下一首歌曲: ${track.title} - ${track.artist}');
      
      try {
        Get.find<PlayController>().nextTrack = track;
        _logger.i('$_tag 下一首歌曲已设置: ${track.title}');
        
        // 发送成功响应
        final successMessage = WebSocketMessageBuilder.createMessage(
          '下一首已设置: ${track.title} - ${track.artist}',
        );
        _sendMessage(connection, successMessage);
      } catch (e) {
        _logger.e('$_tag 设置下一首歌曲失败', error: e);
        final errorMessage = WebSocketMessageBuilder.createErrorMessage(
          '设置下一首歌曲失败: $e',
        );
        _sendMessage(connection, errorMessage);
      }
    } catch (e) {
      _logger.e('$_tag 处理播放下一首消息失败 (解析阶段)', error: e);
      final errorMessage = WebSocketMessageBuilder.createErrorMessage(
        '解析歌曲数据失败: $e',
      );
      _sendMessage(connection, errorMessage);
    }
  }

  /// 广播播放状态给所有连接的客户端
  void broadcastStatus() {
    if (_connections.isEmpty) {
      _logger.d('$_tag 没有连接的客户端，跳过状态广播');
      return;
    }

    try {
      // 获取 PlayController 实例
      final playController = Get.find<PlayController>();

      // 创建状态数据
      final statusData = PlayStatusData.fromPlayController(playController);

      // 创建状态响应消息
      final statusMessage = WebSocketMessageBuilder.createStatusResponse(
        statusData,
      );

      // 广播状态消息给所有客户端
      _broadcastMessage(statusMessage);

      _logger.i(
        '$_tag 向 ${_connections.length} 个客户端广播播放状态: isPlaying=${statusData.isPlaying}, track=${statusData.currentTrack?.title ?? "None"}',
      );
    } catch (e) {
      _logger.e('$_tag 广播播放状态失败', error: e);
    }
  }

  /// 处理连接关闭
  void _handleConnectionClosed(WebSocketConnection connection) {
    _connections.remove(connection);
    _clientCount.value = _connections.length;
    _logger.i('$_tag 客户端断开连接: ${connection.id}, 剩余连接数: ${_connections.length}');
  }

  /// 处理连接错误
  void _handleConnectionError(WebSocketConnection connection, dynamic error) {
    _logger.e('$_tag WebSocket 连接错误 ${connection.id}', error: error);
    _connections.remove(connection);
    _clientCount.value = _connections.length;
  }

  /// 启动 ping 定时器
  void _startPingTimer() {
    _pingTimer = Timer.periodic(_pingInterval, (timer) {
      _sendPingToAllClients();
      _checkPongTimeout();
    });
  }

  /// 停止 ping 定时器
  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// 向所有客户端发送 ping
  void _sendPingToAllClients() {
    final pingMessage = WebSocketMessageBuilder.createPingMessage();

    for (final connection in List<WebSocketConnection>.from(_connections)) {
      connection.lastPing = DateTime.now();
      _sendMessage(connection, pingMessage);
    }

    if (_connections.isNotEmpty) {
      _logger.d('$_tag 向 ${_connections.length} 个客户端发送 ping');
    }
  }

  /// 检查 pong 超时
  void _checkPongTimeout() {
    final now = DateTime.now();
    final timeoutConnections = <WebSocketConnection>[];

    for (final connection in _connections) {
      if (connection.lastPing != null &&
          (connection.lastPong == null ||
              connection.lastPong!.isBefore(connection.lastPing!))) {
        final timeSincePing = now.difference(connection.lastPing!);
        if (timeSincePing > _pongTimeout) {
          timeoutConnections.add(connection);
        }
      }
    }

    // 移除超时的连接
    for (final connection in timeoutConnections) {
      _logger.w('$_tag 客户端 ${connection.id} pong 超时，移除连接');
      try {
        connection.webSocket.close();
      } catch (e) {
        _logger.e('$_tag 关闭超时连接失败', error: e);
      }
      _connections.remove(connection);
    }

    if (timeoutConnections.isNotEmpty) {
      _clientCount.value = _connections.length;
    }
  }

  /// 向指定客户端发送消息
  void _sendMessage(WebSocketConnection connection, dynamic message) {
    try {
      String messageJson;
      if (message is WebSocketMessage) {
        messageJson = message.toJsonString();
      } else if (message is Map<String, dynamic>) {
        messageJson = json.encode(message);
      } else if (message is String) {
        messageJson = message;
      } else {
        messageJson = message.toString();
      }

      connection.webSocket.add(messageJson);
    } catch (e) {
      _logger.e('$_tag 发送消息失败 to ${connection.id}', error: e);
      _connections.remove(connection);
      _clientCount.value = _connections.length;
    }
  }

  /// 广播消息给所有客户端
  void _broadcastMessage(dynamic message, {String? excludeClient}) {
    String messageJson;
    if (message is WebSocketMessage) {
      messageJson = message.toJsonString();
    } else if (message is Map<String, dynamic>) {
      messageJson = json.encode(message);
    } else if (message is String) {
      messageJson = message;
    } else {
      messageJson = message.toString();
    }

    final connectionsToRemove = <WebSocketConnection>[];

    for (final connection in _connections) {
      if (excludeClient != null && connection.id == excludeClient) {
        continue;
      }

      try {
        connection.webSocket.add(messageJson);
      } catch (e) {
        _logger.e('$_tag 广播消息失败 to ${connection.id}', error: e);
        connectionsToRemove.add(connection);
      }
    }

    // 移除失败的连接
    for (final connection in connectionsToRemove) {
      _connections.remove(connection);
    }

    if (connectionsToRemove.isNotEmpty) {
      _clientCount.value = _connections.length;
    }
  }

  /// 公开的广播方法
  void broadcastMessage(dynamic message) {
    if (message is Map<String, dynamic>) {
      message['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      _broadcastMessage(message);
    } else {
      _broadcastMessage(message);
    }
  }

  /// 关闭所有连接
  Future<void> _closeAllConnections() async {
    final List<Future> closeFutures = [];

    for (final connection in _connections) {
      try {
        closeFutures.add(connection.webSocket.close());
      } catch (e) {
        _logger.e('$_tag 关闭连接失败 ${connection.id}', error: e);
      }
    }

    await Future.wait(closeFutures);
    _connections.clear();
  }

  /// 处理 HTTP 请求（根路径）
  void _handleHttpRequest(HttpRequest request) async {
    final uri = request.uri.path;

    // 检查是否为 /downloadById/{id} 路由
    if (uri.startsWith('/downloadById/')) {
      final id = uri.substring('/downloadById/'.length);
      await _handleDownloadById(request, id);
      return;
    }

    switch (uri) {
      case '/':
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.text
          ..write('WebSocket Server is running\nConnect to: $serverUrl');
        break;
      case '/status':
        final status = {
          'running': _isRunning.value,
          'clientCount': _clientCount.value,
          'uptime': DateTime.now().millisecondsSinceEpoch,
        };
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(json.encode(status));
        break;
      case '/allCacheList':
        try {
          // 获取 CacheController 实例
          final cacheController = Get.find<CacheController>();

          // 获取所有缓存项的 key 列表
          final cacheKeys = await cacheController.localCacheList();

          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(json.encode(cacheKeys));

          _logger.i('$_tag 返回缓存列表: ${cacheKeys.length} 个项目');
        } catch (e) {
          _logger.e('$_tag 获取缓存列表失败', error: e);
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..headers.contentType = ContentType.json
            ..write(
              json.encode({
                'error': 'Internal server error',
                'message': 'Failed to get cache list: $e',
              }),
            );
        }
        break;
      default:
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not Found');
    }

    request.response.close();
  }

  /// 处理根据 ID 下载文件的请求
  Future<void> _handleDownloadById(HttpRequest request, String id) async {
    try {
      // 获取 CacheController 实例
      final cacheController = Get.find<CacheController>();

      // 从缓存中获取文件路径
      final filePath = await cacheController.getLocalCache(id);

      if (filePath.isEmpty) {
        // 文件不存在
        request.response
          ..statusCode = HttpStatus.notFound
          ..headers.contentType = ContentType.json
          ..write(
            json.encode({
              'error': 'File not found',
              'message': 'No cached file found for ID: $id',
            }),
          );
        request.response.close();
        return;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        // 文件路径存在但文件实际不存在
        request.response
          ..statusCode = HttpStatus.notFound
          ..headers.contentType = ContentType.json
          ..write(
            json.encode({
              'error': 'File not found',
              'message': 'Cached file does not exist: $filePath',
            }),
          );
        request.response.close();
        return;
      }

      // 获取文件信息
      final fileStats = await file.stat();
      final fileName = file.path.split(Platform.pathSeparator).last;

      // 对文件名进行URL编码以支持非ASCII字符
      final encodedFileName = Uri.encodeComponent(fileName);

      // 设置响应头
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.set(HttpHeaders.contentTypeHeader, 'application/octet-stream')
        ..headers.set(
          HttpHeaders.contentLengthHeader,
          fileStats.size.toString(),
        )
        ..headers.set(
          'content-disposition',
          'attachment; filename*=UTF-8\'\'$encodedFileName',
        );

      // 读取并发送文件内容
      final fileStream = file.openRead();
      await fileStream.pipe(request.response);

      _logger.i('$_tag 成功处理文件下载请求: ID=$id, 文件=$fileName');
    } catch (e, stackTrace) {
      _logger.e('$_tag 处理文件下载请求失败: ID=$id', error: e, stackTrace: stackTrace);

      try {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..headers.contentType = ContentType.json
          ..write(
            json.encode({
              'error': 'Internal server error',
              'message': 'Failed to process download request: $e',
            }),
          );
        request.response.close();
      } catch (closeError) {
        _logger.e('$_tag 关闭错误响应失败', error: closeError);
      }
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

  @override
  void onClose() {
    _logger.i('$_tag 控制器销毁中...');

    // 停止服务器（这会自动清理所有资源）
    stopServer()
        .then((_) {
          _logger.i('$_tag 控制器已销毁');
        })
        .catchError((error) {
          _logger.e('$_tag 销毁时出错', error: error);
        });

    super.onClose();
  }
}

/// WebSocket 连接信息类
class WebSocketConnection {
  final WebSocket webSocket;
  final String id;
  final DateTime connectedAt;
  DateTime? lastPing;
  DateTime? lastPong;

  WebSocketConnection({
    required this.webSocket,
    required this.id,
    required this.connectedAt,
  });
}
