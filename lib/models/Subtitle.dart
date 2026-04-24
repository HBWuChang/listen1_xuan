import 'package:json_annotation/json_annotation.dart';

part 'Subtitle.g.dart';

Object? _subtitleIdReadValue(Map<dynamic, dynamic> map, String key) {
  final value = map[key];
  if (value is int) {
    return value.toString();
  }
  return value;
}

@JsonSerializable(explicitToJson: true)
// {"id":2002416972406562560,"lan":"ai-zh","lan_doc":"中文","is_lock":false,"subtitle_url":"//aisubtitle.hdslb.com/bfs/ai_subtitle/prod/11644760287510537719312328c82d4f4bb99339f78e8818e7dc0ba6a8?auth_key=1777037253-b28028bb44144abca664750e0dcc9489-0-2c79b826debb9ccff4bf4fd17793e055","subtitle_url_v2":"//subtitle.bilibili.com/S%13%1BP.%1D%28%29X%2CR%5Ej%1F%25w%0E%02H%5EHO4%14%7B4%08K@%3C%7B%00M%0B%0A%1AM%08%056N6$%0C0\u0026%02%1E%01%09%0E%1A2V~%15C%5C%12D_%5BBP%08%7B%1FYYu%18WSP_XPZ%5EQ%5E%7Bt%1Cm4Z%19L@EFe@%29%13M%0D%1EKXS%15_%5B-%1E%0B%0DpNX?auth_key=1777037253-b28028bb44144abca664750e0dcc9489-0-2c79b826debb9ccff4bf4fd17793e055","type":1,"id_str":"2002416972406562560","ai_type":0,"ai_status":2}],
class Subtitle {
  @JsonKey(
    name: 'id',
    readValue: _subtitleIdReadValue,
  )
  final String? id;

  @JsonKey(name: 'lan')
  final String? language;

  @JsonKey(name: 'lan_doc')
  final String? languageDescription;

  @JsonKey(name: 'is_lock')
  final bool? isLocked;

  @JsonKey(name: 'subtitle_url')
  final String? subtitleUrl;

  @JsonKey(name: 'subtitle_url_v2')
  final String? subtitleUrlV2;

  @JsonKey(name: 'type')
  final int? type;

  @JsonKey(name: 'id_str')
  final String? idStr;

  @JsonKey(name: 'ai_type')
  final int? aiType;

  @JsonKey(name: 'ai_status')
  final int? aiStatus;

  Subtitle({
    this.id,
    this.language,
    this.languageDescription,
    this.isLocked,
    this.subtitleUrl,
    this.subtitleUrlV2,
    this.type,
    this.idStr,
    this.aiType,
    this.aiStatus,
  });

  factory Subtitle.fromJson(Map<String, dynamic> json) =>
      _$SubtitleFromJson(json);

  Map<String, dynamic> toJson() => _$SubtitleToJson(this);
}
