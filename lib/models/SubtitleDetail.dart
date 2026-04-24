import 'package:json_annotation/json_annotation.dart';
import 'package:listen1_xuan/models/Track.dart';

part 'SubtitleDetail.g.dart';

@JsonSerializable(explicitToJson: true)
class SubtitleDetail {
  @JsonKey(name: 'from')
  final double? from;

  @JsonKey(name: 'to')
  final double? to;
  @JsonKey(name: 'content')
  final String? content;
  SubtitleDetail({this.from, this.to, this.content});

  factory SubtitleDetail.fromJson(Map<String, dynamic> json) =>
      _$SubtitleDetailFromJson(json);

  Map<String, dynamic> toJson() => _$SubtitleDetailToJson(this);
}
