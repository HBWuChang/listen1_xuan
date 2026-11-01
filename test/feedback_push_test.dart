import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:listen1_xuan/controllers/feedback_push_controller.dart';
import 'package:listen1_xuan/controllers/feedback_push_navigation_controller.dart';
import 'package:listen1_xuan/controllers/feedback_unread_controller.dart';
import 'package:listen1_xuan/services/feedback/feedback_push_target.dart';
import 'package:listen1_xuan/services/feedback/feedback_push_transport.dart';
import 'feedback_unread_test.dart' as fixtures;

Map<String, dynamic> payload({String user = fixtures.userA, int message = 11}) => {
  'kind': 'feedback_message', 'issue_id': fixtures.issueA, 'user_id': user, 'message_id': '$message',
};

class PushApi extends fixtures.FakeApi {
  final registrations = <(String?, String)>[];
  int revocations = 0;
  Future<void> Function()? register;
  bool revokeOffline = false;
  @override
  Future<void> registerPushDevice(String installation, String secret, String token, String project) async {
    registrations.add((user, token));
    await register?.call();
  }
  @override
  Future<void> unregisterPushDevice(String installation, String secret) async {
    revocations++;
    if (revokeOffline) throw StateError('offline');
  }
}

class FakeTransport implements FeedbackPushTransport {
  @override
  Future<Map<String, String>> deviceIdentity() async => {
    'installation_id': '00000000-0000-0000-0000-000000000099', 'secret': 'a' * 64,
  };
  bool configured = true, permission = true, autoInit = false;
  int deletions = 0, cancellations = 0;
  String currentToken = 'first-token';
  final tokenStream = StreamController<String>.broadcast();
  final messageStream = StreamController<FeedbackPushEnvelope>.broadcast();
  final tapStream = StreamController<Map<dynamic, dynamic>>.broadcast();
  final shown = <FeedbackPushEnvelope>[];
  List<Map<dynamic, dynamic>> initial = [];
  @override
  Future<bool> initialize() async => configured;
  @override
  String get projectId => 'listen1-xuan';
  @override
  Stream<String> get tokenChanges => tokenStream.stream;
  @override
  Stream<FeedbackPushEnvelope> get messages => messageStream.stream;
  @override
  Stream<Map<dynamic, dynamic>> get taps => tapStream.stream;
  @override
  Future<List<Map<dynamic, dynamic>>> initialTaps() async => initial;
  @override
  Future<bool> requestPermission() async => permission;
  @override
  Future<bool> permissionGranted() async => permission;
  @override
  Future<String?> token() async => currentToken;
  @override
  Future<void> deleteToken() async { deletions++; }
  @override
  Future<void> setAutoInit(bool enabled) async { autoInit = enabled; }
  @override
  Future<void> show(FeedbackPushEnvelope message) async { shown.add(message); }
  @override
  Future<void> cancel({String? issueId}) async { cancellations++; }
  @override
  Future<void> dispose() async {
    await tokenStream.close(); await messageStream.close(); await tapStream.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PushApi api;
  late FakeTransport transport;
  late FeedbackUnreadController unread;
  late FeedbackPushNavigationController navigation;
  final opened = <FeedbackPushTarget>[];
  final errors = <String>[];
  bool ready = true;
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    api = PushApi();
    transport = FakeTransport();
    opened.clear(); errors.clear(); ready = true;
    unread = Get.put(FeedbackUnreadController(api, enableRealtime: false));
    navigation = Get.put(FeedbackPushNavigationController(
      currentUserId: () => api.user,
      canNavigate: () => ready,
      openIssue: (target) async { opened.add(target); },
      openLogin: () async {},
      report: errors.add,
    ));
  });
  tearDown(() async { Get.reset(); await api.client.dispose(); });
  FeedbackPushController create() => Get.put(FeedbackPushController(
    api, unread, navigation, transport: transport, platformSupported: true,
  ));

  test('only valid feedback targets become routes', () {
    expect(FeedbackPushTarget.parse(payload())?.issueId, fixtures.issueA);
    expect(FeedbackPushTarget.parse({...payload(), 'issue_id': 'https://external.invalid'}), isNull);
    expect(FeedbackPushTarget.parse({...payload(), 'kind': 'another_kind'}), isNull);
    expect(FeedbackPushTarget.parse({...payload(), 'message_id': '-1'}), isNull);
  });

  testWidgets('cold click waits for navigator readiness and deduplicates callbacks', (tester) async {
    navigation.receive(payload());
    await tester.pump();
    expect(opened, isEmpty);
    navigation.setReady();
    await tester.pump();
    expect(opened.length, 1);
    navigation.receive(payload());
    await tester.pump();
    expect(opened.length, 1);
  });

  testWidgets('a root dialog delays navigation without losing the target', (tester) async {
    ready = false;
    navigation.setReady();
    navigation.receive(payload());
    await tester.pump();
    expect(opened, isEmpty);
    ready = true;
    await tester.pump(const Duration(milliseconds: 300));
    expect(opened.length, 1);
  });

  testWidgets('a click for another account cannot open a discussion', (tester) async {
    navigation.setReady();
    navigation.receive(payload(user: fixtures.userB));
    await tester.pump();
    expect(opened, isEmpty);
    expect(errors.single, contains('另一个账号'));
  });

  testWidgets('a logged out click resumes only after the expected account signs in', (tester) async {
    api.user = null;
    navigation.setReady();
    navigation.receive(payload());
    await tester.pump();
    expect(opened, isEmpty);
    api.user = fixtures.userA;
    await navigation.tryOpen();
    expect(opened.length, 1);
  });

  testWidgets('missing Firebase config cannot enable push or break startup', (tester) async {
    transport.configured = false;
    final push = create();
    await push.start();
    await push.setEnabled(true);
    expect(push.available, isFalse);
    expect(push.enabled, isFalse);
    expect(push.error, contains('Firebase'));
    expect(api.registrations, isEmpty);
  });

  testWidgets('permission denial leaves push disabled', (tester) async {
    transport.permission = false;
    final push = create();
    await push.start();
    await push.setEnabled(true);
    expect(push.enabled, isFalse);
    expect(push.error, contains('通知权限'));
    expect(api.registrations, isEmpty);
  });

  testWidgets('opt in registers a device and token refresh updates its binding', (tester) async {
    final push = create();
    await push.start();
    expect(api.registrations, isEmpty);
    await push.setEnabled(true);
    expect(api.registrations.last, (fixtures.userA, 'first-token'));
    transport.currentToken = 'rotated-token';
    transport.tokenStream.add('rotated-token');
    await tester.pump();
    expect(api.registrations.last, (fixtures.userA, 'rotated-token'));
    await push.setEnabled(false);
    expect(transport.autoInit, isFalse);
    expect(transport.deletions, greaterThan(0));
  });

  testWidgets('an in-flight old account registration is followed by a safe rebind', (tester) async {
    SharedPreferences.setMockInitialValues({'feedback_push_enabled': true});
    final blocked = Completer<void>();
    api.register = () => blocked.future;
    final push = create();
    final startup = push.start();
    await tester.pump();
    expect(api.registrations.first.$1, fixtures.userA);
    api.user = fixtures.userB;
    push.didChangeAppLifecycleState(AppLifecycleState.resumed);
    api.register = null;
    blocked.complete();
    await startup;
    await tester.pump();
    expect(api.registrations.last.$1, fixtures.userB);
    expect(transport.deletions, greaterThan(0));
    api.user = null;
    final revoked = api.revocations;
    push.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(api.revocations, greaterThan(revoked));
    expect(transport.autoInit, isFalse);
  });

  testWidgets('opting out still stops the local token if server revocation is offline', (tester) async {
    final push = create();
    await push.start();
    await push.setEnabled(true);
    api.revokeOffline = true;
    await push.setEnabled(false);
    expect(push.enabled, isFalse);
    expect(transport.autoInit, isFalse);
    expect(transport.deletions, greaterThan(0));
    expect(push.error, contains('重试'));
    api.revokeOffline = false;
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(push.enabled, isFalse);
    expect(push.error, isNull);
  });

  testWidgets('foreground messages are deduplicated and already-read messages are suppressed', (tester) async {
    api.remoteStates = [fixtures.state(notified: 11)];
    final push = create();
    await push.start();
    await push.setEnabled(true);
    final envelope = FeedbackPushEnvelope(payload(), 'Question');
    transport.messageStream.add(envelope);
    transport.messageStream.add(envelope);
    await tester.pump();
    expect(transport.shown.length, 1);
    api.remoteStates = [fixtures.state(notified: 12, read: 12, revision: 2)];
    transport.messageStream.add(FeedbackPushEnvelope(payload(message: 12), 'Question'));
    await tester.pump();
    expect(transport.shown.length, 1);
    transport.messageStream.add(FeedbackPushEnvelope(payload(user: fixtures.userB, message: 13), 'Question'));
    await tester.pump();
    expect(transport.shown.length, 1);
  });

  testWidgets('a platform initial notification click uses the same pending route flow', (tester) async {
    transport.initial = [payload()];
    final push = create();
    await push.start();
    expect(opened, isEmpty);
    navigation.setReady();
    await tester.pump();
    expect(opened.single.issueId, fixtures.issueA);
    transport.tapStream.add(payload());
    await tester.pump();
    expect(opened.length, 1);
  });
}
