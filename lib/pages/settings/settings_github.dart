part of '../../settings.dart';

class Github {
  static const String OAUTH_URL = 'https://github.com/login/oauth';
  static const String API_URL = 'https://api.github.com';

  static const String clientId = 'e099a4803bb1e2e773a3';
  static const String clientSecret = '81fbfc45c65af8c0fbf2b4dae6f23f22e656cfb8';

  static int status = 0;
  static String username = '';
  static bool usedefault = false;

  static Future<void> handleCallback(
    String code, {
    VoidCallback? onCompleted,
  }) async {
    // _msg('正在向Github请求信息', context, 1.0);
    showInfoSnackbar('正在向Github请求信息', '');
    String res = "";
    try {
      final url = '$OAUTH_URL/access_token';
      final params = {
        'client_id': clientId,
        'client_secret': clientSecret,
        'code': code,
      };
      var response;
      try {
        // throw Exception('使用代理适配器请求失败，尝试使用默认Dio请求');
        response = await dioWithProxyAdapter.post(
          url,
          queryParameters: params,
          options: Options(headers: {'Accept': 'application/json'}),
        );
        res = response.data.toString();
      } catch (e) {
        // _msg('代理适配请求失败,尝试使用默认Dio请求...', context, 1.0);
        showInfoSnackbar('代理适配请求失败,尝试使用默认Dio请求...', null);
        response = await Dio().post(
          url,
          queryParameters: params,
          options: Options(headers: {'Accept': 'application/json'}),
        );
        res = response.data.toString();
      }
      final accessToken = response.data['access_token'];
      final s = Get.find<SettingsController>();

      await s.setString('githubOauthAccessKey', accessToken);

      showInfoSnackbar('设置成功', null);
      onCompleted?.call();
    } catch (e) {
      Clipboard.setData(ClipboardData(text: e.toString() + res));
      showInfoSnackbar('设置失败，错误信息已复制到剪切板$e\n网络请求返回值：$res', null);
    }
  }

  static void openAuthUrl() {
    status = 1;
    final url =
        '$OAUTH_URL/authorize?client_id=$clientId&scope=gist,public_repo';
    Get.dialog(GithubAuthDialog(url: url));
  }

  static int getStatus() => status;

  static String getStatusText() {
    switch (status) {
      case 0:
        return '未连接';
      case 1:
        return '连接中';
      case 2:
        return '$username已登录';
      default:
        return '???';
    }
  }

  static Future<int> updateStatus() async {
    // final accessToken = localStorage.getItem('githubOauthAccessKey');
    // final accessToken = null; // Replace with actual access token retrieval
    final s = Get.find<SettingsController>();

    final accessToken = await s.getString('githubOauthAccessKey');
    if (accessToken == null) {
      status = 0;
    } else {
      var response;
      try {
        response = await dioWithProxyAdapter.get(
          '$API_URL/user',
          options: Options(
            headers: {
              'Authorization': 'token $accessToken',
              'Accept': 'application/json',
            },
          ),
        );
      } catch (e) {
        usedefault = true;
        try {
          response = await Dio().get(
            '$API_URL/user',
            options: Options(
              headers: {
                'Authorization': 'token $accessToken',
                'Accept': 'application/json',
              },
            ),
          );
        } catch (e) {
          status = 0;
          return status;
        }
      }

      final data = response.data;
      if (data['login'] == null) {
        status = 1;
      } else {
        status = 2;
        username = data['login'];
      }
    }
    return status;
  }

  static void logout() {
    // localStorage.removeItem('githubOauthAccessKey');
    status = 0;
  }

  static Map<String, dynamic> json2gist(Map<String, dynamic> jsonObject) {
    final result = <String, dynamic>{};

    result['listen1_backup.json'] = {'content': json.encode(jsonObject)};

    final playlistIds = jsonObject['playerlists'];
    final songsCount = playlistIds.fold<int>(0, (count, playlistId) {
      final playlist = jsonObject[playlistId];
      final cover =
          '<img src="${playlist['info']['cover_img_url']}" width="140" height="140"><br/>';
      final title = playlist['info']['title'];
      var tableHeader = '\n| 音乐标题 | 歌手 | 专辑 |\n';
      tableHeader += '| --- | --- | --- |\n';
      final tableBody = playlist['tracks'].fold<String>('', (r, track) {
        return '$r | ${track['title']} | ${track['artist']} | ${track['album']} | \n';
      });
      final content =
          '<details>\n  <summary>$cover   $title</summary><p>\n$tableHeader$tableBody</p></details>';
      final filename = 'listen1_$playlistId.md';
      result[filename] = {'content': content};
      return (count as int) + (playlist['tracks'].length as int);
    });
    final summary =
        '本歌单由[listen1_xuan](https://github.com/HBWuChang/listen1_xuan)创建, 歌曲数：$songsCount，歌单数：${playlistIds.length}，点击查看更多';
    result['listen1_aha_playlist.md'] = {'content': summary};

    return result;
  }

  static Future<Map<String, dynamic>> gist2json(
    Map<String, dynamic> gistFiles,
  ) async {
    if (!gistFiles['listen1_backup.json']['truncated']) {
      final jsonString = gistFiles['listen1_backup.json']['content'];
      return json.decode(jsonString);
    } else {
      final url = gistFiles['listen1_backup.json']['raw_url'];
      final s = Get.find<SettingsController>();
      final accessToken = await s.getString('githubOauthAccessKey');
      final response = await (usedefault ? Dio() : dioWithProxyAdapter).get(
        url.replaceAll('https://', 'https://h3.040905.xyz/default/https/'),
        options: Options(
          headers: {
            'Authorization': 'token $accessToken',
            'Accept': 'application/json',
          },
        ),
      );
      return json.decode(response.data);
    }
  }

  static Future<List<dynamic>> listExistBackup() async {
    final s = Get.find<SettingsController>();
    final accessToken = await s.getString('githubOauthAccessKey');
    final response = await (usedefault ? Dio() : dioWithProxyAdapter).get(
      '$API_URL/gists',
      options: Options(
        headers: {
          'Authorization': 'token $accessToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      ),
    );
    final result = response.data;
    return result.where((backupObject) {
      return backupObject['description'] != null &&
          backupObject['description'].startsWith('updated by Listen1');
    }).toList();
  }

  static Future<void> backupMySettings2Gist(
    Map<String, dynamic> files,
    String? gistId,
    bool isPublic,
  ) async {
    String method;
    String url;
    if (gistId != null) {
      method = 'patch';
      url = '$API_URL/gists/$gistId';
    } else {
      method = 'post';
      url = '$API_URL/gists';
    }
    final s = Get.find<SettingsController>();
    final accessToken = await s.getString('githubOauthAccessKey');
    await (usedefault ? Dio() : dioWithProxyAdapter).request(
      url,
      options: Options(
        method: method,
        headers: {
          'Authorization': 'token $accessToken',
          'Accept': 'application/json',
        },
      ),
      data: {
        'description':
            'updated by Listen1_xuan(https://github.com/HBWuChang/listen1_xuan) at ${DateTime.now().toLocal()}',
        'public': isPublic,
        'files': files,
      },
    );
  }

  static Future<Map<String, dynamic>> importMySettingsFromGist(
    String gistId,
  ) async {
    final s = Get.find<SettingsController>();
    final accessToken = await s.getString('githubOauthAccessKey');
    final response = await (usedefault ? Dio() : dioWithProxyAdapter).get(
      '$API_URL/gists/$gistId',
      options: Options(
        headers: {
          'Authorization': 'token $accessToken',
          'Accept': 'application/json',
        },
      ),
    );
    return response.data['files'];
  }

  static Future<String> getLatestReleaseVersionBuildNumber() async {
    final latestRelease = await getLatestRelease();
    final tagName = latestRelease.tagName;
    return tagName.split('+').last;
  }

  static Future<GitHubRelease> getLatestRelease() async {
    return (await getReleasesList()).first;
  }

  static Future<List<GitHubRelease>> getReleasesList() async {
    //   curl -L \
    // -H "Accept: application/vnd.github+json" \
    // -H "Authorization: Bearer <YOUR-TOKEN>" \
    // -H "X-GitHub-Api-Version: 2022-11-28" \
    // https://api.github.com/repos/OWNER/REPO/releases

    late Response response;
    try {
      response = await (usedefault ? Dio() : dioWithProxyAdapter).get(
        '$API_URL/repos/HBWuChang/listen1_xuan/releases',
        options: Options(
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        ),
      );
    } catch (e) {
      response = await Dio().get(
        '$API_URL/repos/HBWuChang/listen1_xuan/releases',
        options: Options(
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        ),
      );
    }
    List<dynamic> releasesData = response.data;
    List<GitHubRelease> releases = releasesData
        .map((releaseJson) => GitHubRelease.fromJson(releaseJson))
        .toList();
    return releases;
  }
}

/// Github 授权对话框
class GithubAuthDialog extends StatefulWidget {
  /// 授权页面地址
  final String url;

  const GithubAuthDialog({super.key, required this.url});

  @override
  State<GithubAuthDialog> createState() => _GithubAuthDialogState();
}

class _GithubAuthDialogState extends State<GithubAuthDialog> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submit(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.queryParameters['code'] == null) {
      showInfoSnackbar('无效的URL，请确保输入正确的授权网页地址', null);
      return;
    }
    Github.handleCallback(
      uri.queryParameters['code']!,
      onCompleted: () {
        Get.back();
        Get.find<SettingsController>().refreshLoginData();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Github授权'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SelectableText(
            '请打开授权网页，授权后将显示“Listen1 -> Github授权成功”字样的网页的地址复制到下面的输入框中。',
          ),
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: '网页地址',
              hintText: '请输入显示“Listen1 -> Github授权成功”字样的网页的地址',
            ),
            onSubmitted: _submit,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('取消')),
        TextButton(
          onPressed: () => g_launchURL(Uri.parse(widget.url)),
          child: const Text('打开授权网页'),
        ),
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: widget.url));
            showInfoSnackbar('已复制到剪切板', null);
          },
          child: const Text('复制授权网页地址'),
        ),
        TextButton(
          onPressed: () => _submit(_codeController.text),
          child: const Text('我已输入'),
        ),
      ],
    );
  }
}
