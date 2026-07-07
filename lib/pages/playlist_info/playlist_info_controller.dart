import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/global_settings_animations.dart';
import 'package:listen1_xuan/loweb.dart';
import 'package:listen1_xuan/models/Playlist.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:listen1_xuan/myplaylist.dart';
import 'package:listen1_xuan/pages/playlist_info/playlist_info_args.dart';
import 'package:listen1_xuan/settings.dart';

class PlaylistInfoController extends GetxController {
  final PlaylistInfoArgs args;
  PlaylistInfoController(this.args)
    : _result = PlayList(info: args.playListInfo).obs;
  String get listId => args.listId;
  bool get isMy => args.isMy;
  final Rx<PlayList> _result;

  PlayList get result => _result.value;

  set result(result) => _result.value = result;

  final loading = true.obs;
  final loadFailed = false.obs;
  final isFav = false.obs;
  final useReorderableList = false.obs;

  final tracks = <Track>[].obs;
  List<Track> unfilteredTracks = [];

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
    searchController.addListener(filterTracks);
    innerScrollController.addListener(onInnerScroll);
    searchFocusNode.addListener(() {
      if (searchFocusNode.hasFocus) {
        setInAppHotKeyEnable(false);
      } else {
        setInAppHotKeyEnable(true);
      }
    });
  }

  void checkFav() async {
    final res = await myplaylist.isMyfavPlaylist(listId);
    isFav.value = res;
  }

  void loadData() async {
    var res = await MediaService.getPlaylist(listId);
    res['success']?.call((data) {
      try {
        if (data is PlayList) {
          result = data;
        } else {
          result = PlayList.fromJson(data);
        }
      } catch (e) {
        logger.e('歌单数据解析失败', error: e);
        result = PlayList.fromJson({
          'info': {'id': listId},
        });
      }
      unfilteredTracks = result.tracks ?? [];
      tracks.value = unfilteredTracks;
      loading.value = false;
      if (result.info.title == null) {
        loadFailed.value = true;
      }
    });
  }

  void delTrack(Track track) {
    unfilteredTracks.remove(track);
    filterTracks();
  }

  void filterTracks() {
    String query = searchController.text.toLowerCase();
    tracks.value = unfilteredTracks.where((track) {
      final title = track.title?.toLowerCase() ?? '';
      final artist = track.artist?.toLowerCase() ?? '';
      final album = track.album?.toLowerCase() ?? '';
      return title.contains(query) ||
          artist.contains(query) ||
          album.contains(query);
    }).toList();
  }

  void onReorder(int oldIndex, int newIndex) {
    if (!isMy) {
      showErrorSnackbar('只有自己创建的歌单才能排序', null);
      return;
    }
    if (searchController.text.toLowerCase().isNotEmpty) {
      showErrorSnackbar('搜索状态下无法排序', null);
      return;
    }
    MediaService.insertTrackToMyPlaylist(
      listId,
      tracks[oldIndex],
      tracks[newIndex],
      'top',
    );
    final item = tracks.removeAt(oldIndex);
    tracks.insert(newIndex, item);
  }

  void onInnerScroll() {
    if (!scrollBarVisible) {
      showScrollBar();
    }
    startAutoCloseTimer();
    scrollBarPos =
        innerScrollController.position.pixels /
        innerScrollController.position.maxScrollExtent;
    scrollBarPos = scrollBarPos > 1 ? 1 : scrollBarPos;
    scrollBarPos = scrollBarPos < 0 ? 0 : scrollBarPos;
    if (scrollBarSetState != null && scrollBarVisible) {
      try {
        scrollBarSetState!(() {});
      } catch (e) {
        scrollBarSetState = null;
      }
    }
    // 获取滚动信息
    final move = innerScrollController.position.pixels - lastMove;
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
    lastMove = innerScrollController.position.pixels;
  }

  void showScrollBar() {
    scrollBarPos =
        innerScrollController.position.pixels /
        innerScrollController.position.maxScrollExtent;
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
    scrollBarTimer = Timer(Duration(seconds: 1), () {
      scrollBarOverlayEntry?.remove();
      scrollBarOverlayEntry = null;
      scrollBarVisible = false;
    });
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
            onTap: () {
              scrollBarOverlayEntry?.remove();
              scrollBarOverlayEntry = null;
              scrollBarVisible = false;
            },
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
    searchController.dispose();
    searchFocusNode.dispose();
    innerScrollController.dispose();
    outerScrollController.dispose();
    scrollBarTimer?.cancel();
    scrollBarOverlayEntry?.remove();
    super.onClose();
  }
}
