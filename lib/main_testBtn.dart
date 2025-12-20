part of 'main.dart';

Widget get testBtn => Positioned.fill(
  child: SafeArea(
    top: false,
    child: Align(
      alignment: Alignment.bottomRight,
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
              onPressed: Get.find<UpdController>().checkReleasesUpdate,
              child: Icon(Icons.format_list_numbered),
            ),
            FloatingActionButton(
              onPressed: () async {
                try {
                  logger.i(' ${UpdController.buildGitHash}');
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
