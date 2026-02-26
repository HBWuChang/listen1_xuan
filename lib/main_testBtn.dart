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
                try {
                  var box = await Hive.openBox(SettingsController.hiveStoreKey);
                  await box.put('testKey', 'testValue');
                  var value = box.get('testKey');
                  logger.i('Hive test value: $value');
                } catch (e) {
                  logger.e(e);
                }
              },
              child: Icon(Icons.system_update_alt),
            ),
          ],
        ),
      ),
    ),
  ),
);
