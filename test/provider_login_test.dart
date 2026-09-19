import 'dart:async';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:listen1_xuan/global_settings_animations.dart' show enable_inapp_hotkey;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:listen1_xuan/controllers/DioController.dart';
import 'package:listen1_xuan/controllers/settings_controller.dart';
import 'package:listen1_xuan/models/ProviderUser.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:listen1_xuan/models/bootStrapTrackRes.dart';
import 'package:listen1_xuan/models/websocket_message.dart';
import 'package:listen1_xuan/provider/base.dart';
import 'package:listen1_xuan/provider/bilibili.dart';
import 'package:listen1_xuan/provider/loweb.dart' as music;
import 'package:listen1_xuan/provider/netease.dart';
import 'package:listen1_xuan/provider/qq.dart';
import 'package:listen1_xuan/settings.dart' show outputPlatformToken, savePlatformToken;
import 'package:listen1_xuan/utils/platform_credentials.dart';

class _Settings extends GetxController implements SettingsController {
  @override
  final settings = <String, dynamic>{}.obs;
  int saves = 0;
  @override
  Future<void> saveSettings() async { saves++; }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Dio extends DioController {
  int reloads = 0;
  @override
  Future<void> reloadCookie() async { reloads++; }
}

class _Registry extends music.Provider {
  // Tests register their own providers instead of starting production services.
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Provider extends BaseProvider {
  _Provider(this.id, {this.hidden = false, this.supportLogin = true});
  @override
  final String id;
  @override
  final bool hidden;
  @override
  final bool supportLogin;
  @override
  String get name => id;
  @override
  bool get searchable => true;
  @override
  bool get supportLyric => false;
  @override
  List<String> get cookieUrls => ['https://$id.example.test'];
  Future<ProviderUser?> Function()? query;
  int queries = 0;
  @override
  Future<ProviderUser?> fetchUser() async {
    queries++;
    if (query != null) return query!();
    return ProviderUser(platform: name, userId: token, name: 'test user');
  }
  @override
  Future<void> bootStrapTrack(
    Track track,
    Function(BootSuccessRes res, Track track) success,
    Function(Track track, Object? error) failure,
  ) async {}
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late _Settings settings;
  late _Dio dio;
  late _Registry registry;
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('provider_login_test_');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async => directory.path);
    settings = _Settings();
    dio = _Dio();
    registry = _Registry();
    Get.put<SettingsController>(settings);
    Get.put<DioController>(dio);
    Get.put<music.Provider>(registry);
  });

  tearDown(() async {
    Get.reset();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });

  Future<List<Cookie>> storedCookies(BaseProvider provider) {
    return PersistCookieJar(storage: FileStorage(cookiePath(directory)), ignoreExpires: true)
        .loadForRequest(Uri.parse(provider.cookieUrls.first));
  }

  test('credential menus reflect registration changes and exclude all, hidden and non-login providers', () {
    registry.providers.addAll([Bilibili(), Netease(), QQ(), _Provider('hidden', hidden: true), _Provider('local', supportLogin: false)]);
    expect(PlantformCodes.values, ['bl', 'ne', 'qq', 'github']);
    expect(getCookieCommandsMap['所有'], 'all');
    expect(getCookieCommandsMap['哔哩哔哩'], 'bl');
    expect(registry.tryGetProviderByCredentialKey('bi'), isNull);
    final added = _Provider('new');
    registry.providers.add(added);
    expect(PlantformCodes.values, contains('new'));
    expect(getCookieCommandsMap['new'], 'new');
    registry.providers.remove(added);
    expect(PlantformCodes.values, isNot(contains('new')));
    expect(getCookieCommandsMap, isNot(contains('new')));
  });

  test('remote import dispatches through registered provider and logout clears settings and disk cookies', () async {
    final provider = _Provider('imported');
    registry.providers.add(provider);
    await savePlatformToken(PlatformCredentials(platform: 'imported', credentials: 'sid=test; empty='));
    expect(await outputPlatformToken('imported'), provider.token);
    expect(settings.saves, 1);
    expect(dio.reloads, 1);
    expect(provider.loginStatus.value, LoginStatus.loggedIn);
    expect((await storedCookies(provider)).map((cookie) => cookie.name), ['sid']);
    await provider.logout();
    expect(provider.token, '');
    expect(provider.currentUser.value, isNull);
    expect(provider.loginStatus.value, LoginStatus.noLogin);
    expect(await storedCookies(provider), isEmpty);
    expect(await outputPlatformToken('all'), isNull);
    await expectLater(savePlatformToken(PlatformCredentials(platform: 'all', credentials: 'sid=test')), throwsArgumentError);
  });

  test('QQ favorite request restores legacy login cookies to c.y.qq.com without logging in again', () async {
    final provider = QQ();
    settings.settings[provider.credentialKey] = 'uin=123; qm_keyst=test-key';
    final jar = PersistCookieJar(storage: FileStorage(cookiePath(directory)), ignoreExpires: true);
    await jar.saveFromResponse(Uri.parse('https://u.y.qq.com'), [
      Cookie('uin', '123'), Cookie('qm_keyst', 'test-key'),
    ]);
    // 匿名请求留下的普通 Cookie 不应阻止补齐登录 Cookie。
    await jar.saveFromResponse(Uri.parse('https://c.y.qq.com'), [Cookie('guest', 'test')]);
    dio.dioWithCookieManager.interceptors.add(CookieManager(jar));
    final requests = <RequestOptions>[];
    dio.dioWithCookieManager.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: {
        'code': 0, 'data': {'cdlist': []},
      }));
    }));
    expect(await provider.getUserFavoritePlaylist('123'), isEmpty);
    final request = requests.single;
    expect(request.uri.host, 'c.y.qq.com');
    expect(request.uri.queryParameters['userid'], '123');
    final header = request.headers[HttpHeaders.cookieHeader] as String;
    expect(header, contains('uin=123'));
    expect(header, contains('qm_keyst=test-key'));
    expect(header, contains('guest=test'));
    final diskCookies = await PersistCookieJar(
      storage: FileStorage(cookiePath(directory)), ignoreExpires: true,
    ).loadForRequest(request.uri);
    expect(diskCookies.map((cookie) => cookie.name), containsAll(['uin', 'qm_keyst']));
    expect(settings.saves, 0);
    expect(dio.reloads, 0);
    await provider.dioGetWithCookieAndCsrf('https://outside.example.test/path');
    expect(requests.last.headers[HttpHeaders.cookieHeader], isNull);
  });

  test('QQ token saving and logout cover both API domains', () async {
    final provider = QQ();
    await provider.saveToken('uin=123; qm_keyst=test-key', refreshUser: false);
    for (final host in ['u.y.qq.com', 'c.y.qq.com']) {
      final cookies = await PersistCookieJar(
        storage: FileStorage(cookiePath(directory)), ignoreExpires: true,
      ).loadForRequest(Uri.parse('https://$host'));
      expect(cookies.map((cookie) => cookie.name), containsAll(['uin', 'qm_keyst']));
    }
    await provider.logout();
    for (final host in ['u.y.qq.com', 'c.y.qq.com']) {
      final cookies = await PersistCookieJar(
        storage: FileStorage(cookiePath(directory)), ignoreExpires: true,
      ).loadForRequest(Uri.parse('https://$host'));
      expect(cookies, isEmpty);
    }
  });

  test('simultaneous playlist user queries share one request and an old response cannot undo logout', () async {
    final provider = _Provider('concurrent');
    settings.settings[provider.credentialKey] = 'sid=old';
    final result = Completer<ProviderUser?>();
    provider.query = () => result.future;
    final first = provider.getUser();
    final second = provider.getUser();
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(provider.queries, 1);
    await provider.logout();
    result.complete(ProviderUser(platform: provider.name, userId: 'old', name: 'old'));
    expect(await first, isNull);
    expect(await second, isNull);
    expect(provider.currentUser.value, isNull);
    expect(provider.loginStatus.value, LoginStatus.noLogin);
  });

  test('consecutive imports persist the newest cookie and batching defers settings save', () async {
    final provider = _Provider('ordered');
    final first = provider.saveToken('sid=first', saveRightNow: false);
    final second = provider.saveToken('sid=second', saveRightNow: false);
    await Future.wait([first, second]);
    expect(settings.saves, 0);
    expect(provider.token, 'sid=second');
    expect((await storedCookies(provider)).single.value, 'second');
    expect(provider.currentUser.value?.userId, 'sid=second');
  });

  testWidgets('Bilibili login owns focus and text controller through the closing animation', (tester) async {
    final provider = Bilibili();
    final initialHotKeys = enable_inapp_hotkey;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => provider.login(context),
          child: const Text('open login'),
        ),
      )),
    ));
    await tester.tap(find.text('open login'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(enable_inapp_hotkey, isFalse);
    Navigator.of(tester.element(find.byType(TextField))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(enable_inapp_hotkey, initialHotKeys);
    expect(tester.takeException(), isNull);
  });

  test('missing NetEase csrf is not a request failure and success clears a previous error', () async {
    final netease = Netease();
    settings.settings[netease.credentialKey] = 'unrelated=value';
    expect(await netease.getUser(), isNull);
    expect(netease.loginStatus.value, LoginStatus.noLogin);
    final provider = _Provider('retry');
    settings.settings[provider.credentialKey] = 'sid=test';
    provider.query = () async => throw StateError('offline');
    expect(await provider.getUser(), isNull);
    expect(provider.loginStatus.value, LoginStatus.failed);
    expect(provider.loginError.value, isNotEmpty);
    provider.query = null;
    expect(await provider.getUser(), isNotNull);
    expect(provider.loginStatus.value, LoginStatus.loggedIn);
    expect(provider.loginError.value, isEmpty);
  });
}
