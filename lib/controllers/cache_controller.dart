import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_audio_tagger/flutter_audio_tagger.dart';
import 'package:flutter_audio_tagger/tag.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import '../global_settings_animations.dart';
import 'myPlaylist_controller.dart';
import 'play_controller.dart';
import 'settings_controller.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:mime/mime.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:path/path.dart';

class CacheController extends GetxController {
  final Logger _logger = Logger();
  final String _localCacheListKey = 'local-cache-list';
  final _localCacheList = <String, String>{}.obs;
  String checkFfmpegVersion = '';
  bool isFFmpegOkWithoutCheck = false;
  bool _firstCheck = true;
  final _toDelFiles = <String>{}.obs;
  Set<String> saveMetadataToCacheWorkingIds = {};

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
        files.add(basename(element.path));
      }
    }
    res.removeWhere((key, value) => !files.contains(value));
    return res;
  }

  String get ffmpegPathWindows {
    String? ffmpegPath = Get.find<PlayController>().getPlayerSettings(
      'ffmpegPath',
    );
    if (ffmpegPath != null && ffmpegPath.isNotEmpty) return ffmpegPath;
    return 'ffmpeg';
  }

  late FlutterAudioTagger tagger;
  set ffmpegPathWindows(String path) {
    Get.find<PlayController>().setPlayerSetting('ffmpegPath', path);
  }

  Future<bool> isFFmpegOk() async {
    try {
      var result = await Process.run(ffmpegPathWindows, ['-version']);
      checkFfmpegVersion = result.stdout;
      isFFmpegOkWithoutCheck = result.exitCode == 0;
      return isFFmpegOkWithoutCheck;
    } catch (e) {
      debugPrint('检查FFmpeg失败: $e');
      isFFmpegOkWithoutCheck = false;
      return false;
    }
  }

  bool _isDeleting = false;
  @override
  void onInit() {
    super.onInit();
    if (isAndroid) {
      tagger = FlutterAudioTagger();
    }
    debounce(_localCacheList, (value) {
      _saveLocalCacheList();
    }, time: Duration(seconds: 3));
    debounce(_toDelFiles, (value) {
      Get.find<SettingsController>().settings['toDelFiles'] = _toDelFiles
          .toList();
    }, time: Duration(seconds: 3));
  }

  Future<void> moveOldData() async {
    final oldDir = await getApplicationDocumentsDirectory();
    final newDir = await xuanGetdataDirectory();
    if (oldDir.path != newDir.path) {
      final oldFiles = Directory(oldDir.path).listSync();
      for (var file in oldFiles) {
        try {
          if (file is File &&
              (file.path.endsWith('.mp3') ||
                  file.path.endsWith('.mp4') ||
                  file.path.endsWith('.m4a') ||
                  file.path.endsWith('.m4s') ||
                  file.path.endsWith('.flv') ||
                  file.path.endsWith('.lrc'))) {
            final newPath = '${newDir.path}/${file.uri.pathSegments.last}';
            await file.copy(newPath);
            file.deleteSync(); // 删除旧文件
            debugPrint('迁移文件: ${file.path} -> $newPath');
          }
        } catch (e) {
          debugPrint('迁移文件失败: ${file.path}, 错误: $e');
        }
      }
      debugPrint('旧数据迁移完成');
    } else {
      debugPrint('新旧目录相同，无需迁移');
    }
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localCacheListKey,
      jsonEncode(Map<String, String>.from(_localCacheList)),
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

  /// 获取本地缓存文件路径
  Future<String> getLocalCache(String id) async {
    if (!_isDeleting) tryDelFiles(); // 尝试删除待删除的文件
    if (_localCacheList.containsKey(id)) {
      var downDir = await xuanGetdataDirectory();

      final downPath = downDir.path;
      var filePath = p.join(downPath, _localCacheList[id]!);
      if (await File(filePath).exists()) {
        // return await saveMetadataToCache(id, filePath);
        // if (!(await isSoCalledDownloaded(id))) {
        if (!(await isSoCalledDownloaded(id))) {
          saveMetadataToCache(id, filePath);
        }
        return filePath;
      }
    }
    return '';
  }

  Future<String> getDownloadNamedPath(Track track) async {
    // var downloadDir = await xuan_getdownloadDirectory();
    // final tempPath = downloadDir.path;
    // var fileName = _localCacheList[track.id];
    // if (fileName == null || fileName.isEmpty) return '';
    // if (is_windows) return '$tempPath\\$fileName';
    // return '$tempPath/$fileName';
    String fileName = '${track.title}-${track.artist}.m4a'
        .replaceAll('/', '-')
        .replaceAll('\\', '-')
        .replaceAll(':', '-')
        .replaceAll('?', '-')
        .replaceAll('*', '-')
        .replaceAll('"', '-')
        .replaceAll('<', '-')
        .replaceAll('>', '-')
        .replaceAll('|', '-');
    var res = p.join((await xuanGetdownloadDirectory()).path, fileName);
    return res;
  }

  Future<bool> isSoCalledDownloaded(String id) async {
    if (_localCacheList.containsKey(id)) {
      var downLoad = await xuanGetdownloadDirectory();

      final downLoadPath = downLoad.path;
      final filePath = p.join(downLoadPath, _localCacheList[id]!);
      if (!await File(filePath).exists()) {
        return false;
      }
      if (isWindows||isMacOS) {
        try {
          Metadata metadata = await MetadataGod.readMetadata(file: filePath);
          if (metadata.albumArtist == id) return true; // 如果专辑艺术家与ID相同，返回true
          throw Exception('Metadata albumArtist does not match ID');
        } catch (e) {
          _logger.e('读取元数据失败: $e');
        }
      } else if (isAndroid) {
        try {
          Tag? t = await tagger.getAllTags(filePath);
          if (t?.composer == id) return true; // 如果作曲家与ID相同，返回true
          throw Exception('Metadata composer does not match ID');
        } catch (e) {
          _logger.e('读取元数据失败: $e');
        }
      } else {
        // TODO: For other platforms, assume true for now
        return true;
      }
    }
    return false;
  }

  Future<void> saveMetadataToCache(String id, String filePath) async {
    if (saveMetadataToCacheWorkingIds.contains(id)) return;
    saveMetadataToCacheWorkingIds.add(id);
    if (isWindows) {
      if (_firstCheck) {
        _firstCheck = false;
        await isFFmpegOk();
      }
      if (isFFmpegOkWithoutCheck) {
        Track? track = Get.find<PlayController>().getTrackById(id);
        if (track == null) return;
        try {
          String outPath = await getDownloadNamedPath(track);
          if (!{'.m4s', '.flv'}.any((ext) => filePath.endsWith(ext))) {
            outPath =
                outPath.replaceAll('.m4a', '') + '.' + filePath.split('.').last;
          }

          // 尝试使用FFmpeg转换格式
          // ffmpeg -i .\138077118_u2-1-30280.m4s -vn -acodec copy output.m4a
          var result = await Process.run(ffmpegPathWindows, [
            '-i',
            filePath,
            '-vn',
            '-acodec',
            'copy',
            outPath,
          ], runInShell: true);

          if (result.exitCode == 0) {
            if (basename(filePath) != basename(outPath)) {
              _toDelFiles.add(filePath);
            }
            _localCacheList[id] = outPath.split('/').last.split('\\').last;
            File? cover = await getCachedImageFile(track.img_url ?? '');
            String? mimeType = cover != null
                ? lookupMimeType(cover.path)
                : null;
            bool needToDel = false;
            if (mimeType == null) {
              try {
                await Dio().download(track.img_url ?? '', '$outPath.cover');
                cover = File('$outPath.cover');
                mimeType = lookupMimeType(
                  cover.path,
                  headerBytes: cover.readAsBytesSync(),
                );
                needToDel = true;
              } catch (e) {
                debugPrint('下载封面失败: $e');
              }
            }
            if (isWindows) {
              Metadata toSaveMetadata = mimeType != null
                  ? Metadata(
                      title: track.title,
                      artist: track.artist,
                      album: track.album,
                      albumArtist: id,
                      picture: Picture(
                        data: await cover!.readAsBytes(),
                        mimeType: mimeType,
                      ),
                    )
                  : Metadata(
                      title: track.title,
                      artist: track.artist,
                      album: track.album,
                      albumArtist: id,
                    );
              if (needToDel) {
                try {
                  cover!.deleteSync();
                } catch (e) {
                  debugPrint('删除临时封面失败: $e');
                }
              }
              await MetadataGod.writeMetadata(
                metadata: toSaveMetadata,
                file: outPath,
              );
            } else if (isAndroid) {
              Tag toSaveTag = mimeType != null
                  ? Tag(
                      title: track.title,
                      artist: track.artist,
                      album: track.album,
                      composer: id,
                      artwork: await cover!.readAsBytes(),
                    )
                  : Tag(
                      title: track.title,
                      artist: track.artist,
                      album: track.album,
                      composer: id,
                    );
              if (needToDel) {
                try {
                  cover!.deleteSync();
                } catch (e) {
                  debugPrint('删除临时封面失败: $e');
                }
              }
              await tagger.editTags(toSaveTag, outPath);
              await File(outPath).delete();
              // mv /storage/emulated/0/Download/song_edited.mp3 to /storage/music/song.mp3
              String tdir =
                  '${outPath.substring(0, outPath.lastIndexOf('.'))}_edited.${outPath.split('.').last}';
              await File(tdir).rename(outPath);
            } else {
              // TODO: Other platforms
            }
          }
        } catch (e) {
          debugPrint('FFmpeg提取元数据失败: $e');
        }
      }
    } else if (isAndroid) {
      // Android
      Track? track = Get.find<PlayController>().getTrackById(id);
      if (track == null) return;
      String outPath = '';
      try {
        outPath = await getDownloadNamedPath(track);
        if (!{'.m4s', '.flv'}.any((ext) => filePath.endsWith(ext))) {
          outPath =
              outPath.replaceAll('.m4a', '') + '.' + filePath.split('.').last;
        }
        // 尝试使用FFmpeg转换格式
        // ffmpeg -i .\138077118_u2-1-30280.m4s -vn -acodec copy output.m4a
        var returnCode;
        var session = await FFmpegKit.execute(
          '-y -i \"$filePath\" -vn -acodec copy \"$outPath\"',
        );
        returnCode = await session.getReturnCode();
        debugPrint('FFmpeg执行结果: ${await session.getOutput()}');
        if (ReturnCode.isSuccess(returnCode)) {
          if (basename(filePath) != basename(outPath)) {
            _toDelFiles.add(filePath);
          }
          _localCacheList[id] = outPath.split('/').last.split('\\').last;
          File? cover = await getCachedImageFile(track.img_url ?? '');
          String? mimeType = cover != null ? lookupMimeType(cover.path) : null;
          bool needToDel = false;
          if (mimeType == null) {
            try {
              await Dio().download(track.img_url ?? '', '$outPath.cover');
              cover = File('$outPath.cover');
              mimeType = lookupMimeType(
                cover.path,
                headerBytes: cover.readAsBytesSync(),
              );
              needToDel = true;
            } catch (e) {
              debugPrint('下载封面失败: $e');
            }
          }

          Tag toSaveTag = mimeType != null
              ? Tag(
                  title: track.title,
                  artist: track.artist,
                  album: track.album,
                  composer: id,
                  artwork: await cover!.readAsBytes(),
                )
              : Tag(
                  title: track.title,
                  artist: track.artist,
                  album: track.album,
                  composer: id,
                );
          if (needToDel) {
            try {
              cover!.deleteSync();
            } catch (e) {
              debugPrint('删除临时封面失败: $e');
            }
          }
          await tagger.editTags(toSaveTag, outPath);
          // await File(outPath).delete();
          // mv /storage/emulated/0/Download/song_edited.mp3 to /storage/music/song.mp3
          String tdir =
              '${outPath.substring(0, outPath.lastIndexOf('.'))}_edited.${outPath.split('.').last}';
          tdir = '/storage/emulated/0/Download/${tdir.split('/').last}';
          await File(tdir).rename(outPath);
          if (File(tdir).existsSync()) {
            try {
              File(tdir).deleteSync();
            } catch (e) {
              debugPrint('删除临时文件失败: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('FFmpeg提取元数据失败: $e');
        String tdir =
            '${outPath.substring(0, outPath.lastIndexOf('.'))}_edited.${outPath.split('.').last}';
        tdir = '/storage/emulated/0/Download/${tdir.split('/').last}';
        if (File(tdir).existsSync()) {
          try {
            File(tdir).deleteSync();
          } catch (e) {
            debugPrint('删除临时文件失败: $e');
          }
        }
      }
    } else {
      // TODO: Other platforms
      return;
    }
    saveMetadataToCacheWorkingIds.remove(id);
  }

  /// 设置本地缓存文件路径
  void setLocalCache(String id, String fileName) async {
    _localCacheList[id] = fileName;
  }

  /// 清理本地缓存
  Future<void> cleanLocalCache([bool all = false, String id = '']) async {
    if (id.isNotEmpty) {
      await _cleanSingleCache(id);
      return;
    }

    if (all) {
      await _cleanAllCache();
    } else {
      await _cleanUnusedCache();
    }
  }

  /// 清理单个缓存文件
  Future<void> _cleanSingleCache(String id) async {
    final path = await getLocalCache(id);
    if (path.isNotEmpty) {
      try {
        await File(path).delete();
        _localCacheList.remove(id);
        showInfoSnackbar('已清理', null);
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
