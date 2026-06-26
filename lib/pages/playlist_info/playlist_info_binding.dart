import 'package:get/get.dart';
import 'playlist_info_args.dart';
import 'playlist_info_controller.dart';

class PlaylistInfoBinding extends Bindings {
  final PlaylistInfoArgs args;

  PlaylistInfoBinding({required this.args});

  @override
  void dependencies() {
    Get.put<PlaylistInfoController>(
      PlaylistInfoController(args),
      tag: args.controllerTag,
    );
  }
}
