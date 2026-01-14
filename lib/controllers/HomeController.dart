import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:preload_page_view/preload_page_view.dart';

class HomeController extends GetxController {
  final show_filter = false.obs;
  static const List<String> sources = [
    'myplaylist',
    'bilibili',
    'netease',
    'qq',
    'kugou',
  ];
  List<bool> show_filters = [false, false, true, true, false];
  late RxList<Map<String, dynamic>> filters =
      List<Map<String, dynamic>>.generate(
        sources.length,
        (i) => {'id': '', 'name': '全部'},
      ).obs;
  final source = 'myplaylist'.obs;
  final selectedIndex = 0.obs;
  List<int> offsets = List.generate(sources.length, (i) => 0);
  late BuildContext main_context;

  // bool show_more = false;
  List<Map<String, dynamic>> filter_details = List.generate(
    sources.length,
    (i) => {'recommend': [], 'all': []},
  );
  HomeController get homeController => this;
  void updatePageControllers() {
    try {
      pageControllerHorizon.dispose(); // 销毁旧的 PageController
    } catch (e) {}
    try {
      pageControllerPortrait.dispose(); // 销毁旧的 PageController
    } catch (e) {}
    pageControllerHorizon = PreloadPageController(initialPage: 1);
    pageControllerPortrait = PreloadPageController(initialPage: 0);
    pageControllerHorizon.addListener(() {
      int currentIndex = pageControllerHorizon.page!.round();
      debugPrint(
        "currentIndex: $currentIndex, sources.length: ${HomeController.sources.length}",
      );
      currentIndex = currentIndex + 1;
      homeController.source.value = HomeController.sources[currentIndex];
      homeController.show_filter.value =
          homeController.show_filters[currentIndex];
      selectedIndex.value = currentIndex;
    });
    pageControllerPortrait.addListener(() {
      int index = pageControllerPortrait.page!.round();
      source.value = sources[index];
      homeController.show_filter.value = homeController.show_filters[index];
      selectedIndex.value = index;
    });
  }

  void change_fliter(dynamic id, String name) {
    homeController.filters[HomeController.sources.indexOf(
      homeController.source.value,
    )] = (Map<String, Object>.from({
      'id': id,
      'name': name,
    }));
  }

  late PreloadPageController pageControllerHorizon; // 声明 PageController
  late PreloadPageController pageControllerPortrait; // 声明 PageController
}
