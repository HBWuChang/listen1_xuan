part of '../../play.dart';

Widget get playModeButton => Obx(() {
  return IconButton(
    icon: switch (playmode.value) {
      0 => Icon(Icons.repeat, size: 60.w),
      1 => Icon(Icons.shuffle, size: 60.w),
      2 => Icon(Icons.repeat_one, size: 60.w),
      _ => Icon(Icons.error), // 默认情况
    },
    onPressed: () {
      global_change_play_mode();
    },
  );
});

// 封面组件
Widget buildCoverImage(
  MediaItem? mediaItem,
  double size, {
  double? borderRadius,
}) {
  final radius = borderRadius ?? 8.0;
  return GestureDetector(
    onTap: () => _openLyricPage(),
    child: Container(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: mediaItem == null
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
              ),
      ),
    ),
  );
}

// 歌曲信息组件
Widget buildSongInfo({
  required MediaItem? mediaItem,
  required double titleSize,
  required double artistSize,
  required bool isCollapsed,
}) {
  return Column(
    crossAxisAlignment: isCollapsed
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        mediaItem?.title ?? '未播放',
        style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold),
        textAlign: isCollapsed ? TextAlign.left : TextAlign.center,
        maxLines: isCollapsed ? 1 : 2,
        overflow: TextOverflow.ellipsis,
      ),
      SizedBox(height: 4),
      Text(
        mediaItem?.artist ?? '',
        style: TextStyle(
          fontSize: artistSize,
          color: Get.theme.textTheme.bodySmall?.color,
        ),
        textAlign: isCollapsed ? TextAlign.left : TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

// 播放/暂停按钮（小）
Widget get buildPlayPauseButton {
  return Obx(
    () => IconButton(
      icon: Icon(
        _playController.isplaying.value ? Icons.pause : Icons.play_arrow,
        size: 100.w,
      ),
      onPressed: () {
        if (_playController.isplaying.value) {
          global_pause();
        } else {
          global_play();
        }
      },
    ),
  );
}

// 播放列表按钮
Widget buildPlaylistButton({double size = 28.0}) {
  return Obx(
    () => Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: '正在播放列表',
          icon: Icon(Icons.playlist_play_rounded, size: size),
          onPressed: () {
            Get.toNamed(RouteName.nowPlayingPage, id: 1);
          },
        ),
        if (_playController.current_playing.isNotEmpty)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Get.theme.primaryColor,
                shape: BoxShape.circle,
              ),
              constraints: BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '${_playController.current_playing.length}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    ),
  );
}

// 上一曲按钮
Widget buildPreviousButton() {
  return IconButton(
    icon: Icon(Icons.skip_previous, size: 40.w),
    onPressed: () {
      // TODO: 实现上一曲功能
    },
  );
}

// 下一曲按钮
Widget buildNextButton() {
  return IconButton(
    icon: Icon(Icons.skip_next, size: 40.w),
    onPressed: () {
      // TODO: 实现下一曲功能
    },
  );
}
