// import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'loweb.dart';

final play = Play();
final _player = AudioPlayer();
late AudioHandler _audioHandler;
int playmode = 0;
List<Map<String, dynamic>> randommodetemplist = [];

class Play extends StatefulWidget {
  @override
  _PlayState createState() => _PlayState();
}

Future<void> onPlaybackCompleted([bool force_next = false]) async {
  final current_playing = await get_current_playing();
  final nowplaying_track = await getnowplayingsong();
  if (nowplaying_track['index'] != -1) {
    final index = nowplaying_track['index'];
    switch (playmode) {
      case 0:
        index + 1 < current_playing.length
            ? await playsong(current_playing[index + 1])
            : await playsong(current_playing[0]);
        break;
      case 1:
        final randomIndex = (current_playing.length *
                (DateTime.now().millisecondsSinceEpoch % 1000) /
                1000)
            .floor();
        if (randommodetemplist.contains(current_playing[index])) {
          randommodetemplist.remove(current_playing[index]);
        }
        randommodetemplist.add(current_playing[index]);
        await playsong(current_playing[randomIndex]);
        break;
      case 2:
        if (force_next) {
          index + 1 < current_playing.length
              ? await playsong(current_playing[index + 1])
              : await playsong(current_playing[0]);
          break;
        }
        await _player.seek(Duration.zero);
        break;
      default:
        break;
    }
  }
}

Future<String> get_local_cache(String id) async {
  final prefs = await SharedPreferences.getInstance();
  final local_cache_list_json = prefs.getString('local-cache-list');
  if (local_cache_list_json != null) {
    final local_cache_list = jsonDecode(local_cache_list_json);
    if (local_cache_list[id] != null) {
      final tempDir = await getTemporaryDirectory();
      final tempPath = tempDir.path;
      final filePath = '$tempPath/${local_cache_list[id]}';
      if (await File(filePath).exists()) return filePath;
    }
  }
  return '';
}

Future<void> set_local_cache(String id, String path) async {
  final prefs = await SharedPreferences.getInstance();
  final local_cache_list_json = prefs.getString('local-cache-list');
  if (local_cache_list_json != null) {
    final local_cache_list = jsonDecode(local_cache_list_json);
    local_cache_list[id] = path;
    await prefs.setString('local-cache-list', jsonEncode(local_cache_list));
  } else {
    final local_cache_list = {};
    local_cache_list[id] = path;
    await prefs.setString('local-cache-list', jsonEncode(local_cache_list));
  }
}

Future<void> add_current_playing(List<Map<String, dynamic>> tracks) async {
  List<Map<String, dynamic>> current_playing = await get_current_playing();
  for (var track in tracks) {
    if (!current_playing.any((element) => element['id'] == track['id'])) {
      current_playing.add(track);
    }
  }
  await set_current_playing(current_playing);
}

Future<void> set_current_playing(List<Map<String, dynamic>> tracks) async {
  final prefs = await SharedPreferences.getInstance();
  final current_playing = jsonEncode(tracks);
  await prefs.setString('current-playing', current_playing);
}

Future<List<Map<String, dynamic>>> get_current_playing() async {
  final prefs = await SharedPreferences.getInstance();
  final current_playing = await prefs.getString('current-playing');
  if (current_playing != null) {
    try {
      final List<dynamic> current_playing_json = jsonDecode(current_playing);
      return current_playing_json.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }
  return [];
}

Future<dynamic> get_player_settings(String key) async {
  final prefs = await SharedPreferences.getInstance();
  final player_settings = await prefs.getString('player-settings');
  if (player_settings != null) {
    try {
      final player_settings_json = jsonDecode(player_settings);
      return player_settings_json[key];
    } catch (e) {
      return null;
    }
  }
  return null;
}

Future<void> set_player_settings(String key, dynamic value) async {
  if (key == 'playmode') {
    switch (value) {
      case 0:
        Fluttertoast.showToast(
          msg: '循环',
        );
        break;
      case 1:
        Fluttertoast.showToast(
          msg: '随机',
        );
        break;
      case 2:
        Fluttertoast.showToast(
          msg: '单曲',
        );
        break;
      default:
        break;
    }
  }
  final prefs = await SharedPreferences.getInstance();
  final player_settings = await prefs.getString('player-settings');
  if (player_settings != null) {
    final player_settings_json = jsonDecode(player_settings);
    player_settings_json[key] = value;
    await prefs.setString('player-settings', jsonEncode(player_settings_json));
  } else {
    final player_settings_json = {};
    player_settings_json[key] = value;
    await prefs.setString('player-settings', jsonEncode(player_settings_json));
  }
}

// Future<Map<String, dynamic>,int> getnowplayingsong() async {
Future<Map<String, dynamic>> getnowplayingsong() async {
  final nowplaying_track_id = await get_player_settings("nowplaying_track_id");
  final current_playing = await get_current_playing();
  for (var track in current_playing) {
    if (track['id'] == nowplaying_track_id) {
      return {'track': track, 'index': current_playing.indexOf(track)};
    }
  }
  return {'track': {}, 'index': -1};
}

Future<void> playsong(Map<String, dynamic> track) async {
  final tdir = await get_local_cache(track['id']);
  if (tdir == "") {
    MediaService.bootstrapTrack(
        track, playerSuccessCallback, playerFailCallback);
    return;
  }
  await _player.setFilePath(tdir);

  // 使用 Completer 来等待 _duration 被赋值
  final Completer<void> completer = Completer<void>();
  _player.durationStream.listen((duration) {
    if (duration != null && !completer.isCompleted) {
      // print('音频文件时长: ${duration.inSeconds}秒');
      completer.complete();
    }
  });

  // 等待 _duration 被赋值
  await completer.future;
  await set_player_settings("nowplaying_track_id", track['id']);
  await add_current_playing([track]);
  // 获取音频文件的时长
  final _duration = await _player.duration;
  print(_duration);
  dynamic _item;
  _item = MediaItem(
    id: track['id'],
    title: track['title'],
    artist: track['artist'],
    artUri: Uri.parse(track['img_url']),
    duration: _duration,
  );
  (_audioHandler as AudioPlayerHandler).change_playbackstate(_item);
  _player.play();
}

Future<void> playerSuccessCallback(dynamic res, dynamic track) async {
  print('playerSuccessCallback');
  print(res);
  print(track);

  try {
    final tempDir = await getTemporaryDirectory();
    final tempPath = tempDir.path;
    final _local_cache = await get_local_cache(track['id']);
    if (_local_cache == '') {
      // 获取应用程序的临时目录
      final fileName = res['url'].split('/').last.split('?').first;
      final filePath = '$tempPath/$fileName';
      // 若本地已经存在该文件，则直接播放
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
        case "netease":
          final dio = Dio();
          await dio.download(res['url'], filePath);
        default:
          await Dio().download(res['url'], filePath);
      }
      await set_local_cache(track['id'], fileName);
    }
    playsong(track);
    return;
  } catch (e) {
    print('Error downloading or playing audio: $e');
  }
}

Future<void> playerFailCallback() async {
  print('playerFailCallback');
  Fluttertoast.showToast(
    msg: 'Error downloading audio',
  );
  onPlaybackCompleted(true);
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
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return hours > 0
        ? '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}'
        : '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

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
          return Container(
              height: 80,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Play/pause/stop buttons.
                    StreamBuilder<bool>(
                      stream: _audioHandler.playbackState
                          .map((state) => state.playing)
                          .distinct(),
                      builder: (context, snapshot) {
                        final playing = snapshot.data ?? false;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Show media item title
                            StreamBuilder<MediaItem?>(
                              stream: _audioHandler.mediaItem,
                              builder: (context, snapshot) {
                                final mediaItem = snapshot.data;
                                // return Text(mediaItem?.title ?? '');
                                if (mediaItem == null) {
                                  return Container(
                                    width: 50,
                                    height: 50,
                                  );
                                }
                                return Container(
                                  width: 50,
                                  height: 50,
                                  child: CachedNetworkImage(
                                    imageUrl: mediaItem.artUri.toString(),
                                    fit: BoxFit.cover,
                                  ),
                                );
                              },
                            ),
                            Container(
                                width: 250,
                                height: 50,
                                child: Column(
                                  children: [
                                    Container(
                                      height: 20,
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            Expanded(
                                              flex: 1,
                                              child: StreamBuilder<MediaItem?>(
                                                stream: _audioHandler.mediaItem,
                                                builder: (context, snapshot) {
                                                  final mediaItem =
                                                      snapshot.data;
                                                  return Marquee(
                                                    text: (mediaItem?.title ??
                                                            'null') +
                                                        '  -  ' +
                                                        (mediaItem?.artist ??
                                                            'null'),
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    blankSpace: 20.0,
                                                    velocity: 50.0,
                                                    pauseAfterRound:
                                                        Duration(seconds: 1),
                                                    startPadding: 10.0,
                                                  );
                                                },
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: StreamBuilder<MediaState>(
                                                stream: _mediaStateStream,
                                                builder: (context, snapshot) {
                                                  final mediaItem =
                                                      snapshot.data;
                                                  return Text(
                                                    (formatDuration(mediaItem
                                                                ?.position ??
                                                            Duration.zero) +
                                                        ' / ' +
                                                        formatDuration(mediaItem
                                                                ?.mediaItem
                                                                ?.duration ??
                                                            Duration.zero)),
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    // print(mediaState?.position.inMilliseconds
                                                    //     .toDouble());
                                                    // print(mediaState
                                                    //     ?.mediaItem?.duration?.inMilliseconds
                                                    // .toDouble());
                                                  );
                                                },
                                              ),
                                            ),
                                          ]),
                                    ),
                                    StreamBuilder<MediaState>(
                                      stream: _mediaStateStream,
                                      builder: (context, snapshot) {
                                        final mediaState = snapshot.data;

                                        return Container(
                                            height: 20,
                                            child: Slider(
                                              value: (mediaState?.position
                                                              .inMilliseconds
                                                              .toDouble() ??
                                                          0.0) >
                                                      (mediaState
                                                              ?.mediaItem
                                                              ?.duration
                                                              ?.inMilliseconds
                                                              .toDouble() ??
                                                          1.0)
                                                  ? (mediaState
                                                          ?.mediaItem
                                                          ?.duration
                                                          ?.inMilliseconds
                                                          .toDouble() ??
                                                      1.0)
                                                  : (mediaState?.position
                                                          .inMilliseconds
                                                          .toDouble() ??
                                                      0.0),
                                              max: mediaState?.mediaItem
                                                      ?.duration?.inMilliseconds
                                                      .toDouble() ??
                                                  1.0,
                                              onChanged: (value) {
                                                _audioHandler.seek(Duration(
                                                    milliseconds:
                                                        value.toInt()));
                                              },
                                            ));

                                        // return Text(
                                        //   '${mediaState?.position.inSeconds} / ${mediaState?.mediaItem?.duration?.inSeconds}',
                                        // );
                                      },
                                    ),
                                  ],
                                )),
                            Container(
                              width: 50,
                              height: 50,
                              child: Center(
                                child: playing
                                    ? _button(Icons.pause, _audioHandler.pause)
                                    : _button(
                                        Icons.play_arrow, _audioHandler.play),
                              ),
                            )
                          ],
                        );
                      },
                    ),

                    // Display the processing state.
                    // StreamBuilder<AudioProcessingState>(
                    //   stream: _audioHandler.playbackState
                    //       .map((state) => state.processingState)
                    //       .distinct(),
                    //   builder: (context, snapshot) {
                    //     final processingState =
                    //         snapshot.data ?? AudioProcessingState.idle;
                    //     return Text(
                    //         // ignore: deprecated_member_use
                    //         "Processing state: ${describeEnum(processingState)}");
                    //   },
                    // ),
                  ],
                ),
              ));
        }
      },
    );
  }

  Stream<MediaState> get _mediaStateStream =>
      Rx.combineLatest2<MediaItem?, Duration, MediaState>(
          _audioHandler.mediaItem,
          AudioService.position,
          (mediaItem, position) => MediaState(mediaItem, position));

  IconButton _button(IconData iconData, VoidCallback onPressed) => IconButton(
        icon: Icon(iconData),
        iconSize: 34.0,
        alignment: Alignment.center,
        onPressed: onPressed,
      );
}

class MediaState {
  final MediaItem? mediaItem;
  final Duration position;

  MediaState(this.mediaItem, this.position);
}

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  /// Initialise our audio handler.
  static final _item = MediaItem(
    id: 'https://s.040905.xyz/d/v/temp/%E5%91%A8%E6%9D%B0%E4%BC%A6%20-%20%E6%9C%80%E4%BC%9F%E5%A4%A7%E7%9A%84%E4%BD%9C%E5%93%81%20%5Bmqms2%5D.mp3?sign=fNa5fJ-EtPzcIs_UlZYKYrjNgKhbYy7pKAgpcLEKC6M=:0',
    // album: "Science Friday",
    title: "test",
    // artist: "Science Friday and WNYC Studios",
    // duration: Duration(milliseconds: 5739820),
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
    _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        onPlaybackCompleted();
      }
    });
  }
  // void change_playbackstate(PlaybackState _playbackState) {
  void change_playbackstate(MediaItem _item) {
    // All options shown:
    // playbackState.add(_playbackState);
    mediaItem.add(_item);
  }
  // In this simple example, we handle only 4 actions: play, pause, seek and
  // stop. Any button press from the Flutter UI, notification, lock screen or
  // headset will be routed through to these 4 methods so that you can handle
  // your audio playback logic in one place.

  // @override
  // Future<void> play() => _player.play();
  @override
  Future<void> play() async {
    final currentMediaItem = mediaItem.value;
    if (currentMediaItem != null) {
      final title = currentMediaItem.title;
      print('Playing: $title');
      // 在这里添加你需要的逻辑
      if (title == 'test') {
        try {
          playmode = await get_player_settings("playmode");
        } catch (e) {
          playmode = 0;
        }

        await set_player_settings("playmode", playmode);

        final track = await getnowplayingsong();
        if (track['index'] != -1) {
          await playsong(track['track']);
        } else {
          _player.play();
        }
      } else {
        _player.play();
      }
    } else {
      _player.play();
    }
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToPrevious() async {
    final current_playing = await get_current_playing();
    final nowplaying_track = await getnowplayingsong();
    if (nowplaying_track['index'] != -1) {
      final index = nowplaying_track['index'];
      switch (playmode) {
        case 0:
          index - 1 >= 0
              ? await playsong(current_playing[index - 1])
              : await playsong(current_playing[current_playing.length - 1]);
          break;
        case 1:
          if (randommodetemplist.contains(current_playing[index])) {
            randommodetemplist.remove(current_playing[index]);
            for (var i = randommodetemplist.length - 1; i >= 0; i--) {
              if (current_playing.contains(randommodetemplist[i])) {
                await playsong(randommodetemplist[i]);
                return;
              }
            }
          }
          final randomIndex = (current_playing.length *
                  (DateTime.now().millisecondsSinceEpoch % 1000) /
                  1000)
              .floor();
          await playsong(current_playing[randomIndex]);
          break;
        case 2:
          await playsong(current_playing[index]);
          break;
        default:
          break;
      }
    }
  }

  @override
  Future<void> skipToNext() async {
    final current_playing = await get_current_playing();
    final nowplaying_track = await getnowplayingsong();
    if (nowplaying_track['index'] != -1) {
      final index = nowplaying_track['index'];
      switch (playmode) {
        case 0:
          index + 1 < current_playing.length
              ? await playsong(current_playing[index + 1])
              : await playsong(current_playing[0]);
          break;
        case 1:
          final randomIndex = (current_playing.length *
                  (DateTime.now().millisecondsSinceEpoch % 1000) /
                  1000)
              .floor();
          await playsong(current_playing[randomIndex]);
          break;
        case 2:
          index + 1 < current_playing.length
              ? await playsong(current_playing[index + 1])
              : await playsong(current_playing[0]);
          break;
        default:
          break;
      }
    }
  }

  @override
  Future<void> stop() async {
    try {
      playmode = await get_player_settings("playmode");
    } catch (e) {
      playmode = 0;
    }
    playmode = (playmode + 1) % 3;
    await set_player_settings("playmode", playmode);
  }

  /// Transform a just_audio event into an audio_service state.
  ///
  /// This method is used from the constructor. Every event received from the
  /// just_audio player will be transformed into an audio_service state so that
  /// it can be broadcast to audio_service clients.

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.skipToPrevious,
        MediaControl.stop,
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
