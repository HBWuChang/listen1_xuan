part of '../bodys.dart';

// PlaylistController for GetX state management
class PlaylistController extends GetxController {
  final String source;
  final int initialOffset;
  final Map<String, dynamic> filter;
  final Function(String) onPlaylistTap;

  PlaylistController({
    required this.source,
    required this.initialOffset,
    required this.filter,
    required this.onPlaylistTap,
  });

  // Reactive state variables
  final RxList<dynamic> playlists = <dynamic>[].obs;
  final RxBool loading = true.obs;
  final RxBool loadingMore = false.obs;
  final RxInt perPage = 20.obs;
  final RxBool hasMore = true.obs;
  final RxInt currentOffset = 0.obs;
  final ScrollController scrollController = ScrollController();

  @override
  void onInit() {
    super.onInit();
    currentOffset.value = initialOffset;
    loadData();
    scrollController.addListener(_onScroll);
  }

  @override
  void onClose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.onClose();
  }

  void _onScroll() {
    if (scrollController.position.pixels ==
        scrollController.position.maxScrollExtent) {
      loadMoreData();
    }
  }

  Future<void> loadData() async {
    try {
      loading.value = true;
      Map<String, dynamic> result = await MediaService.showPlaylistArray(
        source,
        initialOffset,
        filter['id'],
      );

      result['success']((data) {
        print(data); // 打印实际的数据
        try {
          playlists.value = data.toList();
          perPage.value = data.length;
          hasMore.value = true;
          loading.value = false;
        } catch (e) {
          print(e);
          loading.value = false;
        }
      });
    } catch (e) {
      print(e);
      loading.value = false;
    }
  }

  Future<void> loadMoreData() async {
    if (loadingMore.value || !hasMore.value) return;
    
    try {
      loadingMore.value = true;
      currentOffset.value += perPage.value;
      
      Map<String, dynamic> result = await MediaService.showPlaylistArray(
        source,
        currentOffset.value,
        filter['id'],
      );
      
      result['success']((data) {
        print(data); // 打印实际的数据
        if (data.length == 0) {
          hasMore.value = false;
        } else {
          playlists.addAll(data);
        }
        loadingMore.value = false;
      });
    } catch (e) {
      print(e);
      loadingMore.value = false;
    }
  }

  Future<void> refreshData() async {
    try {
      playlists.clear();
      currentOffset.value = initialOffset;
      hasMore.value = true;
      await loadData();
    } catch (e) {
      print(e);
    }
  }

  void onPlaylistTapped(Map<String, dynamic> playlist) {
    Get.toNamed(
      playlist['id'],
      arguments: {'listId': playlist['id'], 'is_my': false},
      id: 1,
    );
  }

  // Helper method to get controller tag
  static String getControllerTag(String source, Map<String, dynamic> filter) {
    return 'playlist_${source}_${filter['id'] ?? 'default'}';
  }

  // Helper method to dispose controller with tag
  static void disposeController(String source, Map<String, dynamic> filter) {
    final tag = getControllerTag(source, filter);
    if (Get.isRegistered<PlaylistController>(tag: tag)) {
      Get.delete<PlaylistController>(tag: tag);
    }
  }
}

class Playlist extends GetView<PlaylistController> {
  final String source;
  final int offset;
  final Map<String, dynamic> filter;
  final Function(String) onPlaylistTap;

  const Playlist({
    required this.source,
    required this.offset,
    required this.filter,
    required this.onPlaylistTap,
    Key? key,
  }) : super(key: key);

  @override
  String? get tag => PlaylistController.getControllerTag(source, filter);

  @override
  Widget build(BuildContext context) {
    // Initialize controller with unique tag based on source and filter
    final String controllerTag = PlaylistController.getControllerTag(source, filter);
    Get.put(PlaylistController(
      source: source,
      initialOffset: offset,
      filter: filter,
      onPlaylistTap: onPlaylistTap,
    ), tag: controllerTag);

    return Scaffold(
      body: Center(
        child: Obx(() {
          if (controller.loading.value) {
            return global_loading_anime;
          }

          return _buildPlaylistLayout(context);
        }),
      ),
    );
  }

  Widget _buildPlaylistLayout(BuildContext context) {
    return Obx(() {
      // 如果加载完成且没有歌单数据，显示刷新按钮
      if (!controller.loading.value && controller.playlists.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.music_note_outlined,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => controller.refreshData(),
                icon: Icon(Icons.refresh),
                label: Text('重新加载'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        );
      }

      return SingleChildScrollView(
        controller: controller.scrollController,
        
        child: Column(
          children: [
            _buildPlaylistWrap(context),
            if (controller.loadingMore.value)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            // 手动加载更多按钮
            if (!controller.loadingMore.value && controller.hasMore.value)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () => controller.loadMoreData(),
                  child: Text('加载更多'),
                ),
              ),
            // 没有更多数据的提示
            if (!controller.hasMore.value && controller.playlists.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  '没有更多数据了',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildPlaylistWrap(BuildContext context) {
    // Calculate item width based on screen size
    final screenWidth = MediaQuery.of(context).size.width;
    final isLandscape = screenWidth > MediaQuery.of(context).size.height;
    final padding = isLandscape ? 40.0 : 20.0;
    final availableWidth = screenWidth - padding;
    
    // Adaptive item width (minimum 120, maximum 200)
    const double minItemWidth = 120.0;
    const double maxItemWidth = 200.0;
    const double itemSpacing = 10.0;
    
    // Calculate how many items can fit in one row
    int itemsPerRow = (availableWidth / (minItemWidth + itemSpacing)).floor();
    if (itemsPerRow < 1) itemsPerRow = 1;
    
    // Calculate actual item width
    double actualItemWidth = (availableWidth - (itemsPerRow - 1) * itemSpacing) / itemsPerRow;
    if (actualItemWidth > maxItemWidth) {
      actualItemWidth = maxItemWidth;
    }
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding / 2),
      child: Wrap(
        spacing: itemSpacing,
        runSpacing: itemSpacing,
        children: controller.playlists.map((playlist) {
          return _buildPlaylistItem(context, playlist, actualItemWidth);
        }).toList(),
      ),
    );
  }

  Widget _buildPlaylistItem(BuildContext context, Map<String, dynamic> playlist, double itemWidth) {
    return GestureDetector(
      onTap: () => controller.onPlaylistTapped(playlist),
      child: Container(
        width: itemWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: itemWidth,
              height: itemWidth, // Square aspect ratio
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: ExtendedImage.network(
                  playlist['cover_img_url'],
                  fit: BoxFit.cover,
                  cache: true,
                ),
              ),
            ),
            SizedBox(height: 8.0),
            Container(
              width: itemWidth,
              child: Text(
                playlist['title'],
                style: TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
