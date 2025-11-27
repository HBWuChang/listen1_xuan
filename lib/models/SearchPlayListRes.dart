import 'package:json_annotation/json_annotation.dart';

part 'SearchPlayListRes.g.dart';

/// 搜索歌单结果项
@JsonSerializable()
class SearchPlayListItem {
  /// 歌单ID，格式如 "neplaylist_12345"
  String? id;

  /// 歌单标题
  String? title;

  /// 来源平台
  String? source;

  /// 来源URL
  @JsonKey(name: 'source_url')
  String? sourceUrl;

  /// 封面图片URL
  @JsonKey(name: 'img_url')
  String? imgUrl;

  /// 歌单URL（通常与ID相同）
  String? url;

  /// 创建者昵称
  String? author;

  /// 歌曲数量
  int? count;

  SearchPlayListItem({
    this.id,
    this.title,
    this.source,
    this.sourceUrl,
    this.imgUrl,
    this.url,
    this.author,
    this.count,
  });

  factory SearchPlayListItem.fromJson(Map<String, dynamic> json) =>
      _$SearchPlayListItemFromJson(json);

  Map<String, dynamic> toJson() => _$SearchPlayListItemToJson(this);
}

/// 搜索歌单响应
@JsonSerializable()
class SearchPlayListRes {
  /// 搜索结果列表
  final List<SearchPlayListItem> result;

  /// 总数
  final int total;

  /// 搜索类型（'0': 歌曲, '1': 歌单）
  final String type;

  SearchPlayListRes({
    required this.result,
    required this.total,
    required this.type,
  });

  factory SearchPlayListRes.fromJson(Map<String, dynamic> json) =>
      _$SearchPlayListResFromJson(json);

  Map<String, dynamic> toJson() => _$SearchPlayListResToJson(this);
}
