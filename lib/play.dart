import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_lyric/lyrics_reader_model.dart';
import 'package:iconify_flutter_plus/icons/wi.dart';
import 'package:listen1_xuan/bodys.dart';
import 'package:listen1_xuan/controllers/controllers.dart';
import 'package:listen1_xuan/controllers/nowplaying_controller.dart';
import 'package:listen1_xuan/main.dart';
import 'dart:io';
import 'dart:convert';
import 'package:extended_image/extended_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:media_kit/generated/libmpv/bindings.dart';
import 'package:rxdart/rxdart.dart' as rxdart;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:window_manager/window_manager.dart';
import 'controllers/audioHandler_controller.dart';
import 'controllers/play_controller.dart';
import 'controllers/lyric_controller.dart';
import 'controllers/cache_controller.dart';
import 'controllers/websocket_card_controller.dart';
import 'funcs.dart';
import 'loweb.dart';
import 'package:vibration/vibration.dart';
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:math';
import 'global_settings_animations.dart';
import 'package:smtc_windows/smtc_windows.dart';
import 'package:windows_taskbar/windows_taskbar.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:badges/badges.dart' as badges;

part 'pages/play/play_v.dart';
part 'pages/play/play_h.dart';
part 'pages/play/play_widgets.dart';

// Windows Taskbar API 调用的安全包装器
// 用于处理窗口未初始化的情况
bool _windowsTaskbarInitialized = false;

Future<bool> safeCallWindowsTaskbar(
  Future<void> Function() apiCall,
  String operationName,
) async {
  if (!is_windows) return true;

  // 如果已经初始化过,直接调用
  if (_windowsTaskbarInitialized) {
    try {
      await apiCall();
      return true;
    } catch (e) {
      debugPrint('WindowsTaskbar.$operationName 调用失败: $e');
      return false;
    }
  }

  // 首次调用,需要验证
  try {
    await apiCall();
    _windowsTaskbarInitialized = true;
    debugPrint('WindowsTaskbar.$operationName 调用成功，已标记为初始化');
    return true;
  } catch (e) {
    debugPrint('WindowsTaskbar.$operationName 调用失败(窗口可能未初始化): $e');
    return false;
  }
}

class FileLogOutput extends LogOutput {
  final File file;

  FileLogOutput(this.file);

  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      file.writeAsStringSync(
        '${DateTime.now()}: $line\n',
        mode: FileMode.append,
      );
    }
  }
}

var playmode = 0.obs;
List<Track> randommodetemplist = [];
bool randomTrackInsertAtHead = false;
Future<void> onPlaybackCompleted([bool force_next = false]) async {
  await fresh_playmode();
  final current_playing = await get_current_playing();
  final nowplaying_track = await getnowplayingsong();
  debugPrint('onPlaybackCompleted');
  debugPrint(nowplaying_track.toString());
  if (current_playing.length == 1 && force_next) {
    return;
  }
  if (Get.find<PlayController>().nextTrack != null) {
    await playsong(Get.find<PlayController>().nextTrack!);
    Get.find<PlayController>().nextTrack = null;
    return;
  }
  if (nowplaying_track['index'] != -1) {
    final index = nowplaying_track['index'];
    switch (playmode.value) {
      case 0:
        index + 1 < current_playing.length
            ? await playsong(current_playing[index + 1])
            : await playsong(current_playing[0]);
        break;
      case 1:
        int t = randommodetemplist
            .map((e) => e.id)
            .toList()
            .indexOf(nowplaying_track['track'].id);
        if (t != randommodetemplist.length - 1 && t != -1) {
          Track tt = randommodetemplist[t + 1];
          if (current_playing.any((element) => element.id == tt.id)) {
            await playsong(tt);
            return;
          }
        }
        final random = Random();
        final randomIndex = random.nextInt(current_playing.length);
        Track track = current_playing[randomIndex];
        randommodetemplist.removeWhere((element) => element.id == track.id);
        await playsong(track);
        break;
      case 2:
        if (force_next) {
          index + 1 < current_playing.length
              ? await playsong(current_playing[index + 1])
              : await playsong(current_playing[0]);
          break;
        }
        await Get.find<PlayController>().music_player.seek(Duration.zero);
        break;
      default:
        break;
    }
  }
}

Future<String> get_local_cache(String id) async {
  return await Get.find<CacheController>().getLocalCache(id);
}

Future<void> set_local_cache(String id, String path) async {
  Get.find<CacheController>().setLocalCache(id, path);
}

// Future<void> clean_local_cache([bool all = false]) async {
Future<void> clean_local_cache([bool all = false, String id = '']) async {
  await Get.find<CacheController>().cleanLocalCache(all, id);
}

void add_current_playing(List<Track> tracks) {
  Get.find<PlayController>().add_current_playing(tracks);
}

void set_current_playing(List<Track> tracks) async {
  Get.find<PlayController>().set_current_playing(tracks);
}

List<Track> get_current_playing() {
  return Get.find<PlayController>().current_playing;
}

Future<Map<String, dynamic>> getnowplayingsong() async {
  final nowplaying_track_id = Get.find<PlayController>().getPlayerSettings(
    "nowplaying_track_id",
  );
  final current_playing = await get_current_playing();
  for (var track in current_playing) {
    if (track.id == nowplaying_track_id) {
      return {'track': track, 'index': current_playing.indexOf(track)};
    }
  }
  return {'track': {}, 'index': -1};
}

Future<void> bind_smtc() async {
  try {
    if (is_windows)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          smtc.buttonPressStream.listen((event) {
            switch (event) {
              case PressedButton.play:
                smtc.setPlaybackStatus(PlaybackStatus.playing);
                global_play();
                break;
              case PressedButton.pause:
                smtc.setPlaybackStatus(PlaybackStatus.paused);
                global_pause();
                break;
              case PressedButton.next:
                print('Next');
                global_skipToNext();
                break;
              case PressedButton.previous:
                print('Previous');
                global_skipToPrevious();
                break;
              case PressedButton.stop:
                global_change_play_mode();
                break;
              default:
                break;
            }
          });
        } catch (e) {
          debugPrint("Error: $e");
        }
      });
  } catch (e) {
    debugPrint('绑定SMTC失败');
    debugPrint(e.toString());
  }
}

MediaItem? _currentMediaItem;
Future<void> change_playback_state(
  Track? track, {
  LyricsLineModel? lyric,
}) async {
  try {
    if (lyric != null) {
      if (_currentMediaItem == null) return;
      MediaItem _item = _currentMediaItem!.copyWith(
        displayTitle: lyric.mainText,
        // displaySubtitle: lyric.extText,
      );
      if (Get.find<SettingsController>().showLyricTranslation.value) {
        _item = _item.copyWith(
          displaySubtitle: lyric.hasExt ? lyric.extText : null,
        );
      }
      (Get.find<AudioHandlerController>().audioHandler as AudioPlayerHandler)
          .change_playbackstate(_item);
      return;
    }
    if (track == null) return;
    debugPrint('开始更新播放状态');
    broadcastWs();
    // 使用 Completer 来等待 _duration 被赋值
    final Completer<void> completer = Completer<void>();
    Get.find<PlayController>().music_player.durationStream.listen((duration) {
      if (duration != null && !completer.isCompleted) {
        // print('音频文件时长: ${duration.inSeconds}秒');
        completer.complete();
      }
    });

    // 等待 _duration 被赋值
    await completer.future;
    // 获取音频文件的时长

    final _duration = await Get.find<PlayController>().music_player.duration;
    MediaItem _item;
    _item = MediaItem(
      id: track.id,
      title: track.title!,
      artist: track.artist,
      artUri: Uri.parse(
        track.img_url == null
            ? 'https://s.040905.xyz/d/v/business-spirit-unit.gif?sign=uDy2k6zQMaZr8CnNBem03KTPdcQGX-JVOIRcEBcVOhk=:0'
            : track.img_url!,
      ),
      duration: _duration,
    );
    _currentMediaItem = _item;
    (Get.find<AudioHandlerController>().audioHandler as AudioPlayerHandler)
        .change_playbackstate(_item);
    // smtc.updateMetadata(
    //   const MusicMetadata(
    //     title: 'Title',
    //     album: 'Album',
    //     albumArtist: 'Album Artist',
    //     artist: 'Artist',
    //     thumbnail:
    //         'https://media.glamour.com/photos/5f4c44e20c71c58fc210d35f/master/w_2560%2Cc_limit/mgid_ao_image_mtv.jpg',
    //   ),
    // );
    if (is_windows) {
      safeCallWindowsTaskbar(
        () =>
            WindowsTaskbar.setWindowTitle('${track.title!} - ${track.artist!}'),
        'setWindowTitle',
      );
      try {
        smtc.updateMetadata(
          MusicMetadata(
            title: track.title!,
            album: track.album!,
            albumArtist: track.artist!,
            artist: track.artist!,
            thumbnail: track.img_url == null
                ? 'https://s.040905.xyz/d/v/business-spirit-unit.gif?sign=uDy2k6zQMaZr8CnNBem03KTPdcQGX-JVOIRcEBcVOhk=:0'
                : track.img_url!,
          ),
        );
      } catch (e) {
        smtc = SMTCWindows(
          metadata: MusicMetadata(
            title: track.title!,
            album: track.album!,
            albumArtist: track.artist!,
            artist: track.artist!,
            thumbnail: track.img_url == null
                ? 'https://s.040905.xyz/d/v/business-spirit-unit.gif?sign=uDy2k6zQMaZr8CnNBem03KTPdcQGX-JVOIRcEBcVOhk=:0'
                : track.img_url!,
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
      await bind_smtc();
    }
    debugPrint('更新播放状态成功');
  } catch (e) {
    debugPrint('更新播放状态失败');
    debugPrint(e.toString());
  }
}

// Future<void> playsong(Map<String, dynamic> track) async {
Future<void> playsong(
  Track track, [
  start = true,
  on_playersuccesscallback = false,
  bool isByClick = false,
]) async {
  try {
    if (on_playersuccesscallback &&
        (Get.find<PlayController>().getPlayerSettings("nowplaying_track_id") !=
            track.id)) {
      return;
    }
    Get.find<PlayController>().setPlayerSetting(
      "nowplaying_track_id",
      track.id,
    );
    add_current_playing([track]);
    Get.find<NowPlayingController>().scrollToCurrentTrack();
    final tdir = await get_local_cache(track.id);
    debugPrint('playsong');
    debugPrint(track.toString());
    debugPrint(tdir);
    if (tdir == "") {
      MediaService.bootstrapTrack(
        track,
        playerSuccessCallback,
        playerFailCallback,
      );
      return;
    }
    await Get.find<PlayController>().music_player.setFilePath(tdir);

    if (!randommodetemplist.any((element) => element.id == track.id)) {
      if (randomTrackInsertAtHead) {
        randommodetemplist.insert(0, track);
        randomTrackInsertAtHead = false;
      } else {
        randommodetemplist.add(track);
      }
    } else if (isByClick) {
      // 如果是点击播放，且当前歌曲已经在随机列表中，则将其移动到列表头部
      randommodetemplist.removeWhere((element) => element.id == track.id);
      randommodetemplist.add(track);
    }

    Get.find<LyricController>().loadLyric();
    double t_volume = 100;
    try {
      t_volume = Get.find<PlayController>().getPlayerSettings("volume");
    } catch (e) {
      t_volume = 100;
      Get.find<PlayController>().setPlayerSetting("volume", t_volume);
    }
    Get.find<PlayController>().music_player.setVolume(t_volume / 100);
    if (start) {
      Get.find<PlayController>().music_player.play();
    }
    await change_playback_state(track);
  } catch (e, stackTrace) {
    debugPrint('播放失败!!!!');
    debugPrint(e.toString());
    debugPrint(stackTrace.toString());
  }
}

Future<void> playerSuccessCallback(dynamic res, Track track) async {
  try {
    var tempDir = await xuan_getdataDirectory();
    final tempPath = tempDir.path;
    final _local_cache = await get_local_cache(track.id);
    if (_local_cache == '') {
      // 获取应用程序的临时目录
      // final fileName = res['url'].split('/').last.split('?').first;
      // 根据.定位文件后缀名
      String fileName =
          res['url']
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
          final dio = dio_with_cookie_manager;
          await dio.download(
            res['url'],
            filePath,
            options: Options(
              headers: {
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
              },
            ),
          );
        case "netease":
          final dio = dio_with_cookie_manager;
          await dio.download(res['url'], filePath);
        default:
          await dio_with_cookie_manager.download(res['url'], filePath);
      }
      await set_local_cache(track.id, fileName);
    }
    playsong(track, true, true);
    return;
  } catch (e) {
    print('Error downloading or playing audio: $e');
    debugPrint('Error downloading or playing audio: $e');
    playerFailCallback(track);
  }
}

Future<void> playerFailCallback(Track track) async {
  print('playerFailCallback');
  print(track);
  // {id: netrack_2084034562, title: Anytime Anywhere, artist: milet, artist_id: neartist_31464106, album: Anytime Anywhere, album_id: nealbum_175250775, source: netease, source_url: https://music.163.com/#/song?id=2084034562, img_url: https://p1.music.126.net/11p2mKi5CMKJvAS43ulraQ==/109951168930518368.jpg, sourceName: 网易, $$hashKey: object:2884, disabled: false, index: 365, playNow: true, bitrate: 320kbps, platform: netease, platformText: 网易}
  debugPrint('playerFailCallback');
  showErrorSnackbar('播放失败', track.title);
  if (Get.find<PlayController>().getPlayerSettings("nowplaying_track_id") !=
      track.id) {
    return;
  }
  var connectivityResult = await (Connectivity().checkConnectivity());
  debugPrint(connectivityResult.toString());
  while (connectivityResult == ConnectivityResult.none) {
    connectivityResult = await (Connectivity().checkConnectivity());
    debugPrint(connectivityResult.toString());
    // 等待三秒
    await Future.delayed(Duration(seconds: 3));
  }

  onPlaybackCompleted(true);
}

Future<void> fresh_playmode() async {
  try {
    playmode.value = Get.find<PlayController>().getPlayerSettings("playmode");
  } catch (e) {
    playmode.value = 0;
    Get.find<PlayController>().setPlayerSetting("playmode", playmode.value);
  }
}

bool change_p = false;

/// 打开歌词页面
void _openLyricPage() {
  // 使用路由导航到歌词页面
  if (Get.find<RouteController>().inLyricPage.value) {
    Get.back(id: 1);
  } else {
    Get.toNamed(RouteName.lyricPage, id: 1);
  }
}

void _openNowPlayListPage() {
  // 使用路由导航到歌词页面
  if (Get.find<RouteController>().inNowPlayListPage.value) {
    Get.back(id: 1);
  } else {
    Get.toNamed(RouteName.nowPlayingPage, id: 1);
  }
}

class Play extends StatefulWidget {
  final Function(String, {bool is_my, String search_text}) onPlaylistTap;
  final bool horizon;
  Play({required this.onPlaylistTap, this.horizon = false});
  @override
  _PlayState createState() => _PlayState();
}

late SMTCWindows smtc;
PlayController get _playController => Get.find<PlayController>();

class _PlayState extends State<Play> with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  late Offset position;

  @override
  Widget build(BuildContext context) {
    Widget ctx_bu = GetBuilder<AudioHandlerController>(
      builder: (controller) {
        if (controller.loading.value) {
          return Center(child: globalLoadingAnime);
        } else {
          Widget tW = widget.horizon
              ? SizedBox(height: 60, child: playH(widget.onPlaylistTap))
              : playV;
          return tW;
          return is_windows
              ? tW
              : GestureDetector(
                  onTapDown: (TapDownDetails details) {
                    position = details.globalPosition;
                  },
                  onTap: () async {
                    if (!widget.horizon) {
                      main_showVolumeSlider();
                    }
                    final track = await getnowplayingsong();
                    var ret = await song_dialog(
                      context,
                      track['track'],
                      change_main_status: widget.onPlaylistTap,
                      position: position,
                    );
                    if (ret != null) {
                      if (ret["push"] != null) {
                        Get.toNamed(
                          ret["push"],
                          arguments: {'listId': ret["push"], 'is_my': false},
                          id: 1,
                        );
                      }
                    }
                  },
                  onDoubleTap: () {
                    // if (_player.playing) MediaControl.pause else MediaControl.play,
                    Vibration.vibrate(duration: 100);
                    if (Get.find<PlayController>().music_player.playing) {
                      // (Get.find<AudioHandlerController>().audioHandler as AudioPlayerHandler).pause();
                      global_pause();
                    } else {
                      // (Get.find<AudioHandlerController>().audioHandler as AudioPlayerHandler).play();
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
                        // (Get.find<AudioHandlerController>().audioHandler as AudioPlayerHandler).skipToPrevious();
                        global_skipToPrevious();
                      } else if (details.primaryVelocity! < 0) {
                        // _playNext(); // 向左滑动，播放下一首
                        // (Get.find<AudioHandlerController>().audioHandler as AudioPlayerHandler).skipToNext();
                        global_skipToNext();
                      }
                    }
                  },
                  child: tW,
                );
        }
      },
    );

    return ctx_bu;
  }
}

Stream<MediaState> get _mediaStateStream =>
    rxdart.Rx.combineLatest2<MediaItem?, Duration, MediaState>(
      Get.find<AudioHandlerController>().audioHandler.mediaItem,
      AudioService.position,
      (mediaItem, position) {
        if (is_windows) {
          // 计算进度并更新到 PlayController 的响应式变量
          final progress =
              (position.inMilliseconds /
                      (mediaItem?.duration?.inMilliseconds ?? 1) *
                      100)
                  .toInt();
          Get.find<PlayController>().taskbarProgress.value = progress;
        }
        return MediaState(mediaItem, position);
      },
    );

IconButton _button(
  IconData iconData,
  VoidCallback onPressed, {
  bool h = false,
}) => IconButton(
  icon: Icon(iconData),
  iconSize: h ? 32 : 100.0.w,
  alignment: Alignment.center,
  onPressed: onPressed,
);

class MediaState {
  final MediaItem? mediaItem;
  final Duration position;

  MediaState(this.mediaItem, this.position);
}

Future<void> global_play_or_pause() async {
  if (Get.find<PlayController>().music_player.playing) {
    await Get.find<PlayController>().music_player.pause();
  } else {
    await Get.find<PlayController>().music_player.play();
  }
}

Future<void> global_play() async {
  Get.find<PlayController>().music_player.play();
}

Future<void> global_pause() async {
  Get.find<PlayController>().music_player.pause();
}

Future<void> global_seek(Duration? position, {double? process}) async {
  if (position == null && process != null) {
    position = Duration(
      milliseconds:
          (process *
                  (Get.find<PlayController>()
                          .music_player
                          .duration
                          ?.inMilliseconds ??
                      0))
              .round(),
    );
  }
  Get.find<PlayController>().music_player.seek(position);
}

Future<void> global_seek_to_next({
  Duration time = const Duration(seconds: 3),
}) async {
  var now_pos = Get.find<PlayController>().music_player.position;
  var next_pos = now_pos + time;
  var max_pos = Get.find<PlayController>().music_player.duration ?? now_pos;
  if (next_pos > max_pos) {
    next_pos = max_pos;
  }
  Get.find<PlayController>().music_player.seek(next_pos);
}

Future<void> global_seek_to_previous({
  Duration time = const Duration(seconds: 3),
}) async {
  var now_pos = Get.find<PlayController>().music_player.position;
  var next_pos = now_pos < time ? Duration.zero : now_pos - time;
  Get.find<PlayController>().music_player.seek(next_pos);
}

Future<void> global_volume_up({double step = 0.02}) async {
  var now_pos = Get.find<PlayController>().music_player.volume;
  var next_pos = now_pos + step;
  if (next_pos > 1) {
    next_pos = 1;
  }
  Get.find<PlayController>().currentVolume = next_pos;
}

Future<void> global_volume_down({double step = 0.02}) async {
  var now_pos = Get.find<PlayController>().music_player.volume;
  var next_pos = now_pos - step;
  if (next_pos < 0) {
    next_pos = 0;
  }
  Get.find<PlayController>().currentVolume = next_pos;
}

Future<void> global_skipToPrevious() async {
  await fresh_playmode();

  final current_playing = await get_current_playing();
  final nowplaying_track = await getnowplayingsong();
  if (nowplaying_track['index'] != -1) {
    final index = nowplaying_track['index'];
    switch (playmode.value) {
      case 0:
        index - 1 >= 0
            ? await playsong(current_playing[index - 1])
            : await playsong(current_playing[current_playing.length - 1]);
        break;
      case 1:
        try {
          int t = randommodetemplist
              .map((e) => e.id)
              .toList()
              .indexOf(nowplaying_track['track'].id);
          if (t > 0) {
            Track tt = randommodetemplist[t - 1];
            if (current_playing.any((element) => element.id == tt.id)) {
              await playsong(tt);
              return;
            }
          }
        } catch (e) {
          print(e);
        }
        final randomIndex = Random().nextInt(current_playing.length);
        Track track = current_playing[randomIndex];
        randommodetemplist.removeWhere((element) => element.id == track.id);
        randomTrackInsertAtHead = true; // 下次插入到头部
        await playsong(track);
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
    switch (playmode.value) {
      case 0:
        await Get.find<AudioHandlerController>().audioHandler.setRepeatMode(
          AudioServiceRepeatMode.all,
        );
        break;
      case 1:
        await Get.find<AudioHandlerController>().audioHandler.setRepeatMode(
          AudioServiceRepeatMode.group,
        );
        break;
      case 2:
        await Get.find<AudioHandlerController>().audioHandler.setRepeatMode(
          AudioServiceRepeatMode.one,
        );
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
  playmode.value = (playmode.value + 1) % 3;
  Get.find<PlayController>().setPlayerSetting("playmode", playmode.value);
  broadcastWs();
  return playmode.value;
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
      'https://s.040905.xyz/d/v/business-spirit-unit.gif?sign=uDy2k6zQMaZr8CnNBem03KTPdcQGX-JVOIRcEBcVOhk=:0',
    ),
  );
  AudioPlayerHandler() {
    // So that our clients (the Flutter UI and the system notification) know
    // what state to display, here we set up our audio handler to broadcast all
    // playback state changes as they happen via playbackState...
    Get.find<PlayController>().music_player.playbackEventStream
        .map(_transformEvent)
        .pipe(playbackState);
    // ... and also the current media item via mediaItem.
    mediaItem.add(_item);

    // Load the player.
    if (Get.find<PlayController>().music_player.audioSource == null) {
      Get.find<PlayController>().music_player.setAudioSource(
        AudioSource.uri(Uri.parse(_item.id)),
        preload: false,
      );
    }
    Get.find<PlayController>().music_player.playerStateStream.listen((
      playerState,
    ) {
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
  // Future<void> pause() => Get.find<PlayController>().music_player.pause();
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
  // @override
  // Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
  //   if (change_p) {
  //     change_p = false;
  //     return;
  //   }
  //   // await Get.find<PlayController>().music_player.setRepeatMode(repeatMode);
  //   await global_change_play_mode();
  // }

  /// Transform a just_audio event into an audio_service state.
  ///
  /// This method is used from the constructor. Every event received from the
  /// just_audio player will be transformed into an audio_service state so that
  /// it can be broadcast to audio_service clients.

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (Get.find<PlayController>().music_player.playing)
          MediaControl.pause
        else
          MediaControl.play,
        // MediaControl.pause,
        MediaControl.skipToNext,
        MediaControl.skipToPrevious,
        // MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[Get.find<PlayController>().music_player.processingState]!,
      playing: Get.find<PlayController>().music_player.playing,
      updatePosition: Get.find<PlayController>().music_player.position,
      bufferedPosition:
          Get.find<PlayController>().music_player.bufferedPosition,
      speed: Get.find<PlayController>().music_player.speed,
      queueIndex: event.currentIndex,
    );
  }
}

/// 格式化时长
String formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  if (duration.inHours > 0) {
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }
  return '$twoDigitMinutes:$twoDigitSeconds';
}
