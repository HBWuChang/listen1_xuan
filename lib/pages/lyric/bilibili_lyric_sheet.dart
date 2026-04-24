import 'package:flutter/material.dart' hide CircularProgressIndicator;
import 'package:listen1_xuan/controllers/lyric_controller.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/generated/dm.pb.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
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
  bool _isSaving = false;
  String? _loadError;
  int _selectedGroupIndex = 0;
  List<MapEntry<String, List<DanmuElem>>> _groupEntries = [];
  Set<int> _selectedIndexes = <int>{};

  @override
  void initState() {
    super.initState();
    _loadDanmuGroups();
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
    final currentList = _currentDanmuList();
    if (_selectedIndexes.isEmpty || currentList.isEmpty) {
      showErrorSnackbar('生成歌词失败', '请至少选择一条弹幕');
      return;
    }

    try {
      setState(() => _isSaving = true);

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

  @override
  Widget build(BuildContext context) {
    final currentList = _currentDanmuList();
    final hasMainLyric = !isEmpty(widget.lyricController.sLyric);

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
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_loadError != null)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _loadDanmuGroups,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '弹幕获取失败',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _loadError ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '点击空白区域重试',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
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
                            _selectAllCurrent();
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
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
                          List<int>.generate(currentList.length, (i) => i),
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
                child: currentList.isEmpty
                    ? Center(
                        child: Text(
                          '当前分组没有可用弹幕',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : SuperListView.builder(
                        cacheExtent: 600,
                        itemCount: currentList.length,
                        itemBuilder: (context, index) {
                          final danmu = currentList[index];
                          final isChecked = _selectedIndexes.contains(index);
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
          ],
        ),
      ),
    );
  }
}
