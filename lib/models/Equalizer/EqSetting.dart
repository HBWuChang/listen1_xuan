import 'package:json_annotation/json_annotation.dart';

import 'AEqualizer.dart';
import 'defEqSet.dart';

part 'EqSetting.g.dart';

@JsonSerializable()
class EqSetting {
  Map<String, AEqualizer> equalizers;
  String? nowSelected;

  EqSetting({Map<String, AEqualizer>? equalizers, String? nowSelected})
    : this._internal(equalizers ?? createDefEqSet(), nowSelected);

  EqSetting._internal(this.equalizers, String? nowSelected)
    : nowSelected = _resolveNowSelected(nowSelected, equalizers);

  static String? _resolveNowSelected(
    String? nowSelected,
    Map<String, AEqualizer> equalizers,
  ) {
    if (nowSelected == null) {
      return null;
    }
    if (equalizers.containsKey(nowSelected)) {
      return nowSelected;
    }
    if (equalizers.containsKey('flat')) {
      return 'flat';
    }
    if (equalizers.isNotEmpty) {
      return equalizers.keys.first;
    }
    throw ArgumentError('equalizers can not be empty');
  }

  factory EqSetting.fromJson(Map<String, dynamic> json) =>
      _$EqSettingFromJson(json);

  Map<String, dynamic> toJson() => _$EqSettingToJson(this);

  String? toFilterStringOfNowSelected() {
    if (nowSelected == null) return null;
    final eq = equalizers[nowSelected!];
    if (eq == null) {
      throw ArgumentError('Equalizer with key "$nowSelected" not found');
    }
    return eq.toFilterString();
  }

  AEqualizer? get nowSelectedEqualizer {
    if (nowSelected == null) return null;
    return equalizers[nowSelected!];
  }

  String toFilterStringOf(String key) {
    final eq = equalizers[key];
    if (eq == null) {
      throw ArgumentError('Equalizer with key "$key" not found');
    }
    return eq.toFilterString();
  }
}
