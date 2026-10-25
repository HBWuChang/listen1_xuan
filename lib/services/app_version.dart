import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Prefers the base Android build number, without split-APK ABI offsets.
/// Falls back to package metadata when the optional native channel is unavailable.
Future<String> loadAppVersion() async {
  final info = await PackageInfo.fromPlatform();
  var buildNumber = info.buildNumber;
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      final baseBuildNumber = await const MethodChannel(
        'listen1_xuan/build_info',
      ).invokeMethod<String>('getBuildNumber');
      if (baseBuildNumber != null && baseBuildNumber.isNotEmpty) {
        buildNumber = baseBuildNumber;
      }
    } on MissingPluginException {
      // Older native builds may not have registered this channel.
    } on PlatformException {
      // PackageInfo still provides a usable version if the native lookup fails.
    }
  }
  return '${info.version}+$buildNumber';
}
