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
    crossAxisAlignment: CrossAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        mediaItem?.title ?? '未播放',
        style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
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
        textAlign: TextAlign.center,
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
Widget get buildPlaylistButton => Obx(
  () => badges.Badge(
    position: badges.BadgePosition.topEnd(top: -4.w, end: -4.w),
    showBadge: _playController.current_playing.isNotEmpty,
    badgeContent: Text(
      '${_playController.current_playing.length}',
      style: TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
    badgeStyle: badges.BadgeStyle(
      badgeColor: Get.theme.primaryColor,
      padding: EdgeInsets.all(4),
    ),
    child: IconButton(
      tooltip: '正在播放列表',
      icon: Icon(Icons.playlist_play_rounded, size: 100.w),
      onPressed: _openNowPlayListPage,
    ),
  ),
);

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
