import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/provider/loweb.dart';
import 'package:listen1_xuan/widgets/ext/ext_widget.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import '../bodys.dart';
import '../controllers/play_controller.dart';
import '../controllers/nowplaying_controller.dart';
import 'package:listen1_xuan/global_settings_animations.dart'
    show isDesktop, isMobile;
import 'package:listen1_xuan/models/Track.dart';

/// 播放列表行高（与 [ListTile.minTileHeight] 保持一致）。
/// 固定行高可以让 super_sliver_list 精确估算 extent，并支持用初始滚动偏移直接定位。
const double _kTrackRowHeight = 40;

/// 移动端滚动条行为。
///
/// Flutter 默认只在桌面平台（linux/macOS/windows）的
/// [MaterialScrollBehavior.buildScrollbar] 中自动添加 [Scrollbar]，
/// 移动端不会展示滚动条。这里复用桌面端的同一套逻辑，让移动端的
/// 垂直滚动列表也显示滚动条。
class _AlwaysScrollbarBehavior extends MaterialScrollBehavior {
  const _AlwaysScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // 与桌面端 MaterialScrollBehavior 保持一致：
    // 仅垂直方向添加滚动条，且必须提供 controller。
    switch (axisDirectionToAxis(details.direction)) {
      case Axis.horizontal:
        return child;
      case Axis.vertical:
        assert(details.controller != null);
        return Scrollbar(controller: details.controller, child: child);
    }
  }
}

class NowPlayingPage extends StatefulWidget {
  @override
  _NowPlayingPageState createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  late NowPlayingPageController controller;
  late ScrollController scrollController;
  final ListController _listController = ListController();
  RxBool useReorderableList = false.obs;
  @override
  void initState() {
    super.initState();
    controller = Get.find<NowPlayingPageController>();
    // 首帧就按已知行高定位到当前播放项附近，避免先构建列表顶部的窗口、
    // 再通过 jumpToItem 跳转导致同一帧内构建两批列表项。
    scrollController = ScrollController(
      initialScrollOffset: _initialScrollOffset(),
    );
    scrollController.addListener(_onScroll);
    controller.scrollToCurrentTrack = scrollToCurrentTrack;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 此时列表已经在目标位置附近，这里只是精确居中对齐（微调，不会批量新建子项）
      scrollToCurrentTrack(animated: false);
      controller.showScrollButton.value = false; // 初始化时隐藏按钮
    });
  }

  /// 用固定行高估算当前播放项的位置，作为首帧的初始滚动偏移。
  double _initialScrollOffset() {
    final playingList = controller.filteredPlayingList;
    final index = playingList.indexWhere(
      (track) => track.id == controller.currentTrackId,
    );
    if (index <= 0) return 0;
    return index * _kTrackRowHeight;
  }

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    controller.scrollToCurrentTrack = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 创建控制器实例
    // 获取主题
    final theme = Theme.of(context);

    return Scaffold(
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
            Expanded(child: _buildPlayingList(context, controller)),
          ],
        ),
      ),
    );
  }

  void _onScroll() {
    // 使用 SuperSliverList 的 visibleRange API 判断当前播放歌曲是否在可视区域内
    if (scrollController.hasClients && _listController.isAttached) {
      final playingList = controller.filteredPlayingList;
      final currentTrackId = controller.currentTrackId;
      final currentIndex = playingList.indexWhere(
        (track) => track.id == currentTrackId,
      );

      if (currentIndex != -1) {
        final range = _listController.visibleRange;
        final isCurrentVisible =
            range != null &&
            currentIndex >= range.$1 &&
            currentIndex <= range.$2;

        controller.showScrollButton.value = !isCurrentVisible;
      }
    }
  }

  void scrollToCurrentTrack({bool animated = true}) async {
    final playingList = controller.filteredPlayingList; // 使用过滤后的列表
    final currentTrackId = controller.currentTrackId;

    // 找到当前播放歌曲的索引
    final currentIndex = playingList.indexWhere(
      (track) => track.id == currentTrackId,
    );

    if (currentIndex != -1 &&
        scrollController.hasClients &&
        _listController.isAttached) {
      if (animated) {
        _listController.animateToItem(
          index: () => currentIndex,
          scrollController: scrollController,
          alignment: 0.5,
          duration: (_) => Duration(milliseconds: 500),
          curve: (_) => Curves.easeInOutSine,
          teleport: true,
          teleportThreshold: 1.2,
          approachFactor: 1.2,
        );
      } else {
        _listController.jumpToItem(
          index: currentIndex,
          scrollController: scrollController,
          alignment: 0.5,
        );
      }

      // 添加震动反馈
      HapticFeedback.lightImpact();
    }
  }

  Widget _buildHeader(
    BuildContext context,
    NowPlayingPageController controller,
  ) {
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
                controller.isSearching.value &&
                        controller.searchQuery.value.isNotEmpty
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
            icon: Obx(
              () => Icon(
                controller.isSearching.value ? Icons.search_off : Icons.search,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            onPressed: () {
              controller.toggleSearch();
            },
          ),
          Tooltip(
            message: '排序',
            child: IconButton(
              onPressed: () {
                useReorderableList.value = !useReorderableList.value;
              },
              icon: Transform.rotate(
                angle: -math.pi / 2.0,
                child: Obx(
                  () => Icon(
                    Icons.compare_arrows_rounded,
                    color: useReorderableList.value
                        ? theme.colorScheme.primary
                        : null,
                  ),
                ),
              ),
            ),
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
              provider.myplaylist.Add_to_my_playlist(
                null,
                Get.find<PlayController>().current_playing,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    NowPlayingPageController controller,
  ) {
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
            focusNode: controller.searchFocusNode,
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
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
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
    BuildContext context,
    NowPlayingPageController controller,
  ) {
    final list = Obx(() {
      final playingList = controller.filteredPlayingList; // 使用过滤后的列表
      final currentTrackId = controller.currentTrackId;
      // 在这里统一订阅搜索状态，替代原先每个列表项内部的 Obx
      final isSearching = controller.isSearching.value;
      final query = controller.searchQuery.value;

      if (playingList.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                controller.isSearching.value &&
                        controller.searchQuery.value.isNotEmpty
                    ? Icons.search_off
                    : Icons.queue_music,
                size: 64,
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withOpacity(0.5),
              ),
              16.sbh,
              Text(
                controller.isSearching.value &&
                        controller.searchQuery.value.isNotEmpty
                    ? '没有找到匹配的歌曲'
                    : '播放列表为空',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
            ],
          ),
        );
      }

      final canReorder = useReorderableList.value && !isSearching;

      if (canReorder) {
        return AnimatedReorderableListView(
          onReorder: (oldIndex, newIndex) {
            controller.reorderPlaylist(oldIndex, newIndex);
          },
          isSameItem: (trackA, trackB) => trackA.id == trackB.id,
          controller: scrollController,
          items: playingList,
          longPressDraggable: true,
          buildDefaultDragHandles: false,
          enterTransition: [SlideInDown()],
          exitTransition: [SlideInUp()],
          insertDuration: const Duration(milliseconds: 250),
          removeDuration: const Duration(milliseconds: 250),
          dragStartDelay: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final track = playingList[index];
            return _TrackTile(
              key: ValueKey(track.id),
              track: track,
              isCurrentTrack: track.id == currentTrackId,
              reorderEnabled: true,
              isSearching: isSearching,
              query: query,
              controller: controller,
            );
          },
        );
      }

      return SuperListView.builder(
        controller: scrollController,
        listController: _listController,
        itemCount: playingList.length,
        padding: EdgeInsets.symmetric(horizontal: 16),
        // 行内容没有需要保活的状态，去掉每项的 AutomaticKeepAlive 包装
        addAutomaticKeepAlives: false,
        // 行高固定：让 jumpToItem / 初始偏移的估算精确
        extentEstimation: (_, __) => _kTrackRowHeight,
        // cache 区的子项延迟到后续帧填充，避免首帧一次性物化过多列表项
        delayPopulatingCacheArea: true,
        itemBuilder: (context, index) {
          final track = playingList[index];
          return _TrackTile(
            key: ValueKey(track.id),
            track: track,
            isCurrentTrack: track.id == currentTrackId,
            reorderEnabled: false,
            isSearching: isSearching,
            query: query,
            controller: controller,
          );
        },
      );
    });

    // 移动端默认不显示滚动条，这里复用桌面端的展示逻辑。
    // 桌面端由 MaterialScrollBehavior 自动添加滚动条，因此无需额外包裹。
    // 通过 ScrollbarTheme 统一加粗滚动条、两端圆角（胶囊形），
    // 并开启 interactive 以支持拖动滑块控制列表。
    final styledList = ScrollbarTheme(
      data: ScrollbarTheme.of(context).copyWith(
        thickness: const WidgetStatePropertyAll(16),
        radius: const Radius.circular(8),
        crossAxisMargin: 2,
        interactive: true,
      ),
      child: list,
    );

    if (isMobile) {
      return ScrollConfiguration(
        behavior: const _AlwaysScrollbarBehavior(),
        child: styledList,
      );
    }
    return styledList;
  }

  void _showClearDialog(
    BuildContext context,
    NowPlayingPageController controller,
  ) {
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
    BuildContext context,
    NowPlayingPageController controller,
  ) {
    return Obx(() {
      // 在搜索状态下，只有当前播放歌曲在搜索结果中时才显示浮动按钮
      final shouldShow = controller.shouldShowFloatingButton;
      final isCurrentInFilteredList = controller.filteredPlayingList.any(
        (track) => track.id == controller.currentTrackId,
      );

      if (!shouldShow || !isCurrentInFilteredList || useReorderableList.value) {
        return SizedBox.shrink();
      }

      return AnimatedScale(
        scale: controller.showScrollButton.value ? 1.0 : 0.0,
        duration: Duration(milliseconds: 200),
        child: FloatingActionButton.small(
          onPressed: scrollToCurrentTrack,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          tooltip: '定位到当前播放',
          child: Icon(Icons.my_location, size: 20),
        ),
      );
    });
  }
}

/// 单个播放列表项。
///
/// 相比原实现做了这些优化：
/// - 用 [Text]/[Text.rich] 代替 [SelectableText]（不再为每行创建整套文本编辑栈），
///   标题加 [Tooltip] 便于查看被省略的完整内容；
/// - 用一个轻量的 [InkResponse] + [Icon] 代替两个 [IconButton]（桌面端还只在
///   hover / 当前播放项上才构建，并用 Stack 悬浮在右侧、带渐变背景，不占用标题宽度）；
/// - 当前项背景仍用 Container + BoxDecoration，保持原有的圆角高亮效果；
/// - 搜索状态由列表外层统一传入，去掉每行两个 Obx；
/// - 固定 [ListTile.minTileHeight]，让滚动定位可以按 `index * 行高` 计算。
class _TrackTile extends StatefulWidget {
  const _TrackTile({
    super.key,
    required this.track,
    required this.isCurrentTrack,
    required this.reorderEnabled,
    required this.isSearching,
    required this.query,
    required this.controller,
  });

  final Track track;
  final bool isCurrentTrack;
  final bool reorderEnabled;
  final bool isSearching;
  final String query;
  final NowPlayingPageController controller;

  @override
  State<_TrackTile> createState() => _TrackTileState();
}

class _TrackTileState extends State<_TrackTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = widget.track;
    final isCurrentTrack = widget.isCurrentTrack;
    // 桌面端仅在 hover 或当前播放项上显示操作按钮
    final showActions = !isDesktop || _hovered || isCurrentTrack;

    final displayText = '${track.title ?? '未知歌曲'} · ${track.artist ?? '未知艺术家'}';

    final tile = ListTile(
      minTileHeight: _kTrackRowHeight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      visualDensity: VisualDensity.compact, // 使用紧凑密度保持跨平台一致性
      dense: true, // 使用紧凑模式进一步减少高度
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrentTrack) ...[
            Icon(Icons.graphic_eq, size: 20, color: theme.colorScheme.primary),
            8.sbw,
          ] else
            28.sbw, // 占位符保持对齐
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Tooltip(
              // 鼠标悬停（移动端长按）查看被省略的完整标题
              message: displayText,
              waitDuration: const Duration(milliseconds: 500),
              child: _buildHighlightedText(
                displayText,
                widget.query,
                theme.textTheme.bodyMedium?.copyWith(
                  color: isCurrentTrack
                      ? theme.colorScheme.primary
                      : theme.textTheme.bodyLarge?.color,
                  fontWeight: isCurrentTrack
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                theme.colorScheme.secondary,
              ),
            ),
          ),
        ],
      ),
      subtitle: null, // 移除副标题
      // 桌面端操作按钮用 Stack 悬浮在右侧，不占用标题显示空间
      trailing: isDesktop ? null : _buildActions(theme),
      onTap: () => widget.controller.playTrack(track),
    );

    // 保留原来的 Container 装饰（当前项圆角高亮），视觉效果与之前一致
    final item = Container(
      decoration: BoxDecoration(
        color: isCurrentTrack
            ? theme.colorScheme.primary.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: tile,
    );

    if (!isDesktop) {
      return item;
    }

    return MouseRegion(
      onEnter: (_) {
        if (!_hovered) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: Stack(
        children: [
          item,
          // hover / 当前播放项时才构建，并悬浮在行右侧
          if (showActions)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                // 从透明渐变到页面底色，盖住标题尾部但保留整行宽度
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      theme.scaffoldBackgroundColor.withValues(alpha: 0),
                      theme.scaffoldBackgroundColor.withValues(alpha: 0.75),
                      theme.scaffoldBackgroundColor,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 28, right: 4),
                  child: _buildActions(theme),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(ThemeData theme) {
    final track = widget.track;
    return Row(
      mainAxisSize: MainAxisSize.min, // 确保按钮在行内对齐
      children: [
        _TrackActionIcon(
          icon: Icons.list,
          onTap: () {
            song_dialog(Get.context!, track);
          },
        ),
        _TrackActionIcon(
          icon: Icons.delete,
          color: theme.colorScheme.error.withOpacity(0.7),
          onTap: widget.isCurrentTrack
              ? null
              : () {
                  widget.controller.removeTrackFromList(track);
                },
        ),
      ],
    );
  }
}

/// 轻量的行内操作按钮：InkResponse + Icon，替换昂贵的 IconButton。
class _TrackActionIcon extends StatelessWidget {
  const _TrackActionIcon({required this.icon, this.onTap, this.color});

  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? color
                : Theme.of(context).disabledColor.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}

/// 高亮搜索关键字（用 [Text]/[Text.rich]，避免每行创建 SelectableText 的编辑栈）。
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
      spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
    }

    // 添加高亮文本
    spans.add(
      TextSpan(
        text: text.substring(index, index + query.length),
        style: baseStyle?.copyWith(
          backgroundColor: highlightColor.withOpacity(0.3),
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    start = index + query.length;
    index = lowerText.indexOf(lowerQuery, start);
  }

  // 添加剩余文本
  if (start < text.length) {
    spans.add(TextSpan(text: text.substring(start), style: baseStyle));
  }

  return Text.rich(
    TextSpan(children: spans),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}
