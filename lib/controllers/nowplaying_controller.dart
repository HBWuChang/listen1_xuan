import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:listen1_xuan/global_settings_animations.dart';
import 'package:listen1_xuan/play.dart';
import 'play_controller.dart';
import 'myPlaylist_controller.dart';
import 'package:listen1_xuan/models/Track.dart';

class NowPlayingController extends GetxController {
  late ScrollController scrollController;
  late TextEditingController searchController;
  var showScrollButton = false.obs;
  var searchQuery = ''.obs;
  var isSearching = false.obs;
  FocusNode searchFocusNode = FocusNode();
  // 获取其他控制器
  PlayController get playController => Get.find<PlayController>();
  MyPlayListController get playlistController =>
      Get.find<MyPlayListController>();

  @override
  void onInit() {
    super.onInit();
    scrollController = ScrollController();
    searchController = TextEditingController();
    scrollController.addListener(_onScroll);
    searchFocusNode.addListener(() {
      if (searchFocusNode.hasFocus) {
        set_inapp_hotkey(false);
      } else {
        set_inapp_hotkey(true);
      }
    });
    // 监听搜索框变化
    searchController.addListener(() {
      searchQuery.value = searchController.text;
    });

    // 页面初始化后滚动到当前播放位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToCurrentTrack();
    });
  }

  @override
  void onClose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    searchController.dispose();
    searchFocusNode.dispose();
    super.onClose();
  }

  // 获取单个项目的实际高度（根据平台调整）
  double get itemHeight {
    return 44.0; // 默认值
  }

  // 调试方法：打印当前平台和使用的高度值
  void debugPrintItemHeight() {
    String platform = 'Unknown';
    if (GetPlatform.isWindows)
      platform = 'Windows';
    else if (GetPlatform.isAndroid)
      platform = 'Android';
    else if (GetPlatform.isIOS)
      platform = 'iOS';
    else if (GetPlatform.isMacOS)
      platform = 'macOS';
    else if (GetPlatform.isLinux)
      platform = 'Linux';
    else if (GetPlatform.isWeb)
      platform = 'Web';

    print('当前平台: $platform');
    print('使用的项目高度: $itemHeight');
  }

  void _onScroll() {
    // 检查当前播放的歌曲是否在可视区域内
    if (scrollController.hasClients) {
      final playingList = filteredPlayingList; // 使用过滤后的列表
      final currentTrackId =
          playController.getPlayerSettings("nowplaying_track_id") ?? '';
      final currentIndex = playingList.indexWhere(
        (track) => track.id == currentTrackId,
      );

      if (currentIndex != -1) {
        final currentItemOffset = currentIndex * itemHeight;
        final viewportTop = scrollController.offset;
        final viewportBottom =
            viewportTop + scrollController.position.viewportDimension;

        // 判断当前播放项目是否在可视区域内
        final isCurrentVisible =
            currentItemOffset >= viewportTop &&
            currentItemOffset <= viewportBottom;

        showScrollButton.value = !isCurrentVisible;
      }
    }
  }

  void scrollToCurrentTrack() {
    final playingList = filteredPlayingList; // 使用过滤后的列表
    final currentTrackId =
        playController.getPlayerSettings("nowplaying_track_id") ?? '';

    // 找到当前播放歌曲的索引
    final currentIndex = playingList.indexWhere(
      (track) => track.id == currentTrackId,
    );

    if (currentIndex != -1 && scrollController.hasClients) {
      // 计算滚动位置 - 使用动态高度
      final targetOffset = currentIndex * itemHeight;

      // 获取可视区域高度
      final viewportHeight = scrollController.position.viewportDimension;

      // 调整滚动位置，让当前播放的项目在屏幕中央
      final centeredOffset =
          targetOffset - (viewportHeight / 2) + (itemHeight / 2);

      // 确保滚动位置在有效范围内
      final maxOffset = scrollController.position.maxScrollExtent;
      final finalOffset = centeredOffset.clamp(0.0, maxOffset);

      scrollController.animateTo(
        finalOffset,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );

      // 添加震动反馈
      HapticFeedback.lightImpact();
    }
  }

  void playTrack(Track track) {
    playsong(track, true, false, true);
    HapticFeedback.lightImpact();
  }

  void removeTrackFromList(Track track) {
    final currentList = playController.current_playing;
    currentList.removeWhere((t) => t.id == track.id);
    playController.set_current_playing(currentList);
  }

  void clearPlaylist() {
    playController.set_current_playing([playController.currentTrack]);
  }

  void reorderPlaylist(int oldIndex, int newIndex) {
    final currentList = List<Track>.from(playController.current_playing);

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final track = currentList.removeAt(oldIndex);
    currentList.insert(newIndex, track);

    playController.set_current_playing(currentList);
  }

  // 获取当前播放列表
  List<Track> get currentPlayingList => playController.current_playing;

  // 获取搜索过滤后的播放列表
  List<Track> get filteredPlayingList {
    final query = searchQuery.value.toLowerCase().trim();
    if (query.isEmpty) {
      return currentPlayingList;
    }

    return currentPlayingList.where((track) {
      final title = track.title?.toLowerCase() ?? '';
      final artist = track.artist?.toLowerCase() ?? '';
      final album = track.album?.toLowerCase() ?? '';

      return title.contains(query) ||
          artist.contains(query) ||
          album.contains(query);
    }).toList();
  }

  // 获取当前播放歌曲ID
  String get currentTrackId =>
      playController.getPlayerSettings("nowplaying_track_id") ?? '';

  // 获取歌单列表
  List<PlayList> get playlists =>
      playlistController.playerlists.values.toList();

  // 检查是否有当前播放歌曲
  bool get hasCurrentTrack =>
      currentPlayingList.any((track) => track.id == currentTrackId);

  // 检查是否应该显示浮动按钮
  bool get shouldShowFloatingButton =>
      hasCurrentTrack &&
      currentPlayingList.isNotEmpty &&
      showScrollButton.value;

  // 搜索相关方法
  void toggleSearch() {
    isSearching.value = !isSearching.value;
    if (!isSearching.value) {
      clearSearch();
    }
  }

  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
  }

  void startSearch() {
    isSearching.value = true;
  }

  void stopSearch() {
    isSearching.value = false;
    clearSearch();
  }
}
