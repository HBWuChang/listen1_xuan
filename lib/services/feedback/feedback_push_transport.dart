import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';

class FeedbackPushEnvelope {
  const FeedbackPushEnvelope(this.data, this.title);
  final Map<String, dynamic> data;
  final String title;
}

abstract class FeedbackPushTransport {
  Future<Map<String, String>> deviceIdentity();
  Future<bool> initialize();
  String get projectId;
  Stream<String> get tokenChanges;
  Stream<FeedbackPushEnvelope> get messages;
  Stream<Map<dynamic, dynamic>> get taps;
  Future<List<Map<dynamic, dynamic>>> initialTaps();
  Future<bool> requestPermission();
  Future<bool> permissionGranted();
  Future<String?> token();
  Future<void> deleteToken();
  Future<void> setAutoInit(bool enabled);
  Future<void> show(FeedbackPushEnvelope message);
  Future<void> cancel({String? issueId});
  Future<void> dispose();
}

class FirebaseFeedbackPushTransport implements FeedbackPushTransport {
  static const _native = MethodChannel('listen1_xuan/feedback_push');
  final _taps = StreamController<Map<dynamic, dynamic>>.broadcast();
  StreamSubscription<RemoteMessage>? _opened;
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<Map<String, String>> deviceIdentity() async =>
      (await _native.invokeMapMethod<String, String>('deviceIdentity'))!;

  @override
  Future<bool> initialize() async {
    _native.setMethodCallHandler((call) async {
      if (call.method == 'notificationTapped' && call.arguments is Map) {
        _taps.add(Map<dynamic, dynamic>.from(call.arguments as Map));
      }
    });
    if (await _native.invokeMethod<bool>('isConfigured') != true) return false;
    await Firebase.initializeApp();
    await _native.invokeMethod<void>('ensureChannel');
    _opened = FirebaseMessaging.onMessageOpenedApp.listen((message) => _taps.add(message.data));
    return true;
  }

  @override
  String get projectId => Firebase.app().options.projectId;
  @override
  Stream<String> get tokenChanges => _messaging.onTokenRefresh;
  @override
  Stream<FeedbackPushEnvelope> get messages => FirebaseMessaging.onMessage.map(
    (message) => FeedbackPushEnvelope(message.data, message.notification?.title ?? '在线反馈有新消息'),
  );
  @override
  Stream<Map<dynamic, dynamic>> get taps => _taps.stream;
  @override
  Future<List<Map<dynamic, dynamic>>> initialTaps() async {
    final result = <Map<dynamic, dynamic>>[];
    final native = await _native.invokeMapMethod<dynamic, dynamic>('getInitialTap');
    if (native != null) result.add(native);
    final remote = await _messaging.getInitialMessage();
    if (remote != null) result.add(remote.data);
    return result;
  }
  @override
  Future<bool> requestPermission() async =>
      (await _messaging.requestPermission()).authorizationStatus == AuthorizationStatus.authorized;
  @override
  Future<bool> permissionGranted() async =>
      (await _messaging.getNotificationSettings()).authorizationStatus == AuthorizationStatus.authorized;
  @override
  Future<String?> token() => _messaging.getToken();
  @override
  Future<void> deleteToken() => _messaging.deleteToken();
  @override
  Future<void> setAutoInit(bool enabled) => _messaging.setAutoInitEnabled(enabled);
  @override
  Future<void> show(FeedbackPushEnvelope message) => _native.invokeMethod<void>('show', {
    ...message.data, 'title': message.title,
  });
  @override
  Future<void> cancel({String? issueId}) => _native.invokeMethod<void>('cancel', {'issue_id': issueId});
  @override
  Future<void> dispose() async {
    _native.setMethodCallHandler(null);
    await _opened?.cancel();
    await _taps.close();
  }
}
