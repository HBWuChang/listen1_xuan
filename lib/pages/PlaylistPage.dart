part of '../bodys.dart';

// PlaylistController for GetX state management
class PlaylistController extends GetxController {
  final BaseProvider source;

  PlaylistController({required this.source});

  // Reactive state variables
  final RxList<PlayList> playlists = <PlayList>[].obs;
  final RxBool loading = true.obs;
  final RxBool loadingMore = false.obs;
  final RxInt perPage = 20.obs;
  final RxBool hasMore = true.obs;
  final RxInt currentOffset = 0.obs;
  final ScrollController scrollController = ScrollController();

  @override
  void onInit() {
    super.onInit();
    currentOffset.value = 0;
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
      List<PlayList> result = await source.showPlaylist(
        offset: currentOffset.value,
        filterId: source.nowSelectedPlaylistFilter.value.id,
      )!;

      playlists.value = result;
      perPage.value = result.length;
      hasMore.value = true;
      loading.value = false;
    } catch (e) {
      logger.e('加载歌单数据失败', error: e);
      loading.value = false;
    }
  }

  Future<void> loadMoreData() async {
    if (loadingMore.value || !hasMore.value) return;

    try {
      loadingMore.value = true;
      currentOffset.value += perPage.value;

      List<PlayList> result = await source.showPlaylist(
        offset: currentOffset.value,
        filterId: source.nowSelectedPlaylistFilter.value.id,
      )!;

      logger.t('加载更多歌单数据成功: $result');
      if (result.isEmpty) {
        hasMore.value = false;
      } else {
        playlists.addAll(result);
      }
      loadingMore.value = false;
    } catch (e) {
      logger.e('加载更多歌单数据失败', error: e);
      loadingMore.value = false;
    }
  }

  Future<void> refreshData() async {
    playlists.clear();
    currentOffset.value = 0;
    hasMore.value = true;
    await loadData();
  }

  void onPlaylistTapped(PlayList playlist) {
    Ro.toArg(PlaylistInfoArgs(playListInfo: playlist.info));
  }

  // Helper method to get controller tag
  static String getControllerTag(String source, dynamic id) {
    return 'playlist_${source}_${id ?? 'default'}';
  }

  // Helper method to dispose controller with tag
  static void disposeController(String source, Map<String, dynamic> filter) {
    final tag = getControllerTag(source, filter);
    if (Get.isRegistered<PlaylistController>(tag: tag)) {
      Get.delete<PlaylistController>(tag: tag);
    }
  }
}

class PlaylistPage extends GetView<PlaylistController> {
  final BaseProvider source;

  const PlaylistPage({required this.source, super.key});

  @override
  String get tag => PlaylistController.getControllerTag(
    source.id,
    source.nowSelectedPlaylistFilter.value.id,
  );

  @override
  Widget build(BuildContext context) {
    // Initialize controller with unique tag based on source and filter
    final String controllerTag = tag;
    Get.put(PlaylistController(source: source), tag: controllerTag);

    return Scaffold(
      body: Center(
        child: Obx(() {
          if (controller.loading.value) {
            return globalLoadingAnime;
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
              Icon(Icons.music_note_outlined, size: 64, color: Colors.grey),
              16.sbh,
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
                  style: TextStyle(color: Colors.grey, fontSize: 14),
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
    double actualItemWidth =
        (availableWidth - (itemsPerRow - 1) * itemSpacing) / itemsPerRow;
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

  Widget _buildPlaylistItem(
    BuildContext context,
    PlayList playlist,
    double itemWidth,
  ) {
    return GestureDetector(
      onTap: () => controller.onPlaylistTapped(playlist),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExtendedImage.network(
                playlist.info.cover_img_url ?? '',
                fit: BoxFit.cover,
                cache: true,
                loadStateChanged: (ExtendedImageState state) {
                  if (state.extendedImageLoadState == LoadState.failed) {
                    return Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 40,
                      ),
                    );
                  }
                  if (state.extendedImageLoadState == LoadState.loading) {
                    return globalLoadingAnimeOfExtendedImage;
                  }
                  return null; // Use default rendering
                },
              )
              .clipSmoothRectSize(itemWidth)
              .sbs(itemWidth)
              .hero4playlistItemImg(playlist.info),
          8.sbh,
          Text(
            playlist.info.title ?? '未知歌单',
            style: TextStyle(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ).sbw(itemWidth),
        ],
      ).sbw(itemWidth),
    );
  }
}
