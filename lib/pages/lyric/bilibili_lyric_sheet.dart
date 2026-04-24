import 'package:flutter/material.dart' hide CircularProgressIndicator;
import 'package:listen1_xuan/controllers/lyric_controller.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/generated/dm.pb.dart';
import 'package:listen1_xuan/models/SubtitleDetail.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:listen1_xuan/models/Subtitle.dart';
import '../../widgets/progress_indicator_xuan.dart';

Future<void> showBilibiliLyricSheet({
  required BuildContext context,
  required XLyricController lyricController,
  required String trackId,
  required Duration duration,
}) async {
  await WoltModalSheet.show(
    context: context,
    modalBarrierColor: Colors.transparent,
    modalTypeBuilder: (modalSheetContext) => WoltModalType.bottomSheet(),
    pageListBuilder: (modalSheetContext) {
      return [
        WoltModalSheetPage(
          hasTopBarLayer: false,
          isTopBarLayerAlwaysVisible: false,
          enableDrag: true,
          child: _BilibiliLyricSheetBody(
            lyricController: lyricController,
            trackId: trackId,
            duration: duration,
          ),
        ),
      ];
    },
    useRootNavigator: true,
  );
}

class _BilibiliLyricSheetBody extends StatefulWidget {
  final XLyricController lyricController;
  final String trackId;
  final Duration duration;

  const _BilibiliLyricSheetBody({
    required this.lyricController,
    required this.trackId,
    required this.duration,
  });

  @override
  State<_BilibiliLyricSheetBody> createState() =>
      _BilibiliLyricSheetBodyState();
}

class _BilibiliLyricSheetBodyState extends State<_BilibiliLyricSheetBody> {
  bool _isLoading = true;
  bool _isSubtitleLoading = false;
  bool _isSubtitleDetailLoading = false;
  bool _isSaving = false;
  String? _loadError;
  String? _loadSubtitleError;
  String? _loadSubtitleDetailError;
  int _selectedGroupIndex = 0;
  int _selectedSubtitleIndex = -1;
  List<MapEntry<String, List<DanmuElem>>> _groupEntries = [];
  final Map<String, List<SubtitleDetail>> _subtitleDetailsCache =
      <String, List<SubtitleDetail>>{};
  List<Subtitle> _subtitleGroups = <Subtitle>[];
  Set<int> _selectedIndexes = <int>{};

  @override
  void initState() {
    super.initState();
    _loadDanmuGroups();
    _loadSubtitleGroups();
  }

  List<DanmuElem> _currentDanmuList() {
    if (_groupEntries.isEmpty ||
        _selectedGroupIndex < 0 ||
        _selectedGroupIndex >= _groupEntries.length) {
      return const <DanmuElem>[];
    }
    return _groupEntries[_selectedGroupIndex].value;
  }

  void _selectAllCurrent() {
    final list = _currentDanmuList();
    _selectedIndexes = Set<int>.from(List<int>.generate(list.length, (i) => i));
  }

  String _subtitleDisplayName(Subtitle subtitle) {
    final lanDoc = subtitle.languageDescription?.trim() ?? '';
    final lan = subtitle.language?.trim() ?? '';
    if (lanDoc.isNotEmpty && lan.isNotEmpty) {
      return '$lanDoc ($lan)';
    }
    if (lanDoc.isNotEmpty) return lanDoc;
    if (lan.isNotEmpty) return lan;
    return '未命名字幕';
  }

  String _subtitleCacheKey(Subtitle subtitle, int index) {
    final id = subtitle.id?.trim() ?? '';
    if (id.isNotEmpty) {
      return id;
    }
    final idStr = subtitle.idStr?.trim() ?? '';
    if (idStr.isNotEmpty) {
      return idStr;
    }
    return 'subtitle_$index';
  }

  Future<List<SubtitleDetail>> _ensureSubtitleDetails(int subtitleIndex) async {
    if (subtitleIndex < 0 || subtitleIndex >= _subtitleGroups.length) {
      throw '字幕索引无效';
    }

    final subtitle = _subtitleGroups[subtitleIndex];
    final cacheKey = _subtitleCacheKey(subtitle, subtitleIndex);
    final cached = _subtitleDetailsCache[cacheKey];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    if (!mounted) return const <SubtitleDetail>[];
    setState(() {
      _isSubtitleDetailLoading = true;
      _loadSubtitleDetailError = null;
    });

    try {
      final details = await widget.lyricController.fetchBilibiliSubtitleDetail(
        subtitle,
      );
      if (!mounted) return details;
      setState(() {
        _subtitleDetailsCache[cacheKey] = details;
        _isSubtitleDetailLoading = false;
      });
      return details;
    } catch (e) {
      if (!mounted) rethrow;
      setState(() {
        _isSubtitleDetailLoading = false;
        _loadSubtitleDetailError = e.toString();
      });
      rethrow;
    }
  }

  Future<void> _onSubtitleSelected(int subtitleIndex) async {
    setState(() {
      _selectedSubtitleIndex = subtitleIndex;
      _selectedIndexes = <int>{};
      _loadSubtitleDetailError = null;
    });

    try {
      await _ensureSubtitleDetails(subtitleIndex);
    } catch (_) {
      // 错误提示由 _ensureSubtitleDetails 内部状态展示
    }
  }

  Future<void> _loadSubtitleGroups() async {
    if (!mounted) return;
    setState(() {
      _isSubtitleLoading = true;
      _loadSubtitleError = null;
    });
    try {
      final groups = await widget.lyricController.fetchBilibiliSubtitles(
        widget.trackId,
      );
      if (!mounted) return;
      setState(() {
        _subtitleGroups = groups;
        if (_selectedSubtitleIndex >= _subtitleGroups.length) {
          _selectedSubtitleIndex = -1;
        }
        _isSubtitleLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubtitleLoading = false;
        _loadSubtitleError = e.toString();
      });
    }
  }

  Future<void> _loadDanmuGroups() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final danmuList = await widget.lyricController.findBilibiliLyricDanmu(
        widget.trackId,
        widget.duration,
      );
      if (danmuList.isEmpty) {
        throw '没有可用弹幕';
      }

      final groupedDanmu = <String, List<DanmuElem>>{};
      for (final danmu in danmuList) {
        final key = isEmpty(danmu.uhash) ? '_empty_uhash' : danmu.uhash;
        groupedDanmu.putIfAbsent(key, () => <DanmuElem>[]).add(danmu);
      }

      final entries = groupedDanmu.entries.toList()
        ..forEach(
          (entry) =>
              entry.value.sort((a, b) => a.progress.compareTo(b.progress)),
        )
        ..sort((a, b) => b.value.length.compareTo(a.value.length));

      if (entries.isEmpty) {
        throw '未能构建弹幕分组';
      }

      if (!mounted) return;
      setState(() {
        _groupEntries = entries;
        _selectedGroupIndex = 0;
        _selectAllCurrent();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _groupEntries = [];
        _selectedIndexes = <int>{};
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAsLyric({required bool isTranslation}) async {
    try {
      setState(() => _isSaving = true);

      if (_selectedSubtitleIndex >= 0 &&
          _selectedSubtitleIndex < _subtitleGroups.length) {
        final details = await _ensureSubtitleDetails(_selectedSubtitleIndex);
        if (details.isEmpty) {
          throw '选中的字幕没有可用内容';
        }
        await widget.lyricController.saveSubtitleAsLyric(
          trackId: widget.trackId,
          subtitleDetails: details,
          isTranslation: isTranslation,
        );
      } else {
        final currentList = _currentDanmuList();
        if (_selectedIndexes.isEmpty || currentList.isEmpty) {
          throw '请至少选择一条弹幕或选择一组字幕';
        }

        final selectedDanmu =
            _selectedIndexes
                .where((index) => index >= 0 && index < currentList.length)
                .map((index) => currentList[index])
                .where((e) => !isEmpty(e.text))
                .toList()
              ..sort((a, b) => a.progress.compareTo(b.progress));

        await widget.lyricController.saveDanmuAsLyric(
          trackId: widget.trackId,
          selectedDanmu: selectedDanmu,
          isTranslation: isTranslation,
        );
      }

      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      showErrorSnackbar('生成歌词失败', e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  List<SubtitleDetail> _currentSubtitleDetails() {
    if (_selectedSubtitleIndex < 0 ||
        _selectedSubtitleIndex >= _subtitleGroups.length) {
      return const <SubtitleDetail>[];
    }
    final subtitle = _subtitleGroups[_selectedSubtitleIndex];
    final cacheKey = _subtitleCacheKey(subtitle, _selectedSubtitleIndex);
    return _subtitleDetailsCache[cacheKey] ?? const <SubtitleDetail>[];
  }

  @override
  Widget build(BuildContext context) {
    final currentList = _currentDanmuList();
    final hasMainLyric = !isEmpty(widget.lyricController.sLyric);
    final usingSubtitle =
        _selectedSubtitleIndex >= 0 &&
        _selectedSubtitleIndex < _subtitleGroups.length;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
        minHeight: 300,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('从弹幕生成歌词', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text('字幕列表', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_isSubtitleLoading)
              const SizedBox(
                height: 36,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadSubtitleError != null)
              SizedBox(
                height: 36,
                child: TextButton(
                  onPressed: _loadSubtitleGroups,
                  child: Text('字幕获取失败，点击重试：$_loadSubtitleError'),
                ),
              )
            else if (_subtitleGroups.isEmpty)
              SizedBox(
                height: 36,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '无可用字幕',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              SizedBox(
                height: 36,
                child: SuperListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _subtitleGroups.length,
                  itemBuilder: (context, subtitleIndex) {
                    final subtitle = _subtitleGroups[subtitleIndex];
                    final isSelected = _selectedSubtitleIndex == subtitleIndex;
                    return Padding(
                      padding: EdgeInsets.only(
                        right: subtitleIndex == _subtitleGroups.length - 1
                            ? 0
                            : 8,
                      ),
                      child: ChoiceChip(
                        label: Text(_subtitleDisplayName(subtitle)),
                        selected: isSelected,
                        onSelected: (_) => _onSubtitleSelected(subtitleIndex),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            Text('弹幕分组', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_isLoading)
              const SizedBox(
                height: 36,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadError != null)
              SizedBox(
                height: 36,
                child: TextButton(
                  onPressed: _loadDanmuGroups,
                  child: Text('弹幕获取失败，点击重试：$_loadError'),
                ),
              )
            else
              SizedBox(
                height: 36,
                child: SuperListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _groupEntries.length,
                  itemBuilder: (context, groupIndex) {
                    final count = _groupEntries[groupIndex].value.length;
                    final isSelected = _selectedGroupIndex == groupIndex;
                    return Padding(
                      padding: EdgeInsets.only(
                        right: groupIndex == _groupEntries.length - 1 ? 0 : 8,
                      ),
                      child: ChoiceChip(
                        label: Text('#${groupIndex + 1} ($count)'),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedGroupIndex = groupIndex;
                            _selectedSubtitleIndex = -1;
                            _selectAllCurrent();
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: usingSubtitle
                  ? (_isSubtitleDetailLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _loadSubtitleDetailError != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _loadSubtitleDetailError!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () =>
                                      _onSubtitleSelected(_selectedSubtitleIndex),
                                  child: const Text('重试加载字幕'),
                                ),
                              ],
                            ),
                          )
                        : Builder(
                            builder: (context) {
                              final details = _currentSubtitleDetails();
                              if (details.isEmpty) {
                                return Center(
                                  child: Text(
                                    '选中的字幕没有可用内容',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                );
                              }
                              return Column(
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '已加载 ${details.length} 条字幕（整段应用）',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: SuperListView.builder(
                                      cacheExtent: 600,
                                      itemCount: details.length,
                                      itemBuilder: (context, index) {
                                        final detail = details[index];
                                        final content =
                                            detail.content?.trim().isNotEmpty == true
                                            ? detail.content!.trim()
                                            : '(空文本)';
                                        final fromMs = ((detail.from ?? 0) * 1000)
                                            .round();
                                        return ListTile(
                                          dense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          title: Text(
                                            content,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(
                                            widget.lyricController
                                                .formatLrcTimestamp(
                                              Duration(
                                                milliseconds:
                                                    fromMs < 0 ? 0 : fromMs,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ))
                  : _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : currentList.isEmpty
                  ? Center(
                      child: Text(
                        '当前分组没有可用弹幕',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => setState(_selectAllCurrent),
                              child: const Text('全选'),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  final allIndexes = Set<int>.from(
                                    List<int>.generate(
                                      currentList.length,
                                      (i) => i,
                                    ),
                                  );
                                  _selectedIndexes = allIndexes.difference(
                                    _selectedIndexes,
                                  );
                                });
                              },
                              child: const Text('反选'),
                            ),
                            const Spacer(),
                            Text('已选 ${_selectedIndexes.length} 条'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: SuperListView.builder(
                            cacheExtent: 600,
                            itemCount: currentList.length,
                            itemBuilder: (context, index) {
                              final danmu = currentList[index];
                              final isChecked = _selectedIndexes.contains(
                                index,
                              );
                              final text = isEmpty(danmu.text)
                                  ? '(空文本)'
                                  : danmu.text;

                              return RepaintBoundary(
                                child: ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  leading: Checkbox(
                                    value: isChecked,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedIndexes.add(index);
                                        } else {
                                          _selectedIndexes.remove(index);
                                        }
                                      });
                                    },
                                  ),
                                  title: Text(
                                    text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    widget.lyricController.formatLrcTimestamp(
                                      Duration(
                                        milliseconds: danmu.progress < 0
                                            ? 0
                                            : danmu.progress,
                                      ),
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      if (isChecked) {
                                        _selectedIndexes.remove(index);
                                      } else {
                                        _selectedIndexes.add(index);
                                      }
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving
                        ? null
                        : () => _saveAsLyric(isTranslation: false),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('作为歌词'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving || !hasMainLyric
                        ? null
                        : () => _saveAsLyric(isTranslation: true),
                    child: const Text('作为翻译'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
