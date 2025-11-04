part of '../../play.dart';

// 封面组件
Widget buildCoverImage(double size, {double? borderRadius}) {
  final radius = borderRadius ?? 8.0;
  return GestureDetector(
    onTap: () => _openLyricPage(),
    child: Container(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: StreamBuilder<MediaItem?>(
          stream: Get.find<AudioHandlerController>().audioHandler.mediaItem,
          builder: (context, snapshot) {
            final mediaItem = snapshot.data;
            return mediaItem == null
                ? Container(color: Get.theme.cardColor)
                : ExtendedImage.network(
                    mediaItem.artUri.toString(),
                    fit: BoxFit.cover,
                    cache: true,
                    loadStateChanged: (state) {
                      if (state.extendedImageLoadState == LoadState.failed) {
                        return Icon(Icons.music_note, size: size);
                      }
                      return null;
                    },
                  );
          },
        ),
      ),
    ),
  );
}

// 歌曲信息组件
Widget buildSongInfo({
  required double titleSize,
  required double artistSize,
  required bool isCollapsed,
}) {
  Future<void> onTap(BuildContext context) async {
    if (!globalHorizon) {
      main_showVolumeSlider();
    }
    final track = await getnowplayingsong();
    var ret = await song_dialog(
      context,
      track['track'],
      change_main_status: onPlaylistTap,
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
  }

  ;
  return StreamBuilder<MediaItem?>(
    stream: Get.find<AudioHandlerController>().audioHandler.mediaItem,
    builder: (context, snapshot) {
      final mediaItem = snapshot.data;

      return GestureDetector(
        onTapDown: (TapDownDetails details) {
          position = details.globalPosition;
        },
        onTap: () => onTap(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCollapsed)
              Text(
                mediaItem?.title ?? '未播放',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            else
              SelectableText(
                mediaItem?.title ?? '未播放',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                ),
                onTap: () => onTap(context),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            SizedBox(height: 4),
            if (isCollapsed)
              Text(
                mediaItem?.artist ?? '',
                style: TextStyle(
                  fontSize: artistSize,
                  color: Get.theme.textTheme.bodySmall?.color,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            else
              SelectableText(
                mediaItem?.artist ?? '',
                style: TextStyle(
                  fontSize: artistSize,
                  color: Get.theme.textTheme.bodySmall?.color,
                ),
                onTap: () => onTap(context),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
          ],
        ),
      );
    },
  );
}

double get controlButtonSize => 160.w;
double get controlButtonIconSize => 100.w;

ButtonStyle get controlBtnsStyle => ButtonStyle(
  fixedSize: MaterialStateProperty.all(
    Size(controlButtonSize, controlButtonSize),
  ),
  minimumSize: MaterialStateProperty.all(
    Size(controlButtonSize, controlButtonSize),
  ),
  maximumSize: MaterialStateProperty.all(
    Size(controlButtonSize, controlButtonSize),
  ),
  alignment: Alignment.center,
);
Widget get playModeButton => Obx(() {
  return IconButton(
    style: controlBtnsStyle.copyWith(iconSize: MaterialStateProperty.all(64.w)),
    icon: switch (playmode.value) {
      0 => Icon(Icons.repeat, size: 64.w),
      1 => Icon(Icons.shuffle, size: 64.w),
      2 => Icon(Icons.repeat_one, size: 64.w),
      _ => Icon(Icons.error, size: 64.w), // 默认情况
    },
    onPressed: global_change_play_mode,
  );
});

// 上一曲按钮
Widget buildPreviousButton() {
  return IconButton(
    style: controlBtnsStyle,
    icon: Icon(Icons.skip_previous, size: controlButtonIconSize),
    onPressed: global_skipToPrevious,
  );
}

// 播放/暂停按钮
Widget buildPlayPauseButton(double expandProgress) {
  return Obx(
    () => Stack(
      children: [
        Positioned.fill(
          child: AnimatedOpacity(
            opacity: expandProgress < 0.5 ? 1.0 : 0.0,
            duration: Duration(milliseconds: 200),
            child: StreamBuilder<MediaState>(
              stream: _mediaStateStream,
              builder: (context, snapshot) {
                final mediaState = snapshot.data;
                final duration = (mediaState
                    ?.mediaItem
                    ?.duration
                    ?.inMilliseconds
                    .toDouble());
                if (duration == null || duration <= 0) {
                  return CircularProgressIndicator();
                }
                final position =
                    mediaState?.position.inMilliseconds.toDouble() ?? 0.0;
                final progress = (position / duration).clamp(0.0, 1.0);
                return CircularProgressIndicator(value: progress);
              },
            ),
          ),
        ),
        IconButton(
          style: controlBtnsStyle,
          icon: Icon(
            _playController.isplaying.value ? Icons.pause : Icons.play_arrow,
            size: controlButtonIconSize,
          ),
          onPressed: () {
            if (_playController.isplaying.value) {
              global_pause();
            } else {
              global_play();
            }
          },
        ),
      ],
    ),
  );
}

// 下一曲按钮
Widget buildNextButton() {
  return IconButton(
    style: controlBtnsStyle,
    icon: Icon(Icons.skip_next, size: controlButtonIconSize),
    onPressed: global_skipToNext,
  );
}

// 播放列表按钮
Widget get buildPlaylistButton => Obx(
  () => badges.Badge(
    position: badges.BadgePosition.topEnd(top: -4.w, end: -4.w),
    showBadge: _playController.current_playing.isNotEmpty,
    badgeContent: Text(
      '${_playController.current_playing.length}',
      style: TextStyle(
        color: Get.theme.colorScheme.onPrimaryContainer,
        fontSize: 30.w,
        fontWeight: FontWeight.bold,
      ),
    ),
    badgeStyle: badges.BadgeStyle(
      badgeColor: Get.theme.colorScheme.primaryContainer,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.w),
    ),
    child: IconButton(
      style: controlBtnsStyle,
      tooltip: '正在播放列表',
      icon: Icon(Icons.playlist_play_rounded, size: controlButtonIconSize),
      onPressed: _openNowPlayListPage,
    ),
  ),
);

// 高44居中
Widget get sheetHandle => Positioned.fill(
  child: Align(
    alignment: Alignment.topCenter,
    child: Container(
      margin: EdgeInsets.symmetric(vertical: 10.w),
      width: 120.w,
      height: 20.w,
      decoration: BoxDecoration(
        color: Get.theme.dividerColor.withAlpha(100),
        borderRadius: BorderRadius.circular(10.w),
      ),
    ),
  ),
);

Widget get positionSlider => StreamBuilder<MediaState>(
  stream: _mediaStateStream,
  builder: (context, snapshot) {
    final mediaState = snapshot.data;

    return Container(
      height: 100.w,
      padding: EdgeInsets.symmetric(horizontal: 60.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatDuration(mediaState?.position ?? Duration.zero),
              style: TextStyle(fontSize: 48.0.w),
            ),
          ),
          Expanded(
            child: Slider(
              value:
                  (mediaState?.position.inMilliseconds.toDouble() ?? 0.0) >
                      (mediaState?.mediaItem?.duration?.inMilliseconds
                              .toDouble() ??
                          1.0)
                  ? (mediaState?.mediaItem?.duration?.inMilliseconds
                            .toDouble() ??
                        1.0)
                  : (mediaState?.position.inMilliseconds.toDouble() ?? 0.0),
              max:
                  mediaState?.mediaItem?.duration?.inMilliseconds.toDouble() ??
                  1.0,
              onChanged: (value) {
                global_seek(Duration(milliseconds: value.toInt()));
              },
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatDuration(mediaState?.mediaItem?.duration ?? Duration.zero),
              style: TextStyle(fontSize: 48.0.w),
            ),
          ),
        ],
      ),
    );
  },
);

class SizedBoxWithOverflow extends StatelessWidget {
  double? width;
  double? height;
  double maxWidth = double.infinity;
  double maxHeight = double.infinity;
  Widget? child;

  SizedBoxWithOverflow({
    super.key,
    this.width,
    this.height,
    this.maxWidth = double.infinity,
    this.maxHeight = double.infinity,
    this.child,
  });
  factory SizedBoxWithOverflow.processMaxSizeDir({
    required double maxSize,
    required double process,
    bool isHorizontal = true,
    Widget? child,
  }) {
    return SizedBoxWithOverflow(
      width: isHorizontal ? maxSize * process : maxSize,
      height: isHorizontal ? maxSize : maxSize * process,
      maxWidth: maxSize,
      maxHeight: maxSize,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: OverflowBox(
        fit: OverflowBoxFit.deferToChild,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        child: Opacity(
          opacity: min(
            (width ?? maxWidth) / maxWidth,
            (height ?? maxHeight) / maxHeight,
          ).clamp(0, 1.0),
          child: child,
        ),
      ),
    );
  }
}

// 内联歌词组件 - 在播放器展开时显示
Widget _buildInlineLyric() {
  return LyricVPage();
}
