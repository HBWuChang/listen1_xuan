import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:marquee/marquee.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:listen1_xuan/controllers/DioController.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/global_settings_animations.dart';
import 'package:listen1_xuan/utils/platform_credentials.dart';
import 'package:listen1_xuan/widgets/ext/ext_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/settings_controller.dart';
import 'package:listen1_xuan/models/PlayListFilter.dart';
import 'package:listen1_xuan/models/PlayListFilters.dart';
import 'package:listen1_xuan/models/Playlist.dart';
import 'package:listen1_xuan/models/ProviderUser.dart';
import 'package:listen1_xuan/models/SearchPlayListRes.dart';
import 'package:listen1_xuan/models/SearchRes.dart';
import 'package:listen1_xuan/models/bootStrapTrackRes.dart';

import '../models/Track.dart';

enum SearchType { song, album, dj }

enum LoginStatus { noLogin, processing, loggedIn, failed }

enum PlaylistFiltersLoadingStatus { notLoaded, empty, loading, loaded, failed }

abstract class BaseProvider extends GetxService {
  String get id;
  String get name;
  String get shortDisplayName => name;
  bool get searchable;
  bool get supportLogin;
  bool get hidden => false;
  bool get supportLyric;
  bool get isLocal => false;
  bool get isFirstOnH => false;
  bool get isFirstOnV => false;
  bool get supportShowPlaylist => false;

  /// 是否支持在“我的歌单”页展示“我创建的歌单”
  bool get supportGetUserCreatedPlaylist => false;

  /// 是否支持在“我的歌单”页展示“我收藏的歌单”
  bool get supportGetUserFavoritePlaylist => false;

  /// “我的歌单”页中该平台“我创建的歌单”分组的标题
  String get userCreatedPlaylistSectionTitle => '我创建的$shortDisplayName歌单';

  /// “我的歌单”页中该平台“我创建的歌单”分组标题左侧的图标
  Widget get userCreatedPlaylistSectionLeading =>
      const Icon(Icons.library_music, size: 18);

  /// “我的歌单”页中该平台“我收藏的歌单”分组的标题
  String get userFavoritePlaylistSectionTitle => '我收藏的$shortDisplayName歌单';

  /// “我的歌单”页中该平台“我收藏的歌单”分组标题左侧的图标
  Widget get userFavoritePlaylistSectionLeading =>
      const Icon(Icons.star, size: 18);

  ///为了未来适配纯音源
  List<String> get supportProcessIds => [id];

  /// 搜索接口
  /// 应返回一个 Future，Future 的结果类型应为 SearchRes 或 SearchPlayListRes
  /// curpage 为当前页码，从 1 开始
  /// 该方法不应抛出异常，而是应返回一个包含错误信息的 SearchRes 或 SearchPlayListRes 对象
  Future<dynamic>? search(String keywords, int curpage, SearchType type) =>
      null;
  Future<SearchRes>? searchSong(String keywords, int curpage) {
    return search(
      keywords,
      curpage,
      SearchType.song,
    )?.then((res) => res as SearchRes);
  }

  Future<SearchPlayListRes>? searchPlaylist(
    String keywords,
    int curpage,
    SearchType type,
  ) {
    assert(type != SearchType.song, 'Invalid search type: $type');
    return search(
      keywords,
      curpage,
      type,
    )?.then((res) => res as SearchPlayListRes);
  }

  Future<List<PlayList>>? getRecommendPlaylist() => null;

  /// 获取歌单详情
  Future<PlayList>? getPlaylist(String listId) => null;

  /// 获取热门歌单分类
  Future<PlayListFilters>? getPlaylistFilters() => null;
  Rx<PlayListFilter> nowSelectedPlaylistFilter =
      PlayListFilter.defaultValues().obs;
  Rx<PlayListFilters> playlistFilters = PlayListFilters(
    filters: [],
    recommended: [],
  ).obs;
  Rx<PlaylistFiltersLoadingStatus> playlistFiltersLoadingStatus =
      PlaylistFiltersLoadingStatus.notLoaded.obs;

  /// 获取热门歌单列表
  Future<List<PlayList>>? showPlaylist({int? offset, dynamic filterId}) => null;

  Future<List<PlayList>>? getUserFavoritePlaylist(String userId) => null;
  Future<List<PlayList>>? getUserCreatedPlaylist(String userId) => null;

  Future<(String lyric, String? tlyric)>? lyric(Track track) => null;

  /// 获取歌曲播放地址
  Future<void> bootStrapTrack(
    Track track,
    Function(BootSuccessRes res, Track track) success,
    Function(Track track, Object? error) failure,
  );

  SettingsController get settingsController => Get.find<SettingsController>();

  /// 凭据键兼容现有设置与传输协议，不一定等于歌曲 ID 前缀。
  String get credentialKey => id;
  String get loginDisplayName => shortDisplayName;
  String get loginButtonText => '登录$loginDisplayName';
  Widget get loginIcon => const Icon(Icons.account_circle, size: 18);
  List<String> get cookieUrls => const [];
  String get token => settingsController.settings[credentialKey] as String? ?? '';

  final Rx<LoginStatus> loginStatus = LoginStatus.noLogin.obs;
  final RxString loginError = ''.obs;
  final Rxn<ProviderUser> currentUser = Rxn<ProviderUser>();
  int _userRequestVersion = 0;
  Future<ProviderUser?>? _userRequest;
  Future<void> _credentialWrite = Future<void>.value();

  Future<void> login(BuildContext context) async {}

  /// 平台只负责查询；统一维护用户与状态，避免旧请求覆盖新凭据的状态。
  Future<ProviderUser?> fetchUser() async => null;

  Future<ProviderUser?> getUser() {
    if (_userRequest != null) return _userRequest!;
    final request = _loadUser();
    _userRequest = request;
    request.whenComplete(() {
      if (identical(_userRequest, request)) _userRequest = null;
    });
    return request;
  }

  Future<ProviderUser?> _loadUser() async {
    final version = _userRequestVersion;
    await _credentialWrite;
    if (version != _userRequestVersion) return null;
    loginError.value = '';
    try {
      if (!supportLogin || token.isEmpty) {
        currentUser.value = null;
        loginStatus.value = LoginStatus.noLogin;
        return null;
      }
      loginStatus.value = LoginStatus.processing;
      final user = await fetchUser();
      if (version != _userRequestVersion) return null;
      currentUser.value = user;
      loginStatus.value = user == null ? LoginStatus.noLogin : LoginStatus.loggedIn;
      return user;
    } catch (e) {
      if (version != _userRequestVersion) return null;
      currentUser.value = null;
      loginError.value = e.toString();
      loginStatus.value = LoginStatus.failed;
      return null;
    }
  }

  Future<void> saveToken(
    dynamic credentials, {
    bool saveRightNow = true,
    bool refreshUser = true,
  }) {
    final value = PlatformCredentials(platform: credentialKey, credentials: credentials);
    ++_userRequestVersion;
    _userRequest = null;
    currentUser.value = null;
    loginError.value = '';
    loginStatus.value = LoginStatus.processing;
    // 输入框连续写入及远端导入按顺序落盘，避免旧 Cookie 最后覆盖新值。
    final write = _credentialWrite.then((_) async {
      settingsController.settings[credentialKey] = value.token;
      if (saveRightNow) await settingsController.saveSettings();
      for (final url in cookieUrls) {
        await setSaveCookie(url: url, cookies: value.prcdCookies);
      }
      await Get.find<DioController>().reloadCookie();
    });
    _credentialWrite = write.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
    final latestWrite = _credentialWrite;
    return () async {
      try {
        await write;
        if (!identical(_credentialWrite, latestWrite)) return;
      } catch (e) {
        if (identical(_credentialWrite, latestWrite)) {
          loginError.value = e.toString();
          loginStatus.value = LoginStatus.failed;
        }
        rethrow;
      }
      if (refreshUser) {
        await getUser();
      } else {
        loginStatus.value = LoginStatus.noLogin;
      }
    }();
  }

  Future<void> logout() => saveToken('');

  Future<void> openWebLogin(
    BuildContext context, {
    required String url,
    bool enableZoom = false,
  }) async {
    dynamic controller;
    if (isWindows) {
      controller = WebviewController();
    } else {
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (String url) async {
            await controller.runJavaScript('''
              (function() {
                var meta = document.createElement('meta');
                meta.name = 'viewport';
                meta.content = 'width=device-width, initial-scale=0.5, maximum-scale=3.0, user-scalable=yes';
                document.getElementsByTagName('head')[0].appendChild(meta);
                document.body.style.minWidth = '100vw';
                document.body.style.minHeight = '100vh';
              })();
            ''');
          },
        ))
        ..setUserAgent(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3',
        )
        ..loadRequest(Uri.parse(url));
      if (enableZoom) controller.enableZoom(true);
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LoginWebview(controller: controller, provider: this, open_url: url),
    ));
  }

  @override
  void onReady() {
    super.onReady();
    reloadPlaylistFilters();
  }

  Future<void> reloadPlaylistFilters({bool force = false}) async {
    if (!force &&
        playlistFiltersLoadingStatus.value ==
            PlaylistFiltersLoadingStatus.loaded) {
      return;
    }
    playlistFiltersLoadingStatus.value = PlaylistFiltersLoadingStatus.loading;
    try {
      final filters = await getPlaylistFilters();
      if (filters != null) {
        playlistFilters.value = filters;
        playlistFiltersLoadingStatus.value =
            PlaylistFiltersLoadingStatus.loaded;
      } else {
        playlistFiltersLoadingStatus.value = PlaylistFiltersLoadingStatus.empty;
      }
    } catch (e) {
      playlistFiltersLoadingStatus.value = PlaylistFiltersLoadingStatus.failed;
    }
  }
}

class LoginWebview extends StatefulWidget {
  final dynamic controller;
  final BaseProvider? provider;
  final Future<void> Function(String? url)? onSave;
  final String open_url;
  const LoginWebview({
    super.key,
    required this.controller,
    this.provider,
    this.onSave,
    required this.open_url,
  }) : assert((provider == null) != (onSave == null));
  @override
  _LoginWebviewState createState() => _LoginWebviewState();
}

class _LoginWebviewState extends State<LoginWebview> {
  final List<StreamSubscription> _subscriptions = [];
  String? nowurl;
  Future<void> get__cookie() async {
    if (widget.onSave != null) {
      final url = isWindows ? nowurl : await widget.controller.currentUrl();
      await widget.onSave!(url);
      return;
    }
    final List<Cookie> cookies;
    if (isWindows) {
      final data = jsonDecode(await widget.controller.getCookies())['cookies'];
      cookies = (data as List).map((item) => Cookie(
        item['name'] as String,
        Uri.encodeComponent(item['value'] as String),
      )).toList();
    } else {
      cookies = await WebviewCookieManager().getCookies(widget.open_url);
    }
    await widget.provider!.saveToken(cookies);
    showSuccessSnackbar('设置成功', null);
  }

  @override
  void initState() {
    super.initState();
    if (isWindows) initPlatformState();
  }

  Future<void> initPlatformState() async {
    try {
      await widget.controller.initialize();
      _subscriptions.add(
        widget.controller.url.listen((url) {
          nowurl = url;
        }),
      );
      await widget.controller.setBackgroundColor(Colors.transparent);
      await widget.controller.setPopupWindowPolicy(
        WebviewPopupWindowPolicy.deny,
      );
      await widget.controller.loadUrl(widget.open_url);

      if (!mounted) return;
      setState(() {});
    } on PlatformException catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Error'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Code: ${e.code}'),
                Text('Message: ${e.message}'),
              ],
            ),
            actions: [
              TextButton(
                child: Text('Continue'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      });
    }
  }

  Widget compositeView() {
    if (!widget.controller.value.isInitialized) {
      return const Text(
        'Not Initialized',
        style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w900),
      );
    } else {
      return Card(
        color: Colors.transparent,
        elevation: 0,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: Stack(
          children: [
            Webview(
              widget.controller,
              permissionRequested: _onPermissionRequested,
            ),
            StreamBuilder<LoadingState>(
              stream: widget.controller.loadingState,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data == LoadingState.loading) {
                  return LinearProgressIndicator();
                } else {
                  return SizedBox();
                }
              },
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _subscriptions.forEach((s) => s.cancel());
    if (isWindows) widget.controller.dispose();
    super.dispose();
  }

  Future<WebviewPermissionDecision> _onPermissionRequested(
    String url,
    WebviewPermissionKind kind,
    bool isUserInitiated,
  ) async {
    final decision = await showDialog<WebviewPermissionDecision>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('WebView permission requested'),
        content: Text('WebView has requested permission \'$kind\''),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.deny),
            child: const Text('Deny'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.allow),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    return decision ?? WebviewPermissionDecision.none;
  }

  final _saving = false.obs;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: const Text('请登录后，点击右上角保存cooke按钮'),
        title: Marquee(
          text: '请登录后，点击右上角保存cookie按钮',
          style: const TextStyle(fontSize: 20),
          scrollAxis: Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.start,
          blankSpace: 20.0,
          velocity: 100.0,
          pauseAfterRound: const Duration(seconds: 1),
          startPadding: 10.0,
          accelerationDuration: const Duration(seconds: 1),
          accelerationCurve: Curves.linear,
          decelerationDuration: const Duration(milliseconds: 500),
          decelerationCurve: Curves.easeOut,
        ).sbh(30),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        actions: [
          Obx(
            () => IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saving.value
                  ? null
                  : () async {
                      _saving.value = true;
                      try {
                        await get__cookie();
                      } catch (e) {
                        showErrorSnackbar('保存登录信息失败', '$e');
                      } finally {
                        _saving.value = false;
                      }
                    },
            ),
          ),
        ],
      ),
      body: isWindows
          ? compositeView()
          : WebViewWidget(controller: widget.controller),
    );
  }
}
