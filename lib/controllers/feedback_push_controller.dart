import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/feedback/feedback_api.dart';
import '../services/feedback/feedback_push_target.dart';
import '../services/feedback/feedback_push_transport.dart';
import 'feedback_push_navigation_controller.dart';
import 'feedback_unread_controller.dart';

class FeedbackPushController extends GetxController with WidgetsBindingObserver {
  FeedbackPushController(this.api, this.unread, this.navigation, {
    FeedbackPushTransport? transport, this.platformSupported,
    this.isIssueVisible,
  }) : transport = transport ?? FirebaseFeedbackPushTransport();
  final FeedbackApi api;
  final FeedbackUnreadController unread;
  final FeedbackPushNavigationController navigation;
  final FeedbackPushTransport transport;
  final bool? platformSupported;
  final bool Function(String)? isIssueVisible;
  bool get supported => platformSupported ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
  bool available = false, enabled = false, busy = false;
  String? error;
  SharedPreferences? _preferences;
  String? _installation, _secret, _boundUser, _observedUser;
  String? _legacyInstallation, _legacySecret;
  Future<void>? _startup, _syncFuture;
  int _syncVersion = 0;
  bool _alive = true, _foreground = true;
  Timer? _retry;
  StreamSubscription<AuthState>? _auth;
  StreamSubscription<String>? _tokens;
  StreamSubscription<FeedbackPushEnvelope>? _messages;
  StreamSubscription<Map<dynamic, dynamic>>? _taps;
  final _displayed = <String>{};
  final _cleared = <String, String>{};

  @override
  void onInit() {
    super.onInit();
    if (supported) unawaited(start());
  }

  Future<void> start() => _startup ??= _start();
  Future<void> _start() async {
    if (!supported) return;
    WidgetsBinding.instance.addObserver(this);
    unread.addListener(_unreadChanged);
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!_alive) return;
      _preferences = preferences;
      final identity = await transport.deviceIdentity();
      _installation = identity['installation_id'];
      _secret = identity['secret'];
      _legacyInstallation = preferences.getString('feedback_push_installation');
      _legacySecret = preferences.getString('feedback_push_device_secret');
      enabled = preferences.getBool('feedback_push_enabled') ?? false;
      _boundUser = preferences.getString('feedback_push_bound_user');
      _observedUser = api.currentUserId;
      available = await transport.initialize();
      if (!_alive) return;
      _auth = api.client.auth.onAuthStateChange.listen((_) {
        if (api.currentUserId != _observedUser) {
          _observedUser = api.currentUserId;
          _displayed.clear();
          _cleared.clear();
          unawaited(_cancel());
        }
        unawaited(_requestSync());
        unawaited(navigation.tryOpen());
      }, onError: (Object _) => _scheduleRetry());
      if (available) {
        _tokens = transport.tokenChanges.listen((_) => unawaited(_requestSync()), onError: (Object _) => _scheduleRetry());
        _messages = transport.messages.listen((message) => unawaited(_show(message)), onError: (Object _) {});
        _taps = transport.taps.listen(navigation.receive);
        for (final data in await transport.initialTaps()) {
          navigation.receive(data);
        }
      } else {
        error = '尚未配置 Firebase，暂不可开启反馈推送';
      }
      if (!_alive) return;
      update();
      _unreadChanged();
      await _requestSync();
    } catch (_) {
      if (_alive) {
        error = '反馈推送初始化失败，请检查 Firebase 配置和 Google Play 服务';
        update();
      }
    }
  }

  Future<void> setEnabled(bool value) async {
    if (busy || !supported) return;
    await start();
    if (!_alive) return;
    busy = true;
    error = null;
    update();
    try {
      if (value) {
        if (!available) throw StateError('尚未配置 Firebase，暂不可开启反馈推送');
        if (api.currentUserId == null) throw StateError('请先登录 Supabase 账号');
        if (!await transport.requestPermission()) throw StateError('未获得系统通知权限，请在系统设置中允许通知');
      }
      enabled = value;
      await _preferences!.setBool('feedback_push_enabled', value);
      if (!value) await _cancel();
      await _requestSync();
    } on StateError catch (e) {
      error = e.message.toString();
    } catch (_) {
      error = '反馈推送设置失败，请检查网络与 Google Play 服务后重试';
    } finally {
      if (_alive) { busy = false; update(); }
    }
  }

  Future<void> _requestSync() {
    if (api.currentUserId != _observedUser) {
      _observedUser = api.currentUserId;
      _displayed.clear();
      _cleared.clear();
      unawaited(_cancel());
    }
    _syncVersion++;
    if (!_alive || _installation == null) return Future.value();
    return _syncFuture ??= _synchronize().whenComplete(() => _syncFuture = null);
  }

  Future<void> _synchronize() async {
    int version;
    do {
      version = _syncVersion;
      final user = api.currentUserId;
      try {
        if (_legacyInstallation != null && _legacySecret != null) {
          await api.unregisterPushDevice(_legacyInstallation!, _legacySecret!);
          await _preferences!.remove('feedback_push_installation');
          await _preferences!.remove('feedback_push_device_secret');
          _legacyInstallation = null;
          _legacySecret = null;
        }
        final permitted = available && await transport.permissionGranted();
        final wanted = available && enabled && user != null && permitted;
        if (!_alive) return;
        if (wanted) {
          if (_boundUser != null && _boundUser != user) {
            try {
              await api.unregisterPushDevice(_installation!, _secret!);
            } finally {
              await transport.deleteToken();
            }
          }
          await transport.setAutoInit(true);
          final token = await transport.token().timeout(const Duration(seconds: 15));
          if (token == null) throw StateError('No FCM registration token');
          if (!_alive || version != _syncVersion) continue;
          await api.registerPushDevice(_installation!, _secret!, token, transport.projectId);
          _boundUser = user;
          await _preferences!.setString('feedback_push_bound_user', user);
        } else {
          try {
            await api.unregisterPushDevice(_installation!, _secret!);
          } finally {
            if (available) {
              await transport.setAutoInit(false);
              if (_boundUser != null) {
                try { await transport.deleteToken(); } catch (_) { /* Keep retrying server revocation independently. */ }
              }
            }
          }
          _boundUser = null;
          await _preferences!.remove('feedback_push_bound_user');
        }
        if (_alive && available) {
          error = enabled && !permitted ? '系统通知权限未开启，请在系统设置中允许通知' :
              enabled && user == null ? '登录 Supabase 后继续接收反馈推送' : null;
          update();
        }
      } catch (_) {
        if (_alive) {
          error = '推送设备同步失败，将在网络恢复后重试';
          update();
          _scheduleRetry();
        }
        if (version == _syncVersion) return;
      }
    } while (_alive && version != _syncVersion);
  }

  Future<void> _show(FeedbackPushEnvelope message) async {
    final target = FeedbackPushTarget.parse(message.data);
    if (!_alive || !enabled || !available || target == null || target.userId != api.currentUserId ||
        (isIssueVisible?.call(target.issueId) ?? false) || _displayed.contains(target.key)) {
      return;
    }
    try {
      await unread.syncUnread();
      if (!_alive || !enabled || target.userId != api.currentUserId || _displayed.contains(target.key)) return;
      final state = unread.states[target.issueId];
      if (state?.preference == 'hide' || (state != null && state.lastReadId >= target.messageId)) return;
      _displayed.add(target.key);
      if (_displayed.length > 200) _displayed.remove(_displayed.first);
      await transport.show(message);
    } catch (_) { /* A foreground notification must not interrupt the app. */ }
  }

  void _unreadChanged() {
    if (!available) return;
    for (final state in unread.states.values) {
      final key = '${state.lastReadId}:${state.preference}';
      if (!state.unread && _cleared[state.issueId] != key) {
        _cleared[state.issueId] = key;
        unawaited(_cancel(issueId: state.issueId));
      }
    }
  }

  Future<void> _cancel({String? issueId}) async {
    if (!supported) return;
    try { await transport.cancel(issueId: issueId); } catch (_) { /* Native channel may be closing. */ }
  }

  void _scheduleRetry() {
    if (!_alive || !_foreground || (_retry?.isActive ?? false)) return;
    _retry = Timer(const Duration(seconds: 10), () => unawaited(_requestSync()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state != AppLifecycleState.paused && state != AppLifecycleState.hidden && state != AppLifecycleState.detached;
    if (_foreground) {
      unawaited(_requestSync());
      unawaited(navigation.tryOpen());
    } else {
      _retry?.cancel();
    }
  }

  @override
  void onClose() {
    _alive = false;
    _retry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unread.removeListener(_unreadChanged);
    unawaited(_auth?.cancel());
    unawaited(_tokens?.cancel());
    unawaited(_messages?.cancel());
    unawaited(_taps?.cancel());
    unawaited(transport.dispose());
    super.onClose();
  }
}
