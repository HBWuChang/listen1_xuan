import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smtc_windows/smtc_windows.dart';

import '../global_settings_animations.dart';
import '../play.dart';

class AudioHandlerController extends GetxController {
  late AudioHandler audioHandler;
  var loading = true.obs;
  @override
  void onInit() {
    super.onInit();
    print('AudioHandlerController initialized');
    setNotification();
  }

  Future<void> setNotification() async {
    print('setNotification');
    audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.xiebian.listen1_xuan.channel',
        androidNotificationChannelName: '音频播放',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
      ),
      cacheManager: null,
    );
    await fresh_playmode();
    update_playmode_to_audio_service();
    final track = await getnowplayingsong();
    if (track['index'] != -1) {
      if (is_windows) {
        smtc = SMTCWindows(
          metadata: MusicMetadata(
            title: track['track'].title,
            album: track['track'].album,
            albumArtist: track['track'].artist,
            artist: track['track'].artist,
            thumbnail: track['track'].img_url,
          ),
          timeline: PlaybackTimeline(
            startTimeMs: 0,
            endTimeMs: 1000,
            positionMs: 0,
            minSeekTimeMs: 0,
            maxSeekTimeMs: 1000,
          ),
        );
      }
      await playsong(track['track'], false);
    } else {
      if (is_windows) {
        smtc = SMTCWindows(
          metadata: MusicMetadata(
            title: "test",
            album: "test",
            albumArtist: "test",
            artist: "test",
            thumbnail:
                'https://s.040905.xyz/d/v/business-spirit-unit.gif?sign=uDy2k6zQMaZr8CnNBem03KTPdcQGX-JVOIRcEBcVOhk=:0',
          ),
          timeline: PlaybackTimeline(
            startTimeMs: 0,
            endTimeMs: 1000,
            positionMs: 0,
            minSeekTimeMs: 0,
            maxSeekTimeMs: 1000,
          ),
        );
      }
    }
    loading.value = false;
    update();
    print('AudioHandlerController setNotification completed');
  }
}
