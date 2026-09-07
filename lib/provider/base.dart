import 'package:listen1_xuan/models/Playlist.dart';
import 'package:listen1_xuan/models/bootStrapTrackRes.dart';

import '../models/Track.dart';

enum SearchType { song, album, dj }

abstract class BaseProvider {
  String get id;
  String get name;
  String get shortDisplayName => name;
  bool get searchable;
  bool get supportLogin;
  bool get hidden => false;

  Future<dynamic>? search(String keywords, int curpage, SearchType type);
  Future<dynamic>? getPlaylist(String listId);
  Future<Map<String, dynamic>>? getPlaylistFilters();
  Future<List<PlayList>>? getUserFavoritePlaylist(String userId);
  Future<List<PlayList>>? getUserCreatedPlaylist(String userId);
  Future<void> bootStrapTrack(
    Track track,
    Function(BootSuccessRes res, Track track) success,
    Function(Track track) failure,
  );
}
