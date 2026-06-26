import 'package:flutter/widgets.dart';
import 'package:heroine/heroine.dart';
import 'package:listen1_xuan/models/PlayListInfo.dart';
import 'package:motor/motor.dart';

extension HeroineExts on Widget {
  Heroine hero4playlistItemImg(PlayListInfo playListInfo) =>
      hero(playListInfo.id.hero4playlistItemImg);
  Heroine hero(Object tag) => Heroine(
    tag: tag,
    motion: Motion.smoothSpring(duration: Duration(milliseconds: 300)),
    pauseTickersDuringFlight: true,
    child: this,
  );
}

extension HeroineTagExt on Object {
  String get hero4playlistItemImg => 'playlistItemImg-${toString()}';
}
