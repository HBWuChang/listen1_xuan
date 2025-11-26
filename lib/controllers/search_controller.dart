import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/global_settings_animations.dart';
import 'package:listen1_xuan/controllers/settings_controller.dart';
import 'package:listen1_xuan/models/Track.dart';
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
  final ScrollController scrollController = ScrollController();
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
    scrollController.addListener(_onScroll);

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

  void _onScroll() {
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent) {
      loadMoreData();
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

    // Skip if query is empty or unchanged
    if (query.isEmpty ||
        (query == lastQuery.value && source.value == lastSource.value)) {
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
        'type': songOrPlaylist.value ? 1 : 0,
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
        'type': songOrPlaylist.value ? 1 : 0,
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

  void _rollbackSearch(String prevQuery, String prevSource, int prevPage) {
    lastQuery.value = prevQuery;
    lastSource.value = prevSource;
    currentPage.value = prevPage;
  }

  @override
  void onClose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    focusNode.removeListener(_onFocusChange);
    focusNode.dispose();
    searchTextController.dispose();
    super.onClose();
  }

  void change_main_status(
    String id, {
    bool is_my = false,
    String search_text = "",
  }) {
    if (id != "") {
      Get.toNamed(id, arguments: {'listId': id, 'is_my': is_my}, id: 1);
    } else {
      if (search_text != "") {
        final searchController = Get.find<XSearchController>();
        searchController.searchTextController.text = search_text;
        Get.toNamed(RouteName.searchPage, id: 1);
      }
    }
  }
}
