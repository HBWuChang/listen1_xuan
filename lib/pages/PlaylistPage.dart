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

  /// 首屏加载失败标记与失败原因（页面据此展示错误详情）。
  final RxBool loadFailed = false.obs;
  final RxString loadError = ''.obs;

  /// 加载更多失败标记与失败原因。
  final RxBool loadMoreFailed = false.obs;
  final RxString loadMoreError = ''.obs;

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
    // 加载更多失败后不再自动重试，避免用户停在底部时反复请求；
    // 改由页面上的「重试」按钮显式触发。
    if (loadMoreFailed.value) return;
    if (scrollController.position.pixels ==
        scrollController.position.maxScrollExtent) {
      loadMoreData();
    }
  }

  Future<void> loadData() async {
    loading.value = true;
    loadFailed.value = false;
    loadError.value = '';
    loadMoreFailed.value = false;
    loadMoreError.value = '';
    try {
      final result = await _requestPlaylist(0);

      playlists.value = result;
      currentOffset.value = 0;
      perPage.value = result.length;
      hasMore.value = true;
      loading.value = false;
    } catch (e, stack) {
      logger.e('加载歌单数据失败', error: e, stackTrace: stack);
      loadError.value = _formatError(e);
      loadFailed.value = true;
      loading.value = false;
    }
  }

  Future<void> loadMoreData() async {
    if (loadingMore.value || !hasMore.value) return;

    loadingMore.value = true;
    loadMoreFailed.value = false;
    loadMoreError.value = '';
    // 仅当请求成功才推进 offset，否则重试会直接跳过一整页。
    final nextOffset = currentOffset.value + perPage.value;
    try {
      final result = await _requestPlaylist(nextOffset);

      logger.t('加载更多歌单数据成功: $result');
      if (result.isEmpty) {
        hasMore.value = false;
      } else {
        playlists.addAll(result);
        currentOffset.value = nextOffset;
      }
      loadingMore.value = false;
    } catch (e, stack) {
      logger.e('加载更多歌单数据失败', error: e, stackTrace: stack);
      loadMoreError.value = _formatError(e);
      loadMoreFailed.value = true;
      loadingMore.value = false;
    }
  }

  /// 请求一页歌单；失败时直接抛出，交给调用方决定如何展示。
  Future<List<PlayList>> _requestPlaylist(int offset) async {
    final future = source.showPlaylist(
      offset: offset,
      filterId: source.nowSelectedPlaylistFilter.value.id,
    );
    if (future == null) {
      throw StateError('${source.shortDisplayName}暂不支持歌单列表');
    }
    return await future;
  }

  /// 把异常整理成页面可以直接展示的错误原因。
  String _formatError(Object error) {
    return '数据源：${source.shortDisplayName}（${source.name}）\n'
        '分类：${source.nowSelectedPlaylistFilter.value.name}\n'
        '原因：$error';
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

          if (controller.loadFailed.value) {
            return _buildErrorView(context);
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
            // 下方的三种状态互斥：加载更多失败 / 加载中 / 可以继续加载。
            if (controller.loadMoreFailed.value)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      '加载更多失败',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    8.sbh,
                    SelectableText(
                      controller.loadMoreError.value,
                      textAlign: TextAlign.center,
                    ),
                    12.sbh,
                    FilledButton.icon(
                      onPressed: () => controller.loadMoreData(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              )
            else if (controller.loadingMore.value)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              )
            // 手动加载更多按钮
            else if (controller.hasMore.value)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () => controller.loadMoreData(),
                  child: const Text('加载更多'),
                ),
              )
            // 没有更多数据的提示
            else if (controller.playlists.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
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

  /// 首屏加载失败：展示具体原因并提供重试。
  Widget _buildErrorView(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            12.sbh,
            const Text(
              '加载失败',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            8.sbh,
            SelectableText(
              controller.loadError.value,
              textAlign: TextAlign.center,
            ),
            16.sbh,
            FilledButton.icon(
              onPressed: () => controller.loadData(),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
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
