import 'package:json_annotation/json_annotation.dart';

part 'ReactionRollup.g.dart';

/// GitHub Reaction Rollup 模型
@JsonSerializable()
class ReactionRollup {
  final String url;
  @JsonKey(name: 'total_count')
  final int totalCount;
  @JsonKey(name: '+1')
  final int plusOne;
  @JsonKey(name: '-1')
  final int minusOne;
  final int laugh;
  final int confused;
  final int heart;
  final int hooray;
  final int eyes;
  final int rocket;

  ReactionRollup({
    required this.url,
    required this.totalCount,
    required this.plusOne,
    required this.minusOne,
    required this.laugh,
    required this.confused,
    required this.heart,
    required this.hooray,
    required this.eyes,
    required this.rocket,
  });

  factory ReactionRollup.fromJson(Map<String, dynamic> json) =>
      _$ReactionRollupFromJson(json);

  Map<String, dynamic> toJson() => _$ReactionRollupToJson(this);
}
