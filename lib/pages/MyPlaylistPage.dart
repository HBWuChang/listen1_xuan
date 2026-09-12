part of '../bodys.dart';

class MyPlaylist extends StatefulWidget {
  MyPlaylist({super.key});

  @override
  State<MyPlaylist> createState() => _MyPlaylistState();
}

class _MyPlaylistState extends State<MyPlaylist> {
  bool _isExpandedMy = true;
  bool _isExpandedFav = false;

  /// 各平台“我的歌单”分组的加载状态，key 为 provider.name。
  final Map<String, _ProviderPlaylistSection> _providerSections = {};

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
    required PlayList playList,
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
          if (state.extendedImageLoadState == LoadState.loading) {
            return globalLoadingAnimeOfExtendedImage;
          }
          if (state.extendedImageLoadState == LoadState.failed) {
            return _buildCoverFallbackText(title, size);
          }
          return null;
        },
      ).hero4playlistItemImg(playList.info),
    );
  }

  Future<void> _openPlaylist(PlayList playlist, {required bool isMy}) async {
    await Ro.toArg(PlaylistInfoArgs(playListInfo: playlist.info, isMy: isMy));
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
      playList: playlist,
      title: title,
      coverUrl: playlist.info.cover_img_url,
      size: _coverSize(availableWidth),
    );

    const sizeHeight = 56.0;
    final horizontalPadding = compact ? 8.0 : 12.0;
    final spacing = compact ? 8.0 : 12.0;
    const duration = Duration(milliseconds: 220);

    return Tooltip(
      message: title,
      child: InkWell(
        onTap: () => _openPlaylist(playlist, isMy: isMy),
        child: AnimatedPadding(
          duration: duration,
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(
            horizontal: iconOnly ? 0.0 : horizontalPadding,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedAlign(
                  duration: duration,
                  curve: Curves.easeInOut,
                  alignment: iconOnly ? Alignment.center : Alignment.centerLeft,
                  child: Center(child: cover).sbw(sizeHeight),
                ),
              ),
              Positioned.fill(
                left: sizeHeight + spacing,
                child: IgnorePointer(
                  ignoring: iconOnly,
                  child: AnimatedOpacity(
                    duration: duration,
                    curve: Curves.easeInOut,
                    opacity: iconOnly ? 0.0 : 1.0,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ).sbh(sizeHeight),
      ),
    );
  }

  Widget _buildSectionHeader({
    required Widget leading,
    required String title,
    required VoidCallback onTap,
    required double availableWidth,
    bool centerLeadingWhenIconOnly = false,
    Widget? trailing,
  }) {
    final iconOnly = _isIconOnlyMode(availableWidth);
    final compact = _isCompactMode(availableWidth);
    final shouldCenterLeading = iconOnly && centerLeadingWhenIconOnly;
    final horizontalPadding = shouldCenterLeading
        ? 0.0
        : (iconOnly ? 6.0 : (compact ? 8.0 : 12.0));
    final leadingWidth = iconOnly ? 18.0 : 24.0;
    final spacing = compact ? 8.0 : 12.0;
    const duration = Duration(milliseconds: 220);

    return Tooltip(
      message: title,
      child: InkWell(
        onTap: onTap,
        child: AnimatedPadding(
          duration: duration,
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedAlign(
                  duration: duration,
                  curve: Curves.easeInOut,
                  alignment: shouldCenterLeading
                      ? Alignment.center
                      : Alignment.centerLeft,
                  child: Center(child: leading).sbw(leadingWidth),
                ),
              ),
              Positioned.fill(
                left: leadingWidth + spacing,
                right: trailing != null ? 40 : 0,
                child: IgnorePointer(
                  ignoring: iconOnly,
                  child: AnimatedOpacity(
                    duration: duration,
                    curve: Curves.easeInOut,
                    opacity: iconOnly ? 0.0 : 1.0,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          style: TextStyle(fontSize: compact ? 15 : 20),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (trailing != null)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(child: trailing),
                ),
            ],
          ),
        ).sbh(compact ? 44 : 56),
      ),
    );
  }

  _ProviderPlaylistSection _sectionOf(BaseProvider provider) {
    return _providerSections.putIfAbsent(
      provider.name,
      () => _ProviderPlaylistSection(),
    );
  }

  Future<void> _loadProviderPlaylists(
    BaseProvider provider, {
    bool force = false,
  }) async {
    final section = _sectionOf(provider);
    if (section.loading) return;
    if (section.loaded && !force) return;

    setState(() {
      section.loading = true;
      section.error = null;
    });

    try {
      final user = await provider.getUser();
      if (user == null) {
        throw StateError('未登录或登录已失效');
      }

      final futures = <Future<List<PlayList>>>[];
      if (provider.supportGetUserCreatedPlaylist) {
        final future = provider.getUserCreatedPlaylist(user.userId);
        if (future != null) futures.add(future);
      }
      if (provider.supportGetUserFavoritePlaylist) {
        final future = provider.getUserFavoritePlaylist(user.userId);
        if (future != null) futures.add(future);
      }
      if (futures.isEmpty) {
        throw StateError('该平台未实现歌单接口');
      }

      final results = await Future.wait(futures);
      final playlists = <PlayList>[];
      for (final list in results) {
        playlists.addAll(list);
      }

      if (!mounted) return;
      setState(() {
        section.playlists = playlists;
        section.loaded = true;
        section.loading = false;
        section.error = null;
      });
    } catch (e) {
      logger.e('${provider.userPlaylistSectionTitle}加载失败', error: e);
      if (!mounted) return;
      setState(() {
        section.loading = false;
        section.error = e.toString();
      });
    }
  }

  void _refreshProviderPlaylists(BaseProvider provider) {
    _loadProviderPlaylists(provider, force: true);
  }

  Widget _buildSectionError(String error, VoidCallback onRetry) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(error, textAlign: TextAlign.center),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSection(
    BaseProvider provider,
    double availableWidth,
  ) {
    final section = _sectionOf(provider);
    return _buildExpandableSection(
      leading: provider.userPlaylistSectionLeading,
      title: provider.userPlaylistSectionTitle,
      isExpanded: section.isExpanded,
      availableWidth: availableWidth,
      trailing: IconButton(
        icon: const Icon(Icons.refresh, size: 18),
        tooltip: '刷新',
        onPressed: () => _refreshProviderPlaylists(provider),
      ),
      onExpandedChanged: (expanded) {
        setState(() {
          section.isExpanded = expanded;
        });
        if (expanded) {
          _loadProviderPlaylists(provider);
        }
      },
      body: _buildProviderSectionBody(section, availableWidth, provider),
    );
  }

  Widget _buildProviderSectionBody(
    _ProviderPlaylistSection section,
    double availableWidth,
    BaseProvider provider,
  ) {
    if (section.loading) {
      return Center(child: globalLoadingAnime);
    }
    if (section.error != null) {
      return _buildSectionError(
        section.error!,
        () => _refreshProviderPlaylists(provider),
      );
    }
    return Column(
      children: section.playlists
          .map(
            (playlist) => _buildPlaylistTile(
              playlist: playlist,
              isMy: false,
              availableWidth: availableWidth,
            ),
          )
          .toList(),
    );
  }
  Widget _buildExpandableSection({
    required Widget leading,
    required String title,
    required bool isExpanded,
    required double availableWidth,
    required Widget body,
    required ValueChanged<bool> onExpandedChanged,
    Widget? trailing,
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
              trailing: trailing,
              onTap: () {
                final nextExpanded = !controller.expanded;
                controller.expanded = nextExpanded;
                onExpandedChanged(nextExpanded);
              },
            ),
            collapsed: SizedBox.shrink(),
            expanded: body,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsController>();
    final routeController = Get.find<RouteController>();

    return Obx(
      () => Scaffold(
        floatingActionButton: FloatingActionButton(
          heroTag: HeroTags.songReplaceFab,
          mini: settingsController.songReplaceFabMiniRx.value,
          onPressed: () {
            if (routeController.inSongReplacePage.value) {
              Get.back(id: 1);
              return;
            }
            Get.toNamed(RouteName.songReplacePage, id: 1);
          },
          tooltip: '歌曲替换列表',
          child: Icon(Icons.find_replace_rounded),
        ),
        floatingActionButtonLocation:
            settingsController.songReplaceFabMiniRx.value
            ? settingsController.songReplaceFabLocation.fabMiniLocation
            : settingsController.songReplaceFabLocation.fabLocation,
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
                  ...providers
                      .where(
                        (p) =>
                            p.supportGetUserCreatedPlaylist ||
                            p.supportGetUserFavoritePlaylist,
                      )
                      .map((p) => _buildProviderSection(p, availableWidth)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProviderPlaylistSection {
  bool isExpanded = false;
  bool loaded = false;
  bool loading = false;
  String? error;
  List<PlayList> playlists = [];
}