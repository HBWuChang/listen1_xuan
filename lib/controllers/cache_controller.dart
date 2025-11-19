import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/funcs.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import '../global_settings_animations.dart';
import '../main.dart';
import 'myPlaylist_controller.dart';
import 'play_controller.dart';
import 'settings_controller.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class CacheController extends GetxController {
  final Logger _logger = Logger();
  final String _localCacheListKey = 'local-cache-list';
  final _localCacheList = <String, String>{}.obs;
  final _toDelFiles = <String>{}.obs;
  SettingsController _settingsController = Get.find<SettingsController>();
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
        files.add(basename(element.path));
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localCacheListKey,
      jsonEncode(Map<String, String>.from(_localCacheList)),
    );
  }

  Future<void> downloadAndCacheFile(dynamic res, Track track) async {
    final downDir = await xuanGetdownloadDirectory();
    String downPath = downDir.path;
    String fileName = getDownloadNamed(track, res['url']);
    final filePath = p.join(downPath, fileName);
    _playController.bootStraping[track.id] = fileName;
    switch (res["platform"]) {
      case "bilibili":
        final dio = dioWithCookieManager;
        await dio.download(
          res['url'],
          filePath,
          options: Options(
            headers: {
              "user-agent":
                  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36",
              "accept": "*/*",
              "accept-encoding": "identity;q=1, *;q=0",
              "accept-language": "zh-CN",
              "referer": "https://www.bilibili.com/",
              "sec-fetch-dest": "audio",
              "sec-fetch-mode": "no-cors",
              "sec-fetch-site": "cross-site",
              "range": "bytes=0-",
            },
          ),
        );
      case "netease":
        final dio = dioWithCookieManager;
        await dio.download(res['url'], filePath);
      default:
        await dioWithCookieManager.download(res['url'], filePath);
    }
    setLocalCache(track.id, fileName);
  }

  String getDownloadNamed(Track track, String url) {
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
    fileName = fileName
        .replaceAll('/', unUseableRep)
        .replaceAll('\\', unUseableRep)
        .replaceAll(':', unUseableRep)
        .replaceAll('?', unUseableRep)
        .replaceAll('*', unUseableRep)
        .replaceAll('"', unUseableRep)
        .replaceAll('<', unUseableRep)
        .replaceAll('>', unUseableRep)
        .replaceAll('|', unUseableRep);
    String ext = extension(Uri.parse(url).pathSegments.last);
    // 处理重名
    Set<String> existingFileNames = _localCacheList.values.toSet().union(
      Get.find<PlayController>().bootStraping.values.toSet(),
    );
    if (dedupMethod == DedupMethod.number.index) {
      int count = 1;
      String baseFileName = fileName;
      while (existingFileNames.contains(fileName + ext)) {
        fileName = '$baseFileName($count)';
        count++;
      }
      // } else if (dedupMethod == DedupMethod.strs.index) {
    } else {
      String randomStr = Uuid().v4().substring(0, 6);
      String baseFileName = fileName;
      while (existingFileNames.contains(fileName + ext)) {
        fileName = '$baseFileName$namedConnection$randomStr';
        randomStr = Uuid().v4().substring(0, 6);
      }
    }
    fileName += ext;
    return fileName;
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
        return filePath;
      }
    }
    return '';
  }

  // 设置本地缓存文件路径
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
