import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_lyric/lyrics_reader_model.dart';
import 'package:listen1_xuan/bodys.dart';
import 'package:listen1_xuan/controllers/controllers.dart';
import 'package:listen1_xuan/controllers/nowplaying_controller.dart';
import 'package:listen1_xuan/main.dart';
import 'dart:io';
import 'package:extended_image/extended_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:listen1_xuan/pages/lyric/lyric_page.dart';
import 'package:media_kit/media_kit.dart' show Player;
import 'package:rxdart/rxdart.dart' as rxdart;
import 'package:flutter/foundation.dart';
import 'package:marquee/marquee.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:window_manager/window_manager.dart';
import 'const.dart';
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
import 'package:path/path.dart' as p;
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:material_wave_slider/material_wave_slider.dart';

import 'widgets/container_with_outer_shadow.dart';

part 'pages/play/play_v.dart';
part 'pages/play/play_v0.dart';
part 'pages/play/play_v2.dart';
part 'pages/play/play_h.dart';
part 'pages/play/play_widgets.dart';

// Windows Taskbar API 调用的安全包装器
// 用于处理窗口未初始化的情况
bool _windowsTaskbarInitialized = false;
PlayController _playController = Get.find<PlayController>();
Future<bool> safeCallWindowsTaskbar(
  Future<void> Function() apiCall,
  String operationName,
) async {
  if (!isWindows) return true;

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
  if (_playController.nextTrack != null) {
    await playsong(_playController.nextTrack!);
    _playController.nextTrack = null;
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
        await _playController.music_player.seek(Duration.zero);
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
  _playController.add_current_playing(tracks);
}

void set_current_playing(List<Track> tracks) async {
  _playController.set_current_playing(tracks);
}

List<Track> get_current_playing() {
  return _playController.current_playing;
}

Future<Map<String, dynamic>> getnowplayingsong() async {
  final nowplaying_track_id = _playController.nowPlayingTrackId;
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
    if (isWindows)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          smtc.buttonPressStream.listen((event) {
            switch (event) {
              case PressedButton.play:
                smtc.setPlaybackStatus(PlaybackStatus.playing);
                globalPlay();
                break;
              case PressedButton.pause:
                smtc.setPlaybackStatus(PlaybackStatus.paused);
                globalPause();
                break;
              case PressedButton.next:
                print('Next');
                globalSkipToNext();
                break;
              case PressedButton.previous:
                print('Previous');
                globalSkipToPrevious();
                break;
              case PressedButton.stop:
                globalChangePlayMode();
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
    _playController.music_player.stream.duration.listen((duration) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    // 等待 _duration 被赋值
    await completer.future;
    // 获取音频文件的时长

    final _duration = await _playController.music_player.state.duration;
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
    if (isWindows) {
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

Future<void> playsong(
  Track track, {
  bool start = true,
  bool onBootstrapTrackSuccessCallback = false,
  bool isByClick = false,
}) async {
  await _playController.playsong(
    track,
    start: start,
    onBootstrapTrackSuccessCallback: onBootstrapTrackSuccessCallback,
    isByClick: isByClick,
  );
}

Future<void> fresh_playmode() async {
  try {
    playmode.value = _playController.getPlayerSettings("playmode");
  } catch (e) {
    playmode.value = 0;
    _playController.setPlayerSetting("playmode", playmode.value);
  }
}

bool change_p = false;

/// 打开歌词页面
void _openLyricPage() {
  if (!globalHorizon) {
    _playController.sheetController.animateTo(
      _playController.playVMaxOffset,
      duration: const Duration(milliseconds: 600),
    );
    return;
  }
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
  final bool horizon;
  Play({this.horizon = false});
  @override
  _PlayState createState() => _PlayState();
}

late SMTCWindows smtc;
Offset? position;

class _PlayState extends State<Play> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget ctx_bu = GetBuilder<AudioHandlerController>(
      builder: (controller) {
        if (controller.loading.value) {
          return Center(child: globalLoadingAnime);
        } else {
          Widget tW = widget.horizon
              ? SizedBox(height: 60, child: playH())
              : playV2;
          return tW;
        }
      },
    );

    return ctx_bu;
  }
}

Stream<MediaState> get _mediaStateStream =>
    rxdart.Rx.combineLatest2<MediaItem?, Duration, MediaState>(
      Get.find<AudioHandlerController>().audioHandler.mediaItem,
      rxdart.Rx.merge([
        _music_player.stream.position,
        _music_player.stream.playing.map((_) => _music_player.state.position),
      ]),
      (mediaItem, position) {
        final playing = _music_player.state.playing;
        if (isWindows) {
          // 计算进度并更新到 PlayController 的响应式变量
          final progress =
              (position.inMilliseconds /
                      (mediaItem?.duration?.inMilliseconds ?? 1) *
                      100)
                  .toInt();
          _playController.taskbarProgress.value = progress;
        }
        return MediaState(mediaItem, position, playing: playing);
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
  final bool? playing;
  MediaState(this.mediaItem, this.position, {this.playing});
}

Future<void> globalPlayOrPause() async {
  await _playController.music_player.playOrPause();
}

Future<void> globalPlay() async {
  _playController.music_player.play();
}

Future<void> globalPause() async {
  _playController.music_player.pause();
}

Future<void> globalSeek(Duration? position, {double? process}) async {
  if (position == null && process != null) {
    position = Duration(
      milliseconds:
          (process *
                  (_playController
                          .music_player
                          .state
                          .duration
                          ?.inMilliseconds ??
                      0))
              .round(),
    );
  }
  if (position == null) return;
  _playController.music_player.seek(position);
  if (_playController.needUpdatePosToAudioService.value > 10000) {
    _playController.needUpdatePosToAudioService.value = 0;
  } else {
    _playController.needUpdatePosToAudioService.value++;
  }
}

Future<void> globalSeekToNext({
  Duration time = const Duration(seconds: 3),
}) async {
  var now_pos = _playController.music_player.state.position;
  var next_pos = now_pos + time;
  var max_pos = _playController.music_player.state.duration ?? now_pos;
  if (next_pos > max_pos) {
    next_pos = max_pos;
  }
  _playController.music_player.seek(next_pos);
}

Future<void> globalSeekToPrevious({
  Duration time = const Duration(seconds: 3),
}) async {
  var now_pos = _playController.music_player.state.position;
  var next_pos = now_pos < time ? Duration.zero : now_pos - time;
  _playController.music_player.seek(next_pos);
}

Future<void> globalVolumeUp({double step = 2}) async {
  var now_pos = _playController.music_player.state.volume;
  var next_pos = now_pos + step;
  if (next_pos > 1) {
    next_pos = 1;
  }
  _playController.currentVolume = next_pos;
}

Future<void> globalVolumeDown({double step = 2}) async {
  var now_pos = _playController.music_player.state.volume;
  var next_pos = now_pos - step;
  if (next_pos < 0) {
    next_pos = 0;
  }
  _playController.currentVolume = next_pos;
}

Future<void> globalSkipToPrevious() async {
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

Future<void> globalSkipToNext() async {
  await onPlaybackCompleted(true);
}

Future<int> globalChangePlayMode() async {
  change_p = true;
  await fresh_playmode();
  playmode.value = (playmode.value + 1) % 3;
  _playController.setPlayerSetting("playmode", playmode.value);
  broadcastWs();
  return playmode.value;
}

Player get _music_player => _playController.music_player;

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

    // 使用 merge 替代 combineLatest2，任一流更新即立即发出
    rxdart.Rx.merge([
          _playController.music_player.stream.playing,
          _playController.updatePosToAudioServiceNow.stream.cast<int>(),
        ])
        .map((_) => _playController.music_player.state.playing)
        .map(_transformEvent)
        .pipe(playbackState);
    // _playController.music_player.stream.duration
    //     .map(_transformEvent)
    //     .pipe(playbackState);
    // ... and also the current media item via mediaItem.
    mediaItem.add(_item);

    // Load the player.
    // TODO 初始化问题
    // if (_playController.music_player.state.track == null) {
    //   _playController.music_player.setAudioSource(
    //     AudioSource.uri(Uri.parse(_item.id)),
    //     preload: false,
    //   );
    // }
    _playController.music_player.stream.completed.listen((finish) {
      if (finish) {
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
  Future<void> play() => globalPlay();

  // @override
  // Future<void> pause() => _playController.music_player.pause();
  @override
  Future<void> pause() => globalPause();

  @override
  Future<void> seek(Duration position) => globalSeek(position);
  @override
  Future<void> skipToPrevious() => globalSkipToPrevious();

  @override
  Future<void> skipToNext() => globalSkipToNext();

  PlaybackState _transformEvent(bool playing) {
    return PlaybackState(
      controls: [
        if (playing) MediaControl.pause else MediaControl.play,
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
      processingState: _music_player.state.completed
          ? AudioProcessingState.completed
          : AudioProcessingState.ready,
      updatePosition: _music_player.state.position,
      playing: _music_player.state.playing,
      bufferedPosition: _music_player.state.duration,
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
