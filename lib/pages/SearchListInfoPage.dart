part of '../bodys.dart';

class Searchlistinfo extends StatefulWidget {
  Searchlistinfo();

  @override
  State<Searchlistinfo> createState() => _SearchlistinfoState();
}

class _SearchlistinfoState extends State<Searchlistinfo>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  XSearchController? controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<XSearchController>();

    // 使用保存的 tab 索引初始化 TabController
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: controller!.currentTabIndex.value,
    );

    // 监听 TabController 的变化
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        controller?.switchTab(_tabController.index);
      }
    });

    // 每次进入页面时刷新平台设置
    controller?.refreshFromSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: TextField(
                focusNode: controller!.focusNode,
                decoration: const InputDecoration(
                  hintText: '请输入歌曲名，歌手或专辑',
                  border: InputBorder.none,
                ),
                controller: controller!.searchTextController,
                autofocus: true,
              ),
            ),
            Obx(
              () => DropdownButton<String>(
                value: controller!.selectedOption,
                icon: const Icon(Icons.arrow_downward),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    controller!.updateSelectedOption(newValue);
                  }
                },
                items: XSearchController.searchOptions
                    .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    })
                    .toList(),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Obx(
            () => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: controller!.showTabBar.value ? 48 : 0,
              child: controller!.showTabBar.value
                  ? TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: '歌曲'),
                        Tab(text: '歌单'),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSongList(controller!),
                _buildPlaylistList(controller!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongList(XSearchController controller) {
    return Obx(() {
      if (controller.loading.value) {
        return Center(child: globalLoadingAnime);
      }

      return RefreshIndicator(
        onRefresh: () => controller.refreshSongSearch(),
        child: ListView.builder(
          key: const PageStorageKey<String>('songList'),
          controller: controller.songScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount:
              controller.tracks.length + (controller.loadingMore.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= controller.tracks.length) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(child: globalLoadingAnime),
              );
            }

            final key = GlobalKey();
            final track = controller.tracks[index];

            return ListTile(
              title: Text(track.title ?? ''),
              subtitle: Text('${track.artist} - ${track.album}'),
              trailing: IconButton(
                key: key,
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  song_dialog(
                    context,
                    track,
                    position: Offset(
                      MediaQuery.of(context).size.width,
                      (key.currentContext!.findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dy,
                    ),
                  );
                },
              ),
              onTap: () {
                playsong(track, isByClick: true);
              },
            );
          },
        ),
      );
    });
  }

  Widget _buildPlaylistList(XSearchController controller) {
    return Obx(() {
      if (controller.playlistLoading.value) {
        return Center(child: globalLoadingAnime);
      }

      return RefreshIndicator(
        onRefresh: () => controller.refreshPlaylistSearch(),
        child: ListView.builder(
          key: const PageStorageKey<String>('playlistList'),
          controller: controller.playlistScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount:
              controller.playlists.length +
              (controller.playlistLoadingMore.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= controller.playlists.length) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(child: globalLoadingAnime),
              );
            }

            final playlist = controller.playlists[index];

            return ListTile(
              leading: playlist.imgUrl != null && playlist.imgUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: ExtendedImage.network(
                        playlist.imgUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        cache: true,
                        loadStateChanged: (state) {
                          if (state.extendedImageLoadState ==
                              LoadState.failed) {
                            return const Icon(Icons.image_not_supported);
                          }
                          return null;
                        },
                      ),
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.music_note),
                    ),
              title: Text(
                playlist.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: playlist.author != null && playlist.author!.isNotEmpty
                  ? Text(
                      playlist.author!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    )
                  : null,
              trailing: playlist.count != null
                  ? Text(
                      '${playlist.count} 首歌曲',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    )
                  : null,

              onTap: () {
                if (playlist.id != null) {
                  controller.toListByIDOrSearch(playlist.id!);
                }
              },
            );
          },
        ),
      );
    });
  }
}
