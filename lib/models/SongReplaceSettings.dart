import 'package:json_annotation/json_annotation.dart';
import 'package:listen1_xuan/models/Track.dart';

part 'SongReplaceSettings.g.dart';

/// 歌曲替换设置模型
/// 用于存储歌曲ID映射关系和替换歌曲信息
@JsonSerializable(explicitToJson: true)
class SongReplaceSettings {
  /// trackId 到 trackId 的映射
  /// key: 原始歌曲ID, value: 替换后的歌曲ID
  @JsonKey(name: 'id_mappings', defaultValue: <String, String>{})
  final Map<String, String> idMappings;

  /// trackId 到 Track 模型的映射
  /// 存储替换歌曲的详细信息
  @JsonKey(name: 'track_details', defaultValue: <String, Track>{})
  final Map<String, Track> trackDetails;

  /// trackId 到歌词延迟值的映射
  /// 存储每首歌曲的歌词延迟设置（单位：秒）
  @JsonKey(name: 'song_delays', defaultValue: <String, double>{})
  final Map<String, double> songDelays;

  /// 反向索引：替换歌曲ID 到 原始歌曲ID列表的映射
  /// 用于O(1)时间快速查找某个歌曲是否被用作替换歌曲
  /// 注意：这个字段不序列化，在反序列化后重建
  @JsonKey(includeFromJson: false, includeToJson: false)
  final Map<String, Set<String>> _reverseIndex = {};

  SongReplaceSettings({
    Map<String, String>? idMappings,
    Map<String, Track>? trackDetails,
    Map<String, double>? songDelays,
  }) : idMappings = idMappings ?? {},
       trackDetails = trackDetails ?? {},
       songDelays = songDelays ?? {} {
    _buildReverseIndex();
  }
  Track? getReplacedTrack(String originalId) {
    String replacementId = originalId;
    do {
      String? toRe = idMappings[replacementId];
      if (toRe == null) {
        if (replacementId == originalId) {
          return null;
        } else {
          return trackDetails[replacementId];
        }
      }
      replacementId = toRe;
    } while (true);
  }

  /// 构建反向索引
  void _buildReverseIndex() {
    _reverseIndex.clear();
    for (var entry in idMappings.entries) {
      final originalId = entry.key;
      final replacementId = entry.value;
      _reverseIndex.putIfAbsent(replacementId, () => {}).add(originalId);
    }
  }

  /// O(1) 时间检查某个 trackId 是否被用作替换歌曲
  /// [trackId] 要检查的歌曲ID
  /// 返回 true 表示该歌曲被用作替换歌曲
  bool isUsedAsReplacement(String trackId) {
    return _reverseIndex.containsKey(trackId);
  }

  /// 获取使用某个歌曲作为替换歌曲的所有原始歌曲ID列表
  /// [replacementId] 替换歌曲ID
  /// 返回使用该歌曲作为替换的所有原始歌曲ID集合
  Set<String> getOriginalIdsForReplacement(String replacementId) {
    return _reverseIndex[replacementId] ?? {};
  }

  /// 添加或更新映射关系
  /// [originalId] 原始歌曲ID
  /// [replacementId] 替换歌曲ID
  /// [track] 替换歌曲的详细信息（可选）
  void setMapping(String originalId, String replacementId, {Track? track}) {
    // 如果原始映射存在，先从反向索引中移除
    if (idMappings.containsKey(originalId)) {
      final oldReplacementId = idMappings[originalId]!;
      _reverseIndex[oldReplacementId]?.remove(originalId);
      if (_reverseIndex[oldReplacementId]?.isEmpty ?? false) {
        _reverseIndex.remove(oldReplacementId);
      }
    }

    // 添加新映射
    idMappings[originalId] = replacementId;
    _reverseIndex.putIfAbsent(replacementId, () => {}).add(originalId);

    // 如果提供了 Track 信息，保存到 trackDetails
    if (track != null) {
      trackDetails[replacementId] = track;
    }
  }

  /// 移除映射关系
  /// [originalId] 原始歌曲ID
  /// 返回 true 表示成功移除
  bool removeMapping(String originalId) {
    if (!idMappings.containsKey(originalId)) {
      return false;
    }

    final replacementId = idMappings[originalId]!;
    idMappings.remove(originalId);

    // 更新反向索引
    _reverseIndex[replacementId]?.remove(originalId);
    if (_reverseIndex[replacementId]?.isEmpty ?? false) {
      _reverseIndex.remove(replacementId);
      // 如果该替换歌曲不再被使用，可以选择删除其详细信息
      // trackDetails.remove(replacementId);
    }

    return true;
  }

  /// 获取替换后的歌曲ID
  /// [originalId] 原始歌曲ID
  /// 返回替换歌曲ID，如果没有映射则返回 null
  String? getReplacementId(String originalId) {
    return idMappings[originalId];
  }

  /// 获取替换歌曲的详细信息
  /// [trackId] 歌曲ID
  /// 返回 Track 对象，如果不存在则返回 null
  Track? getTrackDetails(String trackId) {
    return trackDetails[trackId];
  }

  /// 获取歌曲的歌词延迟值
  /// [trackId] 歌曲ID
  /// 返回延迟值（秒），如果不存在则返回 null
  double? getSongDelay(String trackId) {
    return songDelays[trackId];
  }

  /// 设置歌曲的歌词延迟值
  /// [trackId] 歌曲ID
  /// [delay] 延迟值（秒）
  void setSongDelay(String trackId, double delay) {
    if (delay.isNaN) {
      delay = 0.0;
    }
    if (delay == 0.0) {
      songDelays.remove(trackId);
      return;
    }
    songDelays[trackId] = delay;
  }

  /// 移除歌曲的歌词延迟值
  /// [trackId] 歌曲ID
  /// 返回 true 表示成功移除
  bool removeSongDelay(String trackId) {
    return songDelays.remove(trackId) != null;
  }

  /// 清空所有映射
  void clear() {
    idMappings.clear();
    trackDetails.clear();
    songDelays.clear();
    _reverseIndex.clear();
  }

  /// 刷新 trackDetails，删除未被使用的 Track 数据
  /// 自动删除在 idMappings 的 key 和 value 中均未出现的 trackDetails 和 songDelays 条目
  /// 返回删除的条目数量（trackDetails 和 songDelays 的总和）
  int refreshTrackDetails() {
    // 收集所有在 idMappings 中出现过的 trackId（包括 key 和 value）
    final usedTrackIds = <String>{};

    // 添加所有 idMappings 的 key（原始歌曲ID）
    usedTrackIds.addAll(idMappings.keys);

    // 添加所有 idMappings 的 value（替换歌曲ID）
    usedTrackIds.addAll(idMappings.values);

    // 找出 trackDetails 中未被使用的 key
    final unusedTrackKeys = trackDetails.keys
        .where((key) => !usedTrackIds.contains(key))
        .toList();

    // 找出 songDelays 中未被使用的 key
    final unusedDelayKeys = songDelays.keys
        .where((key) => !usedTrackIds.contains(key))
        .toList();

    // 删除未使用的 trackDetails 条目
    for (var key in unusedTrackKeys) {
      trackDetails.remove(key);
    }

    // 删除未使用的 songDelays 条目
    for (var key in unusedDelayKeys) {
      songDelays.remove(key);
    }

    return unusedTrackKeys.length + unusedDelayKeys.length;
  }

  /// 从 JSON 创建实例
  factory SongReplaceSettings.fromJson(Map<String, dynamic> json) {
    final settings = _$SongReplaceSettingsFromJson(json);
    // 反序列化后重建反向索引
    settings._buildReverseIndex();
    return settings;
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() => _$SongReplaceSettingsToJson(this);

  /// 复制并修改
  SongReplaceSettings copyWith({
    Map<String, String>? idMappings,
    Map<String, Track>? trackDetails,
    Map<String, double>? songDelays,
  }) {
    return SongReplaceSettings(
      idMappings: idMappings ?? Map.from(this.idMappings),
      trackDetails: trackDetails ?? Map.from(this.trackDetails),
      songDelays: songDelays ?? Map.from(this.songDelays),
    );
  }
}
