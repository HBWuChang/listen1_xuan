import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

final play = Play();
final player = AudioPlayer();

class Play extends StatefulWidget {
  @override
  _PlayState createState() => _PlayState();
}

Future<void> playerSuccessCallback(dynamic res) async {
  print('playerSuccessCallback');
  print(res);

  try {
    // 获取应用程序的临时目录
    final tempDir = await getTemporaryDirectory();
    final tempPath = tempDir.path;
    // https://upos-sz-mirrorcos.bilivideo.com/ugaxcode/i180803ws2cgt42qae0n4o2fms8hv2h2-192k.m4a?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&uipk=5&nbs=1&deadline=1734258668&gen=playurlv2&os=cosbv&oi=1885697219&trid=05409f4365fd448c970247d9bcc6c639B&mid=0&platform=pc&og=cos&upsig=3824c4ac84a929f3eaaf0ff719b42f14&uparams=e,uipk,nbs,deadline,gen,os,oi,trid,mid,platform,og&bvc=vod&nettype=0&orderid=0,1&logo=00000000
    // final fileName = res['url'].split('/').last;
    final fileName = res['url'].split('/').last.split('?').first;
    final filePath = '$tempPath/$fileName';
    // 若本地已经存在该文件，则直接播放
    if (await File(filePath).exists()) {
      await player.setSource(DeviceFileSource(filePath));
      await player.resume();
      return;
    }
    // 下载文件到本地
    final dio = Dio();
    await dio.download(
      res['url'],
      filePath,
      options: Options(
//         :authority: upos-sz-mirrorhw.bilivideo.com
// :method: GET
// :path: /ugaxcode/i180814qn3c48n7fa0gg0c1o4i8fq7zj-192k.m4a?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&uipk=5&nbs=1&deadline=1734260609&gen=playurlv2&os=hwbv&oi=1885697219&trid=3aafa6c85dda43c1ab00a1b1145b97faB&mid=0&platform=pc&og=hw&upsig=b42ddbe90e0507924372cb84a42bb8de&uparams=e,uipk,nbs,deadline,gen,os,oi,trid,mid,platform,og&bvc=vod&nettype=0&orderid=0,1&logo=00000000
// :scheme: https
// reqable-id: reqable-id-9df22914-f29e-4ca4-9b9a-64b1361a8506
// user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36
// accept: */*
// accept-encoding: identity;q=1, *;q=0
// accept-language: zh-CN
// referer: https://www.bilibili.com/
// sec-fetch-dest: audio
// sec-fetch-mode: no-cors
// sec-fetch-site: cross-site
// range: bytes=0-
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
          }),
    );
    // 设置本地文件路径为音频源
    await player.setSource(DeviceFileSource(filePath));
    await player.resume();
  } catch (e) {
    print('Error downloading or playing audio: $e');
  }
}

Future<void> playerFailCallback() async {
  print('playerFailCallback');
}

Future<void> setNotification(String title, String content) async {
  
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
    // player = AudioPlayer();

    // Set the release mode to keep the source after playback has completed.
    player.setReleaseMode(ReleaseMode.stop);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // await player.setSource(AssetSource('ambient_c_motion.mp3'));
      // await player.resume();
    });
  }

  @override
  void dispose() {
    // Release all sources and dispose the player.
    player.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlayerWidget(player: player);
  }
}

class PlayerWidget extends StatefulWidget {
  final AudioPlayer player;

  const PlayerWidget({
    required this.player,
    super.key,
  });

  @override
  State<StatefulWidget> createState() {
    return _PlayerWidgetState();
  }
}

class _PlayerWidgetState extends State<PlayerWidget> {
  PlayerState? _playerState;
  Duration? _duration;
  Duration? _position;

  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateChangeSubscription;

  bool get _isPlaying => _playerState == PlayerState.playing;

  bool get _isPaused => _playerState == PlayerState.paused;

  String get _durationText => _duration?.toString().split('.').first ?? '';

  String get _positionText => _position?.toString().split('.').first ?? '';

  AudioPlayer get player => widget.player;

  @override
  void initState() {
    super.initState();
    // Use initial values from player
    _playerState = player.state;
    player.getDuration().then(
          (value) => setState(() {
            _duration = value;
          }),
        );
    player.getCurrentPosition().then(
          (value) => setState(() {
            _position = value;
          }),
        );
    _initStreams();
  }

  @override
  void setState(VoidCallback fn) {
    // Subscriptions only can be closed asynchronously,
    // therefore events can occur after widget has been disposed.
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateChangeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const Key('play_button'),
              onPressed: _isPlaying ? null : _play,
              iconSize: 48.0,
              icon: const Icon(Icons.play_arrow),
              color: color,
            ),
            IconButton(
              key: const Key('pause_button'),
              onPressed: _isPlaying ? _pause : null,
              iconSize: 48.0,
              icon: const Icon(Icons.pause),
              color: color,
            ),
            IconButton(
              key: const Key('stop_button'),
              onPressed: _isPlaying || _isPaused ? _stop : null,
              iconSize: 48.0,
              icon: const Icon(Icons.stop),
              color: color,
            ),
          ],
        ),
        Slider(
          onChanged: (value) {
            final duration = _duration;
            if (duration == null) {
              return;
            }
            final position = value * duration.inMilliseconds;
            player.seek(Duration(milliseconds: position.round()));
          },
          value: (_position != null &&
                  _duration != null &&
                  _position!.inMilliseconds > 0 &&
                  _position!.inMilliseconds < _duration!.inMilliseconds)
              ? _position!.inMilliseconds / _duration!.inMilliseconds
              : 0.0,
        ),
        Text(
          _position != null
              ? '$_positionText / $_durationText'
              : _duration != null
                  ? _durationText
                  : '',
          style: const TextStyle(fontSize: 16.0),
        ),
      ],
    );
  }

  void _initStreams() {
    _durationSubscription = player.onDurationChanged.listen((duration) {
      setState(() => _duration = duration);
    });

    _positionSubscription = player.onPositionChanged.listen(
      (p) => setState(() => _position = p),
    );

    _playerCompleteSubscription = player.onPlayerComplete.listen((event) {
      setState(() {
        _playerState = PlayerState.stopped;
        _position = Duration.zero;
      });
    });

    _playerStateChangeSubscription =
        player.onPlayerStateChanged.listen((state) {
      setState(() {
        _playerState = state;
      });
    });
  }

  Future<void> _play() async {
    await player.resume();
    setState(() => _playerState = PlayerState.playing);
  }

  Future<void> _pause() async {
    await player.pause();
    setState(() => _playerState = PlayerState.paused);
  }

  Future<void> _stop() async {
    await player.stop();
    setState(() {
      _playerState = PlayerState.stopped;
      _position = Duration.zero;
    });
  }
}
