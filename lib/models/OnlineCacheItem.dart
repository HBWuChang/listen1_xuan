import 'package:listen1_xuan/constants/const.dart';
import 'package:listen1_xuan/models/AudioQualityOfBL.dart';

class OnlineCacheItem {
  final String url;
  final AudioQualityOfBL? audioQualityOfBL;
  final dynamic extra; // 可选的额外信息字段

  String? get qualityDesc => audioQualityOfBL?.description;
  PlatformSource? get qualityPlat =>
      audioQualityOfBL != null ? PlatformSource.bilibili : null;
  @override
  String toString() => url;

  OnlineCacheItem({required this.url, this.audioQualityOfBL, this.extra});
}
