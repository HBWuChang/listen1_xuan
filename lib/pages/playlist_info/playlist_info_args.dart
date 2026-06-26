import 'package:listen1_xuan/models/PlayListInfo.dart';
import 'package:listen1_xuan/router/base_args.dart';

class PlaylistInfoArgs extends BaseArgs {
  final PlayListInfo playListInfo;
  String get listId => playListInfo.id;
  final bool isMy;

  PlaylistInfoArgs({required this.playListInfo, this.isMy = false});

  @override
  String get path => listId;
  @override
  String get controllerTag => 'playlist_info_$listId';
}
