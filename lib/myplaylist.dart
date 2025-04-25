import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'lowebutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:math';

class MyPlaylist {
  Future<void> arrayMove(List<dynamic> arr, int oldIndex, int newIndex) async {
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

  Future<void> Add_to_my_playlist(
      BuildContext context, List<Map<String, dynamic>> tracks,
      [String? title = "", String? cover_img_url = ""]) async {
    try {
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('请选择要添加到的歌单'),
            content: FutureBuilder(
              future: show_myplaylist('my'),
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.hasData) {
                    final playlists = snapshot.data['result'];

                    return Container(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: playlists.length,
                        itemBuilder: (BuildContext context, int index) {
                          final playlist = playlists[index];
                          return ListTile(
                            title: Text(playlist['info']['title']),
                            onTap: () async {
                              final playlistId = playlist['info']['id'];
                              for (var track in tracks) {
                                await addTrackToMyPlaylist(playlistId, track);
                              }
                              Navigator.of(context).pop();
                              Fluttertoast.showToast(
                                msg: '添加成功',
                              );
                            },
                          );
                        },
                      ),
                    );
                  }
                }
                return Center(
                  child: CircularProgressIndicator(),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  showDialog(
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
                              Fluttertoast.showToast(
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
                  // Navigator.of(context).pop();
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
    } catch (e) {
      // print(e);
      Fluttertoast.showToast(
        msg: '添加失败${e}',
      );
    }
  }

  Future<Map<String, dynamic>> show_myplaylist(String playlistType) async {
    final key = getPlaylistObjectKey(playlistType);
    if (key == '') {
      // fn({'result': []});
      return {'result': []};
    }
    final prefs = await SharedPreferences.getInstance();
    List<String>? playlists = prefs.getStringList(key);
    if (playlists == null) {
      playlists = [];
    }
    final result = playlists
        .map((id) {
          final playlistJson = prefs.getString(id);
          if (playlistJson != null) {
            final playlist = jsonDecode(playlistJson);
            if (playlist['tracks'] != null) {
              for (var track in playlist['tracks']) {
                track.remove('url');
              }
            }
            return playlist;
          }
          return null;
        })
        .where((playlist) => playlist != null)
        .toList();
    return {'result': result};
  }

  Future<Map<String, dynamic>?> get_playlist(String url) async {
    final listId = getParameterByName('list_id', url);
    final prefs = await SharedPreferences.getInstance();
    final playlistJson = listId != null ? prefs.getString(listId) : null;
    return {
      "success": ((fn) {
        if (playlistJson != null) {
          final playlist = jsonDecode(playlistJson);
          if (playlist['tracks'] != null) {
            for (var track in playlist['tracks']) {
              track.remove('url');
              track['disabled'] = false;
            }
          }
          fn(playlist);
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

  Future<List<String>> insertMyPlaylistToMyPlaylists(String playlistType,
      String playlistId, String toPlaylistId, String direction) async {
    final key = getPlaylistObjectKey(playlistType);
    if (key == '') {
      return [];
    }
    final prefs = await SharedPreferences.getInstance();
    List<String>? playlists = prefs.getStringList(key);
    if (playlists == null) {
      return [];
    }
    final index = playlists.indexOf(playlistId);
    int insertIndex = playlists.indexOf(toPlaylistId);
    if (index == insertIndex) {
      return playlists;
    }
    if (insertIndex > index) {
      insertIndex -= 1;
    }
    final offset = direction == 'top' ? 0 : 1;
    await arrayMove(playlists, index, insertIndex + offset);
    prefs.setStringList(key, playlists);
    return playlists;
  }

  Future<void> saveMyPlaylist(
      String playlistType, Map<String, dynamic> playlistObj) async {
    final key = getPlaylistObjectKey(playlistType);
    if (key == '') {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    List<String>? playlists = prefs.getStringList(key);
    if (playlists == null) {
      playlists = [];
    }
    String playlistId;
    if (playlistType == 'my') {
      playlistId = 'myplaylist_${guid()}';
      playlistObj['info']['id'] = playlistId;
      playlistObj['is_mine'] = 1;
    } else if (playlistType == 'favorite') {
      playlistId = playlistObj['info']['id'];
      playlistObj['is_fav'] = 1;
      playlistObj.remove('tracks');
    } else {
      return;
    }
    playlists.add(playlistId);
    prefs.setStringList(key, playlists);
    prefs.setString(playlistId, jsonEncode(playlistObj));
  }

  Future<bool> isMyfavPlaylist(String playlistId) async {
    final prefs = await SharedPreferences.getInstance();
    final playlistJson = prefs.getStringList('favoriteplayerlists');
    if (playlistJson == null) {
      return false;
    }
    return playlistJson.contains(playlistId);
  }

  Future<void> removeMyPlaylist(String playlistType, String playlistId) async {
    final key = getPlaylistObjectKey(playlistType);
    if (key == '') {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    List<String>? playlists = prefs.getStringList(key);
    if (playlists == null) {
      return;
    }
    playlists.remove(playlistId);
    prefs.setStringList(key, playlists);
    prefs.remove(playlistId);
  }

  Future<Map<String, dynamic>?> addTrackToMyPlaylist(
      String playlistId, dynamic track) async {
    final prefs = await SharedPreferences.getInstance();
    final playlistJson = prefs.getString(playlistId);
    if (playlistJson == null) {
      return null;
    }
    final playlist = jsonDecode(playlistJson);
    if (playlist['tracks'] == null) {
      playlist['tracks'] = [];
    }
    if (track is List) {
      playlist['tracks'] = track + playlist['tracks'];
    } else {
      playlist['tracks'].insert(0, track);
    }
    final newTracks = [];
    final trackIds = [];
    for (var track in playlist['tracks']) {
      if (!trackIds.contains(track['id'])) {
        newTracks.add(track);
        trackIds.add(track['id']);
      }
    }
    playlist['tracks'] = newTracks;
    prefs.setString(playlistId, jsonEncode(playlist));
    return playlist;
  }

  Future<Map<String, dynamic>?> insertTrackToMyPlaylist(String playlistId,
      dynamic track, dynamic toTrack, String direction) async {
    final prefs = await SharedPreferences.getInstance();
    final playlistJson = prefs.getString(playlistId);
    if (playlistJson == null) {
      return null;
    }
    final playlist = jsonDecode(playlistJson);
    final index = playlist['tracks'].indexWhere((i) => i['id'] == track['id']);
    int insertIndex =
        playlist['tracks'].indexWhere((i) => i['id'] == toTrack['id']);
    if (index == insertIndex) {
      return playlist;
    }
    if (insertIndex > index) {
      insertIndex -= 1;
    }
    final offset = direction == 'top' ? 0 : 1;
    await arrayMove(playlist['tracks'], index, insertIndex + offset);
    prefs.setString(playlistId, jsonEncode(playlist));
    return playlist;
  }

  Future<void> removeTrackFromMyPlaylist(
      String playlistId, String trackId) async {
    final prefs = await SharedPreferences.getInstance();
    final playlistJson = prefs.getString(playlistId);
    if (playlistJson == null) {
      return;
    }
    final playlist = jsonDecode(playlistJson);
    playlist['tracks'] =
        playlist['tracks'].where((item) => item['id'] != trackId).toList();
    prefs.setString(playlistId, jsonEncode(playlist));
  }

  Future<void> createMyPlaylist(String playlistTitle, dynamic track,
      [String cover_img_url = "images/mycover.jpg"]) async {
    final playlist = {
      'is_mine': 1,
      'info': {
        'cover_img_url': cover_img_url,
        'title': playlistTitle,
        'id': '',
        'source_url': '',
      },
      'tracks': track is List ? track : [track],
    };
    await saveMyPlaylist('my', playlist);
  }

  Future<void> editMyPlaylist(
      String playlistId, String title, String coverImgUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final playlistJson = prefs.getString(playlistId);
    if (playlistJson == null) {
      return;
    }
    final playlist = jsonDecode(playlistJson);
    playlist['info']['title'] = title;
    playlist['info']['cover_img_url'] = coverImgUrl;
    prefs.setString(playlistId, jsonEncode(playlist));
  }

  Future<bool> myPlaylistContainers(String playlistType, String listId) async {
    final key = getPlaylistObjectKey(playlistType);
    if (key == '') {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final playlistJson = prefs.getString(listId);
    if (playlistJson == null) {
      return false;
    }
    final playlist = jsonDecode(playlistJson);
    return playlist['is_fav'] == true;
  }
}

final myplaylist = MyPlaylist();
