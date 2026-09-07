import 'package:listen1_xuan/bl.dart';

class BootSuccessRes {
  final String url;

  /// BaseProvider.name
  final String platform;

  final AudioQualityOfBL? audioQualityOfBL;

  BootSuccessRes({
    required this.url,
    required this.platform,
    this.audioQualityOfBL,
  });
}
