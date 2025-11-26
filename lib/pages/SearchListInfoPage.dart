part of '../bodys.dart';

class Searchlistinfo extends StatelessWidget {
  Searchlistinfo();

  @override
  Widget build(BuildContext context) {
    // Get the global controller
    final controller = Get.find<XSearchController>();
    
    // 每次进入页面时刷新平台设置
    controller.refreshFromSettings();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: TextField(
                focusNode: controller.focusNode,
                decoration: const InputDecoration(
                  hintText: '请输入歌曲名，歌手或专辑',
                  border: InputBorder.none,
                ),
                controller: controller.searchTextController,
                autofocus: true,
              ),
            ),
            Obx(
              () => DropdownButton<String>(
                value: controller.selectedOption,
                icon: const Icon(Icons.arrow_downward),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    controller.updateSelectedOption(newValue);
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
      body: Obx(() {
        if (controller.loading.value) {
          return Center(child: globalLoadingAnime);
        }

        return CustomScrollView(
          controller: controller.scrollController,
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
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
                    showInfoSnackbar('尝试播放：${track.title}', null);
                    playsong(track, isByClick: true);
                  },
                );
              }, childCount: controller.tracks.length),
            ),
            if (controller.loadingMore.value)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(child: globalLoadingAnime),
                ),
              ),
          ],
        );
      }),
    );
  }
}
