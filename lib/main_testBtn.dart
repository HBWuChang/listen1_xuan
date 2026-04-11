part of 'main.dart';

RxInt testCount = 0.obs;

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
              onPressed: () {
                testCount.value++;
                if (testCount.value > 20) {
                  testCount.value = 0;
                }
              },
              child: Obx(
                () => AnimatedDigitWidget(
                  value: testCount.value,
                  enableMinIntegerDigits: true,
                  fractionDigits: 0,
                  textStyle: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
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
