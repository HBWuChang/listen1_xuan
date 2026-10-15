import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/feedback/feedback_api.dart';
import '../../services/feedback/feedback_models.dart';

/// Each list/issue route owns a tagged Get controller; profiles borrow their issue.
class FeedbackController extends GetxController with WidgetsBindingObserver {
  FeedbackController(this.api, {this.enableRealtime = true, FeedbackIssue? initialIssue}) : issue = initialIssue {
    loading = initialIssue != null;
  }
  final bool enableRealtime;
  final FeedbackApi api;
  List<FeedbackIssue> issues = [];
  List<FeedbackMessage> messages = [];
  final profiles = <String, FeedbackProfile>{};
  final references = <int, FeedbackMessage>{};
  final _pendingReferences = <int>{};
  FeedbackIssue? issue;
  FeedbackPermissions permissions = const FeedbackPermissions();
  String? profileId;
  FeedbackPermissions profilePermissions = const FeedbackPermissions();
  String search = '', sort = 'activity';
  bool mine = false,
      ascending = false,
      loading = false,
      loadingMore = false,
      hasMore = true,
      listDirty = false,
      connected = false,
      recovering = false;
  String? error;
  int pageSize = 30, unseen = 0, jumpLoaded = 0;
  bool atLatest = true, jumping = false;
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _auth;
  bool _alive = true, _appForeground = true, _routeActive = true, _recoverAgain = false;
  bool get _foreground => _appForeground && _routeActive;
  bool routeCovered = false, working = false;
  Future<void>? _startup;
  FeedbackIssue? _issueCursor;
  String? _authUserId;
  int _scope = 0, _watchId = 0, _listRequest = 0, _jumpId = 0;
  bool _valid(int scope) => _alive && _foreground && scope == _scope;
  void _emit() {
    if (_alive) update();
  }

  String get userName =>
      permissions.userId == null ? '未登录' : name(permissions.userId!);
  String name(String id) => profiles[id]?.name ?? '用户 ${id.substring(0, 8)}';

  @override
  void onInit() {
    super.onInit();
    unawaited(start().catchError((Object error) { if (_alive) report(error); }));
  }

  Future<void> start() => _startup ??= _start();

  Future<void> _start() async {
    WidgetsBinding.instance.addObserver(this);
    final preferences = await SharedPreferences.getInstance();
    if (!_alive) return;
    pageSize = (preferences.getInt('feedback_message_page_size') ?? 30).clamp(
      1,
      114,
    );
    _authUserId = api.client.auth.currentUser?.id;
    _auth = api.client.auth.onAuthStateChange.listen(
      (state) {
        if (!_alive || !_foreground) return;
        final userId = state.session?.user.id;
        if (userId != _authUserId) {
          _authUserId = userId;
          _scope++;
          recovering = false;
          loadingMore = false;
          cancelJump();
        }
        unawaited(_authChanged());
      },
      onError: (Object error) {
        if (_alive && _foreground) report(error);
      },
    );
    _watch();
    await reload();
  }

  Future<void> _authChanged() async {
    try {
      await refreshContext();
      if (!_alive || !_foreground) return;
      _watch();
      await reload();
    } catch (e) {
      report(e);
    }
  }

  Future<void> setPageSize(int value) async {
    if (value < 1 || value > 114) return;
    pageSize = value;
    _emit();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('feedback_message_page_size', value);
  }

  Future<void> refreshContext() async {
    final scope = _scope;
    final target = profileId;
    final current = await api.context(issueId: issue?.id);
    final targetContext = target == null
        ? null
        : await api.context(issueId: issue?.id, target: target);
    if (!_valid(scope)) return;
    permissions = current;
    if (target == profileId && targetContext != null)
      profilePermissions = targetContext;
    _emit();
  }

  Future<void> reload() async {
    if (issue == null) {
      await reloadIssues();
    } else {
      await recover();
    }
  }

  Future<void> reloadIssues({bool more = false}) async {
    if (!_alive ||
        !_foreground ||
        issue != null ||
        (more && (loading || loadingMore || !hasMore)))
      return;
    final scope = _scope;
    final request = more ? _listRequest : ++_listRequest;
    if (more) {
      loadingMore = true;
    } else {
      loading = true;
      loadingMore = false;
      listDirty = false;
    }
    error = null;
    _emit();
    try {
      final rows = await api.issues(
        search: search,
        mine: mine,
        sort: sort,
        ascending: ascending,
        cursor: more ? _issueCursor : null,
      );
      final context = await api.context();
      if (!_valid(scope) || request != _listRequest) return;
      permissions = context;
      if (rows.isNotEmpty) _issueCursor = rows.last;
      if (!more && rows.isEmpty) _issueCursor = null;
      issues = more
          ? [
              ...issues,
              ...rows.where((row) => !issues.any((old) => old.id == row.id)),
            ]
          : rows;
      hasMore = rows.length == 30;
      await _loadProfiles(rows.map((row) => row.creatorId), scope);
    } catch (e) {
      if (_valid(scope) && request == _listRequest) error = friendlyError(e);
    } finally {
      if (_valid(scope) && request == _listRequest) {
        loading = false;
        loadingMore = false;
        _emit();
      }
    }
  }

  Future<void> openIssue(FeedbackIssue value) async {
    _scope++;
    _listRequest++;
    issue = value;
    profileId = null;
    messages = [];
    references.clear();
    _pendingReferences.clear();
    unseen = 0;
    atLatest = true;
    hasMore = true;
    loading = true;
    loadingMore = false;
    recovering = false;
    error = null;
    _watch();
    _emit();
    await recover();
  }

  Future<void> closeIssue() async {
    _scope++;
    _jumpId++;
    jumping = false;
    issue = null;
    profileId = null;
    messages = [];
    references.clear();
    _pendingReferences.clear();
    profiles.clear();
    loading = false;
    loadingMore = false;
    recovering = false;
    _watch();
    await reloadIssues();
  }

  Future<void> openProfile(String id) async {
    profileId = id;
    profilePermissions = const FeedbackPermissions();
    _emit();
    final scope = _scope;
    try {
      await _loadProfiles([id], scope, force: true);
      await refreshContext();
    } catch (e) {
      if (_valid(scope)) report(e);
    }
  }

  void closeProfile() {
    profileId = null;
    profilePermissions = const FeedbackPermissions();
    _emit();
  }

  Future<void> _loadProfiles(
    Iterable<String> ids,
    int scope, {
    bool force = false,
  }) async {
    final missing = ids
        .where((id) => force || !profiles.containsKey(id))
        .toSet();
    if (missing.isEmpty) return;
    final rows = await api.profiles(missing);
    if (!_valid(scope)) return;
    for (final row in rows) {
      profiles[row.id] = row;
    }
  }

  Future<void> _enrich(List<FeedbackMessage> incoming, int scope) async {
    await _loadProfiles(
      incoming.expand((m) => [m.senderId, ...m.mentions]),
      scope,
    );
    if (!_valid(scope)) return;
    // Fetch references by ID, without embedding a copy in persisted messages.
    final ids = incoming.map((m) => m.replyTo).whereType<int>().toSet();
    for (final id in ids) {
      if (!_valid(scope)) return;
      if (references.containsKey(id) || messages.any((m) => m.id == id))
        continue;
      _pendingReferences.add(id);
      try {
        final reference = await api.message(issue!.id, id);
        if (!_valid(scope)) return;
        if (reference != null) {
          references[id] = mergeFeedbackMessages(
            [if (references[id] != null) references[id]!],
            [reference],
          ).single;
          await _loadProfiles([reference.senderId], scope);
        }
      } finally {
        _pendingReferences.remove(id);
      }
    }
    _emit();
  }

  void _merge(List<FeedbackMessage> incoming, {bool live = false}) {
    if (live && !atLatest)
      unseen += incoming
          .where((m) => !messages.any((old) => old.id == m.id))
          .length;
    messages = mergeFeedbackMessages(messages, incoming);
    for (final message in incoming) {
      if (references.containsKey(message.id)) references[message.id] = message;
    }
    _emit();
  }

  Future<void> recover() async {
    if (!_alive || !_foreground || issue == null) return;
    if (recovering) {
      _recoverAgain = true;
      return;
    }
    final scope = _scope;
    final id = issue!.id;
    recovering = true;
    error = null;
    _emit();
    try {
      final latestIssue = await api.issue(id);
      final context = await api.context(issueId: id);
      if (!_valid(scope)) return;
      issue = latestIssue;
      permissions = context;
      if (messages.isEmpty) {
        final rows = await api.messages(id, limit: pageSize);
        if (!_valid(scope)) return;
        hasMore = rows.length == pageSize;
        _merge(rows);
        await _enrich(rows, scope);
      } else {
        var cursor = messages.first.id;
        while (_valid(scope)) {
          final rows = await api.messages(id, after: cursor, limit: 114);
          if (!_valid(scope)) return;
          _merge(rows, live: true);
          await _enrich(rows, scope);
          if (rows.isEmpty || rows.length < 114) break;
          cursor = rows.last.id;
        }
      }
      await _loadProfiles([latestIssue.creatorId], scope);
      if (profileId != null) await refreshContext();
    } catch (e) {
      if (_valid(scope)) error = friendlyError(e);
    } finally {
      if (_valid(scope)) {
        recovering = false;
        loading = false;
        _emit();
        if (_recoverAgain) {
          _recoverAgain = false;
          unawaited(recover());
        }
      }
    }
  }

  Future<void> older() async {
    if (!_alive ||
        !_foreground ||
        issue == null ||
        loadingMore ||
        loading ||
        !hasMore)
      return;
    final scope = _scope;
    loadingMore = true;
    error = null;
    _emit();
    try {
      final rows = await api.messages(
        issue!.id,
        before: messages.isEmpty ? null : messages.last.id,
        limit: pageSize,
      );
      if (!_valid(scope)) return;
      hasMore = rows.length == pageSize;
      _merge(rows);
      await _enrich(rows, scope);
    } catch (e) {
      if (_valid(scope)) error = friendlyError(e);
    } finally {
      if (_valid(scope)) {
        loadingMore = false;
        _emit();
      }
    }
  }

  FeedbackMessage? reference(int id) {
    for (final message in messages) {
      if (message.id == id) return message;
    }
    return references[id];
  }

  Future<bool> loadToReply(int id) async {
    if (issue == null || jumping) return false;
    if (messages.any((m) => m.id == id)) return true;
    final scope = _scope;
    final jump = ++_jumpId;
    jumping = true;
    jumpLoaded = 0;
    _emit();
    try {
      final target = await api.message(issue!.id, id);
      if (!_valid(scope) || jump != _jumpId) return false;
      if (target == null) throw StateError('引用消息不存在');
      while (_valid(scope) && jump == _jumpId) {
        final index = messages.indexWhere((m) => m.id == id);
        if ((index >= 0 && messages.length - index - 1 >= 10) || !hasMore)
          return index >= 0;
        final previousCount = messages.length;
        await older();
        if (!_valid(scope) || jump != _jumpId) return false;
        jumpLoaded += messages.length - previousCount;
        _emit();
        if (error != null) return false;
        // A concurrent pagination request owns the next batch; wait without spinning.
        if (loadingMore)
          await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      return false;
    } finally {
      if (_valid(scope) && jump == _jumpId) {
        jumping = false;
        _emit();
      }
    }
  }

  void cancelJump() {
    _jumpId++;
    jumping = false;
    _emit();
  }

  void markLatest(bool value) {
    atLatest = value;
    if (value && unseen != 0) {
      unseen = 0;
      _emit();
    }
  }

  Future<void> sendMessage(Map<String, dynamic> data) async {
    final scope = _scope;
    final id = issue!.id;
    await api.action('send', {'issue_id': id, ...data});
    if (!_valid(scope)) return;
    // Fetch the whole missing interval, including concurrent senders.
    await recover();
  }

  Future<void> withdraw(int messageId) async {
    final scope = _scope;
    final row = await api.action('withdraw', {
      'issue_id': issue!.id,
      'message_id': messageId,
    });
    if (!_valid(scope)) return;
    final message = FeedbackMessage.fromJson(row);
    _merge([message]);
  }

  void reconnect() {
    if (_alive && _foreground) {
      _watch();
      unawaited(reload());
    }
  }

  void setWorking(bool value) { working = value; _emit(); }
  void setRouteCovered(bool value) {
    if (routeCovered == value) return;
    routeCovered = value; _emit();
  }
  void suspend() => _setRouteActive(false);
  void resume() => _setRouteActive(true);

  void _setRouteActive(bool value) {
    final previous = _foreground;
    _routeActive = value;
    _activeChanged(previous);
  }

  void _activeChanged(bool previous) {
    if (!_alive || previous == _foreground) return;
    _scope++;
    recovering = false;
    loadingMore = false;
    _recoverAgain = false;
    if (!_foreground) cancelJump();
    _watch();
    if (_foreground) unawaited(reload());
  }

  Future<void> _eventsChanged(int scope) async {
    try {
      await refreshContext();
      if (!_valid(scope)) return;
      await _loadProfiles(profiles.keys.toList(), scope, force: true);
      _emit();
    } catch (e) {
      if (_valid(scope)) report(e);
    }
  }

  void _watch() {
    final watch = ++_watchId;
    final previous = _channel;
    _channel = null;
    connected = false;
    if (previous != null) unawaited(api.client.removeChannel(previous));
    if (!_alive || !_foreground || !enableRealtime) return;
    final scope = _scope;
    final id = issue?.id;
    bool valid() => _valid(scope) && watch == _watchId;
    final channel = api.client.channel(
      'feedback:${identityHashCode(this)}:$watch',
    );
    _channel = channel;
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'feedback_events',
      callback: (_) {
        if (valid()) unawaited(_eventsChanged(scope));
      },
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'feedback_issues',
      filter: id == null
          ? null
          : PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: id,
            ),
      callback: (payload) {
        if (!valid()) return;
        if (id != null) {
          if (payload.newRecord.isNotEmpty)
            issue = FeedbackIssue.fromJson(payload.newRecord);
        } else {
          listDirty = true;
          if (payload.newRecord.isNotEmpty) {
            final updated = FeedbackIssue.fromJson(payload.newRecord);
            final index = issues.indexWhere((row) => row.id == updated.id);
            if (index >= 0) issues[index] = updated;
          }
        }
        _emit();
      },
    );
    if (id != null) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'feedback_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'issue_id',
          value: id,
        ),
        callback: (payload) {
          if (!valid() || payload.newRecord.isEmpty) return;
          final message = FeedbackMessage.fromJson(payload.newRecord);
          // Updates only affect loaded messages/references; do not create history gaps.
          if (payload.eventType == PostgresChangeEvent.update) {
            if (messages.any((m) => m.id == message.id)) _merge([message]);
            if (references.containsKey(message.id) ||
                _pendingReferences.contains(message.id)) {
              references[message.id] = message;
              _emit();
            }
          } else {
            // Catch up from the existing boundary, rather than skipping lost events.
            unawaited(recover());
          }
        },
      );
    }
    channel.subscribe((status, error) {
      if (!valid()) return;
      connected = status == RealtimeSubscribeStatus.subscribed;
      _emit();
      if (connected) unawaited(reload());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_alive) return;
    final previous = _foreground;
    if (state == AppLifecycleState.resumed) {
      _appForeground = true;
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.detached) {
      _appForeground = false;
    }
    _activeChanged(previous);
  }

  static String friendlyError(Object error) =>
      error is PostgrestException ? error.message : '加载失败，请检查网络后重试';
  void report(Object value) {
    error = friendlyError(value);
    _emit();
  }

  @override
  void onClose() {
    _release();
    super.onClose();
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  void _release() {
    if (!_alive) return;
    _alive = false;
    _scope++;
    _watchId++;
    _jumpId++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_auth?.cancel());
    if (_channel != null) unawaited(api.client.removeChannel(_channel!));
    _channel = null;
    issues.clear();
    messages.clear();
    profiles.clear();
    references.clear();
    _pendingReferences.clear();
    issue = null;
    profileId = null;
  }
}
