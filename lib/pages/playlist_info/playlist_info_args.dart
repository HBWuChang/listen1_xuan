import 'package:listen1_xuan/models/PlayListInfo.dart';
import 'package:listen1_xuan/router/base_args.dart';

class PlaylistInfoArgs extends BaseArgs {
  static int _nextControllerInstanceId = 0;

  final PlayListInfo playListInfo;
  String get listId => playListInfo.id;
  final bool isMy;

  @override
  final String controllerTag;

  PlaylistInfoArgs({required this.playListInfo, this.isMy = false})
    : controllerTag =
          'playlist_info_${playListInfo.id}_${_nextControllerInstanceId++}';

  @override
  String get path => listId;
}
