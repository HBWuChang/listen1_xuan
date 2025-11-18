part of '../../settings.dart';

Widget settingsWidget(BuildContext context) {
  return Padding(
    padding: EdgeInsets.all(10),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => outputAllSettingsToFile(false),
                icon: Icon(Icons.save),
                label: Text('保存配置到文件'),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => importSettingsFromFile(),
                icon: Icon(Icons.upload),
                label: Text('导入配置文件'),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: outputPlaylistToGithubGist,
                icon: Icon(Icons.playlist_play),
                label: Text('导出歌单到Github Gist'),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (Github.status != 2) {
                    // _msg('请先登录Github', 1.0);
                    showWarningSnackbar('请先登录Github Gist', null);
                    return;
                  }
                  var playlists = await Github.listExistBackup();
                  print(playlists);

                  try {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('从Github Gist导入歌单'),
                          content: Container(
                            width: double.maxFinite,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: playlists.length,
                              itemBuilder: (BuildContext context, int index) {
                                final playlist = playlists[index];
                                return ListTile(
                                  title: Text(playlist['id']),
                                  subtitle: Text(playlist['description']),
                                  onTap: () async {
                                    try {
                                      // showInfoSnackbar('正在导入', null);
                                      final msg =
                                          '正在导入歌单 ${playlist['id']}\n正在从Github Gist获取配置文件'
                                              .obs;
                                      showLoadingDialog(msg);
                                      final jsfile =
                                          await Github.importMySettingsFromGist(
                                            playlist['id'],
                                          );
                                      msg.value =
                                          '正在导入歌单 ${playlist['id']}\n解析配置文件';
                                      final settings = await Github.gist2json(
                                        jsfile,
                                      );
                                      msg.value =
                                          '正在导入歌单 ${playlist['id']}\n应用配置文件';
                                      await importSettingsFromFile(
                                        true,
                                        settings,
                                      );
                                      Get.back();
                                      Navigator.of(context).pop();
                                      showSuccessSnackbar('导入成功', null);
                                    } catch (e) {
                                      showErrorSnackbar('导入失败', e.toString());
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('取消'),
                            ),
                          ],
                        );
                      },
                    );
                  } catch (e) {
                    showErrorSnackbar('添加失败', e.toString());
                  }
                },

                icon: Icon(Icons.playlist_add),
                label: Text('从Github Gist导入歌单'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
