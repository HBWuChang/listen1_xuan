import 'dart:convert';

import '../controllers/play_controller.dart';

/// WebSocket 消息基类
/// 用于服务器和客户端之间的通信
class WebSocketMessage {
  final String type;
  final String content;

  const WebSocketMessage({required this.type, required this.content});

  /// 从 JSON 字符串创建 WebSocketMessage
  factory WebSocketMessage.fromJsonString(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return WebSocketMessage.fromJson(json);
  }

  /// 从 Map 创建 WebSocketMessage
  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: json['type'] as String,
      content: json['content'] as String,
    );
  }

  /// 转换为 JSON Map
  Map<String, dynamic> toJson() {
    return {'type': type, 'content': content};
  }

  /// 转换为 JSON 字符串
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// 创建带有内容对象的消息
  /// content 将被序列化为 JSON 字符串
  factory WebSocketMessage.withContent(String type, dynamic contentObject) {
    String contentJson;
    if (contentObject is Map<String, dynamic>) {
      contentJson = jsonEncode(contentObject);
    } else if (contentObject is String) {
      contentJson = contentObject;
    } else {
      // 尝试调用 toJson 方法
      try {
        final dynamic obj = contentObject as dynamic;
        contentJson = jsonEncode(obj.toJson());
      } catch (e) {
        // 如果没有 toJson 方法，直接转换为字符串
        contentJson = contentObject.toString();
      }
    }

    return WebSocketMessage(type: type, content: contentJson);
  }

  /// 解析 content 为指定类型的对象
  T parseContent<T>(T Function(Map<String, dynamic>) fromJson) {
    final Map<String, dynamic> contentJson = jsonDecode(content);
    return fromJson(contentJson);
  }

  /// 尝试解析 content 为 Map
  Map<String, dynamic>? parseContentAsMap() {
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return 'WebSocketMessage(type: $type, content: $content)';
  }
}

/// 播放状态数据类
/// 包含当前播放的曲目和播放状态
class PlayStatusData {
  final Track? currentTrack;
  final bool isPlaying;
  final double volume;
  final int playMode;
  final DateTime timestamp;

  PlayStatusData({
    required this.currentTrack,
    required this.isPlaying,
    required this.volume,
    required this.playMode,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 从 JSON 创建 PlayStatusData
  factory PlayStatusData.fromJson(Map<String, dynamic> json) {
    Track? track;
    if (json['currentTrack'] != null) {
      track = Track.fromJson(json['currentTrack'] as Map<String, dynamic>);
    }

    DateTime? timestamp;
    if (json['timestamp'] != null) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int);
    }

    return PlayStatusData(
      currentTrack: track,
      isPlaying: json['isPlaying'] as bool,
      volume: json['volume'] as double? ?? 0.5,
      playMode: json['playMode'] as int? ?? 0,
      timestamp: timestamp,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'currentTrack': currentTrack?.toJson(),
      'isPlaying': isPlaying,
      'volume': volume,
      'playMode': playMode,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  /// 从 PlayController 创建 PlayStatusData
  factory PlayStatusData.fromPlayController(PlayController controller) {
    return PlayStatusData(
      currentTrack: controller.currentTrack.id.isNotEmpty
          ? controller.currentTrack
          : null,
      isPlaying: controller.isplaying.value,
      volume: controller.currentVolume,
      playMode: controller.getPlayerSettings("playmode") ?? 0,
    );
  }

  @override
  String toString() {
    return 'PlayStatusData(currentTrack: ${currentTrack?.title ?? "None"}, isPlaying: $isPlaying, volume: $volume, playMode: $playMode)';
  }
}

/// WebSocket 消息类型常量
class WebSocketMessageType {
  /// 客户端请求播放状态
  static const String getStatus = 'getStatus';

  /// 服务器响应播放状态
  static const String status = 'status';

  /// 播放控制消息
  static const String ctrl = 'ctrl';

  /// 播放指定歌曲消息
  static const String track = 'track';

  /// 心跳消息
  static const String ping = 'ping';
  static const String pong = 'pong';

  /// 普通消息
  static const String message = 'message';

  /// 广播消息
  static const String broadcast = 'broadcast';

  /// 欢迎消息
  static const String welcome = 'welcome';

  /// 错误消息
  static const String error = 'error';

  /// 获取 Cookie 消息
  static const String getCookie = 'getCookie';

  /// 设置 Cookie 消息
  static const String setCookie = 'setCookie';
}

/// 播放控制命令常量
class PlayControlCommands {
  static const String play = 'play';
  static const String pause = 'pause';
  static const String stop = 'stop';
  static const String next = 'next';
  static const String previous = 'previous';
}

Map<String, String> getCookieCommandsMap = {
  '所有': GetCookieCommands.all,
  '哔哩哔哩': GetCookieCommands.bl,
  '网易云音乐': GetCookieCommands.ne,
  'QQ音乐': GetCookieCommands.qq,
};

class GetCookieCommands {
  static const String all = 'all';
  static const String bl = 'bl';
  static const String ne = 'ne';
  static const String qq = 'qq';
  static const List<String> values = [bl, ne, qq];
}

/// WebSocket 消息构建器
/// 提供便捷的方法来创建常用的消息类型
class WebSocketMessageBuilder {
  /// 创建获取状态请求消息
  static WebSocketMessage createGetStatusRequest() {
    return WebSocketMessage(type: WebSocketMessageType.getStatus, content: '');
  }

  /// 创建状态响应消息
  static WebSocketMessage createStatusResponse(PlayStatusData statusData) {
    return WebSocketMessage.withContent(
      WebSocketMessageType.status,
      statusData,
    );
  }

  /// 创建 Ping 消息
  static WebSocketMessage createPingMessage() {
    return WebSocketMessage.withContent(WebSocketMessageType.ping, {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 创建 Pong 消息
  static WebSocketMessage createPongMessage() {
    return WebSocketMessage.withContent(WebSocketMessageType.pong, {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 创建普通消息
  static WebSocketMessage createMessage(String messageContent, {String? from}) {
    final content = {
      'message': messageContent,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (from != null) {
      content['from'] = from;
    }

    return WebSocketMessage.withContent(WebSocketMessageType.message, content);
  }

  /// 创建广播消息
  static WebSocketMessage createBroadcastMessage(
    String messageContent, {
    String? from,
  }) {
    final content = {
      'message': messageContent,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (from != null) {
      content['from'] = from;
    }

    return WebSocketMessage.withContent(
      WebSocketMessageType.broadcast,
      content,
    );
  }

  /// 创建欢迎消息
  static WebSocketMessage createWelcomeMessage(String clientId) {
    return WebSocketMessage.withContent(WebSocketMessageType.welcome, {
      'message': '连接成功！',
      'clientId': clientId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 创建错误消息
  static WebSocketMessage createErrorMessage(String errorMessage) {
    return WebSocketMessage.withContent(WebSocketMessageType.error, {
      'error': errorMessage,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 创建播放控制消息
  static WebSocketMessage createControlMessage(String command) {
    return WebSocketMessage(type: WebSocketMessageType.ctrl, content: command);
  }

  /// 创建播放指定歌曲消息
  static WebSocketMessage createTrackMessage(Track trackData) {
    final trackJson = jsonEncode(trackData.toJson());
    return WebSocketMessage(
      type: WebSocketMessageType.track,
      content: trackJson,
    );
  }
}
