part of '../../play.dart';

Widget get playV0 => Center(
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // Show media item title
      StreamBuilder<MediaItem?>(
        stream: Get.find<AudioHandlerController>().audioHandler.mediaItem,
        builder: (context, snapshot) {
          final mediaItem = snapshot.data;
          // return Text(mediaItem?.title ?? '');
          if (mediaItem == null) {
            return Container(width: 168.w, height: 168.w);
          }
          return GestureDetector(
            onTap: () {
              // 点击封面打开歌词页面
              _openLyricPage();
            },
            child: Container(
              width: 168.w,
              height: 168.w,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
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
            ),
          );
        },
      ),
      Container(
        width: 864.w,
        height: 150.w,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -20.w,
              left: 0,
              right: 0,
              child: Container(
                height: 120.w,
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
                      width: 200.w,
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
                                style: TextStyle(fontSize: 60.0.sp),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Obx(
                      () => SizedBox(
                        width: 120.w,
                        height: 120.w,
                        child: Stack(
                          children: [
                            Center(
                              child: IconButton(
                                tooltip: '正在播放列表',
                                icon: Icon(Icons.playlist_play_rounded),
                                onPressed: () async {
                                  Get.toNamed(RouteName.nowPlayingPage, id: 1);
                                },
                              ),
                            ),
                            Positioned(
                              top: 0,
                              child: Text(
                                '${_playController.current_playing.length}',
                                style: TextStyle(fontSize: 32.sp),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    playModeButton,
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -30.w,
              right: 0,
              left: 0,
              child: StreamBuilder<MediaState>(
                stream: _mediaStateStream,
                builder: (context, snapshot) {
                  final mediaState = snapshot.data;
                  return Container(
                    height: 120.w,
                    child: Slider(
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
                        global_seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      Container(
        width: 150.w,
        height: 150.w,
        child: Obx(
          () => Center(
            child: _playController.isplaying.value
                ? _button(Icons.pause, () {
                    global_pause();
                  })
                : _button(Icons.play_arrow, () {
                    global_play();
                  }),
          ),
        ),
      ),
    ],
  ),
);
// 256.w
