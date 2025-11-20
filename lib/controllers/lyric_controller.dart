import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_lyric/lyrics_reader_model.dart';
import 'package:flutter_lyric/lyrics_model_builder.dart';
import 'dart:io';
import '../funcs.dart';
import '../loweb.dart';
import '../controllers/play_controller.dart';
import '../controllers/cache_controller.dart';
import '../controllers/settings_controller.dart';
import '../global_settings_animations.dart';
import '../play.dart';
import 'package:path/path.dart' as p;

class LyricController extends GetxController {
  // 歌词显示相关
  var currentLyric = ''.obs;
  var translationLyric = ''.obs;
  var isLyricLoading = false.obs;
  var hasLyric = false.obs;
  final updFormatShowLyric = LyricsLineModel().obs;
  // showTranslation 已移至 SettingsController

  // 歌词解析相关
  LyricsReaderModel? lyricModel;

  // 当前歌曲信息
  var currentTrackId = ''.obs;

  // 存储原始歌词数据
  String _originalLyric = '';
  String _originalTranslation = '';

  /// 获取缓存控制器
  CacheController get _cacheController => Get.find<CacheController>();

  /// 获取设置控制器
  SettingsController get _settingsController => Get.find<SettingsController>();

  /// 生成歌词缓存文件路径
  String _getLyricCacheFileName(String trackId, {bool isTranslation = false}) {
    final suffix = isTranslation ? '_tlyric' : '_lyric';
    return '${trackId}${suffix}.lrc';
  }

  /// 从本地缓存读取歌词
  Future<Map<String, String>> _loadLyricFromCache(String trackId) async {
    final result = <String, String>{};

    try {
      // 获取音乐文件的缓存路径作为基础路径
      final musicCachePath = await _cacheController.getLocalCache(trackId);
      if (musicCachePath.isEmpty) return result;

      // 构建歌词文件路径
      final tempDir = await xuanGetdataDirectory();
      final tempPath = tempDir.path;

      // 主歌词文件
      final lyricFileName = _getLyricCacheFileName(trackId);
      final lyricFilePath = p.join(tempPath, lyricFileName);

      if (await File(lyricFilePath).exists()) {
        result['lyric'] = await File(lyricFilePath).readAsString();
      }

      // 翻译歌词文件
      final tlyricFileName = _getLyricCacheFileName(
        trackId,
        isTranslation: true,
      );
      final tlyricFilePath = p.join(tempPath, tlyricFileName);

      if (await File(tlyricFilePath).exists()) {
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
  }) async {
    try {
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
        isTranslation ? '${trackId}_tlyric' : '${trackId}_lyric',
        fileName,
      );
    } catch (e) {
      print('保存歌词到缓存失败: $e');
    }
  }

  @override
  void onInit() {
    super.onInit();
    // 监听播放位置变化，更新歌词显示
    Get.find<PlayController>().music_player.stream.position.listen((position) {
      if (lyricModel != null) {
        _updateCurrentLyric(position);
      }
    });
    ever(updFormatShowLyric, (value) {
      if (isWindows) return;
      if (!value.hasMain) return;
      if (!_settingsController.tryShowLyricInNotification) return;
      change_playback_state(null, lyric: value);
    });
  }

  /// 加载歌词
  Future<void> loadLyric() async {
    String trackId = Get.find<PlayController>().nowPlayingTrackId;
    if (trackId.isEmpty) return;
    isLyricLoading.value = true;
    hasLyric.value = false;
    currentLyric.value = '';
    translationLyric.value = '';
    lyricModel = null;

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
      }

      isLyricLoading.value = false;
    });
  }

  /// 处理歌词数据
  void _processLyricData(String lyric, String tlyric) {
    currentLyric.value = lyric;
    _originalLyric = lyric;

    if (tlyric.isNotEmpty) {
      translationLyric.value = tlyric;
      _originalTranslation = tlyric;
    } else {
      _originalTranslation = '';
    }

    // 构建歌词模型
    _rebuildLyricModel();
    hasLyric.value = true;
  }

  String formatShowLyric(LyricsLineModel? line) {
    if (line == null) return '';
    String mainText = line.mainText ?? '';
    String extText = line.extText ?? '';

    if (_settingsController.showLyricTranslation.value && !isEmpty(extText)) {
      return '$mainText\n$extText';
    } else {
      return mainText;
    }
  }

  /// 更新当前显示的歌词
  void _updateCurrentLyric(Duration position) {
    if (lyricModel == null || lyricModel?.lyrics.isEmpty == true) return;
    LyricsLineModel? line =
        lyricModel?.lyrics[lyricModel!.getCurrentLine(position.inMilliseconds)];
    // debugPrint('更新歌词: ${formatShowLyric(line)}');
    // updFormatShowLyric.value = formatShowLyric(line);
    updFormatShowLyric.value = line ?? LyricsLineModel();

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
    _rebuildLyricModel();
  }

  /// 重新构建歌词模型
  void _rebuildLyricModel() {
    if (_originalLyric.isEmpty) return;

    var builder = LyricsModelBuilder.create().bindLyricToMain(_originalLyric);

    // 只有在开启翻译显示且有翻译内容时才绑定翻译歌词
    if (_settingsController.showLyricTranslation.value &&
        _originalTranslation.isNotEmpty) {
      builder = builder.bindLyricToExt(_originalTranslation);
    }

    lyricModel = builder.getModel();
  }

  /// 清理特定歌曲的歌词缓存
  Future<void> clearLyricCache(String trackId) async {
    try {
      // 清理主歌词缓存
      final lyricCacheKey = '${trackId}_lyric';
      final tlyricCacheKey = '${trackId}_tlyric';

      await _cacheController.cleanLocalCache(false, lyricCacheKey);
      await _cacheController.cleanLocalCache(false, tlyricCacheKey);
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
}
