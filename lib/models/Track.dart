import 'dart:convert';
import 'dart:io';

String gzipJsonString(String jsonStr) {
  // 将字符串转为字节
  List<int> jsonBytes = utf8.encode(jsonStr);
  // gzip 压缩
  List<int> compressedBytes = gzip.encode(jsonBytes);
  // base64Url 编码为字符串（URL 安全）
  return base64Url.encode(compressedBytes);
}

String ungzipJsonString(String base64CompressedStr) {
  // base64Url 解码
  List<int> compressedBytes = base64Url.decode(base64CompressedStr);
  // gzip 解压
  List<int> decompressedBytes = gzip.decode(compressedBytes);
  // 转为字符串
  return utf8.decode(decompressedBytes);
}

class Track {
  String id;
  String? title;
  String? artist;
  String? artist_id;
  String? album;
  String? album_id;
  String? source;
  String? source_url;
  String? img_url;
  String? lyric_url;

  Track({
    required this.id,
    this.title,
    this.artist,
    this.artist_id,
    this.album,
    this.album_id,
    this.source,
    this.source_url,
    this.img_url,
    this.lyric_url,
  });

  // 从 JSON 创建 Track 对象
  factory Track.fromJson(Map<String, dynamic> json) {
    String? lyric_url;
    if (json['lyric_url'] is String) {
      lyric_url = json['lyric_url'];
    } else if (json['lyric_url'] != null) {
      lyric_url = json['lyric_url'].toString();
    } else {
      lyric_url = null;
    }
    return Track(
      id: json['id'] as String,
      title: json['title'] as String?,
      artist: json['artist'] as String?,
      artist_id: json['artist_id'] as String?,
      album: json['album'] as String?,
      album_id: json['album_id'] as String?,
      source: json['source'] as String?,
      source_url: json['source_url'] as String?,
      img_url: json['img_url'] as String?,
      lyric_url: lyric_url,
    );
  }
  factory Track.fromBase64MaybeGzip(String base64Str) {
    String jsonString;
    try {
      // 尝试作为 gzip 压缩数据解压
      jsonString = ungzipJsonString(base64Str);
    } catch (e) {
      // 如果解压失败，尝试作为普通 base64 解码
      jsonString = utf8.decode(base64Url.decode(base64Str));
    }
    Map<String, dynamic> jsonMap = jsonDecode(jsonString);
    return Track.fromJson(jsonMap);
  }
  String toBase64WithGzip() {
    String jsonString = jsonEncode(toJson());
    // return base64Url.encode(utf8.encode(jsonString));
    return gzipJsonString(jsonString);
  }
  // 转换为 JSON
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'id': id};
    if (title != null) map['title'] = title;
    if (artist != null) map['artist'] = artist;
    if (artist_id != null) map['artist_id'] = artist_id;
    if (album != null) map['album'] = album;
    if (album_id != null) map['album_id'] = album_id;
    if (source != null) map['source'] = source;
    if (source_url != null) map['source_url'] = source_url;
    if (img_url != null) map['img_url'] = img_url;
    if (lyric_url != null) map['lyric_url'] = lyric_url;
    return map;
  }
}
