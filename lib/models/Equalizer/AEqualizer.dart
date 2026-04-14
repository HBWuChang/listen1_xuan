import 'package:json_annotation/json_annotation.dart';

import 'Equalizer.dart';
part 'AEqualizer.g.dart';

@JsonSerializable()
class AEqualizer {
  List<Equalizer> equalizers;

  AEqualizer({required this.equalizers});

  factory AEqualizer.fromJson(Map<String, dynamic> json) =>
      _$AEqualizerFromJson(json);

  Map<String, dynamic> toJson() => _$AEqualizerToJson(this);

  String toFilterString() {
    final params = <String>[];
    for (final eq in equalizers) {
      params.add(eq.toFilterString());
    }
    return params.join(',');
  }
}
