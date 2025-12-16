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
                  int gitLatestVersionBuildNumber = int.parse(
                    await Github.getLatestReleaseVersionBuildNumber(),
                  );
                  int localVersionBuildNumber = int.parse(
                    (await PackageInfo.fromPlatform()).buildNumber,
                  );
                  if (localVersionBuildNumber < gitLatestVersionBuildNumber) {
                    showInfoSnackbar(
                      '有新版本可用，最新版本buildNumber：$gitLatestVersionBuildNumber',
                      null,
                    );
                  }
                  logger.i('最新版本buildNumber：$gitLatestVersionBuildNumber');
                  logger.i('本地版本buildNumber：$localVersionBuildNumber');
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
