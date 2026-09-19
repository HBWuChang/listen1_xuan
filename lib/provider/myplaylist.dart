import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:listen1_xuan/controllers/myPlaylist_controller.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/models/PlayListInfo.dart';
import 'package:listen1_xuan/models/Playlist.dart';
import 'package:listen1_xuan/models/bootStrapTrackRes.dart';
import 'base.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:uuid/uuid.dart';

class MyPlaylist extends BaseProvider {
  @override
  String get id => "my";
  @override
  bool get searchable => false;
  @override
  bool get supportLogin => false;
  @override
  String get shortDisplayName => "我的";
  @override
  String get name => "myplaylist";
  @override
  bool get supportLyric => false;
  @override
  bool get isLocal => true;
  @override
  bool get isFirstOnV => true;
  @override
  bool get supportShowPlaylist => true;

  final MyPlayListController _myPlayListController =
      Get.put<MyPlayListController>(MyPlayListController(), permanent: true);
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

  Future<void> Add_to_my_playlist(
    dynamic context,
    List<Track> tracks, [
    String? title = "",
    String? cover_img_url = "",
  ]) async {
    try {
      final playlists = show_myplaylist('my');
      await Get.dialog(
        AlertDialog(
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
                    addTrackToMyPlaylist(playlistId, tracks);
                    Get.back();
                    showSuccessSnackbar('添加成功', null);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Get.dialog(
                  AlertDialog(
                    title: Text('请输入歌单信息'),
                    content: Column(
                      children: [
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
                          controller: TextEditingController(
                            text: cover_img_url,
                          ),
                          onChanged: (text) {
                            cover_img_url = text;
                          },
                          decoration: InputDecoration(
                            labelText: '封面图片链接',
                            // border: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          if (title == '') {
                            return;
                          }
                          await createMyPlaylist(
                            title!,
                            tracks,
                            cover_img_url ?? "images/mycover.jpg",
                          );
                          Get.back();
                          Get.back();
                          showSuccessSnackbar('添加成功', null);
                        },
                        child: Text('确定'),
                      ),
                      TextButton(
                        onPressed: () {
                          Get.back();
                        },
                        child: Text('取消'),
                      ),
                    ],
                  ),
                );
              },
              child: Text('新建歌单'),
            ),
            TextButton(
              onPressed: () {
                Get.back();
              },
              child: Text('取消'),
            ),
          ],
        ),
      );
    } catch (e) {
      // print(e);
      showErrorSnackbar('添加失败', e.toString());
    }
  }

  @override
  Future<List<PlayList>>? getUserFavoritePlaylist(String userId) async {
    final playlists = show_myplaylist('favorite');
    return playlists;
  }

  @override
  Future<List<PlayList>>? getUserCreatedPlaylist(String userId) async {
    final playlists = show_myplaylist('my');
    return playlists;
  }

  List<PlayList> show_myplaylist(String playlistType) {
    final key = getPlaylistObjectKey(playlistType);
    if (key == '') {
      // fn({'result': []});
      return [];
    }
    switch (key) {
      case 'playerlists':
        return _myPlayListController.playerlists.values.toList();
      case 'favoriteplayerlists':
        return _myPlayListController.favoriteplayerlists.values.toList();
      default:
        return [];
    }
  }

  @override
  Future<PlayList>? getPlaylist(String listId) {
    final playlist = _myPlayListController.playerlists[listId];
    if (playlist == null) {
      return null;
    }
    return Future.value(playlist);
  }

  String guid() {
    return Uuid().v4();
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
    String playlistId,
    Track track,
    Track toTrack,
    String direction,
  ) {
    final playlist = _myPlayListController.playerlists[playlistId];
    if (playlist == null || playlist.tracks == null) {
      return null;
    }
    final index = playlist.tracks!.indexWhere((i) => i.id == track.id);
    int insertIndex = playlist.tracks!.indexWhere((i) => i.id == toTrack.id);
    if (index == -1 || insertIndex == -1 || index == insertIndex) {
      return playlist;
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

  Future<void> createMyPlaylist(
    String playlistTitle,
    List<Track> tracks, [
    String cover_img_url = "images/mycover.jpg",
  ]) async {
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

  @override
  Future<void> bootStrapTrack(
    Track track,
    Function(BootSuccessRes res, Track track) success,
    Function(Track track, Object? error) failure,
  ) async {
    failure(track, UnsupportedError('不支持获取本地歌单歌曲的播放地址: ${track.id}'));
  }
}
