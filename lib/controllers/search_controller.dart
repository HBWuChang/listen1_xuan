import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/global_settings_animations.dart';
import 'package:listen1_xuan/controllers/settings_controller.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:listen1_xuan/models/SearchPlayListRes.dart';
import 'package:listen1_xuan/loweb.dart';

import '../funcs.dart';
import 'routeController.dart';

// SearchController for GetX state management
class XSearchController extends GetxController {
  XSearchController();

  // Search options
  static const List<String> searchOptions = ['BiliBili', '网易云', "QQ", '酷狗'];

  // Reactive state variables
  final RxBool loading = true.obs;
  final RxBool loadingMore = false.obs;
  final RxBool songOrPlaylist = false.obs;
  final RxList<Track> tracks = <Track>[].obs;
  final RxMap<String, dynamic> result = <String, dynamic>{}.obs;
  final RxString source = 'netease'.obs;
  final RxString lastSource = 'netease'.obs;
  final RxInt currentPage = 1.obs;
  final RxString lastQuery = ''.obs;
  final RxString searchQuery = ''.obs;

  // 歌单搜索相关变量
  final RxBool playlistLoading = true.obs;
  final RxBool playlistLoadingMore = false.obs;
  final RxList<SearchPlayListItem> playlists = <SearchPlayListItem>[].obs;
  final RxMap<String, dynamic> playlistResult = <String, dynamic>{}.obs;
  final RxInt playlistCurrentPage = 1.obs;
  final RxString playlistLastQuery = ''.obs;
  final RxString playlistLastSource = 'netease'.obs;

  // Tab 控制
  final RxInt currentTabIndex = 0.obs;
  final RxBool showTabBar = true.obs;
  double _lastScrollOffset = 0.0;

  // 计算属性：从 source 获取显示名称
  String get selectedOption {
    switch (source.value) {
      case 'bilibili':
        return 'BiliBili';
      case 'netease':
        return '网易云';
      case 'qq':
        return 'QQ';
      case 'kugou':
        return '酷狗';
      default:
        return '网易云';
    }
  }

  // Controllers
  late TextEditingController searchTextController;
  final ScrollController songScrollController = ScrollController();
  final ScrollController playlistScrollController = ScrollController();
  final FocusNode focusNode = FocusNode();

  // Settings controller
  final SettingsController settingsController = Get.find<SettingsController>();

  @override
  void onInit() {
    super.onInit();

    // Initialize text controller
    searchTextController = TextEditingController();

    // Setup listeners
    _setupListeners();
  }

  void switchTab(int index) {
    currentTabIndex.value = index;
    // 切换 tab 时重置滚动状态
    _lastScrollOffset = 0.0;
    showTabBar.value = true;

    // 检查切换到的 tab 是否需要更新搜索结果
    final query = searchQuery.value.trim();
    if (query.isEmpty) return;

    if (index == 0) {
      // 切换到歌曲 tab，检查是否需要重新搜索
      if (lastQuery.value != query || lastSource.value != source.value) {
        _performSongSearch();
      }
    } else {
      // 切换到歌单 tab，检查是否需要重新搜索
      if (playlistLastQuery.value != query ||
          playlistLastSource.value != source.value) {
        _performPlaylistSearch();
      }
    }
  }

  // 每次进入页面时调用，重新加载平台设置
  void refreshFromSettings() {
    final lastSource = settingsController.searchLastSource;
    _updateSourceFromOption(lastSource);
  }

  void _setupListeners() {
    // Listen to text changes with debounce
    searchTextController.addListener(() {
      searchQuery.value = searchTextController.text;
    });

    // Debounced search trigger
    debounce(
      searchQuery,
      (_) => _performSearch(),
      time: const Duration(milliseconds: 400),
    );

    // Scroll listener for pagination
    songScrollController.addListener(_onSongScroll);
    playlistScrollController.addListener(_onPlaylistScroll);

    // Focus listener for hotkey management
    focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (focusNode.hasFocus) {
      set_inapp_hotkey(false);
    } else {
      set_inapp_hotkey(true);
    }
  }

  void _onSongScroll() {
    final currentOffset = songScrollController.position.pixels;

    // 控制 TabBar 显示/隐藏
    if (currentOffset > _lastScrollOffset && currentOffset > 50) {
      // 向下滚动，隐藏 TabBar
      if (showTabBar.value) {
        showTabBar.value = false;
      }
    } else if (currentOffset < _lastScrollOffset) {
      // 向上滚动，显示 TabBar
      if (!showTabBar.value) {
        showTabBar.value = true;
      }
    }

    _lastScrollOffset = currentOffset;

    // 分页加载
    if (songScrollController.position.pixels >=
        songScrollController.position.maxScrollExtent) {
      loadMoreData();
    }
  }

  void _onPlaylistScroll() {
    final currentOffset = playlistScrollController.position.pixels;

    // 控制 TabBar 显示/隐藏
    if (currentOffset > _lastScrollOffset && currentOffset > 50) {
      // 向下滚动，隐藏 TabBar
      if (showTabBar.value) {
        showTabBar.value = false;
      }
    } else if (currentOffset < _lastScrollOffset) {
      // 向上滚动，显示 TabBar
      if (!showTabBar.value) {
        showTabBar.value = true;
      }
    }

    _lastScrollOffset = currentOffset;

    // 分页加载
    if (playlistScrollController.position.pixels >=
        playlistScrollController.position.maxScrollExtent) {
      loadMorePlaylistData();
    }
  }

  void updateSelectedOption(String displayName) {
    _updateSourceFromOption(displayName);

    // Save to settings if enabled
    if (settingsController.searchUseLastSource) {
      settingsController.searchLastSource = displayName;
    }

    // 切换平台后重新搜索
    if (searchQuery.value.trim().isNotEmpty) {
      _performSearch();
    }
  }

  void _updateSourceFromOption(String option) {
    switch (option) {
      case 'BiliBili':
        source.value = 'bilibili';
        break;
      case '网易云':
        source.value = 'netease';
        break;
      case 'QQ':
        source.value = 'qq';
        break;
      case '酷狗':
        source.value = 'kugou';
        break;
      default:
        source.value = 'netease';
    }
  }

  Future<void> _performSearch() async {
    final query = searchQuery.value.trim();

    // Skip if query is empty
    if (query.isEmpty) {
      return;
    }

    // 只搜索当前显示的 tab
    if (currentTabIndex.value == 0) {
      // 当前显示歌曲 tab
      _performSongSearch();
    } else {
      // 当前显示歌单 tab
      _performPlaylistSearch();
    }
  }

  // 下拉刷新歌曲搜索
  Future<void> refreshSongSearch() async {
    final query = searchQuery.value.trim();
    if (query.isEmpty) return;

    // 强制重新搜索，不检查缓存
    lastQuery.value = '';
    currentPage.value = 1;
    await _performSongSearch();
  }

  // 下拉刷新歌单搜索
  Future<void> refreshPlaylistSearch() async {
    final query = searchQuery.value.trim();
    if (query.isEmpty) return;

    // 强制重新搜索，不检查缓存
    playlistLastQuery.value = '';
    playlistCurrentPage.value = 1;
    await _performPlaylistSearch();
  }

  Future<void> _performSongSearch() async {
    final query = searchQuery.value.trim();

    // Skip if query is empty or unchanged
    if (query.isEmpty ||
        (query == lastQuery.value &&
            source.value == lastSource.value &&
            tracks.isNotEmpty)) {
      return;
    }

    // Save previous state for rollback
    final previousQuery = lastQuery.value;
    final previousSource = lastSource.value;
    final previousPage = currentPage.value;

    // Update state
    lastQuery.value = query;
    lastSource.value = source.value;
    currentPage.value = 1;

    try {
      loading.value = true;

      final ret = await MediaService.search(source.value, {
        'keywords': query,
        'curpage': currentPage.value,
        'type': 0, // 搜索歌曲
      });

      ret["success"]((data) {
        try {
          result.value = data;
          tracks.value = List<Track>.from(
            data['result'].map((item) => Track.fromJson(item)),
          );
        } catch (e) {
          _rollbackSearch(previousQuery, previousSource, previousPage);
          showErrorSnackbar('搜索失败', e.toString());
        } finally {
          loading.value = false;
        }
      });
    } catch (e) {
      _rollbackSearch(previousQuery, previousSource, previousPage);
      loading.value = false;
      showErrorSnackbar('搜索请求失败', e.toString());
    }
  }

  Future<void> _performPlaylistSearch() async {
    final query = searchQuery.value.trim();

    // Skip if query is empty or unchanged
    if (query.isEmpty ||
        (query == playlistLastQuery.value &&
            source.value == playlistLastSource.value)) {
      return;
    }

    // Save previous state for rollback
    final previousQuery = playlistLastQuery.value;
    final previousSource = playlistLastSource.value;
    final previousPage = playlistCurrentPage.value;

    // Update state
    playlistLastQuery.value = query;
    playlistLastSource.value = source.value;
    playlistCurrentPage.value = 1;

    try {
      playlistLoading.value = true;

      final ret = await MediaService.search(source.value, {
        'keywords': query,
        'curpage': playlistCurrentPage.value,
        'type': 1, // 搜索歌单
      });

      ret["success"]((data) {
        try {
          playlistResult.value = data;
          playlists.value = List<SearchPlayListItem>.from(
            data['result'].map((item) => SearchPlayListItem.fromJson(item)),
          );
        } catch (e) {
          _rollbackPlaylistSearch(previousQuery, previousSource, previousPage);
          showErrorSnackbar('歌单搜索失败', e.toString());
        } finally {
          playlistLoading.value = false;
        }
      });
    } catch (e) {
      _rollbackPlaylistSearch(previousQuery, previousSource, previousPage);
      playlistLoading.value = false;
      showErrorSnackbar('歌单搜索请求失败', e.toString());
    }
  }

  Future<void> loadMoreData() async {
    if (loading.value || loadingMore.value) return;

    final previousPage = currentPage.value;

    try {
      currentPage.value += 1;

      // Check if we've reached the end
      if (result.isNotEmpty &&
          currentPage.value >=
              result['total'] / (tracks.length / (currentPage.value - 1))) {
        currentPage.value = previousPage;
        return;
      }

      loadingMore.value = true;

      final ret = await MediaService.search(source.value, {
        'keywords': searchQuery.value,
        'curpage': currentPage.value,
        'type': 0, // 搜索歌曲
      });

      ret["success"]((data) {
        try {
          result.value = data;
          tracks.addAll(
            List<Track>.from(
              data['result'].map((item) => Track.fromJson(item)),
            ),
          );
        } catch (e) {
          currentPage.value = previousPage;
          showErrorSnackbar('加载更多数据失败', e.toString());
        } finally {
          loadingMore.value = false;
        }
      });
    } catch (e) {
      currentPage.value = previousPage;
      loadingMore.value = false;
      showErrorSnackbar('加载更多数据失败', e.toString());
    }
  }

  Future<void> loadMorePlaylistData() async {
    if (playlistLoading.value || playlistLoadingMore.value) return;

    final previousPage = playlistCurrentPage.value;

    try {
      playlistCurrentPage.value += 1;

      // Check if we've reached the end
      if (playlistResult.isNotEmpty &&
          playlistCurrentPage.value >=
              playlistResult['total'] /
                  (playlists.length / (playlistCurrentPage.value - 1))) {
        playlistCurrentPage.value = previousPage;
        return;
      }

      playlistLoadingMore.value = true;

      final ret = await MediaService.search(source.value, {
        'keywords': searchQuery.value,
        'curpage': playlistCurrentPage.value,
        'type': 1, // 搜索歌单
      });

      ret["success"]((data) {
        try {
          playlistResult.value = data;
          playlists.addAll(
            List<SearchPlayListItem>.from(
              data['result'].map((item) => SearchPlayListItem.fromJson(item)),
            ),
          );
        } catch (e) {
          playlistCurrentPage.value = previousPage;
          showErrorSnackbar('加载更多歌单失败', e.toString());
        } finally {
          playlistLoadingMore.value = false;
        }
      });
    } catch (e) {
      playlistCurrentPage.value = previousPage;
      playlistLoadingMore.value = false;
      showErrorSnackbar('加载更多歌单失败', e.toString());
    }
  }

  void _rollbackSearch(String prevQuery, String prevSource, int prevPage) {
    lastQuery.value = prevQuery;
    lastSource.value = prevSource;
    currentPage.value = prevPage;
  }

  void _rollbackPlaylistSearch(
    String prevQuery,
    String prevSource,
    int prevPage,
  ) {
    playlistLastQuery.value = prevQuery;
    playlistLastSource.value = prevSource;
    playlistCurrentPage.value = prevPage;
  }

  @override
  void onClose() {
    songScrollController.removeListener(_onSongScroll);
    songScrollController.dispose();
    playlistScrollController.removeListener(_onPlaylistScroll);
    playlistScrollController.dispose();
    focusNode.removeListener(_onFocusChange);
    focusNode.dispose();
    searchTextController.dispose();
    super.onClose();
  }

  void toListByIDOrSearch(
    String id, {
    bool is_my = false,
    String search_text = "",
  }) {
    if (!isEmpty(id)) {
      Get.toNamed(id, arguments: {'listId': id, 'is_my': is_my}, id: 1);
    } else {
      if (!isEmpty(search_text)) {
        final searchController = Get.find<XSearchController>();
        searchController.searchTextController.text = search_text;
        Get.toNamed(RouteName.searchPage, id: 1);
      }
    }
  }
}
