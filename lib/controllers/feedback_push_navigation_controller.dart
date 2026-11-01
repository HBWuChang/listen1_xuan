import 'dart:async';
import 'package:get/get.dart';
import '../services/feedback/feedback_push_target.dart';

/// Notification clicks wait for the home navigator and restored Auth session.
/// Injected actions keep Firebase/platform callbacks out of navigation tests.
class FeedbackPushNavigationController extends GetxController {
  FeedbackPushNavigationController({required this.currentUserId, required this.canNavigate,
    required this.openIssue, required this.openLogin, required this.report});
  final String? Function() currentUserId;
  final bool Function() canNavigate;
  final Future<void> Function(FeedbackPushTarget) openIssue;
  final Future<void> Function() openLogin;
  final void Function(String) report;
  FeedbackPushTarget? _pending;
  final _handled = <String>{};
  bool _ready = false, _opening = false, _loginRequested = false;
  Timer? _wait;

  void receive(Map<dynamic, dynamic> data) {
    final target = FeedbackPushTarget.parse(data);
    if (target == null || _handled.contains(target.key) || _pending?.key == target.key) return;
    _pending = target;
    _loginRequested = false;
    unawaited(tryOpen());
  }

  void setReady() {
    _ready = true;
    unawaited(tryOpen());
  }

  Future<void> tryOpen() async {
    if (isClosed || _opening || _pending == null) return;
    if (!_ready) return;
    if (!canNavigate()) {
      if (!(_wait?.isActive ?? false)) {
        _wait = Timer(const Duration(milliseconds: 300), () => unawaited(tryOpen()));
      }
      return;
    }
    final target = _pending!;
    final user = currentUserId();
    if (user == null) {
      if (_loginRequested) return;
      _loginRequested = true;
      _opening = true;
      try {
        await openLogin();
      } catch (_) {
        report('无法打开登录页面，请先登录后从在线反馈查看');
      } finally {
        _opening = false;
      }
      if (currentUserId() != null) unawaited(tryOpen());
      return;
    }
    if (user != target.userId) {
      _pending = null;
      report('这条反馈通知属于另一个账号，请切换账号后从在线反馈查看');
      return;
    }
    _opening = true;
    try {
      await openIssue(target);
      _handled.add(target.key);
      if (_handled.length > 100) _handled.remove(_handled.first);
      if (_pending?.key == target.key) _pending = null;
    } catch (_) {
      report('无法打开反馈问题，请从在线反馈重试');
      if (_pending?.key == target.key) _pending = null;
    } finally {
      _opening = false;
    }
    if (_pending != null) unawaited(tryOpen());
  }

  @override
  void onClose() {
    _wait?.cancel();
    _pending = null;
    super.onClose();
  }
}
