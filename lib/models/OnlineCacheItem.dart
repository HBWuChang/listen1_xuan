import 'package:listen1_xuan/constants/const.dart';
import 'audio_metadata.dart';
import 'package:listen1_xuan/models/AudioQualityOfBL.dart';

class OnlineCacheItem {
  final String url;
  final AudioMetadata? audioMetadata;
  final AudioQualityOfBL? audioQualityOfBL;
  final dynamic extra; // 可选的额外信息字段

  String? get qualityDesc => audioMetadata?.qualityDescription ?? audioQualityOfBL?.description;
  PlatformSource? get qualityPlat =>
      ((audioMetadata?.platform == 'bilibili' && qualityDesc != null) || audioQualityOfBL != null) ? PlatformSource.bilibili : null;
  @override
  String toString() => url;

  OnlineCacheItem({required this.url, this.audioQualityOfBL, this.audioMetadata, this.extra});
}
