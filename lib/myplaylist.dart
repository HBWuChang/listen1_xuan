import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'controllers/myPlaylist_controller.dart';
import 'controllers/play_controller.dart';
import 'lowebutil.dart';
import 'dart:math';
import 'global_settings_animations.dart';

class MyPlaylist {
  final MyPlayListController _myPlayListController =
      Get.find<MyPlayListController>();
  void arrayMove(List<dynamic> arr, int oldIndex, int newIndex) {
    if (newIndex >= arr.length) {
      int k = newIndex - arr.length + 1;
      while (k > 0) {
        k -= 1;
        arr.add(null);
      }
    }
    arr.insert(newIndex, arr.removeAt(oldIndex));
  }

  String getPlaylistObjectKey(String playlistType) {
    if (playlistType == 'my') {
      return 'playerlists';
    } else if (playlistType == 'favorite') {
      return 'favoriteplayerlists';
    }
    return '';
  }

  Future<void> Add_to_my_playlist(BuildContext context, List<Track> tracks,
      [String? title = "", String? cover_img_url = ""]) async {
    try {
      final playlists = show_myplaylist('my')['result'];
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('请选择要添加到的歌单'),
            content: Container(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (BuildContext context, int index) {
                  PlayList playlist = playlists[index];
                  return ListTile(
                    title: Text(playlist.info.title ?? ''),
                    onTap: () async {
                      final playlistId = playlist.info.id;
                      for (var track in tracks) {
                        await addTrackToMyPlaylist(playlistId, track);
                      }
                      Navigator.of(context).pop();
                      xuan_toast(
                        msg: '添加成功',
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('请输入歌单信息'),
                        content: Column(children: [
                          TextField(
                            controller: TextEditingController(text: title),
                            onChanged: (text) {
                              title = text;
                            },
                            decoration: InputDecoration(
                              labelText: '歌单标题',
                              // border: InputBorder.none,
                            ),
                          ),
                          TextField(
                              controller:
                                  TextEditingController(text: cover_img_url),
                              onChanged: (text) {
                                cover_img_url = text;
                              },
                              decoration: InputDecoration(
                                labelText: '封面图片链接',
                                // border: InputBorder.none,
                              )),
                        ]),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              if (title == '') {
                                return;
                              }
                              await createMyPlaylist(title!, tracks,
                                  cover_img_url ?? "images/mycover.jpg");
                              Navigator.of(context).pop();
                              Navigator.of(context).pop();
                              xuan_toast(
                                msg: '添加成功',
                              );
                            },
                            child: Text('确定'),
                          ),
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
                },
                child: Text('新建歌单'),
              ),
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
      try {
        My_playlist_loaddata(() {});
      } catch (e) {}
    } catch (e) {
      // print(e);
      xuan_toast(
        msg: '添加失败${e}',
      );
    }
  }

  Map<String, dynamic> show_myplaylist(String playlistType) {
    final key = getPlaylistObjectKey(playlistType);
    if (key == '') {
      // fn({'result': []});
      return {'result': []};
    }
    // final prefs = await SharedPreferences.getInstance();
    // List<String>? playlists = prefs.getStringList(key);
    // if (playlists == null) {
    //   playlists = [];
    // }
    // final result = playlists
    //     .map((id) {
    //       final playlistJson = prefs.getString(id);
    //       if (playlistJson != null) {
    //         final playlist = jsonDecode(playlistJson);
    //         if (playlist['tracks'] != null) {
    //           for (var track in playlist['tracks']) {
    //             track.remove('url');
    //           }
    //         }
    //         return playlist;
    //       }
    //       return null;
    //     })
    //     .where((playlist) => playlist != null)
    //     .toList();
    // return {'result': result};
    switch (key) {
      case 'playerlists':
        return {'result': _myPlayListController.playerlists.values.toList()};
      case 'favoriteplayerlists':
        return {
          'result': _myPlayListController.favoriteplayerlists.values.toList()
        };
      default:
        return {'result': []};
    }
  }

  Future<Map<String, dynamic>?> get_playlist(String url) async {
    final listId = getParameterByName('list_id', url);
    final playlist = _myPlayListController.playerlists[listId];
    return {
      "success": ((fn) {
        if (playlist != null) {
          fn(playlist.toJson());
          // return playlist;
        } else {
          fn(null);
          // return null;
        }
      })
    };
  }

  String guid() {
    String s4() {
      final random = Random();
      return (random.nextInt(9000) + 1000).toString(); // 生成 1000 到 9999 之间的随机数
    }

    return '${s4()}${s4()}-${s4()}-${s4()}-${s4()}-${s4()}${s4()}${s4()}';
  }

  void saveMyPlaylist(String playlistType, PlayList playlistObj) {
    final key = getPlaylistObjectKey(playlistType);
    if (key == '') {
      return;
    }
    String playlistId;
    if (playlistType == 'my') {
      playlistId = 'myplaylist_${guid()}';
      playlistObj.info.id = playlistId;
      playlistObj.is_mine = 1;
    } else if (playlistType == 'favorite') {
      playlistId = playlistObj.info.id;
      playlistObj.is_fav = 1;
      playlistObj.tracks = [];
    } else {
      return;
    }
    switch (key) {
      case 'playerlists':
        _myPlayListController.playerlists[playlistId] = playlistObj;
        break;
      case 'favoriteplayerlists':
        _myPlayListController.favoriteplayerlists[playlistId] = playlistObj;
        break;
      default:
        return;
    }
  }

  bool isMyfavPlaylist(String playlistId) {
    return _myPlayListController.favoriteplayerlists.containsKey(playlistId);
  }

  void removeMyPlaylist(String playlistType, String playlistId) {
    final key = getPlaylistObjectKey(playlistType);
    if (key == '') {
      return;
    }
    switch (key) {
      case 'playerlists':
        _myPlayListController.playerlists.remove(playlistId);
        break;
      case 'favoriteplayerlists':
        _myPlayListController.favoriteplayerlists.remove(playlistId);
        break;
      default:
        return;
    }
  }

  PlayList? addTrackToMyPlaylist(String playlistId, dynamic track) {
    final playlist = _myPlayListController.playerlists[playlistId];
    if (playlist == null) {
      return null;
    }
    if (playlist.tracks == null) {
      playlist.tracks = [];
    }
    if (!(track is List)) {
      track = [track];
    }
    track = List<Track>.from(track);
    Set<String> trackIds = playlist.tracks!.map((t) => t.id).toSet();
    track.removeWhere((t) => trackIds.contains(t.id));
    playlist.tracks!.insertAll(0, track as List<Track>);
    _myPlayListController.playerlists[playlistId] = playlist;
    return playlist;
  }

  PlayList? insertTrackToMyPlaylist(
      String playlistId, Track track, Track toTrack, String direction) {
    final playlist = _myPlayListController.playerlists[playlistId];
    if (playlist == null || playlist.tracks == null) {
      return null;
    }
    final index = playlist.tracks!.indexWhere((i) => i.id == track.id);
    int insertIndex = playlist.tracks!.indexWhere((i) => i.id == toTrack.id);
    if (index == -1 || insertIndex == -1 || index == insertIndex) {
      return playlist;
    }
    if (insertIndex > index) {
      insertIndex -= 1;
    }
    final offset = direction == 'top' ? 0 : 1;
    arrayMove(playlist.tracks!, index, insertIndex + offset);
    _myPlayListController.playerlists[playlistId] = playlist;
    return playlist;
  }

  bool removeTrackFromMyPlaylist(String playlistId, String trackId) {
    final playlist = _myPlayListController.playerlists[playlistId];
    if (playlist == null || playlist.tracks == null) {
      return false;
    }
    final initialLength = playlist.tracks!.length;
    playlist.tracks!.removeWhere((track) => track.id == trackId);
    _myPlayListController.playerlists[playlistId] = playlist;
    return playlist.tracks!.length < initialLength;
  }

  Future<void> createMyPlaylist(String playlistTitle, List<Track> tracks,
      [String cover_img_url = "images/mycover.jpg"]) async {
    // final playlist = {
    //   'is_mine': 1,
    //   'info': {
    //     'cover_img_url': cover_img_url,
    //     'title': playlistTitle,
    //     'id': '',
    //     'source_url': '',
    //   },
    //   'tracks': track is List ? track : [track],
    // };
    final playlist = PlayList(
      info: PlayListInfo(
        id: '',
        cover_img_url: cover_img_url,
        title: playlistTitle,
        source_url: '',
      ),
      is_mine: 1,
      tracks: tracks,
    );
    saveMyPlaylist('my', playlist);
  }

  bool editMyPlaylist(String playlistId, String title, String coverImgUrl) {
    final playlist = _myPlayListController.playerlists[playlistId];
    if (playlist == null) {
      return false;
    }
    playlist.info.title = title;
    playlist.info.cover_img_url = coverImgUrl;
    _myPlayListController.playerlists[playlistId] = playlist;
    return true;
  }

  bool myPlaylistContainers(String playlistType, String listId) {
    final key = getPlaylistObjectKey(playlistType);
    if (key == '') {
      return false;
    }
    switch (key) {
      case 'playerlists':
        return _myPlayListController.playerlists.containsKey(listId);
      case 'favoriteplayerlists':
        return _myPlayListController.favoriteplayerlists.containsKey(listId);
      default:
        return false;
    }
  }
}

final myplaylist = MyPlaylist();
