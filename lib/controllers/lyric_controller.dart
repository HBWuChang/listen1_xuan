import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:get/get.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:listen1_xuan/bl.dart';
import 'package:listen1_xuan/controllers/controllers.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';
import 'dart:io';
import '../funcs.dart';
import '../loweb.dart';
import '../controllers/play_controller.dart';
import '../controllers/cache_controller.dart';
import '../controllers/settings_controller.dart';
import '../global_settings_animations.dart';
import '../play.dart';
import 'package:path/path.dart' as p;
import 'dart:typed_data';
import '../generated/dm.pb.dart'; // 引入生成的类

class XLyricController extends GetxController {
  // 歌词显示相关
  late LyricController lyricController;
  var isLyricLoading = false.obs;
  var hasLyric = false.obs;
  RxDouble globalLyricDelay = RxDouble(0.0);
  RxDouble nowPlayingLyricDelay = RxDouble(0.0);
  bool updNowPlayingLyricDelay = false;
  Rx<LyricLine?> updFormatShowLyric = Rx<LyricLine?>(null);
  // showTranslation 已移至 SettingsController

  // 歌词解析相关
  // LyricsReaderModel? lyricModel;

  // 当前歌曲信息
  var currentTrackId = ''.obs;

  /// 获取缓存控制器
  CacheController get _cacheController => Get.find<CacheController>();

  /// 获取设置控制器
  SettingsController get _settingsController => Get.find<SettingsController>();

  /// 生成歌词缓存文件路径
  String _getLyricCacheFileName(String trackId, {bool isTranslation = false}) {
    final suffix = isTranslation ? '_tlyric' : '_lyric';
    return '$trackId$suffix.lrc';
  }

  String _getLyricCacheKey(String trackId, {bool isTranslation = false}) {
    return isTranslation ? '${trackId}_tlyric' : '${trackId}_lyric';
  }

  /// 从本地缓存读取歌词
  Future<Map<String, String>> _loadLyricFromCache(String trackId) async {
    final result = <String, String>{};

    try {
      // 1) 优先从 lyricBox 读取“特殊歌词”（如弹幕生成）
      final lyricKey = _getLyricCacheKey(trackId);
      final tlyricKey = _getLyricCacheKey(trackId, isTranslation: true);

      final boxLyric = _settingsController.getLyricBoxString(lyricKey);
      if (boxLyric != null && boxLyric.isNotEmpty) {
        result['lyric'] = boxLyric;
      }
      final boxTLyric = _settingsController.getLyricBoxString(tlyricKey);
      if (boxTLyric != null && boxTLyric.isNotEmpty) {
        result['tlyric'] = boxTLyric;
      }

      final needsFileLyric = !(result['lyric']?.isNotEmpty ?? false);
      final needsFileTLyric = !(result['tlyric']?.isNotEmpty ?? false);
      if (!needsFileLyric && !needsFileTLyric) {
        return result;
      }

      // 2) lyricBox 没有时，再从本地文件缓存读取
      // 获取音乐文件的缓存路径作为基础路径
      final musicCachePath = await _cacheController.getLocalCache(trackId);
      if (musicCachePath.isEmpty) return result;

      // 构建歌词文件路径
      final tempDir = await xuanGetdataDirectory();
      final tempPath = tempDir.path;

      // 主歌词文件
      final lyricFileName = _getLyricCacheFileName(trackId);
      final lyricFilePath = p.join(tempPath, lyricFileName);

      if (needsFileLyric && await File(lyricFilePath).exists()) {
        result['lyric'] = await File(lyricFilePath).readAsString();
      }

      // 翻译歌词文件
      final tlyricFileName = _getLyricCacheFileName(
        trackId,
        isTranslation: true,
      );
      final tlyricFilePath = p.join(tempPath, tlyricFileName);

      if (needsFileTLyric && await File(tlyricFilePath).exists()) {
        result['tlyric'] = await File(tlyricFilePath).readAsString();
      }
    } catch (e) {
      debugPrint('从缓存读取歌词失败: $e');
    }

    return result;
  }

  /// 保存歌词到本地缓存
  Future<void> _saveLyricToCache(
    String trackId,
    String lyric, {
    bool isTranslation = false,
    bool toLyricBox = false,
  }) async {
    try {
      if (toLyricBox && _settingsController.useLyricBox) {
        final key = _getLyricCacheKey(trackId, isTranslation: isTranslation);
        await _settingsController.setLyricBoxString(key, lyric);
        return;
      }

      final tempDir = await xuanGetdataDirectory();
      final tempPath = tempDir.path;

      final fileName = _getLyricCacheFileName(
        trackId,
        isTranslation: isTranslation,
      );
      final filePath = p.join(tempPath, fileName);

      await File(filePath).writeAsString(lyric);

      // 将歌词文件添加到缓存管理
      _cacheController.setLocalCache(
        _getLyricCacheKey(trackId, isTranslation: isTranslation),
        fileName,
      );
    } catch (e) {
      print('保存歌词到缓存失败: $e');
    }
  }

  String? sLyric;
  Rx<String?> sLyricTra = Rx<String?>(null);

  @override
  void onInit() {
    super.onInit();
    lyricController = LyricController();
    // 监听播放位置变化，更新歌词显示（应用延迟）
    Get.find<PlayController>().music_player.stream.position.listen((position) {
      // 计算总延迟 = 全局延迟 + 当前歌曲延迟
      final totalDelay = globalLyricDelay.value + nowPlayingLyricDelay.value;
      Duration adjustedPosition =
          position + Duration(milliseconds: (totalDelay * 1000).round());
      if (adjustedPosition < Duration.zero) {
        adjustedPosition = Duration.zero;
      }
      lyricController.setProgress(adjustedPosition);
    });
    lyricController.activeIndexNotifiter.addListener(() {
      _updateCurrentLyric(lyricController.activeIndexNotifiter.value);
    });
    ever(updFormatShowLyric, (value) {
      if (isEmpty(value)) return;
      change_playback_state(null, lyric: value);
    });
    lyricController.setOnTapLineCallback((Duration position) {
      Duration adjustedPosition =
          position -
          Duration(
            milliseconds:
                ((globalLyricDelay.value + nowPlayingLyricDelay.value) * 1000)
                    .round(),
          );
      if (adjustedPosition < Duration.zero) {
        adjustedPosition = Duration.zero;
      }
      seekToTime(adjustedPosition);
    });
    globalLyricDelay.value = _settingsController.globalLyricDelay;
    interval(globalLyricDelay, (value) {
      // 更新全局延迟设置
      _settingsController.globalLyricDelay = value;
    }, time: Duration(milliseconds: 100));
    interval(nowPlayingLyricDelay, (value) {
      if (updNowPlayingLyricDelay == false) {
        updNowPlayingLyricDelay = true;
        return;
      }
      if (nowPlayingLyricDelay.value.isNaN) {
        nowPlayingLyricDelay.value = 0.0;
      }
      Get.find<PlayController>().songReplaceSettings.value.setSongDelay(
        Get.find<PlayController>().nowPlayingTrackId,
        value,
      );
      Get.find<PlayController>().songReplaceSettings.refresh();
    }, time: Duration(milliseconds: 100));
  }

  /// 加载歌词
  Future<void> loadLyric() async {
    String trackId = Get.find<PlayController>().nowPlayingTrackId;
    if (trackId.isEmpty) return;
    isLyricLoading.value = true;
    hasLyric.value = false;
    // lyricModel = null;
    nowPlayingLyricDelay.value =
        Get.find<PlayController>().songReplaceSettings.value.getSongDelay(
          trackId,
        ) ??
        0.0;
    try {
      // 首先尝试从本地缓存加载歌词
      final cachedLyrics = await _loadLyricFromCache(trackId);

      if (cachedLyrics.containsKey('lyric') &&
          cachedLyrics['lyric']!.isNotEmpty) {
        // 从缓存加载成功
        debugPrint('从缓存加载歌词: $trackId');
        _processLyricData(cachedLyrics['lyric']!, cachedLyrics['tlyric'] ?? '');
        isLyricLoading.value = false;
        return;
      }

      // 缓存中没有歌词，从网络获取
      debugPrint('从网络获取歌词: $trackId');
      await _loadLyricFromNetwork(trackId);
    } catch (e) {
      debugPrint('加载歌词失败: $e');
      isLyricLoading.value = false;
      hasLyric.value = false;
    }
  }

  /// 从网络加载歌词
  Future<void> _loadLyricFromNetwork(String trackId) async {
    // 使用 MediaService.getLyric 获取歌词
    var lyricResult;
    if (trackId.contains('kgtrack')) {
      lyricResult = await MediaService.getLyric(
        trackId,
        albumId: Get.find<PlayController>().currentTrack.album_id,
      );
    } else {
      lyricResult = await MediaService.getLyric(trackId);
    }

    lyricResult['success']((data) async {
      final lyric = data['lyric'] ?? '';
      final tlyric = data['tlyric'] ?? '';

      if (lyric.isNotEmpty) {
        // 保存歌词到缓存
        await _saveLyricToCache(trackId, lyric);
        if (tlyric.isNotEmpty) {
          await _saveLyricToCache(trackId, tlyric, isTranslation: true);
        }

        // 处理歌词数据
        _processLyricData(lyric, tlyric);
      } else {
        lyricController.loadLyricModel(LyricModel(lines: []));
      }
      isLyricLoading.value = false;
    });
  }

  /// 处理歌词数据
  void _processLyricData([String? lyric, String? tlyric]) {
    if (!isEmpty(lyric)) {
      sLyric = lyric;
      sLyricTra.value = tlyric;
    } else {
      lyric = sLyric ?? '';
      tlyric = sLyricTra.value;
    }
    if (!_settingsController.showLyricTranslation.value) {
      tlyric = null;
    }
    lyricController.loadLyric(lyric!, translationLyric: tlyric);
    // 构建歌词模型
    hasLyric.value = true;
  }

  // String formatShowLyric(LyricsLineModel? line) {
  //   if (line == null) return '';
  //   String mainText = line.mainText ?? '';
  //   String extText = line.extText ?? '';

  //   if (_settingsController.showLyricTranslation.value && !isEmpty(extText)) {
  //     return '$mainText\n$extText';
  //   } else {
  //     return mainText;
  //   }
  // }

  /// 更新当前显示的歌词
  void _updateCurrentLyric(int index) {
    if (hasLyric.value == false) return;
    updFormatShowLyric.value =
        lyricController.lyricNotifier.value?.lines[index];
    // 这里可以添加更复杂的歌词高亮逻辑
    // 目前只是简单的存储，实际的歌词高亮由 flutter_lyric 组件处理
  }

  /// 跳转到指定时间
  void seekToTime(Duration time) {
    final playController = Get.find<PlayController>();
    playController.music_player.seek(time);
  }

  /// 获取当前播放位置
  Duration getCurrentPosition() {
    final playController = Get.find<PlayController>();
    return playController.music_player.state.position;
  }

  /// 获取歌曲总时长
  Duration? getTotalDuration() {
    final playController = Get.find<PlayController>();
    return playController.music_player.state.duration;
  }

  /// 切换翻译显示状态
  void toggleTranslation() {
    _settingsController.showLyricTranslation.value =
        !_settingsController.showLyricTranslation.value;

    _processLyricData();
  }

  /// 查找哔哩哔哩歌词
  Future<void> findBilibiliLyric() async {
    try {
      final playController = Get.find<PlayController>();
      final trackId = playController.nowPlayingTrackId;
      final duration = playController.music_player.state.duration;

      if (trackId.isEmpty) {
        showErrorSnackbar('获取弹幕失败', '当前没有正在播放的歌曲');
        return;
      }
      if (duration <= Duration.zero) {
        showErrorSnackbar('获取弹幕失败', '当前歌曲时长无效');
        return;
      }

      final context = Get.context;
      if (context == null) {
        showErrorSnackbar('打开窗口失败', '当前页面上下文不可用');
        return;
      }

      final isLoading = true.obs;
      final loadError = RxnString();
      final groupEntries = <MapEntry<String, List<DanmuElem>>>[].obs;
      final selectedGroupIndex = 0.obs;
      final selectedIndexes = <int>{}.obs;

      List<DanmuElem> currentDanmuList() {
        if (groupEntries.isEmpty ||
            selectedGroupIndex.value < 0 ||
            selectedGroupIndex.value >= groupEntries.length) {
          return [];
        }
        final sorted = List<DanmuElem>.from(
          groupEntries[selectedGroupIndex.value].value,
        )..sort((a, b) => a.progress.compareTo(b.progress));
        return sorted;
      }

      void selectAllCurrent() {
        final list = currentDanmuList();
        selectedIndexes
          ..clear()
          ..addAll(List<int>.generate(list.length, (i) => i));
        selectedIndexes.refresh();
      }

      Future<void> loadDanmuGroups() async {
        isLoading.value = true;
        loadError.value = null;
        try {
          final danmuList = await findBilibiliLyricDanmu(trackId, duration);
          if (danmuList.isEmpty) {
            throw '没有可用弹幕';
          }

          final groupedDanmu = <String, List<DanmuElem>>{};
          for (final danmu in danmuList) {
            final key = isEmpty(danmu.uhash) ? '_empty_uhash' : danmu.uhash;
            groupedDanmu.putIfAbsent(key, () => <DanmuElem>[]).add(danmu);
          }

          final entries = groupedDanmu.entries.toList()
            ..sort((a, b) => b.value.length.compareTo(a.value.length));

          if (entries.isEmpty) {
            throw '未能构建弹幕分组';
          }

          groupEntries.assignAll(entries);
          selectedGroupIndex.value = 0;
          selectAllCurrent();
        } catch (e) {
          groupEntries.clear();
          selectedIndexes.clear();
          loadError.value = e.toString();
        } finally {
          isLoading.value = false;
        }
      }

      WoltModalSheet.show(
        context: context,
        modalBarrierColor: Colors.transparent,
        modalTypeBuilder: (modalSheetContext) => WoltModalType.bottomSheet(),
        pageListBuilder: (modalSheetContext) {
          final isSaving = false.obs;

          Future<void> saveAsLyric({required bool isTranslation}) async {
            final currentList = currentDanmuList();
            if (selectedIndexes.isEmpty || currentList.isEmpty) {
              showErrorSnackbar('生成歌词失败', '请至少选择一条弹幕');
              return;
            }

            try {
              isSaving.value = true;

              final selectedDanmu =
                  selectedIndexes
                      .where(
                        (index) => index >= 0 && index < currentList.length,
                      )
                      .map((index) => currentList[index])
                      .where((e) => !isEmpty(e.text))
                      .toList()
                    ..sort((a, b) => a.progress.compareTo(b.progress));

              final lrcContent = _buildLrcFromDanmu(selectedDanmu);
              if (isEmpty(lrcContent)) {
                showErrorSnackbar('生成歌词失败', '所选弹幕文本为空');
                return;
              }

              await _saveLyricToCache(
                trackId,
                lrcContent,
                isTranslation: isTranslation,
                toLyricBox: true,
              );
              await loadLyric();

              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            } catch (e) {
              showErrorSnackbar('生成歌词失败', e.toString());
            } finally {
              isSaving.value = false;
            }
          }

          return [
            WoltModalSheetPage(
              hasTopBarLayer: false,
              isTopBarLayerAlwaysVisible: false,
              enableDrag: true,
              child: Obx(() {
                final currentList = currentDanmuList();
                final hasMainLyric = !isEmpty(sLyric);

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
                        Text(
                          '从弹幕生成歌词',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        if (isLoading.value)
                          const Expanded(
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (loadError.value != null)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: loadDanmuGroups,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '弹幕获取失败',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      loadError.value ?? '',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '点击空白区域重试',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else ...[
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: List<Widget>.generate(
                                groupEntries.length,
                                (groupIndex) {
                                  final count =
                                      groupEntries[groupIndex].value.length;
                                  final isSelected =
                                      selectedGroupIndex.value == groupIndex;
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      right:
                                          groupIndex == groupEntries.length - 1
                                          ? 0
                                          : 8,
                                    ),
                                    child: ChoiceChip(
                                      label: Text(
                                        '#${groupIndex + 1} ($count)',
                                      ),
                                      selected: isSelected,
                                      onSelected: (_) {
                                        selectedGroupIndex.value = groupIndex;
                                        selectAllCurrent();
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              TextButton(
                                onPressed: selectAllCurrent,
                                child: const Text('全选'),
                              ),
                              TextButton(
                                onPressed: () {
                                  final allIndexes = Set<int>.from(
                                    List<int>.generate(
                                      currentList.length,
                                      (i) => i,
                                    ),
                                  );
                                  final inverted = allIndexes.difference(
                                    selectedIndexes,
                                  );
                                  selectedIndexes
                                    ..clear()
                                    ..addAll(inverted);
                                  selectedIndexes.refresh();
                                },
                                child: const Text('反选'),
                              ),
                              const Spacer(),
                              Text('已选 ${selectedIndexes.length} 条'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: currentList.isEmpty
                                ? Center(
                                    child: Text(
                                      '当前分组没有可用弹幕',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: currentList.length,
                                    itemBuilder: (context, index) {
                                      final danmu = currentList[index];
                                      final isChecked = selectedIndexes
                                          .contains(index);
                                      final text = isEmpty(danmu.text)
                                          ? '(空文本)'
                                          : danmu.text;

                                      return CheckboxListTile(
                                        dense: true,
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        value: isChecked,
                                        onChanged: (value) {
                                          if (value == true) {
                                            selectedIndexes.add(index);
                                          } else {
                                            selectedIndexes.remove(index);
                                          }
                                          selectedIndexes.refresh();
                                        },
                                        title: Text(
                                          text,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          _formatLrcTimestamp(
                                            Duration(
                                              milliseconds: danmu.progress < 0
                                                  ? 0
                                                  : danmu.progress,
                                            ),
                                          ),
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
                                  onPressed: isSaving.value
                                      ? null
                                      : () => saveAsLyric(isTranslation: false),
                                  child: isSaving.value
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('作为歌词'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isSaving.value || !hasMainLyric
                                      ? null
                                      : () => saveAsLyric(isTranslation: true),
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
              }),
            ),
          ];
        },
        useRootNavigator: true,
      );

      loadDanmuGroups();
    } catch (e) {
      showErrorSnackbar('获取弹幕失败', e.toString());
    }
  }

  String _buildLrcFromDanmu(List<DanmuElem> danmuList) {
    if (danmuList.isEmpty) return '';

    final sorted = List<DanmuElem>.from(danmuList)
      ..sort((a, b) => a.progress.compareTo(b.progress));

    final buffer = StringBuffer();
    for (final danmu in sorted) {
      if (isEmpty(danmu.text)) {
        continue;
      }
      final progress = danmu.progress < 0 ? 0 : danmu.progress;
      final timestamp = _formatLrcTimestamp(Duration(milliseconds: progress));
      buffer.writeln('[$timestamp]${danmu.text.trim()}');
    }

    return buffer.toString().trim();
  }

  String _formatLrcTimestamp(Duration duration) {
    final totalMilliseconds = duration.inMilliseconds;
    final minutes = (totalMilliseconds ~/ 60000).toString().padLeft(2, '0');
    final seconds = ((totalMilliseconds % 60000) ~/ 1000).toString().padLeft(
      2,
      '0',
    );
    final centiseconds = ((totalMilliseconds % 1000) ~/ 10).toString().padLeft(
      2,
      '0',
    );
    return '$minutes:$seconds.$centiseconds';
  }

  Future<List<DanmuElem>> findBilibiliLyricDanmu(
    String trackId,
    Duration duration,
  ) async {
    // Duration dur = Get.find<PlayController>().music_player.state.duration;

    int segmentTotal = (duration.inMilliseconds / (6 * 60 * 1000)).ceil();
    segmentTotal = segmentTotal > 0 ? segmentTotal : 1;
    // String id = Get.find<PlayController>().nowPlayingTrackId;
    if (!trackId.startsWith('bi')) {
      throw '当前歌曲不是哔哩哔哩歌曲，无法获取弹幕';
    }
    Map<String, dynamic> param = {
      "type": 1,
      // "oid": 31825857879,
      // "segment_index": 1,
      "pull_mode": 1,
    };
    if (trackId.split('-').length > 1) {
      param['oid'] = trackId.split('-')[1];
    } else {
      final aOrBvId = trackId.substring('bitrack_v_'.length);
      if (aOrBvId.startsWith('BV')) {
        //         curl -G 'https://api.bilibili.com/x/player/pagelist' \
        // --data-urlencode 'bvid=BV1ex411J7GE'
        final response = await dioWithCookieManager.get(
          'https://api.bilibili.com/x/player/pagelist',
          queryParameters: {'bvid': aOrBvId},
        );
        final cid = response.data['data'][0]['cid'];
        param['oid'] = cid;
      } else {
        //         curl -G 'https://api.bilibili.com/x/player/pagelist' \
        // --data-urlencode 'aid=13502509'
        final response = await dioWithCookieManager.get(
          'https://api.bilibili.com/x/player/pagelist',
          queryParameters: {'aid': aOrBvId},
        );
        final cid = response.data['data'][0]['cid'];
        param['oid'] = cid;
      }
    }
    int segmentIndex = 1;
    List<DanmuElem> allDanmuElems = [];
    do {
      param['segment_index'] = segmentIndex;
      final response = await Bilibili.wrap_wbi_request(
        'https://api.bilibili.com/x/v2/dm/wbi/web/seg.so',
        segmentIndex != 1 ? param : {...param, 'ps': 0, 'pe': 120000},
        responseType: ResponseType.bytes,
      );
      if (response.statusCode == 200) {
        final bytes = response.data as Uint8List;
        DmSegMobileReply dmSegMobileReply = DmSegMobileReply.fromBuffer(bytes);
        allDanmuElems.addAll(dmSegMobileReply.elems);
      } else {
        throw '请求弹幕第$segmentIndex段失败，状态码: ${response.statusCode}';
      }
      if (segmentIndex == 1) {
        final response = await Bilibili.wrap_wbi_request(
          'https://api.bilibili.com/x/v2/dm/wbi/web/seg.so',
          {...param, 'ps': 120000, 'pe': 360000},
          responseType: ResponseType.bytes,
        );
        if (response.statusCode == 200) {
          final bytes = response.data as Uint8List;
          DmSegMobileReply dmSegMobileReply = DmSegMobileReply.fromBuffer(
            bytes,
          );
          allDanmuElems.addAll(dmSegMobileReply.elems);
        } else {
          throw '请求弹幕第$segmentIndex段失败，状态码: ${response.statusCode}';
        }
      }
    } while (++segmentIndex <= segmentTotal);

    // debugPrint('总弹幕数量: ${allDanmuElems.length}');
    return allDanmuElems;
  }

  Future<void> fetchDanmu() async {
    final url =
        "https://api.bilibili.com/x/v2/dm/wbi/web/seg.so?type=1&oid=31825857879&pid=115060697470544&segment_index=1&pull_mode=1&ps=120000&pe=360000&web_location=1315873&w_rid=deb11704e0c4b28cff30ef0c2dedf050&wts=1772077522";

    // try {
    final response = await dioWithCookieManager.get(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          "Accept-Encoding": "identity", // 明确要求不进行任何
        },
      ),
    );
    debugPrint(
      '前20${(response.data as Uint8List).take(20).toList().toString()}',
    );
    debugPrint(' ${String.fromCharCodes(response.data)}');
    DmSegMobileReply dmSegMobileReply = DmSegMobileReply.fromBuffer(
      (response.data as Uint8List),
    );
    if (response.statusCode == 200) {
      final bytes = response.data as Uint8List;
    } else {
      print('请求失败，状态码: ${response.statusCode}');
    }
    // } catch (e) {
    //   print("解析错误: $e");
    // }
  }

  String? _extractTrackIdFromLyricBoxKey(Object key) {
    if (key is! String) return null;

    const tSuffix = '_tlyric';
    const suffix = '_lyric';

    if (key.endsWith(tSuffix)) {
      return key.substring(0, key.length - tSuffix.length);
    }
    if (key.endsWith(suffix)) {
      return key.substring(0, key.length - suffix.length);
    }
    return null;
  }

  /// 删除 lyricBox 中除 keepIds 之外的所有歌词记录（仅处理 *_lyric / *_tlyric）
  Future<void> clearLyricBoxExceptIds(Iterable<String> keepIds) async {
    try {
      if (!_settingsController.useLyricBox) return;
      final box = _settingsController.lyricBox;
      if (box == null) return;

      final keepSet = keepIds.toSet();
      final keysToDelete = <dynamic>[];

      for (final key in box.keys) {
        final trackId = _extractTrackIdFromLyricBoxKey(key);
        if (trackId == null) continue;
        if (!keepSet.contains(trackId)) {
          keysToDelete.add(key);
        }
      }

      if (keysToDelete.isEmpty) return;
      await box.deleteAll(keysToDelete);
    } catch (e) {
      debugPrint('清理 lyricBox 失败: $e');
    }
  }

  /// 清理特定歌曲的歌词缓存
  Future<void> clearLyricCache(String trackId) async {
    try {
      // 直接删除歌词文件与 lyricBox 字段（不走 CacheController，它面向音频缓存）
      final tempDir = await xuanGetdataDirectory();
      final tempPath = tempDir.path;

      Future<void> deleteFileIfExists(String fileName) async {
        final filePath = p.join(tempPath, fileName);
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      await deleteFileIfExists(_getLyricCacheFileName(trackId));
      await deleteFileIfExists(
        _getLyricCacheFileName(trackId, isTranslation: true),
      );

      if (_settingsController.useLyricBox) {
        final box = _settingsController.lyricBox;
        await box?.delete(_getLyricCacheKey(trackId));
        await box?.delete(_getLyricCacheKey(trackId, isTranslation: true));
      }
    } catch (e) {
      print('清理歌词缓存失败: $e');
    }
  }

  /// 检查歌词缓存是否存在
  Future<bool> hasLyricCache(String trackId) async {
    final cachedLyrics = await _loadLyricFromCache(trackId);
    return cachedLyrics.containsKey('lyric') &&
        cachedLyrics['lyric']!.isNotEmpty;
  }

  @override
  void onClose() {
    lyricController.dispose();
    super.onClose();
  }
}
