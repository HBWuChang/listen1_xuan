// double get lyricBorderRadius => globalHorizon ? 20.0 : 48.w;

import 'package:protobuf/protobuf.dart';

const String downDirName = 'Listen1';
const String cacheUnUseableRepUnUseable = '/\\:*?"<>|';

///Heros
class HeroTags {
  static const String songReplaceFab = 'songReplaceFab';
}

// helps
class HelpMarkdownFiles {
  static const String songReplacePage = 'assets/help/song_replace_help.md';
}

enum PlatformSource {
  bilibili('bilibili'),
  qq('qq'),
  kugou('kugou'),
  netease('netease'),
  unknow('unknow');

  @override
  String toString() => name;
  final String name;
  const PlatformSource(this.name);
}

extension PlatformSourceExt on PlatformSource {
  static PlatformSource? findPlatformSourceByName(String name) {
    return PlatformSource.values.firstWhere(
      (e) => e.name == name,
      orElse: () => PlatformSource.unknow,
    );
  }

  String? get shortDisplayName {
    switch (this) {
      case PlatformSource.bilibili:
        return 'B站';
      case PlatformSource.qq:
        return 'QQ';
      case PlatformSource.kugou:
        return '酷狗';
      case PlatformSource.netease:
        return '网易';
      case PlatformSource.unknow:
        return null;
    }
  }
}

const commonDuration = Duration(milliseconds: 300);
