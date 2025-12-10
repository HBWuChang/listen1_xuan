part of '../../play.dart';

final GlobalKey _buttonKey = GlobalKey();
final materialWaveSliderStateKeyH = GlobalKey<MaterialWaveSliderState>();
Widget playH() {
  return Center(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 50,
          height: 50,
          child: Center(
            // 上一首
            child: _button(Icons.skip_previous, () {
              globalSkipToPrevious();
            }, h: true),
          ),
        ),
        Container(
          width: 50,
          height: 50,
          child: Center(
            // 上一首
            child: PlayPauseBtn(
              isPlaying: _playController.isplaying,
              size: 50,
              onPlayPressed: globalPlay,
              onPausePressed: globalPause,
            ),
          ),
        ),
        Container(
          width: 50,
          height: 50,
          child: Center(
            // 上一首
            child: _button(Icons.skip_next, () {
              globalSkipToNext();
            }, h: true),
          ),
        ),
        // Show media item title
        StreamBuilder<MediaItem?>(
          stream: Get.find<AudioHandlerController>().audioHandler.mediaItem,
          builder: (context, snapshot) {
            final mediaItem = snapshot.data;
            // return Text(mediaItem?.title ?? '');
            if (mediaItem == null) {
              return Container(width: 50, height: 50);
            }
            return GestureDetector(
              onTap: () {
                // 点击封面打开歌词页面
                _openLyricPage();
              },
              child: Container(
                width: 50,
                height: 50,
                child: ExtendedImage.network(
                  mediaItem.artUri.toString(),
                  fit: BoxFit.cover,
                  cache: true,
                  loadStateChanged: (state) {
                    if (state.extendedImageLoadState == LoadState.failed) {
                      return Icon(Icons.music_note, size: 168.w);
                    }
                  },
                ),
              ),
            );
          },
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 20,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 5,
                      child: StreamBuilder<MediaItem?>(
                        stream: Get.find<AudioHandlerController>()
                            .audioHandler
                            .mediaItem,
                        builder: (context, snapshot) {
                          final mediaItem = snapshot.data;
                          return Text(
                            '${mediaItem?.title ?? 'null'}  -  ${mediaItem?.artist ?? 'null'}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                    Container(
                      width: 120,
                      child: StreamBuilder<MediaState>(
                        stream: _mediaStateStream,
                        builder: (context, snapshot) {
                          final mediaItem = snapshot.data;
                          return Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                (formatDuration(
                                      mediaItem?.position ?? Duration.zero,
                                    ) +
                                    ' / ' +
                                    formatDuration(
                                      mediaItem?.mediaItem?.duration ??
                                          Duration.zero,
                                    )),
                                style: TextStyle(fontSize: 20.0),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: StreamBuilder<MediaState>(
                  stream: _mediaStateStream,
                  builder: (context, snapshot) {
                    final mediaState = snapshot.data;

                    return MaterialWaveSlider(
                      key: materialWaveSliderStateKeyH,
                      height: 20,
                      paused: !(mediaState?.playing ?? false),
                      value:
                          (mediaState?.position.inMilliseconds.toDouble() ??
                                  0.0) >
                              (mediaState?.mediaItem?.duration?.inMilliseconds
                                      .toDouble() ??
                                  1.0)
                          ? (mediaState?.mediaItem?.duration?.inMilliseconds
                                    .toDouble() ??
                                1.0)
                          : (mediaState?.position.inMilliseconds.toDouble() ??
                                0.0),
                      max:
                          mediaState?.mediaItem?.duration?.inMilliseconds
                              .toDouble() ??
                          1.0,
                      onChanged: (value) {
                        globalSeek(Duration(milliseconds: value.toInt()));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: _buttonKey,
          tooltip: '歌曲弹窗',
          icon: Icon(Icons.list),
          onPressed: () async {
            final track = await getnowplayingsong();

            var ret = await song_dialog(
              Get.context!,
              track['track'],
              position:
                  (_buttonKey.currentContext!.findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero),
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
        ),
        Obx(
          () => badges.Badge(
            position: badges.BadgePosition.topEnd(top: -4, end: -4),
            ignorePointer: true,
            showBadge: _playController.current_playing.isNotEmpty,
            badgeContent: Text(
              '${_playController.current_playing.length}',
              style: TextStyle(
                color: AdaptiveTheme.of(
                  Get.context!,
                ).theme.colorScheme.onPrimaryContainer,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            badgeStyle: badges.BadgeStyle(
              shape: badges.BadgeShape.square,
              borderRadius: BorderRadius.circular(8),
              badgeColor: AdaptiveTheme.of(
                Get.context!,
              ).theme.colorScheme.primaryContainer,
              padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            ),
            child: IconButton(
              tooltip: '正在播放列表',
              icon: Icon(Icons.playlist_play_rounded),
              onPressed: () async {
                Get.toNamed(RouteName.nowPlayingPage, id: 1);
              },
            ),
          ),
        ),
        Obx(() {
          return IconButton(
            tooltip: switch (playmode.value) {
              0 => '循环播放',
              1 => '随机播放',
              2 => '单曲循环',
              _ => '未知模式',
            },
            icon: switch (playmode.value) {
              0 => Icon(Icons.repeat),
              1 => Icon(Icons.shuffle),
              2 => Icon(Icons.repeat_one),
              _ => Icon(Icons.error), // 默认情况
            },
            onPressed: () {
              globalChangePlayMode();
            },
          );
        }),
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
            Listener(
              onPointerSignal: (pointerSignal) {
                if (pointerSignal is PointerScrollEvent) {
                  // 获取滚轮的滚动方向
                  final scrollDelta = pointerSignal.scrollDelta.dy;
                  final stepSize = 1; // 每次滚动的音量步长

                  double newVolume = _playController.currentVolume;
                  if (scrollDelta > 0) {
                    // 向下滚动，减小音量
                    newVolume = (newVolume - stepSize);
                  } else if (scrollDelta < 0) {
                    // 向上滚动，增大音量
                    newVolume = (newVolume + stepSize);
                  }
                  newVolume = newVolume.clamp(
                    0.0,
                    100.0,
                  ); // 确保音量在 0.0 到 100.0 之间
                  _playController.currentVolume = newVolume; // 更新音量
                }
              },
              child: Obx(
                () => Slider(
                  min: 0,
                  max: 100,
                  value: _playController.currentVolume,
                  onChanged: (value) {
                    _playController.currentVolume = value;
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
