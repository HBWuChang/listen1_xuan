// double get lyricBorderRadius => globalHorizon ? 20.0 : 48.w;

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
  netease('netease');

  @override
  String toString() => name;
  final String name;
  const PlatformSource(this.name);
}
