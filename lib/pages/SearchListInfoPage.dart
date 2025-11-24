part of '../bodys.dart';

class Searchlistinfo extends StatefulWidget {
  TextEditingController input_text_Controller;
  final Function(String) onPlaylistTap;
  Searchlistinfo({
    required this.input_text_Controller,
    required this.onPlaylistTap,
  });

  @override
  _SearchlistinfoState createState() => _SearchlistinfoState();
}

final List<String> searchOptions = ['BiliBili', '网易云', "QQ", '酷狗'];

class _SearchlistinfoState extends State<Searchlistinfo> {
  bool _loading = true;
  bool _loadingMore = false;
  bool song_or_playlist = false;
  List<Track> tracks = [];
  Map<String, dynamic> result = {};
  String source = 'netease';
  String lastsource = 'netease';
  int curpage = 1;
  final ScrollController _scrollController = ScrollController();
  String lastquery = "";
  bool searchPlayList = false;
  final FocusNode _focusNode = FocusNode(); // 创建 FocusNode
  final query = ''.obs;
  @override
  void initState() {
    super.initState();
    widget.input_text_Controller.addListener(() {
      query.value = widget.input_text_Controller.text;
    });
    _scrollController.addListener(_onScroll);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        set_inapp_hotkey(false);
      } else {
        set_inapp_hotkey(true);
      }
    });
    interval(query, (_) {
      _filterTracks();
    }, time: Duration(milliseconds: 400));
    _filterTracks();
    selectedOptionNotifier.addListener(_filterTracks);
  }

  void change_source() async {
    switch (selectedOptionNotifier.value) {
      case 'BiliBili':
        source = 'bilibili';
        break;
      case '网易云':
        source = 'netease';
        break;
      case 'QQ':
        source = 'qq';
        break;
      case '酷狗':
        source = 'kugou';
        break;
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent) {
      _loadMoreData();
    }
  }

  void _loadMoreData() async {
    if (_loading || _loadingMore) return;
    final previousPage = curpage;
    try {
      curpage += 1;
      if (curpage >= result['total'] / (tracks.length / (curpage - 1))) {
        curpage = previousPage;
        return;
      }
      change_source();
      setState(() {
        _loadingMore = true;
      });
      var ret = await MediaService.search(source, {
        'keywords': widget.input_text_Controller.text,
        'curpage': curpage,
        'type': song_or_playlist ? 1 : 0,
      });
      ret["success"]((data) {
        try {
          result = data;
          if (mounted) {
            setState(() {
              tracks.addAll(
                List<Track>.from(
                  data['result'].map((item) => Track.fromJson(item)),
                ),
              );
              _loadingMore = false;
            });
          }
        } catch (e) {
          curpage = previousPage;
          if (mounted) {
            setState(() {
              _loadingMore = false;
            });
            showErrorSnackbar('加载更多数据失败', e.toString());
          }
        }
      });
    } catch (e) {
      curpage = previousPage;
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
        showErrorSnackbar('加载更多数据失败', e.toString());
      }
    }
  }

  void _filterTracks() async {
    String query = widget.input_text_Controller.text.toLowerCase();
    change_source();
    if (query == '' || (query == lastquery && lastsource == source)) {
      return;
    }
    final previousQuery = lastquery;
    final previousSource = lastsource;
    final previousPage = curpage;
    lastquery = query;
    lastsource = source;
    curpage = 1;
    try {
      setState(() {
        _loading = true;
      });
      var ret = await MediaService.search(source, {
        'keywords': query,
        'curpage': curpage,
        'type': song_or_playlist ? 1 : 0,
      });
      ret["success"]((data) {
        try {
          result = data;
          if (mounted) {
            setState(() {
              tracks = List<Track>.from(
                data['result'].map((item) => Track.fromJson(item)),
              );
              _loading = false;
            });
          }
        } catch (e) {
          lastquery = previousQuery;
          lastsource = previousSource;
          curpage = previousPage;
          if (mounted) {
            setState(() {
              _loading = false;
            });
            showErrorSnackbar('搜索失败', e.toString());
          }
        }
      });
    } catch (e) {
      lastquery = previousQuery;
      lastsource = previousSource;
      curpage = previousPage;
      if (mounted) {
        setState(() {
          _loading = false;
        });
        showErrorSnackbar('搜索请求失败', e.toString());
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    selectedOptionNotifier.removeListener(_filterTracks);
    super.dispose();
  }

  String selectedOption = Get.find<SettingsController>().searchLastSource;
  final ValueNotifier<String> selectedOptionNotifier = ValueNotifier<String>(
    Get.find<SettingsController>().searchLastSource,
  );
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: TextField(
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: '请输入歌曲名，歌手或专辑',
                  border: InputBorder.none,
                ),
                controller: widget.input_text_Controller,
                autofocus: true,
              ),
            ),
            DropdownButton<String>(
              value: selectedOption,
              icon: Icon(Icons.arrow_downward),
              onChanged: (String? newValue) {
                setState(() {
                  selectedOption = newValue!;
                  selectedOptionNotifier.value = newValue;
                });
                if (Get.find<SettingsController>().searchUseLastSource) {
                  Get.find<SettingsController>().searchLastSource = newValue!;
                }
              },
              items: searchOptions.map<DropdownMenuItem<String>>((
                String value,
              ) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      body: Center(
        child: _loading
            ? globalLoadingAnime
            : CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      var _key = GlobalKey();
                      final track = tracks[index];
                      return ListTile(
                        title: Text(track.title!),
                        subtitle: Text('${track.artist} - ${track.album}'),
                        trailing: IconButton(
                          key: _key,
                          icon: Icon(Icons.more_vert),
                          onPressed: () {
                            song_dialog(
                              context,
                              track,
                              change_main_status: widget.onPlaylistTap,
                              position: Offset(
                                MediaQuery.of(context).size.width,
                                (_key.currentContext!.findRenderObject()
                                        as RenderBox)
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
                    }, childCount: tracks.length),
                  ),
                  if (_loadingMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(child: globalLoadingAnime),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
