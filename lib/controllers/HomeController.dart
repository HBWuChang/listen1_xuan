import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/main.dart';
import 'package:listen1_xuan/models/PlayListFilters.dart';
import 'package:listen1_xuan/provider/base.dart';
import 'package:preload_page_view/preload_page_view.dart';

import '../provider/loweb.dart';

class HomeController extends GetxController {
  bool get showFilter =>
      playlistFiltersLoadingStatus != PlaylistFiltersLoadingStatus.empty;
  bool get canFilterClick =>
      playlistFiltersLoadingStatus == PlaylistFiltersLoadingStatus.loaded ||
      playlistFiltersLoadingStatus == PlaylistFiltersLoadingStatus.failed;
  PlaylistFiltersLoadingStatus get playlistFiltersLoadingStatus =>
      currentProvider.playlistFiltersLoadingStatus.value;
  PlayListFilters get playlistFilters => currentProvider.playlistFilters.value;

  BaseProvider get currentProvider => globalHorizon
      ? supportShowPlaylistProvidersH[selectedIndex.value]
      : supportShowPlaylistProviders[selectedIndex.value];
  final selectedIndex = 0.obs;

  HomeController get homeController => this;
  void updatePageControllers() {
    try {
      pageControllerHorizon?.dispose(); // 销毁旧的 PageController
    } catch (e) {
      debugPrint('销毁旧的 pageControllerHorizon 失败: $e');
    }
    try {
      pageControllerPortrait?.dispose(); // 销毁旧的 PageController
    } catch (e) {
      debugPrint('销毁旧的 pageControllerPortrait 失败: $e');
    }
    pageControllerHorizon = PreloadPageController(
      initialPage: provider.indexOfFirstOnH,
    );
    pageControllerPortrait = PreloadPageController(
      initialPage: provider.indexOfFirstOnV,
    );
    pageControllerHorizon!.addListener(() {
      int currentIndex = pageControllerHorizon!.page!.round();
      selectedIndex.value = currentIndex;
    });
    pageControllerPortrait!.addListener(() {
      int index = pageControllerPortrait!.page!.round();
      selectedIndex.value = index;
    });
  }

  PreloadPageController? pageControllerHorizon; // 声明 PageController
  PreloadPageController? pageControllerPortrait; // 声明 PageController
}
