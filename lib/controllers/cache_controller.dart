import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/lyric_controller.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:listen1_xuan/models/OnlineCacheItem.dart';
import 'package:listen1_xuan/services/bilibili_mp3_transcoder.dart';
import 'package:listen1_xuan/services/cache_audio_metadata.dart';
import 'package:listen1_xuan/services/cache_file_naming.dart';
import 'package:listen1_xuan/services/ffmpeg_config.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'dart:convert';
import '../constants/const.dart';
import '../constants/network_defaults.dart';
import '../global_settings_animations.dart';
import 'DioController.dart';
import 'myPlaylist_controller.dart';
import 'play_controller.dart';
import 'settings_controller.dart';
import 'package:listen1_xuan/models/Track.dart';

class CacheController extends GetxController {
  static const int _maxCoverArtBytes = 20 * 1024 * 1024;

  final Logger _logger = Logger();
  final String _localCacheListKey = 'local-cache-list';
  final _localCacheList = <String, String>{}.obs;
  final _onlineCacheList = <String, OnlineCacheItem>{}.obs;
  final _toDelFiles = <String>{}.obs;
  final Set<String> _activeDownloadFileNames = {};
  final SettingsController _settingsController = Get.find<SettingsController>();
  PlayController get _playController => Get.find<PlayController>();
  Future<Map<String, String>> localCacheList() async {
    Map<String, String> res = Map<String, String>.fromEntries(
      _localCacheList.entries
          .where((entry) => !entry.key.contains('lyric'))
          .map((entry) => MapEntry(entry.key, entry.value)),
    );
    var downDir = await xuanGetdataDirectory();
    Set<String> files = {};
    for (var element in (await downDir.list().toList())) {
      if (element is File) {
        files.add(p.basename(element.path));
      }
    }
    res.removeWhere((key, value) => !files.contains(value));
    return res;
  }

  bool _isDeleting = false;
  @override
  void onInit() {
    super.onInit();
    debounce(_localCacheList, (value) {
      _saveLocalCacheList();
    }, time: Duration(seconds: 3));
    debounce(_toDelFiles, (value) {
      Get.find<SettingsController>().settings['toDelFiles'] = _toDelFiles
          .toList();
    }, time: Duration(seconds: 3));
  }

  /// 加载本地缓存列表
  void loadLocalCacheList() {
    _localCacheList.value =
        Get.find<SettingsController>().CacheController_localCacheList;
    var t = Get.find<SettingsController>().settings['toDelFiles'] ?? [];
    try {
      _toDelFiles.clear();
      _toDelFiles.addAll(Set<String>.from(t));
    } catch (e) {
      debugPrint('加载待删除文件列表失败: $e');
    }
  }

  /// 保存本地缓存列表
  Future<void> _saveLocalCacheList() async {
    final s = Get.find<SettingsController>();
    await s.setString(
      _localCacheListKey,
      jsonEncode(Map<String, String>.from(_localCacheList)),
    );
  }

  Future<Directory> changeCacheDirectory(String? customPath) async {
    if (_playController.bootStrapDownloading.isNotEmpty) {
      throw StateError('有歌曲正在缓存，请等待下载完成后再更改路径');
    }

    final oldDirectory = await xuanGetdataDirectory();
    final newDirectory = customPath == null || customPath.trim().isEmpty
        ? await xuanGetDefaultCacheDirectory()
        : Directory(customPath.trim());

    if (!await newDirectory.exists()) {
      await newDirectory.create(recursive: true);
    }
    await _verifyDirectoryWritable(newDirectory);

    if (p.equals(
      p.normalize(oldDirectory.absolute.path),
      p.normalize(newDirectory.absolute.path),
    )) {
      _settingsController.cacheDirectoryPath = customPath?.trim() ?? '';
      return newDirectory;
    }

    final createdFiles = <File>[];
    final filesToDelete = <File>[];
    try {
      for (final fileName in _localCacheList.values.toSet()) {
        final source = File(p.join(oldDirectory.path, fileName));
        if (!await source.exists()) continue;

        final destination = File(p.join(newDirectory.path, fileName));
        if (await destination.exists()) {
          if (await source.length() != await destination.length()) {
            throw FileSystemException('目标目录存在同名缓存文件', destination.path);
          }
        } else {
          final partial = File('${destination.path}.listen1-moving');
          if (await partial.exists()) await partial.delete();
          await source.copy(partial.path);
          await partial.rename(destination.path);
          createdFiles.add(destination);
        }
        filesToDelete.add(source);
      }

      _settingsController.cacheDirectoryPath = customPath?.trim() ?? '';
    } catch (_) {
      for (final file in createdFiles.reversed) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      rethrow;
    }

    for (final file in filesToDelete) {
      try {
        if (await file.exists()) await file.delete();
      } catch (e) {
        _logger.w('旧缓存文件删除失败', error: e);
      }
    }
    return newDirectory;
  }

  Future<void> _verifyDirectoryWritable(Directory directory) async {
    final probe = File(
      p.join(
        directory.path,
        '.listen1-write-test-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    try {
      await probe.writeAsString('');
    } finally {
      if (await probe.exists()) await probe.delete();
    }
  }

  Future<void> downloadAndCacheFile(
    dynamic res,
    Track track, {
    Track? sTrack,
  }) async {
    _onlineCacheList[track.id] = OnlineCacheItem(
      url: res['url'],
      audioQualityOfBL: res['audioQualityOfBL'],
    );
    if (_settingsController.disableSongDownload) return;

    if (_playController.bootStrapDownloading.containsKey(
      sTrack?.id ?? track.id,
    )) {
      return;
    }

    final downDir = await xuanGetdataDirectory();
    String downPath = downDir.path;
    final isBilibili = res['platform'] == PlatformSource.bilibili.name;
    final existingFileNames = await listExistingCacheFileNames(downDir)
      ..addAll(_activeDownloadFileNames);
    String fileName = getDownloadNamed(
      track,
      res['url'],
      extensionOverride: isFfmpegEnabled && isBilibili ? '.mp3' : null,
      existingFileNames: existingFileNames,
    );
    final filePath = p.join(downPath, fileName);
    final downloadId = sTrack?.id ?? track.id;
    _activeDownloadFileNames.add(fileName);
    _playController.bootStrapDownloading[downloadId] = fileName;
    void onReceiveProgress(int count, int total) {
      if (_playController.bootStrapDownloading.containsKey(downloadId)) {
        _playController.bootStrapDownloading[downloadId] = total > 0
            ? '${formatBytes(count)}/${formatBytes(total)}'
            : formatBytes(count);
      }
    }

    void onSuccess() {
      showDebugSnackbar('$fileName 下载完成', null);
      _activeDownloadFileNames.remove(fileName);
      setLocalCache(track.id, fileName);
      if (downloadId != track.id) {
        _playController.bootStrapDownloading.remove(downloadId);
      }
    }

    void onError(Object error) {
      _logger.e('下载文件失败: $error');
      _activeDownloadFileNames.remove(fileName);
      _playController.bootStrapDownloading.remove(downloadId);
      showErrorSnackbar('下载文件失败', error.toString());
    }

    Future<void> runCacheOperation(Future<void> Function() operation) async {
      try {
        await operation();
        onSuccess();
      } catch (error) {
        onError(error);
      }
    }

    if (isFfmpegEnabled && isBilibili && !_isMp3Url(res['url'])) {
      unawaited(
        runCacheOperation(
          () => _transcodeBilibiliToMp3(
            sourceUrl: res['url'],
            filePath: filePath,
            track: track,
            onReceiveProgress: onReceiveProgress,
          ),
        ),
      );
      return;
    }

    unawaited(
      runCacheOperation(() async {
        final partialFile = File(
          CacheAudioMetadata.temporaryDownloadPath(filePath),
        );
        try {
          if (await partialFile.exists()) await partialFile.delete();
          await dioWithCookieManager.download(
            res['url'],
            partialFile.path,
            options: isBilibili ? Options(headers: kBilibiliPlayHeader) : null,
            onReceiveProgress: onReceiveProgress,
          );
          await finalizeCacheFile(
            inputPath: partialFile.path,
            outputPath: filePath,
            track: track,
          );
        } finally {
          if (await partialFile.exists()) await partialFile.delete();
        }
      }),
    );
  }

  Future<void> _transcodeBilibiliToMp3({
    required String sourceUrl,
    required String filePath,
    required Track track,
    required void Function(int count, int total) onReceiveProgress,
  }) async {
    final partialFile = File('$filePath.listen1-part.mp3');
    final retainMetadata = _settingsController.cacheRetainMetadata;
    File? coverFile;
    try {
      if (await partialFile.exists()) await partialFile.delete();
      coverFile = await _downloadCoverArt(
        track: track,
        outputPath: partialFile.path,
        retainMetadata: retainMetadata,
      );
      await const BilibiliMp3Transcoder().transcode(
        dio: dioWithCookieManager,
        sourceUrl: sourceUrl,
        outputPath: partialFile.path,
        retainMetadata: retainMetadata,
        metadata: _metadataForTrack(track),
        coverPath: coverFile?.path,
        onDownloadProgress: onReceiveProgress,
      );
      final outputFile = File(filePath);
      if (await outputFile.exists()) await outputFile.delete();
      await partialFile.rename(filePath);
    } catch (_) {
      if (await partialFile.exists()) await partialFile.delete();
      rethrow;
    } finally {
      await _deleteTemporaryCover(coverFile);
    }
  }

  bool _isMp3Url(String url) {
    return p.extension(Uri.parse(url).path).toLowerCase() == '.mp3';
  }

  Future<void> finalizeCacheFile({
    required String inputPath,
    required String outputPath,
    Track? track,
  }) async {
    // 无 FFmpeg 的精简版直接落盘，不做元数据写入。
    if (!isFfmpegEnabled) {
      final outputFile = File(outputPath);
      if (await outputFile.exists()) await outputFile.delete();
      await File(inputPath).rename(outputPath);
      return;
    }

    final metadataOutput = File(
      CacheAudioMetadata.temporaryOutputPath(outputPath),
    );
    final retainMetadata = _settingsController.cacheRetainMetadata;
    File? coverFile;
    try {
      if (await metadataOutput.exists()) await metadataOutput.delete();
      if (track != null) {
        coverFile = await _downloadCoverArt(
          track: track,
          outputPath: metadataOutput.path,
          retainMetadata: retainMetadata,
        );
      }
      await const CacheAudioMetadata().rewrite(
        inputPath: inputPath,
        outputPath: metadataOutput.path,
        retainMetadata: retainMetadata,
        metadata: track == null ? null : _metadataForTrack(track),
        coverPath: coverFile?.path,
      );

      final outputFile = File(outputPath);
      if (await outputFile.exists()) await outputFile.delete();
      await metadataOutput.rename(outputPath);
    } catch (_) {
      if (await metadataOutput.exists()) await metadataOutput.delete();
      rethrow;
    } finally {
      await _deleteTemporaryCover(coverFile);
    }
  }

  Future<File?> _downloadCoverArt({
    required Track track,
    required String outputPath,
    required bool retainMetadata,
  }) async {
    if (!retainMetadata ||
        !CacheAudioMetadata.supportsEmbeddedCover(outputPath)) {
      return null;
    }

    var coverUrl = track.img_url?.trim() ?? '';
    if (coverUrl.isEmpty) return null;
    coverUrl = coverUrl.replaceAll('{size}', '500');
    if (coverUrl.startsWith('//')) coverUrl = 'https:$coverUrl';
    final uri = Uri.tryParse(coverUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    final coverFile = File(CacheAudioMetadata.temporaryCoverPath(outputPath));
    try {
      if (await coverFile.exists()) await coverFile.delete();
      final isBilibiliCover =
          track.source == PlatformSource.bilibili.name ||
          track.id.startsWith('bi');
      Map<String, String>? headers;
      if (isBilibiliCover) {
        headers = Map<String, String>.from(kBilibiliPlayHeader)
          ..remove(HttpHeaders.rangeHeader);
      }
      await dioWithCookieManager.download(
        uri.toString(),
        coverFile.path,
        options: headers == null ? null : Options(headers: headers),
      );
      final length = await coverFile.length();
      if (length == 0 || length > _maxCoverArtBytes) {
        throw const FormatException('歌曲封面为空或超过 20MB');
      }
      return coverFile;
    } catch (error) {
      _logger.w('下载歌曲封面失败: $coverUrl', error: error);
      if (await coverFile.exists()) await coverFile.delete();
      return null;
    }
  }

  Future<void> _deleteTemporaryCover(File? coverFile) async {
    if (coverFile == null) return;
    try {
      if (await coverFile.exists()) await coverFile.delete();
    } catch (error) {
      _logger.w('临时歌曲封面删除失败: ${coverFile.path}', error: error);
    }
  }

  CacheTrackMetadata _metadataForTrack(Track track) {
    return CacheTrackMetadata(
      title: track.title,
      artist: track.artist,
      album: track.album,
      albumArtist: track.artist,
    );
  }

  String getDownloadNamed(
    Track track,
    String url, {
    String? extensionOverride,
    required Set<String> existingFileNames,
  }) {
    String fileName = '';
    List<int> namedMethod = _settingsController.cacheNamedMethod;
    String namedConnection = _settingsController.cacheNamedConnection;
    String ifEmptyRep = _settingsController.cacheIfEmptyRep;
    String unUseableRep = _settingsController.cacheUnUseableRep;
    int dedupMethod = _settingsController.cacheDedupMethod;
    for (var m in namedMethod) {
      switch (NamedMethod.values[m]) {
        case NamedMethod.id:
          if (track.id.isNotEmpty) {
            fileName += track.id;
          } else {
            fileName += ifEmptyRep;
          }
          break;
        case NamedMethod.title:
          if (track.title != null && track.title!.isNotEmpty) {
            fileName += track.title!;
          } else {
            fileName += ifEmptyRep;
          }
          break;
        case NamedMethod.artist:
          if (track.artist != null && track.artist!.isNotEmpty) {
            fileName += track.artist!;
          } else {
            fileName += ifEmptyRep;
          }
          break;
        case NamedMethod.album:
          if (track.album != null && track.album!.isNotEmpty) {
            fileName += track.album!;
          } else {
            fileName += ifEmptyRep;
          }
          break;
        case NamedMethod.source:
          if (track.source != null && track.source!.isNotEmpty) {
            fileName += track.source!;
          } else {
            fileName += ifEmptyRep;
          }
          break;
      }
      fileName += namedConnection;
    }
    fileName = fileName.substring(0, fileName.length - namedConnection.length);
    // 处理不可用字符
    for (var char in cacheUnUseableRepUnUseable.split('')) {
      fileName = fileName.replaceAll(char, unUseableRep);
    }
    final ext =
        extensionOverride ?? p.extension(Uri.parse(url).pathSegments.last);
    return deduplicateCacheFileName(
      baseName: fileName,
      extension: ext,
      existingFileNames: existingFileNames,
      useNumberSuffix: dedupMethod == DedupMethod.number.index,
      separator: namedConnection,
    );
  }

  Future<void> tryDelFiles() async {
    if (_toDelFiles.isEmpty) return;
    _isDeleting = true;
    _toDelFiles.forEach((filePath) async {
      try {
        File file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('删除文件成功: $filePath');
          _toDelFiles.remove(filePath);
        } else {
          debugPrint('文件不存在: $filePath');
          _toDelFiles.remove(filePath);
        }
      } catch (e) {
        debugPrint('删除文件失败: $filePath, 错误: $e');
      }
    });
    _isDeleting = false;
  }

  bool isOnlineCache(String id) {
    return _onlineCacheList.containsKey(id);
  }

  Map<String, String>? httpHeadersOfOnlineCache(String id) {
    id = _playController.songReplaceSettings.value.getReplacementId(id) ?? id;
    if (isOnlineCache(id) && id.startsWith('bi')) {
      return kBilibiliPlayHeader;
    }
    return null;
  }

  /// 获取本地缓存文件路径
  Future<String> getLocalCache(String id) async {
    if (!_isDeleting) tryDelFiles(); // 尝试删除待删除的文件
    id = _playController.songReplaceSettings.value.getReplacementId(id) ?? id;
    if (_onlineCacheList.containsKey(id)) {
      return _onlineCacheList[id]!.url;
    }
    if (_localCacheList.containsKey(id)) {
      var downDir = await xuanGetdataDirectory();

      final downPath = downDir.path;
      var filePath = p.join(downPath, _localCacheList[id]!);
      if (await File(filePath).exists()) {
        return filePath;
      }
    }
    return '';
  }

  OnlineCacheItem? getLocalCacheOnlineCacheItem(String id) {
    id = _playController.songReplaceSettings.value.getReplacementId(id) ?? id;
    if (_onlineCacheList.containsKey(id)) {
      return _onlineCacheList[id]!;
    }
    return null;
  }

  // 设置本地缓存文件路径
  void setLocalCache(String id, String fileName) async {
    _onlineCacheList.remove(id);
    _localCacheList[id] = fileName;
    _playController.bootStrapDownloading.remove(id);
  }

  /// 清理本地缓存
  Future<void> cleanLocalCache([
    bool all = false,
    String id = '',
    bool hideSnackbar = false,
  ]) async {
    if (id.isNotEmpty) {
      await _cleanSingleCache(id, hideSnackbar: hideSnackbar);
      return;
    }

    if (all) {
      await _cleanAllCache();
    } else {
      await _cleanUnusedCache();
    }
  }

  void testSetErrorAddr() {
    _onlineCacheList[_playController.currentTrack.id] = OnlineCacheItem(
      url: 'http://example.com/nonexistentfile.mp3',
    );
  }

  /// 清理单个缓存文件
  Future<void> _cleanSingleCache(String id, {bool hideSnackbar = false}) async {
    if (_playController.bootStrapDownloading.containsKey(id)) {
      showWarningSnackbar('正在下载中，无法清理', null);
      return;
    }
    Get.find<XLyricController>().clearLyricCache(id);
    id = _playController.songReplaceSettings.value.getReplacementId(id) ?? id;
    final path = await getLocalCache(id);
    if (isOnlineCache(id)) {
      _onlineCacheList.remove(id);
      if (!hideSnackbar) showInfoSnackbar('已清理在线缓存', null);
      return;
    }
    if (path.isNotEmpty) {
      try {
        await File(path).delete();
        _localCacheList.remove(id);

        if (!hideSnackbar) {
          showInfoSnackbar('已清理', null);
        }
      } catch (e) {
        showErrorSnackbar('清理失败', e.toString());
      }
    } else {
      showWarningSnackbar('没有可清理的缓存文件', null);
    }
  }

  /// 清理所有缓存
  Future<void> _cleanAllCache() async {
    final tempDir = await xuanGetdataDirectory();
    final files = await _getCacheFiles(tempDir.path);

    int count = 0;
    for (final file in files) {
      try {
        await File(file).delete();
        count++;
      } catch (e) {
        print('删除文件失败: $file, 错误: $e');
      }
    }

    // 清空缓存列表
    _localCacheList.clear();

    _showCleanResult(count);
  }

  /// 清理未使用的缓存
  Future<void> _cleanUnusedCache() async {
    final tempDir = await xuanGetdataDirectory();
    final files = await _getCacheFiles(tempDir.path);
    Set<String> notToDelIds = {};
    notToDelIds.addAll(Get.find<MyPlayListController>().savedIds);
    notToDelIds.addAll(Get.find<PlayController>().playingIds);
    notToDelIds.addAll(
      Get.find<PlayController>().songReplaceSettings.value.idMappings.values,
    );
    _localCacheList.removeWhere((key, value) {
      return !notToDelIds.contains(key);
    });
    int count = 0;
    final cacheFileNames = _localCacheList.values.toSet();
    bool checkLyric(String filename) {
      if (!filename.endsWith('.lrc')) {
        return false;
      }
      List<String> trackIds = filename.split('_');
      if (trackIds.length == 0) return false;
      trackIds.removeLast();
      return notToDelIds.contains(trackIds.join('_'));
    }

    for (final file in files) {
      final fileName = p.basename(file);

      // 如果文件不在缓存列表中，则删除
      if (!cacheFileNames.contains(fileName) && !checkLyric(fileName)) {
        try {
          await File(file).delete();
          count++;
        } catch (e) {
          print('删除未使用文件失败: $file, 错误: $e');
        }
      }
    }
    Get.find<XLyricController>().clearLyricBoxExceptIds(notToDelIds);
    // 清理无效的缓存记录（文件已不存在）
    await _cleanInvalidCacheRecords();

    _showCleanResult(count);
  }

  /// 获取缓存目录下的所有文件
  Future<List<String>> _getCacheFiles(String tempPath) async {
    final List<String> without = ['app.log'];
    final List<String> jumpList = ['.json', '.apk', '.zip', '.log', '.exe'];
    final List<String> files = [];

    try {
      final filesAndDirs = Directory(tempPath).listSync();

      for (final fileSystemEntity in filesAndDirs) {
        if (fileSystemEntity is File) {
          final fileName = p.basename(fileSystemEntity.path);

          // 跳过系统文件和特定类型文件
          if (without.contains(fileName)) continue;

          bool shouldJump = false;
          for (final extension in jumpList) {
            if (fileName.endsWith(extension)) {
              shouldJump = true;
              break;
            }
          }

          if (!shouldJump) {
            files.add(fileSystemEntity.path);
          }
        }
      }
    } catch (e) {
      print('读取缓存目录失败: $e');
    }

    return files;
  }

  /// 清理无效的缓存记录
  Future<void> _cleanInvalidCacheRecords() async {
    final tempDir = await xuanGetdataDirectory();
    final tempPath = tempDir.path;
    final List<String> keysToRemove = [];

    for (final entry in _localCacheList.entries) {
      final filePath = p.join(tempPath, entry.value);

      if (!await File(filePath).exists()) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _localCacheList.remove(key);
    }
  }

  /// 显示清理结果
  void _showCleanResult(int count) {
    if (count > 0) {
      showInfoSnackbar('清理了$count个缓存文件', null);
    } else {
      showWarningSnackbar('没有可清理的缓存文件', null);
    }
  }

  /// 获取缓存大小（可选功能）
  Future<int> getCacheSize() async {
    final tempDir = await xuanGetdataDirectory();
    final tempPath = tempDir.path;

    final filesanddirs = Directory(tempPath).listSync();
    int totalSize = 0;
    List<String> jumpList = ['.json', '.apk', '.zip', '.log'];
    List<String> without = ['app.log'];

    for (var file in filesanddirs) {
      if (file is File && !without.contains(p.basename(file.path))) {
        bool jumpFlag = false;
        for (var jump in jumpList) {
          if (p.basename(file.path).endsWith(jump)) {
            jumpFlag = true;
            break;
          }
        }
        if (!jumpFlag) {
          totalSize += await file.length();
        }
      }
    }

    return totalSize;
  }

  /// 格式化缓存大小显示
  String formatCacheSize(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
    }
  }
}

enum NamedMethod {
  id('歌曲ID'),
  title('标题'),
  artist('作者'),
  album('专辑'),
  source('来源');

  final String name;
  const NamedMethod(this.name);
}

// 去重方法
enum DedupMethod {
  number('尾随序号'),
  strs('尾随随机字符串');

  final String name;
  const DedupMethod(this.name);
}
