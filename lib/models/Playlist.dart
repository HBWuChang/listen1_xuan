import 'PlayListInfo.dart';
import 'Track.dart';

class PlayList {
  PlayListInfo info;
  int is_mine;
  int is_fav;
  List<Track>? tracks;
  PlayList({
    required this.info,
    this.is_mine = 0,
    this.is_fav = 0,
    this.tracks,
  });
  factory PlayList.fromJson(Map<String, dynamic> json) {
    var tracks = json['tracks'];
    if (tracks is List) {
      if (tracks.isNotEmpty) {
        if (tracks[0] is Map<String, dynamic>) {
          tracks = tracks.map((track) => Track.fromJson(track)).toList();
        } else if (tracks[0] is Track) {
          // If already a list of Track objects, no conversion needed
        } else {
          throw Exception('Invalid track data format');
        }
      }
    }
    tracks = tracks != null ? List<Track>.from(tracks) : null;
    return PlayList(
      info: PlayListInfo.fromJson(json['info']),
      is_mine: json['is_mine'] as int? ?? 0,
      is_fav: json['is_fav'] as int? ?? 0,
      tracks: tracks,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'info': info.toJson(),
      'is_mine': is_mine,
      'is_fav': is_fav,
      'tracks': tracks?.map((track) => track.toJson()).toList(),
    };
  }
}