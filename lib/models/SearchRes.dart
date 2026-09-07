import 'package:json_annotation/json_annotation.dart';
import 'package:listen1_xuan/models/Track.dart';

part 'SearchRes.g.dart';

@JsonSerializable()
class SearchRes {
  /// 搜索结果列表
  final List<Track> result;

  /// 总数
  final int total;

  final String? error;

  bool get hasError => error != null;

  SearchRes({required this.result, required this.total, this.error});

  factory SearchRes.error(String error) =>
      SearchRes(result: [], total: 0, error: error);
  factory SearchRes.empty() => SearchRes(result: [], total: 0, error: null);

  factory SearchRes.fromJson(Map<String, dynamic> json) =>
      _$SearchResFromJson(json);

  Map<String, dynamic> toJson() => _$SearchResToJson(this);
}
