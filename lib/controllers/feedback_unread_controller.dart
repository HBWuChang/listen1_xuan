import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/feedback/feedback_api.dart';
import '../services/feedback/feedback_models.dart';

/// Persists only account-scoped notification metadata, never chat contents.
class FeedbackUnreadController extends GetxController with WidgetsBindingObserver {
  FeedbackUnreadController(this.api, {this.enableRealtime = true});
  final FeedbackApi api;
  final bool enableRealtime;
  final states = <String, FeedbackIssueState>{};
  final _pendingReads = <String, int>{};
  StreamSubscription<AuthState>? _auth;
  RealtimeChannel? _channel;
  Timer? _retry;
  String? _userId;
  int _epoch = 0, _watchId = 0;
  bool _foreground = true, _refreshAgain = false, _alive = true;
  int? _refreshingEpoch, _drainingEpoch;
  String? error;

  bool get hasUnread => states.values.any((state) => state.unread);
  bool unread(String issueId) => states[issueId]?.unread ?? false;
  String preference(String issueId) => states[issueId]?.preference ?? 'unset';
  bool _valid(int epoch) => _alive && epoch == _epoch && api.currentUserId == _userId;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _foreground = !_background(WidgetsBinding.instance.lifecycleState);
    _auth = api.client.auth.onAuthStateChange.listen(
      (_) => synchronizeAccount(),
      onError: (Object _) => _scheduleRetry(),
    );
    synchronizeAccount();
  }

  /// Also called before mutations, so stale responses never cross accounts.
  void synchronizeAccount() {
    if (!_alive) return;
    final userId = api.currentUserId;
    if (userId != _userId) {
      _epoch++;
      _userId = userId;
      states.clear();
      _pendingReads.clear();
      _refreshAgain = false;
      error = null;
      _retry?.cancel();
      _stopWatch();
      update();
    }
    if (userId == null || !_foreground) return;
    if (_channel == null) _watch();
    unawaited(syncUnread());
  }

  void _merge(FeedbackIssueState state) {
    if (state.userId != _userId) return;
    final previous = states[state.issueId];
    if (previous != null && previous.revision >= state.revision) return;
    states[state.issueId] = state;
    update();
  }

  Future<void> syncUnread() async {
    final epoch = _epoch;
    final userId = _userId;
    if (!_valid(epoch) || userId == null || !_foreground) return;
    if (_refreshingEpoch == epoch) {
      _refreshAgain = true;
      return;
    }
    _refreshingEpoch = epoch;
    try {
      do {
        _refreshAgain = false;
        String? after;
        do {
          final rows = await api.issueStates(userId, after: after);
          if (!_valid(epoch) || !_foreground) return;
          // Per-row revisions prevent an older HTTP snapshot undoing Realtime.
          for (final row in rows) {
            _merge(row);
          }
          if (rows.length < 500) break;
          after = rows.last.issueId;
        } while (_valid(epoch) && _foreground);
        error = null;
      } while (_refreshAgain && _valid(epoch) && _foreground);
    } catch (_) {
      if (_valid(epoch)) {
        error = '未读状态同步失败，将在连接恢复后重试';
        _scheduleRetry();
      }
    } finally {
      if (_refreshingEpoch == epoch) _refreshingEpoch = null;
    }
    if (_valid(epoch)) await _drainReads();
  }

  Future<void> markRead(String issueId, {required int through}) async {
    if (api.currentUserId != _userId) synchronizeAccount();
    if (!_alive || _userId == null) return;
    final pending = _pendingReads[issueId] ?? 0;
    // Freeze the read boundary now: retrying after an outage must not clear
    // messages that arrived after the user left this discussion.
    _pendingReads[issueId] = through > pending ? through : pending;
    await _drainReads();
  }

  Future<void> _drainReads() async {
    final epoch = _epoch;
    if (!_valid(epoch) || _userId == null || !_foreground || _drainingEpoch == epoch) return;
    _drainingEpoch = epoch;
    try {
      while (_pendingReads.isNotEmpty && _valid(epoch) && _foreground) {
        final request = _pendingReads.entries.first;
        final state = await api.markRead(request.key, request.value);
        if (!_valid(epoch)) return;
        _merge(state);
        if (_pendingReads[request.key] == request.value) _pendingReads.remove(request.key);
      }
    } catch (_) {
      if (_valid(epoch)) _scheduleRetry();
    } finally {
      if (_drainingEpoch == epoch) _drainingEpoch = null;
    }
  }

  Future<void> setPreference(String issueId, String preference) async {
    if (api.currentUserId != _userId) synchronizeAccount();
    if (_userId == null) throw StateError('请先登录');
    final epoch = _epoch;
    final state = await api.setUnreadPreference(issueId, preference);
    if (_valid(epoch)) _merge(state);
  }

  void _watch() {
    if (!enableRealtime || !_foreground || _userId == null || !_alive) return;
    _stopWatch();
    final epoch = _epoch, watchId = _watchId;
    final userId = _userId!;
    bool valid() => _valid(epoch) && _foreground && watchId == _watchId;
    final channel = api.client.channel('feedback-unread:$userId:$watchId');
    _channel = channel;
    for (final event in [PostgresChangeEvent.insert, PostgresChangeEvent.update]) {
      channel.onPostgresChanges(
        event: event,
        schema: 'public',
        table: 'feedback_issue_states',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
        callback: (payload) {
          if (valid() && payload.newRecord.isNotEmpty) {
            _merge(FeedbackIssueState.fromJson(payload.newRecord));
          }
        },
      );
    }
    channel.subscribe((status, _) {
      if (!valid()) return;
      if (status == RealtimeSubscribeStatus.subscribed) {
        unawaited(syncUnread());
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut || status == RealtimeSubscribeStatus.closed) {
        _scheduleRetry();
      }
    });
  }

  void _scheduleRetry() {
    if (!_alive || !_foreground || _userId == null || (_retry?.isActive ?? false)) return;
    _retry = Timer(const Duration(seconds: 10), () {
      if (!_alive || !_foreground) return;
      _watch();
      unawaited(syncUnread());
    });
  }

  void _stopWatch() {
    _watchId++;
    final old = _channel;
    _channel = null;
    if (old != null) unawaited(_removeChannel(old));
  }

  Future<void> _removeChannel(RealtimeChannel channel) async {
    try {
      await api.client.removeChannel(channel);
    } catch (_) {
      // Connection cleanup must not interrupt account changes or app shutdown.
    }
  }

  bool _background(AppLifecycleState? state) => state == AppLifecycleState.paused ||
      state == AppLifecycleState.hidden || state == AppLifecycleState.detached;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _foreground;
    _foreground = !_background(state);
    if (!_foreground) {
      _retry?.cancel();
      _stopWatch();
    } else if (!wasForeground) {
      synchronizeAccount();
    }
  }

  @override
  void onClose() {
    _alive = false;
    _epoch++;
    _retry?.cancel();
    _stopWatch();
    unawaited(_auth?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    states.clear();
    _pendingReads.clear();
    super.onClose();
  }
}
