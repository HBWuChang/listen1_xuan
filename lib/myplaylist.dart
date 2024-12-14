import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'lowebutil.dart';
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

  // Future<void> show_myplaylist(String playlistType) async {
  Future<Map<String, dynamic>> showMyPlaylist(String playlistType) async {
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
    final result = playlists.map((id) {
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
    }).where((playlist) => playlist != null).toList();
    // fn({'result': result});
    return {'result': result};
  }

  Future<void> getMyPlaylist(String url, Function fn) async {
    final listId = getParameterByName('list_id', url);
    final prefs = await SharedPreferences.getInstance();
    final playlistJson = listId != null ? prefs.getString(listId) : null;
    if (playlistJson != null) {
      final playlist = jsonDecode(playlistJson);
      if (playlist['tracks'] != null) {
        for (var track in playlist['tracks']) {
          track.remove('url');
          track['disabled'] = false;
        }
      }
      fn(playlist);
    } else {
      fn(null);
    }
  }

  String guid() {
    String s4() {
      return (10000 + (10000 * (1 + (new DateTime.now().millisecondsSinceEpoch % 10000)))).toString().substring(1);
    }
    return '${s4()}${s4()}-${s4()}-${s4()}-${s4()}-${s4()}${s4()}${s4()}';
  }

  Future<List<String>> insertMyPlaylistToMyPlaylists(
      String playlistType, String playlistId, String toPlaylistId, String direction) async {
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

  Future<void> saveMyPlaylist(String playlistType, Map<String, dynamic> playlistObj) async {
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

  Future<Map<String, dynamic>?> addTrackToMyPlaylist(String playlistId, dynamic track) async {
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

  Future<Map<String, dynamic>?> insertTrackToMyPlaylist(
      String playlistId, dynamic track, dynamic toTrack, String direction) async {
    final prefs = await SharedPreferences.getInstance();
    final playlistJson = prefs.getString(playlistId);
    if (playlistJson == null) {
      return null;
    }
    final playlist = jsonDecode(playlistJson);
    final index = playlist['tracks'].indexWhere((i) => i['id'] == track['id']);
    int insertIndex = playlist['tracks'].indexWhere((i) => i['id'] == toTrack['id']);
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

  Future<void> removeTrackFromMyPlaylist(String playlistId, String trackId) async {
    final prefs = await SharedPreferences.getInstance();
    final playlistJson = prefs.getString(playlistId);
    if (playlistJson == null) {
      return;
    }
    final playlist = jsonDecode(playlistJson);
    playlist['tracks'] = playlist['tracks'].where((item) => item['id'] != trackId).toList();
    prefs.setString(playlistId, jsonEncode(playlist));
  }

  Future<void> createMyPlaylist(String playlistTitle, dynamic track) async {
    final playlist = {
      'is_mine': 1,
      'info': {
        'cover_img_url': 'images/mycover.jpg',
        'title': playlistTitle,
        'id': '',
        'source_url': '',
      },
      'tracks': track is List ? track : [track],
    };
    await saveMyPlaylist('my', playlist);
  }

  Future<void> editMyPlaylist(String playlistId, String title, String coverImgUrl) async {
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