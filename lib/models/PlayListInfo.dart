class PlayListInfo {
  String id;
  String? cover_img_url;
  String? title;
  String? source_url;

  PlayListInfo({
    required this.id,
    this.cover_img_url,
    this.title,
    this.source_url,
  });
  factory PlayListInfo.fromJson(Map<String, dynamic> json) {
    return PlayListInfo(
      id: json['id'] as String,
      cover_img_url: json['cover_img_url'] as String?,
      title: json['title'] as String?,
      source_url: json['source_url'] as String?,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cover_img_url': cover_img_url,
      'title': title,
      'source_url': source_url,
    };
  }
}
