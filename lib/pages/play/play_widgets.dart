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
        child: Obx(() {
          Track? mediaItem = _playController.nowPlayingTrackRx.value;
          return isEmpty(mediaItem?.img_url)
              ? Container(color: Get.theme.cardColor)
              : ExtendedImage.network(
                  mediaItem!.img_url!,
                  fit: BoxFit.cover,
                  cache: true,
                  loadStateChanged: (state) {
                    if (state.extendedImageLoadState == LoadState.failed) {
                      return Icon(Icons.music_note, size: size);
                    }
                    return null;
                  },
                );
        }),
      ),
    ),
  );
}

DragStartDetails? _dragStartDetails;
Widget withDragDetector({required Widget child, required bool isCollapsed}) {
  return Builder(
    builder: (context) => GestureDetector(
      onTapDown: (TapDownDetails details) {
        position = details.globalPosition;
      },
      onTap: () => _onTap(context),
      onDoubleTap: _onDoubleTap,
      onLongPress: isCollapsed ? _onLongPress : null,
      onHorizontalDragStart: (details) {
        _dragStartDetails = details;
      },
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: child,
    ),
  );
}

Future<void> _onTap(BuildContext context) async {
  if (!globalHorizon) {
    showVolumeSlider();
  }
  final track = await getnowplayingsong();
  var ret = await song_dialog(context, track['track'], position: position);
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

Future<void> _onDoubleTap() async {
  if (isAndroid || isIos) Vibration.vibrate(duration: 100);
  if (Get.find<PlayController>().music_player.state.playing) {
    globalPause();
  } else {
    globalPlay();
  }
}

void _onLongPress() {
  if (isAndroid || isIos) Vibration.vibrate(duration: 100);
  globalChangePlayMode();
}

void _onHorizontalDragEnd(DragEndDetails details) {
  Offset movePos = details.globalPosition - _dragStartDetails!.globalPosition;
  if (movePos.dx.abs() < movePos.dy.abs()) return;
  if (isAndroid || isIos) Vibration.vibrate(duration: 100);
  if (movePos.dx < 0) {
    globalSkipToNext();
  } else {
    globalSkipToPrevious();
  }
}

// 歌曲信息组件
Widget buildSongInfo({
  required double titleSize,
  required double artistSize,
  required bool isCollapsed,
}) {
  return Builder(
    builder: (context) => Obx(() {
      Track? mediaItem = _playController.nowPlayingTrackRx.value;
      return AnimatedSwitcher(
        duration: Duration(milliseconds: 200),
        transitionBuilder: horTitleTextTra,
        child: Container(
          key: ValueKey(mediaItem?.id ?? 'no-song'),
          color: Colors.transparent,
          padding: EdgeInsets.only(bottom: 20.w),
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
                  onTap: () => _onTap(context),
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
                  onTap: () => _onTap(context),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
            ],
          ),
        ),
      );
    }),
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
Widget get showVolumeSliderBtn {
  return IconButton(
    style: controlBtnsStyle,
    icon: Icon(Icons.volume_up, size: 64.w),
    onPressed: showVolumeSlider,
  );
}

Widget get playModeButton => Obx(() {
  return IconButton(
    style: controlBtnsStyle.copyWith(iconSize: MaterialStateProperty.all(64.w)),
    icon: switch (playmode.value) {
      0 => Icon(Icons.repeat, size: 64.w),
      1 => Icon(Icons.shuffle, size: 64.w),
      2 => Icon(Icons.repeat_one, size: 64.w),
      _ => Icon(Icons.error, size: 64.w), // 默认情况
    },
    onPressed: globalChangePlayMode,
  );
});

// 上一曲按钮
Widget buildPreviousButton() {
  return IconButton(
    style: controlBtnsStyle,
    icon: Icon(Icons.skip_previous, size: controlButtonIconSize),
    onPressed: globalSkipToPrevious,
  );
}

GlobalKey _playButtonKey = GlobalKey();
// 播放/暂停按钮
Widget buildPlayPauseButton(double expandProgress) {
  return Stack(
    children: [
      Positioned.fill(
        child: AnimatedOpacity(
          opacity: expandProgress < 0.5 ? 1.0 : 0.0,
          duration: Duration(milliseconds: 200),
          child: StreamBuilder<MediaState>(
            stream: _mediaStateStream,
            builder: (context, snapshot) {
              final mediaState = snapshot.data;
              final duration =
                  mediaState?.duration.inMilliseconds.toDouble() ?? 0.0;
              double? progress;
              if (!(duration <= 0)) {
                final position =
                    mediaState?.position.inMilliseconds.toDouble() ?? 0.0;
                progress = (position / duration).clamp(0.0, 1.0);
              }

              // 使用 AnimatedBuilder 监听旋转动画控制器
              return AnimatedBuilder(
                animation: _playController.playVPlayBtnProcessController,
                builder: (context, child) {
                  // 应用选中的曲线
                  final curvedValue = _playController
                      .playButtonRotationCurveValue
                      .transform(
                        _playController.playVPlayBtnProcessController.value,
                      );

                  return Transform.rotate(
                    angle: curvedValue * 2 * pi,
                    child: Obx(
                      () => MotorCircularProgressIndicator(
                        key: _playButtonKey,
                        strokeWidth: 4.w,
                        value: _playController.loading ? null : progress,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      PlayPauseBtn(
        isPlaying: _playController.isplaying,
        size: controlButtonIconSize,
        onPlayPressed: globalPlay,
        onPausePressed: globalPause,
        style: controlBtnsStyle,
      ),
    ],
  );
}

// 下一曲按钮
Widget buildNextButton() {
  return IconButton(
    style: controlBtnsStyle,
    icon: Icon(Icons.skip_next, size: controlButtonIconSize),
    onPressed: globalSkipToNext,
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
        color: AdaptiveTheme.of(
          Get.context!,
        ).theme.colorScheme.onPrimaryContainer,
        fontSize: 30.w,
        fontWeight: FontWeight.bold,
      ),
    ),
    ignorePointer: true,
    badgeStyle: badges.BadgeStyle(
      badgeColor: AdaptiveTheme.of(
        Get.context!,
      ).theme.colorScheme.primaryContainer,
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
Widget get songDialogBtn {
  return IconButton(
    style: controlBtnsStyle,
    icon: Icon(Icons.more_vert_rounded, size: 64.w),
    onPressed: () async {
      final track = await getnowplayingsong();
      var ret = await song_dialog(
        Get.context!,
        track['track'],
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
  );
}

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
final materialWaveSliderStateKeyV = GlobalKey<MaterialWaveSliderState>();

Widget get positionSlider => StreamBuilder<MediaState>(
  stream: _mediaStateStream,
  builder: (context, snapshot) {
    final mediaState = snapshot.data;

    return Container(
      height: 80.w,
      padding: EdgeInsets.symmetric(horizontal: 60.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120.w,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Obx(
                  () => AnimatedSwitcher(
                    duration: Duration(milliseconds: 200),
                    transitionBuilder: horTitleTextTra,
                    child: _playController.loading
                        ? Text(
                            key: ValueKey('slider-loading-position'),
                            _playController
                                    .bootStraping[_playController
                                        .nowPlayingTrackRx
                                        .value
                                        ?.id]
                                    ?.split('/')
                                    .first ??
                                '',
                            style: TextStyle(fontSize: 48.0.w),
                          )
                        : KeyedSubtree(
                            key: ValueKey('slider-playing-position'),
                            child: _buildDurationBySplitStreams(
                              hourStream: _mediaPositionHourStream,
                              minuteStream: _mediaPositionMinuteStream,
                              secondStream: _mediaPositionSecondStream,
                              initialHour:
                                  (mediaState?.position ?? Duration.zero)
                                      .inHours,
                              initialMinute:
                                  (mediaState?.position ?? Duration.zero)
                                      .inMinutes
                                      .remainder(60),
                              initialSecond:
                                  (mediaState?.position ?? Duration.zero)
                                      .inSeconds
                                      .remainder(60),
                              textStyle: TextStyle(fontSize: 48.0.w),
                              keyPrefix: 'slider-pos',
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Theme(
                data: Theme.of(context).copyWith(
                  sliderTheme: SliderTheme.of(context).copyWith(
                    trackHeight: 4.w,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10.w),
                    // overlayShape: RoundSliderOverlayShape(overlayRadius: 32.w),
                  ),
                ),
                child: Obx(
                  () => _playController.loading
                      ? LinearProgressIndicator()
                      : MaterialWaveSlider(
                          key: materialWaveSliderStateKeyV,
                          height: 60.w,
                          amplitude: 8.w,
                          velocity: 1800.0,
                          paused: mediaState?.playing == false,
                          transitionOnChange: false,
                          thumbWidth: 8.w,
                          value:
                              (mediaState?.position.inMilliseconds.toDouble() ??
                                      0.0) >
                                  (mediaState?.duration.inMilliseconds
                                          .toDouble() ??
                                      0.0)
                              ? (mediaState?.duration.inMilliseconds
                                        .toDouble() ??
                                    0.0)
                              : (mediaState?.position.inMilliseconds
                                            .toDouble() ??
                                        0.0)
                                    .clamp(
                                      0.0,
                                      mediaState?.duration.inMilliseconds
                                              .toDouble() ??
                                          0.0,
                                    ),
                          max:
                              mediaState?.duration.inMilliseconds.toDouble() ??
                              0.0,
                          onChanged: (value) {
                            globalSeek(Duration(milliseconds: value.toInt()));
                          },
                        ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 120.w,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Obx(
                  () => AnimatedSwitcher(
                    duration: Duration(milliseconds: 200),
                    transitionBuilder: horTitleTextTra,
                    child: _playController.loading
                        ? Text(
                            key: ValueKey('slider-loading-duration'),
                            _playController
                                    .bootStraping[_playController
                                        .nowPlayingTrackRx
                                        .value
                                        ?.id]
                                    ?.split('/')
                                    .last ??
                                '',
                            style: TextStyle(fontSize: 48.0.w),
                          )
                        : KeyedSubtree(
                            key: ValueKey('slider-playing-duration'),
                            child: _buildDurationBySplitStreams(
                              hourStream: _mediaDurationHourStream,
                              minuteStream: _mediaDurationMinuteStream,
                              secondStream: _mediaDurationSecondStream,
                              initialHour:
                                  (mediaState?.duration ?? Duration.zero)
                                      .inHours,
                              initialMinute:
                                  (mediaState?.duration ?? Duration.zero)
                                      .inMinutes
                                      .remainder(60),
                              initialSecond:
                                  (mediaState?.duration ?? Duration.zero)
                                      .inSeconds
                                      .remainder(60),
                              textStyle: TextStyle(fontSize: 48.0.w),
                              keyPrefix: 'slider-dur',
                            ),
                          ),
                  ),
                ),
              ),
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

// 播放/暂停按钮组件 - 带动画效果
class PlayPauseBtn extends StatefulWidget {
  final RxBool isPlaying;
  final double size;
  final VoidCallback? onPlayPressed;
  final VoidCallback? onPausePressed;
  final ButtonStyle? style;
  const PlayPauseBtn({
    Key? key,
    required this.isPlaying,
    this.size = 50.0,
    this.onPlayPressed,
    this.onPausePressed,
    this.style,
  }) : super(key: key);

  @override
  State<PlayPauseBtn> createState() => _PlayPauseBtnState();
}

class _PlayPauseBtnState extends State<PlayPauseBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Worker _worker;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 初始化状态
    if (widget.isPlaying.value) {
      _animationController.value = 1.0;
    }

    // 监听 RxBool 变化
    _worker = ever(widget.isPlaying, (isPlaying) {
      if (isPlaying) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _worker.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      style: widget.style,
      iconSize: globalHorizon ? 32 : 100.w,
      icon: AnimatedIcon(
        icon: AnimatedIcons.play_pause,
        progress: _animationController,
      ),
      onPressed: () {
        if (widget.isPlaying.value) {
          widget.onPausePressed?.call();
        } else {
          widget.onPlayPressed?.call();
        }
      },
    );
  }
}

Widget Function(Widget, Animation<double>) get horTitleTextTra =>
    (Widget child, Animation<double> animation) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInCirc),

        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          ),
          child: child,
        ),
      );
    };

Widget formatMediaStateByParts({TextStyle? textStyle}) {
  final style = textStyle ?? TextStyle(fontSize: 20.0);
  final state = _playController.mediaState.value;

  return Obx(() {
    bool disSomeEffect = Get.find<ThemeController>().disSomeEffect;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDurationBySplitStreams(
          hourStream: _mediaPositionHourStream,
          minuteStream: _mediaPositionMinuteStream,
          secondStream: _mediaPositionSecondStream,
          initialHour: state.position.inHours,
          initialMinute: state.position.inMinutes.remainder(60),
          initialSecond: state.position.inSeconds.remainder(60),
          textStyle: style,
          keyPrefix: 'pos',
          disSomeEffect: disSomeEffect,
        ),
        Text('/', style: style),
        _buildDurationBySplitStreams(
          hourStream: _mediaDurationHourStream,
          minuteStream: _mediaDurationMinuteStream,
          secondStream: _mediaDurationSecondStream,
          initialHour: state.duration.inHours,
          initialMinute: state.duration.inMinutes.remainder(60),
          initialSecond: state.duration.inSeconds.remainder(60),
          textStyle: style,
          keyPrefix: 'dur',
          disSomeEffect: disSomeEffect,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: StreamBuilder<bool>(
            stream: _mediaBufferingStream,
            initialData: state.buffering,
            builder: (context, snapshot) {
              final buffering = snapshot.data ?? false;
              if (!buffering) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('(', style: style),
                  _buildDurationBySplitStreams(
                    hourStream: _mediaBufferHourStream,
                    minuteStream: _mediaBufferMinuteStream,
                    secondStream: _mediaBufferSecondStream,
                    initialHour: state.buffer.inHours,
                    initialMinute: state.buffer.inMinutes.remainder(60),
                    initialSecond: state.buffer.inSeconds.remainder(60),
                    textStyle: style,
                    keyPrefix: 'buf',
                    disSomeEffect: disSomeEffect,
                  ),
                  Text(')', style: style),
                ],
              );
            },
          ),
        ),
      ],
    );
  });
}

Widget _buildDurationBySplitStreams({
  required Stream<int> hourStream,
  required Stream<int> minuteStream,
  required Stream<int> secondStream,
  required int initialHour,
  required int initialMinute,
  required int initialSecond,
  required TextStyle textStyle,
  required String keyPrefix,
  bool disSomeEffect = false,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        child: StreamBuilder<int>(
          stream: hourStream,
          initialData: initialHour,
          builder: (context, snapshot) {
            final hour = snapshot.data ?? 0;
            if (hour <= 0) return const SizedBox.shrink();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (disSomeEffect)
                  Text('${hour.toString().padLeft(2, '0')}:', style: textStyle)
                else ...[
                  StableAnimatedDigit(
                    key: ValueKey('$keyPrefix-hour'),
                    value: hour,
                    firstScrollAnimate: false,
                    fractionDigits: 0,
                    textStyle: textStyle,
                  ),
                  Text(':', style: textStyle),
                ],
              ],
            );
          },
        ),
      ),
      StreamBuilder<int>(
        stream: minuteStream,
        initialData: initialMinute,
        builder: (context, snapshot) {
          return disSomeEffect
              ? Text('${snapshot.data ?? 0}'.padLeft(2, '0'), style: textStyle)
              : StableAnimatedDigit(
                  key: ValueKey('$keyPrefix-min'),
                  value: snapshot.data ?? 0,
                  enableMinIntegerDigits: true,
                  firstScrollAnimate: false,
                  fractionDigits: 0,
                  textStyle: textStyle,
                );
        },
      ),
      Text(':', style: textStyle),
      StreamBuilder<int>(
        stream: secondStream,
        initialData: initialSecond,
        builder: (context, snapshot) {
          return disSomeEffect
              ? Text('${snapshot.data ?? 0}'.padLeft(2, '0'), style: textStyle)
              : StableAnimatedDigit(
                  key: ValueKey('$keyPrefix-sec'),
                  value: snapshot.data ?? 0,
                  enableMinIntegerDigits: true,
                  firstScrollAnimate: false,
                  textStyle: textStyle,
                  fractionDigits: 0,
                );
        },
      ),
    ],
  );
}

class StableAnimatedDigit extends StatefulWidget {
  final int value;
  final bool enableMinIntegerDigits;
  final bool firstScrollAnimate;
  final int fractionDigits;
  final TextStyle? textStyle;

  const StableAnimatedDigit({
    super.key,
    required this.value,
    this.enableMinIntegerDigits = false,
    this.firstScrollAnimate = false,
    this.fractionDigits = 0,
    this.textStyle,
  });

  @override
  State<StableAnimatedDigit> createState() => _StableAnimatedDigitState();
}

class _StableAnimatedDigitState extends State<StableAnimatedDigit> {
  late int _cachedValue;
  late Widget _cachedWidget;

  @override
  void initState() {
    super.initState();
    _cachedValue = widget.value;
    _cachedWidget = _buildDigit(_cachedValue);
  }

  @override
  void didUpdateWidget(covariant StableAnimatedDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _cachedValue) {
      _cachedValue = widget.value;
      _cachedWidget = _buildDigit(_cachedValue);
    }
  }

  Widget _buildDigit(int value) {
    return AnimatedDigitWidget(
      value: value,
      enableMinIntegerDigits: widget.enableMinIntegerDigits,
      firstScrollAnimate: widget.firstScrollAnimate,
      fractionDigits: widget.fractionDigits,
      textStyle: widget.textStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _cachedWidget;
  }
}
