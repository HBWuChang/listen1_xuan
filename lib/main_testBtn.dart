part of 'main.dart';

Widget get testBtn => Positioned.fill(
  child: SafeArea(
    top: false,
    child: Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: globalHorizon ? 76 : 300.w,
          right: globalHorizon ? 16 : 40.w,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: 'toast_count_btn',
              onPressed: Get.find<XLyricController>().findBilibiliLyric,
              child: Icon(Icons.format_list_numbered),
            ),
            FloatingActionButton(
              onPressed: () async {
                Get.find<SettingsController>().getPlayLists().then((
                  playlists,
                ) async {
                  Set<String> keysToRemove = playlists.difference(
                    Get.find<MyPlayListController>().favoriteplayerlists.keys
                        .toSet(),
                  );
                  debugPrint(
                    Get.find<MyPlayListController>().favoriteplayerlists.keys
                        .toSet()
                        .toString(),
                  );
                  debugPrint(
                    Get.find<MyPlayListController>().favoriteplayerlists.keys
                        .toSet()
                        .length
                        .toString(),
                  );
                  debugPrint(playlists.toString());
                  debugPrint(playlists.length.toString());
                  debugPrint('keysToRemove: $keysToRemove');
                  debugPrint('keysToRemove length: ${keysToRemove.length}');
                  for (var key in keysToRemove) {
                    await Get.find<SettingsController>().remove(key: key);
                  }
                });
              },
              child: Icon(Icons.system_update_alt),
            ),
          ],
        ),
      ),
    ),
  ),
);
