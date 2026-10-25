import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Uses the base Android build number, without split-APK ABI offsets.
Future<String> loadAppVersion() async {
  final info = await PackageInfo.fromPlatform();
  var buildNumber = info.buildNumber;
  if (defaultTargetPlatform == TargetPlatform.android) {
    buildNumber =
        await const MethodChannel(
          'listen1_xuan/build_info',
        ).invokeMethod<String>('getBuildNumber') ??
        buildNumber;
  }
  return '${info.version}+$buildNumber';
}
