import 'package:listen1_xuan/models/AudioQualityOfBL.dart';
import 'audio_metadata.dart';

class BootSuccessRes {
  final String url;

  /// BaseProvider.name
  final String platform;

  final AudioMetadata? audioMetadata;
  final String? bitrate;
  final AudioQualityOfBL? audioQualityOfBL;

  BootSuccessRes({
    required this.url,
    required this.platform,
    this.bitrate,
    this.audioMetadata,
    this.audioQualityOfBL,
  });
}
