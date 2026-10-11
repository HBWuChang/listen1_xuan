import 'dart:math' as math;
import 'AudioQualityOfBL.dart';

class AudioMetadata {
  const AudioMetadata({this.platform, this.sourceQualityCode, this.fileName,
    this.transcoded = false, this.measuredI, this.targetI,
    this.normalTargetI, this.undersizedTargetI});

  final String? platform;
  final int? sourceQualityCode;
  final String? fileName;
  final bool transcoded;
  final double? measuredI;
  final double? targetI;
  final double? normalTargetI;
  final double? undersizedTargetI;
  static const double defaultOtherPlatformGain = 0.56;
  bool get hasWebLoudnessParams => measuredI != null &&
      normalTargetI != null && undersizedTargetI != null;

  AudioQualityOfBL? get sourceQuality => sourceQualityCode == null
      ? null : AudioQualityCode.fromCode(sourceQualityCode!);
  String? get qualityDescription => transcoded ? 'MP3' : sourceQuality?.description;

  static double validOtherPlatformGain(dynamic value) =>
      value is num && value.isFinite && value >= 0 && value <= 1
          ? value.toDouble() : defaultOtherPlatformGain;

  double gain(bool enabled, {double otherPlatformGain = defaultOtherPlatformGain}) {
    if (!enabled) return 1;
    if (platform != 'bilibili') return validOtherPlatformGain(otherPlatformGain);
    final measured = measuredI;
    final target = normalTargetI;
    final threshold = undersizedTargetI;
    if (measured == null || !measured.isFinite || measured == 0 ||
        target == null || !target.isFinite || threshold == null ||
        !threshold.isFinite) {
      return validOtherPlatformGain(otherPlatformGain);
    }
    if (measured < threshold) {
      return 1;
    }
    return math.pow(10, (target - measured) / 20).toDouble();
  }

  static AudioMetadata fromBilibiliVolume(dynamic volume, {int? qualityCode}) {
    final measured = volume is Map ? volume['measured_i'] : null;
    final target = volume is Map ? volume['target_i'] : null;
    final scene = volume is Map ? volume['multi_scene_args'] : null;
    return AudioMetadata(platform: 'bilibili', sourceQualityCode: qualityCode,
      measuredI: measured is num ? measured.toDouble() : null,
      targetI: target is num ? target.toDouble() : null,
      normalTargetI: scene is Map ? _number(scene['normal_target_i']) : null,
      undersizedTargetI: scene is Map ? _number(scene['undersized_target_i']) : null);
  }

  static double? _number(dynamic value) => value is num
      ? value.toDouble() : value is String ? double.tryParse(value) : null;

  AudioMetadata withLoudness(AudioMetadata other) => AudioMetadata(
    platform: platform ?? other.platform, sourceQualityCode: sourceQualityCode,
    fileName: fileName, transcoded: transcoded,
    measuredI: other.measuredI, targetI: other.targetI,
    normalTargetI: other.normalTargetI, undersizedTargetI: other.undersizedTargetI);

  AudioMetadata forFile(String name, {required bool transcoded}) => AudioMetadata(
    platform: platform, sourceQualityCode: sourceQualityCode, fileName: name,
    transcoded: transcoded, measuredI: measuredI, targetI: targetI,
    normalTargetI: normalTargetI, undersizedTargetI: undersizedTargetI);

  Map<String, dynamic> toMap() => {
    'version': 1, 'platform': platform, 'sourceQualityCode': sourceQualityCode,
    'fileName': fileName, 'transcoded': transcoded,
    'measuredI': measuredI, 'targetI': targetI,
    'normalTargetI': normalTargetI, 'undersizedTargetI': undersizedTargetI,
  };

  static AudioMetadata? fromMap(dynamic value) {
    if (value is! Map || value['version'] != 1) return null;
    return AudioMetadata(
      platform: value['platform'] is String ? value['platform'] : null,
      sourceQualityCode: value['sourceQualityCode'] is num ? (value['sourceQualityCode'] as num).toInt() : null,
      fileName: value['fileName'] is String ? value['fileName'] : null,
      transcoded: value['transcoded'] == true,
      measuredI: value['measuredI'] is num ? (value['measuredI'] as num).toDouble() : null,
      targetI: _number(value['targetI']),
      normalTargetI: _number(value['normalTargetI']),
      undersizedTargetI: _number(value['undersizedTargetI']),
    );
  }
}
