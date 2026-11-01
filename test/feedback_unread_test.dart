import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:listen1_xuan/controllers/feedback_unread_controller.dart';
import 'package:listen1_xuan/pages/feedback/feedback_controller.dart';
import 'package:listen1_xuan/services/feedback/feedback_api.dart';
import 'package:listen1_xuan/services/feedback/feedback_models.dart';
import 'package:listen1_xuan/widgets/feedback_unread_badge.dart';

const userA = '00000000-0000-0000-0000-000000000001';
const userB = '00000000-0000-0000-0000-000000000002';
const issueA = '00000000-0000-0000-0000-000000000010';

FeedbackIssueState state({String user = userA, String issue = issueA,
    String preference = 'unset', int notified = 10, int read = 0, int revision = 1}) =>
  FeedbackIssueState.fromJson({
    'user_id': user, 'issue_id': issue, 'preference': preference,
    'participated': true, 'last_notified_id': notified,
    'last_read_id': read, 'revision': revision,
  });

final fixtureIssue = FeedbackIssue.fromJson({
  'id': issueA, 'creator_id': userB, 'title': 'Issue', 'description': 'Description',
  'status': 'open', 'locked': false,
  'created_at': '2026-11-01T00:00:00Z', 'last_message_at': '2026-11-01T00:00:00Z',
});

FeedbackMessage message(int id) => FeedbackMessage.fromJson({
  'id': id, 'issue_id': issueA, 'sender_id': userB, 'body': 'Message $id',
  'mentions': <String>[], 'mention_all': false, 'reply_to': null,
  'created_at': '2026-11-01T00:00:00Z', 'withdrawn_at': null,
});

class FakeApi extends FeedbackApi {
  FakeApi() : super(SupabaseClient('https://example.supabase.co', 'public-test-key'));
  String? user = userA;
  @override
  String? get currentUserId => user;
  List<FeedbackIssueState> remoteStates = [];
  List<FeedbackMessage> history = [message(10)];
  final pages = <String?>[];
  final reads = <(String, int)>[];
  Future<List<FeedbackIssueState>> Function(String, String?)? fetch;
  Future<FeedbackIssueState> Function(String, int)? read;
  bool offline = false;

  @override
  Future<List<FeedbackIssueState>> issueStates(String userId, {String? after}) async {
    pages.add(after);
    if (fetch != null) return fetch!(userId, after);
    return remoteStates.where((s) => s.userId == userId && (after == null || s.issueId.compareTo(after) > 0)).take(500).toList();
  }

  @override
  Future<FeedbackIssueState> markRead(String issueId, int through) async {
    reads.add((issueId, through));
    if (read != null) return read!(issueId, through);
    if (offline) throw StateError('offline');
    final current = remoteStates.first;
    return state(user: user!, issue: issueId, notified: current.lastNotifiedId,
      read: through, revision: current.revision + 1);
  }

  @override
  Future<FeedbackIssueState> setUnreadPreference(String issueId, String preference) async {
    final current = remoteStates.first;
    return state(user: user!, issue: issueId, preference: preference,
      notified: current.lastNotifiedId,
      read: preference == 'hide' ? current.lastNotifiedId : current.lastReadId,
      revision: current.revision + 1);
  }

  @override
  Future<FeedbackIssue> issue(String id) async => issueForTest;
  FeedbackIssue get issueForTest => fixtureIssue;
  @override
  Future<FeedbackPermissions> context({String? issueId, String? target}) async => FeedbackPermissions(userId: user);
  @override
  Future<List<FeedbackProfile>> profiles(Iterable<String> ids) async => [];
  @override
  Future<List<FeedbackMessage>> messages(String issueId, {int? before, int? after, int limit = 30}) async =>
      history.where((m) => (after == null || m.id > after) && (before == null || m.id < before)).take(limit).toList();
}

class RecordingUnread extends FeedbackUnreadController {
  RecordingUnread(super.api) : super(enableRealtime: false);
  final reads = <(String, int)>[];
  @override
  Future<void> markRead(String issueId, {required int through}) async {
    reads.add((issueId, through));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeApi api;
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    api = FakeApi();
  });
  tearDown(() async {
    Get.reset();
    await api.client.dispose();
  });

  testWidgets('global unread includes states beyond the first 500 rows', (tester) async {
    api.remoteStates = List.generate(501, (i) => state(
      issue: i.toString().padLeft(8, '0'), notified: 10,
      read: i == 500 ? 0 : 10,
    ));
    final controller = Get.put(FeedbackUnreadController(api, enableRealtime: false));
    await tester.pump();
    expect(controller.states.length, 501);
    expect(controller.hasUnread, isTrue);
    expect(api.pages, contains('00000499'));
  });

  testWidgets('older HTTP snapshot cannot undo a newer mutation revision', (tester) async {
    final snapshot = Completer<List<FeedbackIssueState>>();
    api.remoteStates = [state()];
    api.fetch = (_, __) => snapshot.future;
    final controller = Get.put(FeedbackUnreadController(api, enableRealtime: false));
    await controller.setPreference(issueA, 'hide');
    expect(controller.hasUnread, isFalse);
    snapshot.complete([state()]);
    await tester.pump();
    expect(controller.preference(issueA), 'hide');
    expect(controller.states[issueA]!.revision, 2);
    expect(controller.hasUnread, isFalse);
  });

  testWidgets('an old account snapshot cannot populate the next account', (tester) async {
    final snapshotA = Completer<List<FeedbackIssueState>>();
    api.fetch = (user, _) async => user == userA ? snapshotA.future : [state(user: userB, read: 10)];
    final controller = Get.put(FeedbackUnreadController(api, enableRealtime: false));
    api.user = userB;
    controller.synchronizeAccount();
    await tester.pump();
    snapshotA.complete([state()]);
    await tester.pump();
    expect(controller.states.values.every((s) => s.userId == userB), isTrue);
    expect(controller.hasUnread, isFalse);
    api.user = null;
    controller.synchronizeAccount();
    expect(controller.states, isEmpty);
  });

  testWidgets('a pending read response cannot cross accounts', (tester) async {
    final response = Completer<FeedbackIssueState>();
    api.remoteStates = [state()];
    api.read = (_, __) => response.future;
    final controller = Get.put(FeedbackUnreadController(api, enableRealtime: false));
    await tester.pump();
    final pending = controller.markRead(issueA, through: 10);
    api.user = userB;
    api.remoteStates = [state(user: userB, read: 10)];
    controller.synchronizeAccount();
    await tester.pump();
    response.complete(state(read: 10, revision: 9));
    await pending;
    expect(controller.states[issueA]!.userId, userB);
    expect(controller.states[issueA]!.revision, 1);
  });

  testWidgets('offline read retries preserve the original message boundary', (tester) async {
    api.remoteStates = [state(notified: 11)];
    api.offline = true;
    final controller = Get.put(FeedbackUnreadController(api, enableRealtime: false));
    await tester.pump();
    await controller.markRead(issueA, through: 10);
    api.offline = false;
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(api.reads.map((request) => request.$2), everyElement(10));
    expect(api.reads.length, greaterThanOrEqualTo(2));
    expect(controller.states[issueA]!.lastReadId, 10);
    expect(controller.hasUnread, isTrue);
  });

  testWidgets('issue, feedback entry and settings badges share account state', (tester) async {
    api.remoteStates = [state()];
    final controller = Get.put(FeedbackUnreadController(api, enableRealtime: false));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Row(children: [
      FeedbackUnreadBadge(issueId: issueA, child: Text('Issue')),
      FeedbackUnreadBadge(child: Text('Feedback')),
      FeedbackUnreadBadge(child: Icon(Icons.settings)),
    ]))));
    await tester.pump();
    expect(tester.widgetList<Badge>(find.byType(Badge)).where((b) => b.isLabelVisible).length, 3);
    await controller.setPreference(issueA, 'hide');
    await tester.pump();
    expect(tester.widgetList<Badge>(find.byType(Badge)).every((b) => !b.isLabelVisible), isTrue);
  });

  testWidgets('entry marks loaded history once; exit includes known notifications', (tester) async {
    final unread = RecordingUnread(api);
    final controller = FeedbackController(api, enableRealtime: false, initialIssue: fixtureIssue, unread: unread);
    await controller.start();
    expect(unread.reads, [(issueA, 10)]);
    api.history = [message(11), message(10)];
    await controller.recover();
    expect(unread.reads, [(issueA, 10)]);
    unread.states[issueA] = state(notified: 12);
    controller.markIssueReadOnExit();
    expect(unread.reads.last, (issueA, 12));
    unread.states[issueA] = state(notified: 13);
    controller.onClose();
    expect(unread.reads, [(issueA, 10), (issueA, 12)]);
    unread.onClose();
  });
}
