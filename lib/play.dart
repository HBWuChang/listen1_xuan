// import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:listen1_xuan/bodys.dart';
import 'package:listen1_xuan/main.dart';
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
import 'myplaylist.dart';
import 'package:vibration/vibration.dart';
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:math';
import 'animations.dart';

class FileLogOutput extends LogOutput {
  final File file;

  FileLogOutput(this.file);

  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      file.writeAsStringSync('${DateTime.now()}: $line\n',
          mode: FileMode.append);
    }
  }
}

final Logger playlogger = Logger(
    level: Level.all,
    output: FileLogOutput(
        File('/data/user/0/com.xiebian.listen1_xuan/cache/app.log')));

final music_player = AudioPlayer();
late AudioHandler _audioHandler;
int playmode = 0;
List<Map<String, dynamic>> randommodetemplist = [];

Future<void> onPlaybackCompleted([bool force_next = false]) async {
  try {
    playmode = await get_player_settings("playmode");
  } catch (e) {
    playmode = 0;
    await set_player_settings("playmode", playmode);
  }

  final current_playing = await get_current_playing();
  final nowplaying_track = await getnowplayingsong();
  playlogger.d('onPlaybackCompleted');
  playlogger.d(nowplaying_track);
  if (current_playing.length == 1 && force_next) {
    return;
  }
  if (nowplaying_track['index'] != -1) {
    final index = nowplaying_track['index'];
    switch (playmode) {
      case 0:
        index + 1 < current_playing.length
            ? await playsong(current_playing[index + 1])
            : await playsong(current_playing[0]);
        break;
      case 1:
        // final randomIndex = (current_playing.length *
        //         (DateTime.now().millisecondsSinceEpoch % 1000) /
        //         1000)
        //     .floor();

        final random = Random();
        final randomIndex = random.nextInt(current_playing.length);
        // if (randommodetemplist.contains(current_playing[index])) {
        //   randommodetemplist.remove(current_playing[index]);
        // }
        for (var i = randommodetemplist.length - 1; i >= 0; i--) {
          if (randommodetemplist[i]['id'] == current_playing[index]['id']) {
            randommodetemplist.removeAt(i);
            break;
          }
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
        await music_player.seek(Duration.zero);
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
      final tempDir = await getApplicationDocumentsDirectory();
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

// Future<void> clean_local_cache([bool all = false]) async {
Future<void> clean_local_cache([bool all = false, String id = '']) async {
  if (id != '') {
    String path = await get_local_cache(id);
    if (path != '') {
      await File(path).delete();
      Fluttertoast.showToast(
        msg: '已清理',
      );
      return;
    }
    Fluttertoast.showToast(
      msg: '没有可清理的缓存文件',
    );
    return;
  }

  List<String> without = [
    'app.log',
  ];
  final prefs = await SharedPreferences.getInstance();
  final local_cache_list_json = prefs.getString('local-cache-list');
  final tempDir = await getApplicationDocumentsDirectory();
  final tempPath = tempDir.path;

  // 列出文件夹下的所有文件
  final filesanddirs = Directory(tempPath).listSync();
  List<String> files = [];
  for (var file in filesanddirs) {
    if (file is File && !without.contains(file.path.split('/').last)) {
      files.add(file.path);
    }
  }
  int count = 0;
  if (local_cache_list_json != null) {
    final local_cache_list = jsonDecode(local_cache_list_json);
    for (var file in files) {
      if (all) {
        await File(file).delete();
        count++;
      } else {
        bool flag = true;
        for (var key in local_cache_list.keys) {
          if (local_cache_list[key] == file.split('/').last) {
            flag = false;
            break;
          }
        }
        print(file.split('/').last);
        if (flag) {
          await File(file).delete();
          count++;
        }
      }
    }
  } else {
    for (var file in files) {
      await File(file).delete();
      count++;
    }
  }
  if (count > 0) {
    Fluttertoast.showToast(
      msg: '清理了$count个缓存文件',
    );
  } else {
    Fluttertoast.showToast(
      msg: '没有可清理的缓存文件',
    );
  }
  if (all) {
    await prefs.remove('local-cache-list');
  } else {
    if (local_cache_list_json != null) {
      final local_cache_list = jsonDecode(local_cache_list_json);
      for (var key in local_cache_list.keys) {
        if (!files.contains('$tempPath/${local_cache_list[key]}')) {
          local_cache_list.remove(key);
        }
      }
      await prefs.setString('local-cache-list', jsonEncode(local_cache_list));
    }
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

Future<void> change_playback_state(dynamic track) async {
  try {
    playlogger.d('开始更新播放状态');
    // 使用 Completer 来等待 _duration 被赋值
    final Completer<void> completer = Completer<void>();
    music_player.durationStream.listen((duration) {
      if (duration != null && !completer.isCompleted) {
        // print('音频文件时长: ${duration.inSeconds}秒');
        completer.complete();
      }
    });

    // 等待 _duration 被赋值
    await completer.future;
    // 获取音频文件的时长

    final _duration = await music_player.duration;
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
    playlogger.d('更新播放状态成功');
  } catch (e) {
    playlogger.e('更新播放状态失败');
    playlogger.e(e);
  }
}

// Future<void> playsong(Map<String, dynamic> track) async {
Future<void> playsong(Map<String, dynamic> track,
    [start = true, on_playersuccesscallback = false]) async {
  try {
    if (on_playersuccesscallback &&
        (await get_player_settings("nowplaying_track_id") != track['id'])) {
      return;
    }
    await set_player_settings("nowplaying_track_id", track['id']);
    await add_current_playing([track]);
    final tdir = await get_local_cache(track['id']);
    playlogger.d('playsong');
    playlogger.d(track);
    playlogger.d(tdir);
    if (tdir == "") {
      MediaService.bootstrapTrack(
          track, playerSuccessCallback, playerFailCallback);
      return;
    }
    await music_player.setFilePath(tdir);
    double t_volume = 100;
    try {
      t_volume = await get_player_settings("volume");
    } catch (e) {
      t_volume = 100;
      await set_player_settings("volume", t_volume);
    }
    music_player.setVolume(t_volume / 100);
    if (start) {
      music_player.play();
    }
    await change_playback_state(track);
  } catch (e, stackTrace) {
    playlogger.e('播放失败!!!!');
    playlogger.e(e);
    playlogger.e(stackTrace);
  }
}

Future<void> playerSuccessCallback(dynamic res, dynamic track) async {
  print('playerSuccessCallback');
  print(res);
  print(track);
  playlogger.d('playerSuccessCallback');
  playlogger.d(res);
  playlogger.d(track);
  try {
    final tempDir = await getApplicationDocumentsDirectory();
    final tempPath = tempDir.path;
    final _local_cache = await get_local_cache(track['id']);
    if (_local_cache == '') {
      // 获取应用程序的临时目录
      // final fileName = res['url'].split('/').last.split('?').first;
      // 根据.定位文件后缀名
      String fileName = res['url']
              .split('.')[res['url'].split('.').length - 2]
              .split('/')
              .last +
          '.' +
          res['url'].split('.').last.split('?').first;
      // switch (res["platform"]) {
      //   case "bilibili":
      //     fileName = fileName + '.mp3';
      // }
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
    playsong(track, true, true);
    return;
  } catch (e) {
    print('Error downloading or playing audio: $e');
    playlogger.e('Error downloading or playing audio: $e');
    playerFailCallback(track);
  }
}

Future<void> playerFailCallback(dynamic track) async {
  print('playerFailCallback');
  print(track);
  // {id: netrack_2084034562, title: Anytime Anywhere, artist: milet, artist_id: neartist_31464106, album: Anytime Anywhere, album_id: nealbum_175250775, source: netease, source_url: https://music.163.com/#/song?id=2084034562, img_url: https://p1.music.126.net/11p2mKi5CMKJvAS43ulraQ==/109951168930518368.jpg, sourceName: 网易, $$hashKey: object:2884, disabled: false, index: 365, playNow: true, bitrate: 320kbps, platform: netease, platformText: 网易}
  playlogger.e('playerFailCallback');
  Fluttertoast.showToast(
    msg: '播放失败：${track['title']}',
  );
  if (await get_player_settings("nowplaying_track_id") != track['id']) {
    return;
  }
  var connectivityResult = await (Connectivity().checkConnectivity());
  playlogger.d(connectivityResult);
  while (connectivityResult == ConnectivityResult.none) {
    connectivityResult = await (Connectivity().checkConnectivity());
    playlogger.d(connectivityResult);
    // 等待三秒
    await Future.delayed(Duration(seconds: 3));
  }
  if (playmode == 1) {
    playlogger.d(randommodetemplist);
    if (randommodetemplist.length - 1 > 0) {
      randommodetemplist.removeAt(randommodetemplist.length - 1);
    }
  }

  onPlaybackCompleted(true);
}

Future<void> fresh_playmode() async {
  try {
    playmode = await get_player_settings("playmode");
  } catch (e) {
    playmode = 0;
    await set_player_settings("playmode", playmode);
  }
}

Future<void> setNotification() async {
  print('setNotification');
  if (Platform.isWindows) {
    // Windows-specific code
  } else {
    // Non-Windows code
  }
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
    await fresh_playmode();
    update_playmode_to_audio_service();
    final track = await getnowplayingsong();
    if (track['index'] != -1) {
      await playsong(track['track'], false);
    }
  }
}

var playmode_setstate;
bool change_p = false;

class Play extends StatefulWidget {
  final Function(String, {bool is_my, String search_text}) onPlaylistTap;
  bool horizon = false;
  Play({required this.onPlaylistTap, this.horizon = false});
  @override
  _PlayState createState() => _PlayState();
}

class _PlayState extends State<Play> {
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return hours > 0
        ? '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}'
        : '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  double _currentVolume = 0.5;

  @override
  void initState() {
    super.initState();
    get_vo();
  }

  void get_vo() async {
    try {
      _currentVolume = await get_player_settings("volume");
    } catch (e) {
      _currentVolume = 50;
    }
    _currentVolume = _currentVolume / 100;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // return PlayerWidget(player: player);
    return FutureBuilder<void>(
      future: setNotification(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: global_loading_anime);
        } else if (snapshot.hasError) {
          return Center(child: Text('Error initializing audio handler'));
        } else {
          return GestureDetector(
              onTap: () async {
                if (!widget.horizon) {
                  main_showVolumeSlider();
                }
                final track = await getnowplayingsong();
                var ret = await song_dialog(
                    context, track['track'], widget.onPlaylistTap);
                if (ret != null) {
                  if (ret["push"] != null) {
                    clean_top_context();
                    Navigator.of(top_context.last).push(
                      MaterialPageRoute(
                        builder: (context) => PlaylistInfo(
                          listId: ret["push"],
                          onPlaylistTap: widget.onPlaylistTap,
                          is_my: false,
                        ),
                      ),
                    );
                  }
                }
              },
              onDoubleTap: () {
                // if (_player.playing) MediaControl.pause else MediaControl.play,
                Vibration.vibrate(duration: 100);
                if (music_player.playing) {
                  // (_audioHandler as AudioPlayerHandler).pause();
                  global_pause();
                } else {
                  // (_audioHandler as AudioPlayerHandler).play();
                  global_play();
                }
              },
              onLongPress: () {
                Vibration.vibrate(duration: 100);
                global_change_play_mode();
              },
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null) {
                  Vibration.vibrate(duration: 100);

                  if (details.primaryVelocity! > 0) {
                    // _playPrevious(); // 向右滑动，播放上一首
                    // (_audioHandler as AudioPlayerHandler).skipToPrevious();
                    global_skipToPrevious();
                  } else if (details.primaryVelocity! < 0) {
                    // _playNext(); // 向左滑动，播放下一首
                    // (_audioHandler as AudioPlayerHandler).skipToNext();
                    global_skipToNext();
                  }
                }
              },
              child: Container(
                height: widget.horizon ? 60 : 80,
                child: widget.horizon
                    ? Center(
                        child: StreamBuilder<bool>(
                          stream: _audioHandler.playbackState
                              .map((state) => state.playing)
                              .distinct(),
                          builder: (context, snapshot) {
                            final playing = snapshot.data ?? false;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  child: Center(
                                    // 上一首
                                    child: _button(Icons.skip_previous, () {
                                      global_skipToPrevious();
                                    }),
                                  ),
                                ),
                                Container(
                                  width: 50,
                                  height: 50,
                                  child: Center(
                                    child: playing
                                        ? _button(Icons.pause, () {
                                            if (music_player.playing) {
                                              global_pause();
                                            } else {
                                              global_play();
                                            }
                                          })
                                        : _button(Icons.play_arrow, () {
                                            if (music_player.playing) {
                                              global_pause();
                                            } else {
                                              global_play();
                                            }
                                          }),
                                  ),
                                ),
                                Container(
                                  width: 50,
                                  height: 50,
                                  child: Center(
                                    // 上一首
                                    child: _button(Icons.skip_next, () {
                                      global_skipToNext();
                                    }),
                                  ),
                                ),
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
                                        errorWidget: (context, url, error) =>
                                            Icon(
                                          Icons.music_note,
                                          size: 50,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                Container(
                                    width: (MediaQuery.of(context).size.width -
                                        500),
                                    height: 50,
                                    child: Column(
                                      children: [
                                        Container(
                                          height: 20,
                                          child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  flex: 5,
                                                  child:
                                                      StreamBuilder<MediaItem?>(
                                                    stream:
                                                        _audioHandler.mediaItem,
                                                    builder:
                                                        (context, snapshot) {
                                                      final mediaItem =
                                                          snapshot.data;
                                                      return Marquee(
                                                        text: (mediaItem
                                                                    ?.title ??
                                                                'null') +
                                                            '  -  ' +
                                                            (mediaItem
                                                                    ?.artist ??
                                                                'null'),
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                        blankSpace: 20.0,
                                                        velocity: 50.0,
                                                        pauseAfterRound:
                                                            Duration(
                                                                seconds: 1),
                                                        startPadding: 10.0,
                                                      );
                                                    },
                                                  ),
                                                ),
                                                Container(
                                                  width: 120,
                                                  child:
                                                      StreamBuilder<MediaState>(
                                                    stream: _mediaStateStream,
                                                    builder:
                                                        (context, snapshot) {
                                                      final mediaItem =
                                                          snapshot.data;
                                                      return Center(
                                                          child: FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        child: Text(
                                                          (formatDuration(mediaItem
                                                                      ?.position ??
                                                                  Duration
                                                                      .zero) +
                                                              ' / ' +
                                                              formatDuration(mediaItem
                                                                      ?.mediaItem
                                                                      ?.duration ??
                                                                  Duration
                                                                      .zero)),
                                                          style: TextStyle(
                                                              fontSize: 20.0),
                                                        ),
                                                      ));
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
                                                  value: (mediaState
                                                                  ?.position.inMilliseconds
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
                                                  max: mediaState
                                                          ?.mediaItem
                                                          ?.duration
                                                          ?.inMilliseconds
                                                          .toDouble() ??
                                                      1.0,
                                                  onChanged: (value) {
                                                    global_seek(Duration(
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
                                IconButton(
                                  icon: Icon(Icons.list),
                                  onPressed: () async {
                                    final track = await getnowplayingsong();
                                    var ret = await song_dialog(context,
                                        track['track'], widget.onPlaylistTap);
                                    if (ret != null) {
                                      if (ret["push"] != null) {
                                        clean_top_context();
                                        Navigator.of(top_context.last).push(
                                          MaterialPageRoute(
                                            builder: (context) => PlaylistInfo(
                                              listId: ret["push"],
                                              onPlaylistTap:
                                                  widget.onPlaylistTap,
                                              is_my: false,
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                                StatefulBuilder(
                                  builder: (context, setState) {
                                    playmode_setstate = setState;
                                    return IconButton(
                                      icon: switch (playmode) {
                                        0 => Icon(Icons.repeat),
                                        1 => Icon(Icons.shuffle),
                                        2 => Icon(Icons.repeat_one),
                                        _ => Icon(Icons.error), // 默认情况
                                      },
                                      onPressed: () {
                                        setState(() {
                                          global_change_play_mode();
                                        });
                                      },
                                    );
                                  },
                                ),
                                Stack(
                                  children: [
                                    // 强行移动的图标
                                    Positioned(
                                      top: 18, // 距离顶部 50 像素
                                      left: 0, // 距离左侧 100 像素
                                      child: Icon(
                                        Icons.volume_up,
                                        size: 24, // 图标大小
                                      ),
                                    ),
                                    // 其他控件
                                    StatefulBuilder(
                                      builder: (context, setState) {
                                        return Slider(
                                          value: _currentVolume,
                                          onChanged: (value) {
                                            setState(() {
                                              _currentVolume = value;
                                            });
                                            set_player_settings(
                                                "volume", value * 100);
                                            music_player.setVolume(value);
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      )
                    : Center(
                        child: StreamBuilder<bool>(
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
                                        errorWidget: (context, url, error) =>
                                            Icon(
                                          Icons.music_note,
                                          size: 50,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                Container(
                                    // width: MediaQuery.of(context).size.width - 100,
                                    width: (MediaQuery.of(context).size.width -
                                        100),
                                    height: 50,
                                    child: Column(
                                      children: [
                                        Container(
                                          height: 20,
                                          child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  flex: 5,
                                                  child:
                                                      StreamBuilder<MediaItem?>(
                                                    stream:
                                                        _audioHandler.mediaItem,
                                                    builder:
                                                        (context, snapshot) {
                                                      final mediaItem =
                                                          snapshot.data;
                                                      return Marquee(
                                                        text: (mediaItem
                                                                    ?.title ??
                                                                'null') +
                                                            '  -  ' +
                                                            (mediaItem
                                                                    ?.artist ??
                                                                'null'),
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                        blankSpace: 20.0,
                                                        velocity: 50.0,
                                                        pauseAfterRound:
                                                            Duration(
                                                                seconds: 1),
                                                        startPadding: 10.0,
                                                      );
                                                    },
                                                  ),
                                                ),
                                                Container(
                                                  width: 150,
                                                  child:
                                                      StreamBuilder<MediaState>(
                                                    stream: _mediaStateStream,
                                                    builder:
                                                        (context, snapshot) {
                                                      final mediaItem =
                                                          snapshot.data;
                                                      return Center(
                                                          child: FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        child: Text(
                                                          (formatDuration(mediaItem
                                                                      ?.position ??
                                                                  Duration
                                                                      .zero) +
                                                              ' / ' +
                                                              formatDuration(mediaItem
                                                                      ?.mediaItem
                                                                      ?.duration ??
                                                                  Duration
                                                                      .zero)),
                                                          style: TextStyle(
                                                              fontSize: 20.0),
                                                        ),
                                                      ));
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
                                                  value: (mediaState
                                                                  ?.position.inMilliseconds
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
                                                  max: mediaState
                                                          ?.mediaItem
                                                          ?.duration
                                                          ?.inMilliseconds
                                                          .toDouble() ??
                                                      1.0,
                                                  onChanged: (value) {
                                                    global_seek(Duration(
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
                                        // ? _button(Icons.pause, global_pause)
                                        // : _button(Icons.play_arrow, global_play),
                                        ? _button(Icons.pause, () {
                                            if (music_player.playing) {
                                              global_pause();
                                            } else {
                                              global_play();
                                            }
                                          })
                                        : _button(Icons.play_arrow, () {
                                            if (music_player.playing) {
                                              global_pause();
                                            } else {
                                              global_play();
                                            }
                                          }),
                                  ),
                                )
                              ],
                            );
                          },
                        ),
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

Future<void> global_play() async {
  music_player.play();
}

Future<void> global_pause() async {
  music_player.pause();
}

Future<void> global_seek(Duration position) async {
  music_player.seek(position);
}

Future<void> global_skipToPrevious() async {
  await fresh_playmode();

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
        try {
          await playsong(randommodetemplist[randommodetemplist.length - 1]);
          randommodetemplist.removeAt(randommodetemplist.length - 1);
          return;
        } catch (e) {
          print(e);
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

Future<void> global_skipToNext() async {
  await onPlaybackCompleted(true);
}

Future<void> update_playmode_to_audio_service() async {
  try {
    switch (playmode) {
      case 0:
        await _audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
        break;
      case 1:
        await _audioHandler.setRepeatMode(AudioServiceRepeatMode.group);
        break;
      case 2:
        await _audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
        break;
      default:
        break;
    }
  } catch (e) {
    print(e);
  }
}

Future<int> global_change_play_mode() async {
  change_p = true;
  await fresh_playmode();
  playmode_setstate(() {
    playmode = (playmode + 1) % 3;
  });
  await set_player_settings("playmode", playmode);
  update_playmode_to_audio_service();
  return playmode;
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
        'https://s.040905.xyz/d/v/business-spirit-unit.gif?sign=uDy2k6zQMaZr8CnNBem03KTPdcQGX-JVOIRcEBcVOhk=:0'),
  );
  AudioPlayerHandler() {
    // So that our clients (the Flutter UI and the system notification) know
    // what state to display, here we set up our audio handler to broadcast all
    // playback state changes as they happen via playbackState...
    music_player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    // ... and also the current media item via mediaItem.
    mediaItem.add(_item);

    // Load the player.
    music_player.setAudioSource(AudioSource.uri(Uri.parse(_item.id)),
        preload: false);
    music_player.playerStateStream.listen((playerState) {
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
  Future<void> play() => global_play();

  // @override
  // Future<void> pause() => music_player.pause();
  @override
  Future<void> pause() => global_pause();

  @override
  Future<void> seek(Duration position) => global_seek(position);
  @override
  Future<void> skipToPrevious() => global_skipToPrevious();

  @override
  Future<void> skipToNext() => global_skipToNext();

  // @override
  // Future<void> stop() async {
  //   await global_change_play_mode();
  // }

  // @override
  // Future<void> stop() => global_change_play_mode();
  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    if (change_p) {
      change_p = false;
      return;
    }
    // await music_player.setRepeatMode(repeatMode);
    await global_change_play_mode();
  }

  /// Transform a just_audio event into an audio_service state.
  ///
  /// This method is used from the constructor. Every event received from the
  /// just_audio player will be transformed into an audio_service state so that
  /// it can be broadcast to audio_service clients.

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (music_player.playing) MediaControl.pause else MediaControl.play,
        // MediaControl.pause,
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
      }[music_player.processingState]!,
      playing: music_player.playing,
      updatePosition: music_player.position,
      bufferedPosition: music_player.bufferedPosition,
      speed: music_player.speed,
      queueIndex: event.currentIndex,
    );
  }
}
