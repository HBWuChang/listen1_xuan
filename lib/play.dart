// import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

final play = Play();
final _player = AudioPlayer();
late AudioHandler _audioHandler;

class Play extends StatefulWidget {
  @override
  _PlayState createState() => _PlayState();
}

Future<void> playerSuccessCallback(dynamic res, dynamic track) async {
  print('playerSuccessCallback');
  print(res);
  print(track);

  try {
    // 获取应用程序的临时目录
    final tempDir = await getTemporaryDirectory();
    final tempPath = tempDir.path;
    final fileName = res['url'].split('/').last.split('?').first;
    final filePath = '$tempPath/$fileName';
    // 若本地已经存在该文件，则直接播放
    if (!await File(filePath).exists()) {
      switch (res["platform"]) {
        case "bilibili":
          final dio = Dio();
          await dio.download(
            res['url'],
            filePath,
            options: Options(headers: {
              "user-agent":
                  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36",
              "accept": "*/*",
              "accept-encoding": "identity;q=1, *;q=0",
              "accept-language": "zh-CN",
              "referer": "https://www.bilibili.com/",
              "sec-fetch-dest": "audio",
              "sec-fetch-mode": "no-cors",
              "sec-fetch-site": "cross-site",
              "range": "bytes=0-",
            }),
          );
      }
      // 设置本地文件路径为音频源
    }
    dynamic _item;
    _item = MediaItem(
      id: filePath,
      // id: "https://s.040905.xyz/d/v/temp/%E5%91%A8%E6%9D%B0%E4%BC%A6%20-%20%E6%9C%80%E4%BC%9F%E5%A4%A7%E7%9A%84%E4%BD%9C%E5%93%81%20%5Bmqms2%5D.mp3?sign=fNa5fJ-EtPzcIs_UlZYKYrjNgKhbYy7pKAgpcLEKC6M=:0",
      title: track['title'],
      artist: track['artist'],
      artUri: Uri.parse(track['img_url']),
    );

    _audioHandler.updateMediaItem(_item);
    _player
        // .setAudioSource(AudioSource.uri(Uri.parse(_item.id),));
        .setAudioSource(AudioSource.uri(Uri.parse(_item.id)));
    _player.play();

    return;
  } catch (e) {
    print('Error downloading or playing audio: $e');
  }
}

Future<void> playerFailCallback() async {
  print('playerFailCallback');
}

Future<void> setNotification() async {
  print('setNotification');
  // print(_audioHandler);
  try {
    _audioHandler.hashCode;
  } catch (e) {
    _audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.ryanheise.myapp.channel.audio',
        androidNotificationChannelName: 'Audio playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
      cacheManager: null,
    );
  }
}

class _PlayState extends State<Play> {
  // late AudioPlayer player = AudioPlayer();

  // Function get playerFailCallback => () async {
  //       print('playerFailCallback');
  //     };

  // Function get playerSuccessCallback => (res) async {
  //       print('playerSuccessCallback');
  //       print(res);
  //       // await player.play(UrlSource('https://example.com/my-audio.wav'));
  //       // await player.play(UrlSource(res['url']));
  //       await player.setSource(UrlSource(res['url']));
  //       await player.resume();
  //     };

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // Release all sources and dispose the player.
    // player.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // return PlayerWidget(player: player);
    return FutureBuilder<void>(
      future: setNotification(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error initializing audio handler'));
        } else {
          return StreamBuilder<bool>(
            stream: _audioHandler.playbackState
                .map((state) => state.playing)
                .distinct(),
            builder: (context, snapshot) {
              final playing = snapshot.data ?? false;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _button(Icons.fast_rewind, _audioHandler.rewind),
                  if (playing)
                    _button(Icons.pause, _audioHandler.pause)
                  else
                    _button(Icons.play_arrow, _audioHandler.play),
                  _button(Icons.stop, _audioHandler.stop),
                  _button(Icons.fast_forward, _audioHandler.fastForward),
                ],
              );
            },
          );
        }
      },
    );
  }

  IconButton _button(IconData iconData, VoidCallback onPressed) => IconButton(
        icon: Icon(iconData),
        iconSize: 64.0,
        onPressed: onPressed,
      );
}

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  /// Initialise our audio handler.
  static final _item = MediaItem(
    id: 'https://s.040905.xyz/d/v/temp/%E5%91%A8%E6%9D%B0%E4%BC%A6%20-%20%E6%9C%80%E4%BC%9F%E5%A4%A7%E7%9A%84%E4%BD%9C%E5%93%81%20%5Bmqms2%5D.mp3?sign=fNa5fJ-EtPzcIs_UlZYKYrjNgKhbYy7pKAgpcLEKC6M=:0',
    // album: "Science Friday",
    title: "test",
    // artist: "Science Friday and WNYC Studios",
    // duration: const Duration(milliseconds: 5739820),
    artUri: Uri.parse(
        'https://media.wnyc.org/i/1400/1400/l/80/1/ScienceFriday_WNYCStudios_1400.jpg'),
  );
  AudioPlayerHandler() {
    // So that our clients (the Flutter UI and the system notification) know
    // what state to display, here we set up our audio handler to broadcast all
    // playback state changes as they happen via playbackState...
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    // ... and also the current media item via mediaItem.
    mediaItem.add(_item);

    // Load the player.
    _player.setAudioSource(AudioSource.uri(Uri.parse(_item.id)));
  }

  // In this simple example, we handle only 4 actions: play, pause, seek and
  // stop. Any button press from the Flutter UI, notification, lock screen or
  // headset will be routed through to these 4 methods so that you can handle
  // your audio playback logic in one place.

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  /// Transform a just_audio event into an audio_service state.
  ///
  /// This method is used from the constructor. Every event received from the
  /// just_audio player will be transformed into an audio_service state so that
  /// it can be broadcast to audio_service clients.
  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}
