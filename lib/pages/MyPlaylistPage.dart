part of '../bodys.dart';

class MyPlaylist extends StatefulWidget {
  MyPlaylist({super.key});

  @override
  State<MyPlaylist> createState() => _MyPlaylistState();
}

class _MyPlaylistState extends State<MyPlaylist> {
  List<PlayList> _playlistsBl = [];
  List<PlayList> _playlistsNe = [];
  List<PlayList> _playlistsQq = [];
  bool _isExpandedMy = true;
  bool _isExpandedFav = false;
  bool _isExpandedBl = false;
  bool _isExpandedNe = false;
  bool _isExpandedQq = false;
  bool _isBlDataLoaded = false;
  bool _isNeDataLoaded = false;
  bool _isQqDataLoaded = false;

  bool _isIconOnlyMode(double width) => width <= 90;

  bool _isCompactMode(double width) => width <= 220;

  double _coverSize(double width) {
    return 50;
  }

  Widget _buildCoverFallbackText(String text, double size) {
    final content = text.trim().isEmpty ? '歌单' : text;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      padding: EdgeInsets.all(size <= 34 ? 2 : 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: size <= 34 ? 8 : 10,
          height: 1.1,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _buildPlaylistCover({
    required String title,
    required String? coverUrl,
    required double size,
  }) {
    if (coverUrl == null || coverUrl.isEmpty) {
      return _buildCoverFallbackText(title, size);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: ExtendedImage.network(
        coverUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cache: true,
        loadStateChanged: (state) {
          if (state.extendedImageLoadState == LoadState.failed) {
            return _buildCoverFallbackText(title, size);
          }
          return null;
        },
      ),
    );
  }

  Future<void> _openPlaylist(PlayList playlist, {required bool isMy}) async {
    final args = <String, dynamic>{'listId': playlist.info.id};
    if (isMy) {
      args['is_my'] = true;
    }
    await Get.toNamed(playlist.info.id, arguments: args, id: 1);
  }

  Widget _buildPlaylistTile({
    required PlayList playlist,
    required bool isMy,
    required double availableWidth,
  }) {
    final iconOnly = _isIconOnlyMode(availableWidth);
    final compact = _isCompactMode(availableWidth);
    final title = playlist.info.title ?? '';
    final cover = _buildPlaylistCover(
      title: title,
      coverUrl: playlist.info.cover_img_url,
      size: _coverSize(availableWidth),
    );

    if (iconOnly) {
      return Tooltip(
        message: title,
        child: InkWell(
          onTap: () => _openPlaylist(playlist, isMy: isMy),
          child: SizedBox(
            height: 48,
            child: Align(alignment: Alignment.center, child: cover),
          ),
        ),
      );
    }

    // final leadingWidth = compact ? 36.0 : 44.0;
    double sizeHeight = compact ? 48 : 56;
    final horizontalPadding = compact ? 8.0 : 12.0;

    return Tooltip(
      message: title,
      child: InkWell(
        onTap: () => _openPlaylist(playlist, isMy: isMy),
        child: SizedBox(
          height: sizeHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              children: [
                SizedBox(
                  width: sizeHeight,
                  child: Center(child: cover),
                ),
                SizedBox(width: compact ? 8 : 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required Widget leading,
    required String title,
    required VoidCallback onTap,
    required double availableWidth,
    bool centerLeadingWhenIconOnly = false,
  }) {
    final iconOnly = _isIconOnlyMode(availableWidth);
    final compact = _isCompactMode(availableWidth);
    final horizontalPadding = (iconOnly && centerLeadingWhenIconOnly)
        ? 0.0
        : (iconOnly ? 6.0 : (compact ? 8.0 : 12.0));
    final leadingWidth = iconOnly ? 18.0 : 24.0;

    return Tooltip(
      message: title,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: compact ? 44 : 56,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              mainAxisAlignment: (iconOnly && centerLeadingWhenIconOnly)
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: leadingWidth,
                  child: Center(child: leading),
                ),
                if (!iconOnly) ...[
                  SizedBox(width: compact ? 8 : 12),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        style: TextStyle(fontSize: compact ? 15 : 20),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _loadBlData() async {
    try {
      final resultBl = await bilibili.Xuan_get_bl_playlist();
      setState(() {
        _playlistsBl = resultBl;
        _isBlDataLoaded = true;
      });
    } catch (e) {
      logger.e('哔哩哔哩歌单加载失败', error: e);
    }
  }

  void _loadNeData() async {
    try {
      final neUserInfo = await Netease().get_user();
      final uid = neUserInfo['result']['user_id'];
      final resultNe = await netease.get_user_created_playlist(
        '/get_user_favorite_playlist?user_id=$uid',
      );
      final resultNe2 = await netease.get_user_favorite_playlist(
        '/get_user_favorite_playlist?user_id=$uid',
      );
      var flag1 = false;
      var flag2 = false;

      void checkLoaded() {
        if (flag1 && flag2) {
          setState(() {
            _isNeDataLoaded = true;
          });
        }
      }

      resultNe['success']((data) {
        if (data['status'] != 'fail') {
          for (var i = 0; i < data['data']['playlists'].length; i++) {
            _playlistsNe.add(
              PlayList(
                info: PlayListInfo(
                  id: data['data']['playlists'][i]['id'],
                  cover_img_url: data['data']['playlists'][i]['cover_img_url'],
                  title: data['data']['playlists'][i]['title'],
                  source_url: data['data']['playlists'][i]['source_url'],
                ),
              ),
            );
          }
        }
        flag1 = true;
        checkLoaded();
      });

      resultNe2['success']((data) {
        if (data['status'] != 'fail') {
          for (var i = 0; i < data['data']['playlists'].length; i++) {
            _playlistsNe.add(
              PlayList(
                info: PlayListInfo(
                  id: data['data']['playlists'][i]['id'],
                  cover_img_url: data['data']['playlists'][i]['cover_img_url'],
                  title: data['data']['playlists'][i]['title'],
                  source_url: data['data']['playlists'][i]['source_url'],
                ),
              ),
            );
          }
        }
        flag2 = true;
        checkLoaded();
      });
    } catch (e) {
      showErrorSnackbar('网易云音乐歌单加载失败', e.toString());
    }
  }

  void _loadQqData() async {
    try {
      final qqUserInfo = await QQ().get_user();
      final uid = qqUserInfo['data']['user_id'];
      final resultQq = await qq.get_user_created_playlist(
        '/get_user_favorite_playlist?user_id=$uid',
      );
      final resultQq2 = await qq.get_user_favorite_playlist(
        '/get_user_favorite_playlist?user_id=$uid',
      );
      var flag1 = false;
      var flag2 = false;

      void checkLoaded() {
        if (flag1 && flag2) {
          setState(() {
            _isQqDataLoaded = true;
          });
        }
      }

      resultQq['success']((data) {
        if (data['status'] != 'fail') {
          for (var i = 0; i < data['data']['playlists'].length; i++) {
            _playlistsQq.add(
              PlayList(
                info: PlayListInfo(
                  cover_img_url: data['data']['playlists'][i]['cover_img_url'],
                  title: data['data']['playlists'][i]['title'],
                  id: data['data']['playlists'][i]['id'],
                  source_url: data['data']['playlists'][i]['source_url'],
                ),
              ),
            );
          }
        }
        flag1 = true;
        checkLoaded();
      });

      resultQq2['success']((data) {
        if (data['status'] != 'fail') {
          for (var i = 0; i < data['data']['playlists'].length; i++) {
            _playlistsQq.add(
              PlayList(
                info: PlayListInfo(
                  cover_img_url: data['data']['playlists'][i]['cover_img_url'],
                  title: data['data']['playlists'][i]['title'],
                  id: data['data']['playlists'][i]['id'],
                  source_url: data['data']['playlists'][i]['source_url'],
                ),
              ),
            );
          }
        }
        flag2 = true;
        checkLoaded();
      });
    } catch (e) {
      showErrorSnackbar('QQ音乐歌单加载失败', e.toString());
    }
  }

  Widget _buildExpandableSection({
    required Widget leading,
    required String title,
    required bool isExpanded,
    required double availableWidth,
    required Widget body,
    required ValueChanged<bool> onExpandedChanged,
  }) {
    final controller = ExpandableController(initialExpanded: isExpanded);
    return ExpandableNotifier(
      controller: controller,
      child: Builder(
        builder: (context) {
          return ExpandablePanel(
            theme: const ExpandableThemeData(
              hasIcon: false,
              tapHeaderToExpand: false,
              tapBodyToCollapse: false,
              tapBodyToExpand: false,
              animationDuration: Duration(milliseconds: 180),
            ),
            header: _buildSectionHeader(
              leading: leading,
              title: title,
              availableWidth: availableWidth,
              centerLeadingWhenIconOnly: true,
              onTap: () {
                final nextExpanded = !controller.expanded;
                controller.expanded = nextExpanded;
                onExpandedChanged(nextExpanded);
              },
            ),
            collapsed: const SizedBox.shrink(),
            expanded: body,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        floatingActionButton: Obx(
          () => FloatingActionButton(
            heroTag: HeroTags.songReplaceFab,
            mini: Get.find<SettingsController>().songReplaceFabMini,
            onPressed: () {
              if (Get.find<RouteController>().inSongReplacePage.value) {
                Get.back(id: 1);
                return;
              }
              Get.toNamed(RouteName.songReplacePage, id: 1);
            },
            tooltip: '歌曲替换列表',
            child: Icon(Icons.find_replace_rounded),
          ),
        ),
        floatingActionButtonLocation:
            Get.find<SettingsController>().songReplaceFabMini
            ? Get.find<SettingsController>()
                  .songReplaceFabLocation
                  .fabMiniLocation
            : Get.find<SettingsController>().songReplaceFabLocation.fabLocation,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildExpandableSection(
                    leading: const Icon(Icons.library_music, size: 18),
                    title: '我创建的歌单',
                    isExpanded: _isExpandedMy,
                    availableWidth: availableWidth,
                    onExpandedChanged: (expanded) {
                      setState(() {
                        _isExpandedMy = expanded;
                      });
                    },
                    body: Obx(
                      () => Column(
                        children: Get.find<MyPlayListController>()
                            .playerlists
                            .values
                            .toList()
                            .map(
                              (playlist) => _buildPlaylistTile(
                                playlist: playlist,
                                isMy: true,
                                availableWidth: availableWidth,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  _buildExpandableSection(
                    leading: const Icon(Icons.star, size: 18),
                    title: '我收藏的歌单',
                    isExpanded: _isExpandedFav,
                    availableWidth: availableWidth,
                    onExpandedChanged: (expanded) {
                      setState(() {
                        _isExpandedFav = expanded;
                      });
                    },
                    body: Obx(
                      () => Column(
                        children: Get.find<MyPlayListController>()
                            .favoriteplayerlists
                            .values
                            .map(
                              (playlist) => _buildPlaylistTile(
                                playlist: playlist,
                                isMy: false,
                                availableWidth: availableWidth,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  _buildExpandableSection(
                    leading: SvgPicture.string(
                      '<svg width="18" height="18" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg" class="zhuzhan-icon"><path fill-rule="evenodd" clip-rule="evenodd" d="M3.73252 2.67094C3.33229 2.28484 3.33229 1.64373 3.73252 1.25764C4.11291 0.890684 4.71552 0.890684 5.09591 1.25764L7.21723 3.30403C7.27749 3.36218 7.32869 3.4261 7.37081 3.49407H10.5789C10.6211 3.4261 10.6723 3.36218 10.7325 3.30403L12.8538 1.25764C13.2342 0.890684 13.8368 0.890684 14.2172 1.25764C14.6175 1.64373 14.6175 2.28484 14.2172 2.67094L13.364 3.49407H14C16.2091 3.49407 18 5.28493 18 7.49407V12.9996C18 15.2087 16.2091 16.9996 14 16.9996H4C1.79086 16.9996 0 15.2087 0 12.9996V7.49406C0 5.28492 1.79086 3.49407 4 3.49407H4.58579L3.73252 2.67094ZM4 5.42343C2.89543 5.42343 2 6.31886 2 7.42343V13.0702C2 14.1748 2.89543 15.0702 4 15.0702H14C15.1046 15.0702 16 14.1748 16 13.0702V7.42343C16 6.31886 15.1046 5.42343 14 5.42343H4ZM5 9.31747C5 8.76519 5.44772 8.31747 6 8.31747C6.55228 8.31747 7 8.76519 7 9.31747V10.2115C7 10.7638 6.55228 11.2115 6 11.2115C5.44772 11.2115 5 10.7638 5 10.2115V9.31747ZM12 8.31747C11.4477 8.31747 11 8.76519 11 9.31747V10.2115C11 10.7638 11.4477 11.2115 12 11.2115C12.5523 11.2115 13 10.7638 13 10.2115V9.31747C13 8.76519 12.5523 8.31747 12 8.31747Z" fill="gray"></path></svg>',
                    ),
                    title: '我的哔哩哔哩收藏',
                    isExpanded: _isExpandedBl,
                    availableWidth: availableWidth,
                    onExpandedChanged: (expanded) {
                      setState(() {
                        _isExpandedBl = expanded;
                      });
                      if (expanded && !_isBlDataLoaded) {
                        _loadBlData();
                      }
                    },
                    body: _isBlDataLoaded
                        ? Column(
                            children: _playlistsBl
                                .map(
                                  (playlist) => _buildPlaylistTile(
                                    playlist: playlist,
                                    isMy: false,
                                    availableWidth: availableWidth,
                                  ),
                                )
                                .toList(),
                          )
                        : Center(child: globalLoadingAnime),
                  ),
                  _buildExpandableSection(
                    leading: ExtendedImage.network(
                      'https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/28469918905/0dfc/b6c0/d913/713572367ec9d917628e41266a39a67f.png',
                      width: 18,
                      cache: true,
                      height: 18,
                    ),
                    title: '我的网易云歌单',
                    isExpanded: _isExpandedNe,
                    availableWidth: availableWidth,
                    onExpandedChanged: (expanded) {
                      setState(() {
                        _isExpandedNe = expanded;
                      });
                      if (expanded && !_isNeDataLoaded) {
                        _loadNeData();
                      }
                    },
                    body: _isNeDataLoaded
                        ? Column(
                            children: _playlistsNe
                                .map(
                                  (playlist) => _buildPlaylistTile(
                                    playlist: playlist,
                                    isMy: false,
                                    availableWidth: availableWidth,
                                  ),
                                )
                                .toList(),
                          )
                        : Center(child: globalLoadingAnime),
                  ),
                  _buildExpandableSection(
                    leading: ExtendedImage.network(
                      'https://ts2.cn.mm.bing.net/th?id=ODLS.07d947f8-8fdd-4949-8b9a-be5283268438&w=32&h=32&qlt=90&pcl=fffffa&o=6&pid=1.2',
                      cache: true,
                      width: 18,
                      height: 18,
                    ),
                    title: '我的QQ歌单',
                    isExpanded: _isExpandedQq,
                    availableWidth: availableWidth,
                    onExpandedChanged: (expanded) {
                      setState(() {
                        _isExpandedQq = expanded;
                      });
                      if (expanded && !_isQqDataLoaded) {
                        _loadQqData();
                      }
                    },
                    body: _isQqDataLoaded
                        ? Column(
                            children: _playlistsQq
                                .map(
                                  (playlist) => _buildPlaylistTile(
                                    playlist: playlist,
                                    isMy: false,
                                    availableWidth: availableWidth,
                                  ),
                                )
                                .toList(),
                          )
                        : Center(child: globalLoadingAnime),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
