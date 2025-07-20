import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../controllers/play_controller.dart';
import '../controllers/nowplaying_controller.dart';
import '../myplaylist.dart';

class NowPlayingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 确保页面加载后，滚动到当前播放位置
      Get.find<NowPlayingController>().scrollToCurrentTrack();
    });
    // 创建控制器实例
    final controller = Get.find<NowPlayingController>();
    // 获取主题
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async {
        Get.back(id: 1);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: _buildScrollToCurrentButton(context, controller),
        body: Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor.withOpacity(0.95),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              _buildHeader(context, controller),
              _buildSearchBar(context, controller),
              Expanded(
                child: _buildPlayingList(context, controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, NowPlayingController controller) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: theme.textTheme.bodyLarge?.color,
              size: 28,
            ),
            onPressed: () {
              Get.back(id: 1);
            },
          ),
          Expanded(
            child: Obx(() {
              final playingList = controller.filteredPlayingList; // 使用过滤后的列表
              final totalCount = controller.currentPlayingList.length;
              final filteredCount = playingList.length;
              
              return Text(
                controller.isSearching.value && controller.searchQuery.value.isNotEmpty
                    ? '搜索结果 ($filteredCount/$totalCount)'
                    : '当前播放 ($totalCount)',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              );
            }),
          ),
          IconButton(
            tooltip: controller.isSearching.value ? '关闭搜索' : '搜索',
            icon: Obx(() => Icon(
              controller.isSearching.value ? Icons.search_off : Icons.search,
              color: theme.textTheme.bodyLarge?.color,
            )),
            onPressed: () {
              controller.toggleSearch();
            },
          ),
          IconButton(
            tooltip: '清空播放列表',
            icon: Icon(
              Icons.clear_all,
              color: theme.textTheme.bodyLarge?.color,
            ),
            onPressed: () {
              _showClearDialog(context, controller);
            },
          ),
          IconButton(
            tooltip: '添加当前列表到歌单',
            icon: Icon(
              Icons.add_to_photos_outlined,
              color: theme.textTheme.bodyLarge?.color,
            ),
            onPressed: () {
              myplaylist.Add_to_my_playlist(
                null,
                Get.find<PlayController>().current_playing,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, NowPlayingController controller) {
    final theme = Theme.of(context);

    return Obx(() {
      if (!controller.isSearching.value) {
        return SizedBox.shrink();
      }

      return AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: TextField(
            controller: controller.searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '搜索歌曲、艺术家或专辑...',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                size: 20,
              ),
              suffixIcon: Obx(() {
                if (controller.searchQuery.value.isEmpty) {
                  return SizedBox.shrink();
                }
                return IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    size: 20,
                  ),
                  onPressed: controller.clearSearch,
                  splashRadius: 16,
                );
              }),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: theme.textTheme.bodyMedium,
            onChanged: (value) {
              // 搜索逻辑已经在 controller 中通过监听器处理
            },
          ),
        ),
      );
    });
  }

  Widget _buildPlayingList(
      BuildContext context, NowPlayingController controller) {
    return Obx(() {
      final playingList = controller.filteredPlayingList; // 使用过滤后的列表
      final currentTrackId = controller.currentTrackId;

      if (playingList.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                controller.isSearching.value && controller.searchQuery.value.isNotEmpty
                    ? Icons.search_off
                    : Icons.queue_music,
                size: 64,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.5),
              ),
              SizedBox(height: 16),
              Text(
                controller.isSearching.value && controller.searchQuery.value.isNotEmpty
                    ? '没有找到匹配的歌曲'
                    : '播放列表为空',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withOpacity(0.7),
                    ),
              ),
            ],
          ),
        );
      }

      return Scrollbar(
        controller: controller.scrollController,
        thumbVisibility: true, // 始终显示滚动条缩略图
        trackVisibility: true, // 始终显示滚动条轨道
        thickness: 12.0, // 增加滚动条厚度，便于触摸操作
        radius: Radius.circular(6), // 增加滚动条圆角
        interactive: true, // 启用交互式滚动条
        child: ReorderableListView.builder(
          scrollController: controller.scrollController,
          buildDefaultDragHandles: false,
          padding: EdgeInsets.symmetric(horizontal: 16),
          itemCount: playingList.length,
          onReorder: (oldIndex, newIndex) {
            // 在搜索状态下禁用重排序
            if (!controller.isSearching.value) {
              // 需要找到在原始列表中的索引
              final originalList = controller.currentPlayingList;
              final draggedTrack = playingList[oldIndex];
              final targetTrack = playingList[newIndex > oldIndex ? newIndex - 1 : newIndex];
              
              final originalOldIndex = originalList.indexWhere((t) => t.id == draggedTrack.id);
              final originalNewIndex = originalList.indexWhere((t) => t.id == targetTrack.id);
              
              if (originalOldIndex != -1 && originalNewIndex != -1) {
                controller.reorderPlaylist(originalOldIndex, originalNewIndex);
              }
            }
          },
          itemBuilder: (context, index) {
            final track = playingList[index];
            final isCurrentTrack = track.id == currentTrackId;

            return _buildTrackItem(
                context, track, index, isCurrentTrack, controller);
          },
        ),
      );
    });
  }

  Widget _buildTrackItem(BuildContext context, Track track, int index,
      bool isCurrentTrack, NowPlayingController controller) {
    final theme = Theme.of(context);

    return Container(
      key: ValueKey(track.id), // 重排序需要的key
      margin: EdgeInsets.only(bottom: 8), // 明确设置margin
      decoration: BoxDecoration(
        color: isCurrentTrack
            ? theme.colorScheme.primary.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        visualDensity: VisualDensity.compact, // 使用紧凑密度保持跨平台一致性
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽手柄 - 在搜索状态下隐藏
            Obx(() => controller.isSearching.value
                ? SizedBox(width: 20) // 占位符保持布局一致
                : ReorderableDragStartListener(
                    index: index,
                    child: Icon(
                      Icons.drag_handle,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                      size: 20,
                    ),
                  )),
            SizedBox(width: 8),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: theme.colorScheme.surface,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: track.img_url ?? '',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: theme.colorScheme.surface,
                    child: Icon(
                      Icons.music_note,
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: theme.colorScheme.surface,
                    child: Icon(
                      Icons.music_note,
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            if (isCurrentTrack) ...[
              Icon(
                Icons.graphic_eq,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              SizedBox(width: 4),
            ],
            Expanded(
              child: Obx(() {
                final query = controller.searchQuery.value;
                return _buildHighlightedText(
                  track.title ?? '未知歌曲',
                  query,
                  theme.textTheme.bodyLarge?.copyWith(
                    color: isCurrentTrack
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodyLarge?.color,
                    fontWeight:
                        isCurrentTrack ? FontWeight.w600 : FontWeight.normal,
                  ),
                  theme.colorScheme.secondary,
                );
              }),
            ),
          ],
        ),
        subtitle: Obx(() {
          final query = controller.searchQuery.value;
          return _buildHighlightedText(
            track.artist ?? '未知艺术家',
            query,
            theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
            theme.colorScheme.secondary,
          );
        }),
        trailing: IconButton(
            onPressed: isCurrentTrack
                ? null
                : () {
                    controller.removeTrackFromList(track);
                  },
            icon: Icon(
              Icons.delete,
            ),
            color: theme.colorScheme.error.withOpacity(0.7)),
        onTap: () {
          controller.playTrack(track);
        },
      ),
    );
  }

  void _showClearDialog(BuildContext context, NowPlayingController controller) {
    Get.defaultDialog(
      title: '清空播放列表',
      middleText: '确定要清空整个播放列表吗？',
      textCancel: '取消',
      textConfirm: '确认',
      confirmTextColor: Get.theme.colorScheme.onError,
      buttonColor: Get.theme.colorScheme.error,
      onConfirm: () {
        controller.clearPlaylist();
        Get.back();
      },
      onCancel: () {
        Get.back();
      },
    );
  }

  Widget _buildScrollToCurrentButton(
      BuildContext context, NowPlayingController controller) {
    return Obx(() {
      // 在搜索状态下，只有当前播放歌曲在搜索结果中时才显示浮动按钮
      final shouldShow = controller.shouldShowFloatingButton;
      final isCurrentInFilteredList = controller.filteredPlayingList
          .any((track) => track.id == controller.currentTrackId);
      
      if (!shouldShow || !isCurrentInFilteredList) {
        return SizedBox.shrink();
      }

      return AnimatedScale(
        scale: controller.showScrollButton.value ? 1.0 : 0.0,
        duration: Duration(milliseconds: 200),
        child: FloatingActionButton.small(
          onPressed: () => controller.scrollToCurrentTrack(),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          child: Icon(Icons.my_location, size: 20),
          tooltip: '定位到当前播放',
        ),
      );
    });
  }

  Widget _buildHighlightedText(
    String text,
    String query,
    TextStyle? baseStyle,
    Color highlightColor,
  ) {
    if (query.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];

    int start = 0;
    int index = lowerText.indexOf(lowerQuery);

    while (index != -1) {
      // 添加高亮前的文本
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: baseStyle,
        ));
      }

      // 添加高亮文本
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: baseStyle?.copyWith(
          backgroundColor: highlightColor.withOpacity(0.3),
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + query.length;
      index = lowerText.indexOf(lowerQuery, start);
    }

    // 添加剩余文本
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: baseStyle,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
