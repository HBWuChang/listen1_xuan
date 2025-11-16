import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:listen1_xuan/global_settings_animations.dart';
import 'package:listen1_xuan/play.dart';
import 'play_controller.dart';
import 'myPlaylist_controller.dart';
import 'package:listen1_xuan/models/Track.dart';

class NowPlayingController extends GetxController {
  var showScrollButton = false.obs;
  var searchQuery = ''.obs;
  var isSearching = false.obs;
  FocusNode searchFocusNode = FocusNode();
  // 获取其他控制器
  PlayController get playController => Get.find<PlayController>();
  MyPlayListController get playlistController =>
      Get.find<MyPlayListController>();
  late TextEditingController searchController;
  Function? scrollToCurrentTrack;
  @override
  void onInit() {
    super.onInit();
    searchController = TextEditingController();
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
    everAll([searchQuery, playController.currentPlayingRx], (_) {
      // 每当搜索查询变化时，更新过滤后的播放列表
      final query = searchQuery.value.toLowerCase().trim();
      if (query.isEmpty) {
        filteredPlayingList.value = currentPlayingList;
      } else {
        filteredPlayingList.value = currentPlayingList.where((track) {
          final title = track.title?.toLowerCase() ?? '';
          final artist = track.artist?.toLowerCase() ?? '';
          final album = track.album?.toLowerCase() ?? '';

          return title.contains(query) ||
              artist.contains(query) ||
              album.contains(query);
        }).toList();
      }
    });
    searchQuery.refresh();
  }

  @override
  void onClose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.onClose();
  }

  // 获取单个项目的实际高度（根据平台调整）
  double get itemHeight {
    return 44.0; // 默认值
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
  RxList<Track> filteredPlayingList = <Track>[].obs;

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
