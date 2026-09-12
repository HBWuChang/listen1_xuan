import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/global_settings_animations.dart';
import 'package:listen1_xuan/models/Playlist.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:listen1_xuan/pages/playlist_info/playlist_info_args.dart';
import 'package:listen1_xuan/provider/loweb.dart';
import 'package:listen1_xuan/settings.dart';

class PlaylistInfoController extends GetxController {
  final PlaylistInfoArgs args;
  PlaylistInfoController(this.args)
    : result = PlayList(info: args.playListInfo);

  String get listId => args.listId;
  bool get isMy => args.isMy;

  /// 歌单数据。非响应式字段，页面通过 [loading] / [loadFailed] /
  /// [_tracksRevision] / [_filterQuery] 等响应式信号触发刷新。
  PlayList result;

  final loading = true.obs;
  final loadFailed = false.obs;
  final loadError = ''.obs;
  final isFav = false.obs;
  final useReorderableList = false.obs;

  /// 歌单结构变更计数，用于通知依赖 [tracks] 的 Obx 刷新。
  final _tracksRevision = 0.obs;

  /// 过滤关键字（小写），变化时依赖 [tracks] 的 Obx 会重新计算。
  final _filterQuery = ''.obs;

  List<Track>? _cachedTracks;
  int _cachedRevision = -1;
  String _cachedQuery = '';

  /// 直接读取 [result] 内的歌曲；有搜索关键字时返回过滤后的视图。
  List<Track> get tracks {
    final revision = _tracksRevision.value;
    final query = _filterQuery.value;
    if (_cachedTracks != null &&
        _cachedRevision == revision &&
        _cachedQuery == query) {
      return _cachedTracks!;
    }
    final all = result.tracks ?? const <Track>[];
    final computed = query.isEmpty
        ? all
        : all.where((track) {
            final title = track.title?.toLowerCase() ?? '';
            final artist = track.artist?.toLowerCase() ?? '';
            final album = track.album?.toLowerCase() ?? '';
            return title.contains(query) ||
                artist.contains(query) ||
                album.contains(query);
          }).toList();
    _cachedTracks = computed;
    _cachedRevision = revision;
    _cachedQuery = query;
    return computed;
  }

  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  final ScrollController outerScrollController = ScrollController();
  final ScrollController innerScrollController = ScrollController();

  // scroll bar state
  OverlayEntry? scrollBarOverlayEntry;
  bool scrollBarVisible = false;
  double scrollBarPos = 0.5;
  Timer? scrollBarTimer;
  StateSetter? scrollBarSetState;
  bool lastMoveIsUp = false;
  bool onDragSlider = false;
  double lastMove = 0;

  @override
  void onInit() {
    super.onInit();
    checkFav();
    loadData();
    searchController.addListener(onSearchChanged);
    innerScrollController.addListener(onInnerScroll);
    searchFocusNode.addListener(() {
      if (searchFocusNode.hasFocus) {
        setInAppHotKeyEnable(false);
      } else {
        setInAppHotKeyEnable(true);
      }
    });
  }

  void checkFav() {
    isFav.value = provider.myplaylist.isMyfavPlaylist(listId);
  }

  Future<void> loadData() async {
    loading.value = true;
    loadFailed.value = false;
    loadError.value = '';
    try {
      final source = provider.getProviderByItemId(listId);
      final data = await source.getPlaylist(listId);
      if (data == null) {
        throw StateError('接口未返回歌单数据');
      }
      if (data.info.title == null) {
        throw StateError('歌单不存在或已被删除');
      }
      result = data;
      _bumpTracks();
      loading.value = false;
    } catch (e, stack) {
      logger.e('加载歌单失败: $listId', error: e, stackTrace: stack);
      loadError.value = _formatError(e);
      loadFailed.value = true;
      loading.value = false;
    }
  }

  String _formatError(Object error) {
    String platformName;
    try {
      platformName = provider.getProviderByItemId(listId).shortDisplayName;
    } catch (_) {
      platformName = '未知平台';
    }
    return '歌单 ID：$listId\n'
        '平台：$platformName\n'
        '原因：$error';
  }

  void onSearchChanged() {
    _filterQuery.value = searchController.text.trim().toLowerCase();
  }

  void _bumpTracks() {
    _tracksRevision.value++;
  }

  void delTrack(Track track) {
    result.tracks?.remove(track);
    _bumpTracks();
  }

  void onReorder(int oldIndex, int newIndex) {
    if (!isMy) {
      showErrorSnackbar('只有自己创建的歌单才能排序', null);
      return;
    }
    if (searchController.text.trim().isNotEmpty) {
      showErrorSnackbar('搜索状态下无法排序', null);
      return;
    }
    final list = result.tracks;
    if (list == null ||
        oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= list.length ||
        newIndex >= list.length) {
      return;
    }
    provider.insertTrackToMyPlaylist(
      listId,
      list[oldIndex],
      list[newIndex],
      'top',
    );
    // provider 内部就是同一个 PlayList 对象，顺序已更新，这里只需通知刷新。
    _bumpTracks();
  }

  void onInnerScroll() {
    final position = innerScrollController.position;
    if (position.maxScrollExtent <= 0) {
      hideScrollBar();
      return;
    }
    if (!scrollBarVisible) {
      showScrollBar();
    }
    startAutoCloseTimer();
    scrollBarPos = (position.pixels / position.maxScrollExtent).clamp(
      0.0,
      1.0,
    );
    if (scrollBarSetState != null && scrollBarVisible) {
      try {
        scrollBarSetState!(() {});
      } catch (e) {
        scrollBarSetState = null;
      }
    }
    // 获取滚动信息
    final move = position.pixels - lastMove;
    // 判断滚动方向
    bool nowMoveIsUp = move > 0;
    if (nowMoveIsUp != lastMoveIsUp && move > 20) {
      lastMoveIsUp = nowMoveIsUp;
      return;
    }
    lastMoveIsUp = nowMoveIsUp;
    if (!onDragSlider) {
      if (move > 0) {
        if (outerScrollController.position.maxScrollExtent !=
            outerScrollController.offset) {
          outerScrollController.jumpTo(
            (outerScrollController.offset + move) >
                    outerScrollController.position.maxScrollExtent
                ? outerScrollController.position.maxScrollExtent
                : (outerScrollController.offset + move),
          );
        }
      } else {
        if (outerScrollController.offset != 0) {
          outerScrollController.jumpTo(
            (outerScrollController.offset + move) < 0
                ? 0
                : (outerScrollController.offset + move),
          );
        }
      }
    }
    lastMove = position.pixels;
  }

  void showScrollBar() {
    final max = innerScrollController.position.maxScrollExtent;
    if (max <= 0) {
      return;
    }
    scrollBarPos = (innerScrollController.position.pixels / max).clamp(
      0.0,
      1.0,
    );
    scrollBarVisible = true;
    scrollBarOverlayEntry = createOverlayEntry();
    final context = Get.overlayContext;
    if (context != null) {
      Overlay.of(context).insert(scrollBarOverlayEntry!);
    }
    startAutoCloseTimer();
  }

  void startAutoCloseTimer() {
    scrollBarTimer?.cancel();
    scrollBarTimer = Timer(const Duration(seconds: 1), hideScrollBar);
  }

  void hideScrollBar() {
    scrollBarTimer?.cancel();
    scrollBarTimer = null;
    scrollBarOverlayEntry?.remove();
    scrollBarOverlayEntry = null;
    scrollBarSetState = null;
    scrollBarVisible = false;
  }

  OverlayEntry createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Positioned(
        top: 100,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: hideScrollBar,
            child: Container(
              height: MediaQuery.of(context).size.height - 200,
              width: 30,
              decoration: BoxDecoration(
                color: const Color.fromARGB(0, 120, 120, 120),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(0, 120, 120, 120),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: RotatedBox(
                quarterTurns: 1,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    scrollBarSetState = setState;
                    return Slider(
                      value: scrollBarPos,
                      onChanged: (value) {
                        setState(() {
                          scrollBarPos = value;
                        });
                        innerScrollController.jumpTo(
                          value *
                              innerScrollController.position.maxScrollExtent,
                        );
                        startAutoCloseTimer();
                      },
                      onChangeStart: (value) => onDragSlider = true,
                      onChangeEnd: (value) {
                        onDragSlider = false;
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void onClose() {
    searchController.removeListener(onSearchChanged);
    searchController.dispose();
    searchFocusNode.dispose();
    innerScrollController.removeListener(onInnerScroll);
    innerScrollController.dispose();
    outerScrollController.dispose();
    hideScrollBar();
    super.onClose();
  }
}
