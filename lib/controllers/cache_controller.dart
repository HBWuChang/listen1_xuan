import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import '../global_settings_animations.dart';
import 'settings_controller.dart';

class CacheController extends GetxController {
  final String _localCacheListKey = 'local-cache-list';
  final _localCacheList = <String, String>{}.obs;
  @override
  void onInit() {
    super.onInit();
    debounce(_localCacheList, (value) {
      _saveLocalCacheList();
    }, time: Duration(seconds: 3));
  }

  /// 加载本地缓存列表
  void loadLocalCacheList() {
    _localCacheList.value =
        Get.find<SettingsController>().CacheController_localCacheList;
  }

  /// 保存本地缓存列表
  Future<void> _saveLocalCacheList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localCacheListKey,
        jsonEncode(Map<String, String>.from(_localCacheList)));
  }

  /// 获取本地缓存文件路径
  Future<String> getLocalCache(String id) async {
    // final prefs = await SharedPreferences.getInstance();
    // final localCacheListJson = prefs.getString(_localCacheListKey);
    // if (localCacheListJson != null) {
    //   final localCacheList = jsonDecode(localCacheListJson);
    //   if (localCacheList[id] != null) {
    //     var tempDir = await xuan_getdataDirectory();

    //     final tempPath = tempDir.path;
    //     var filePath = '$tempPath/${localCacheList[id]}';
    //     if (is_windows) filePath = '$tempPath\\${localCacheList[id]}';
    //     if (await File(filePath).exists()) return filePath;
    //   }
    // }
    // return '';
    if (_localCacheList.containsKey(id)) {
      var tempDir = await xuan_getdataDirectory();

      final tempPath = tempDir.path;
      var filePath = '$tempPath/${_localCacheList[id]}';
      if (is_windows) filePath = '$tempPath\\${_localCacheList[id]}';
      if (await File(filePath).exists()) return filePath;
    }
    return '';
  }

  /// 设置本地缓存文件路径
  void setLocalCache(String id, String path) async {
    // final prefs = await SharedPreferences.getInstance();
    // final localCacheListJson = prefs.getString(_localCacheListKey);
    // if (localCacheListJson != null) {
    //   final localCacheList = jsonDecode(localCacheListJson);
    //   localCacheList[id] = path;
    //   await prefs.setString('local-cache-list', jsonEncode(localCacheList));
    // } else {
    //   final localCacheList = {};
    //   localCacheList[id] = path;
    //   await prefs.setString('local-cache-list', jsonEncode(localCacheList));
    // }
    _localCacheList[id] = path;
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
        xuan_toast(msg: '已清理');
      } catch (e) {
        xuan_toast(msg: '清理失败: $e');
      }
    } else {
      xuan_toast(msg: '没有可清理的缓存文件');
    }
  }

  /// 清理所有缓存
  Future<void> _cleanAllCache() async {
    final tempDir = await xuan_getdataDirectory();
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
    final tempDir = await xuan_getdataDirectory();
    final files = await _getCacheFiles(tempDir.path);

    int count = 0;
    final cacheFileNames = _localCacheList.values.toSet();

    for (final file in files) {
      final fileName = file.split(is_windows ? "\\" : '/').last;

      // 如果文件不在缓存列表中，则删除
      if (!cacheFileNames.contains(fileName)) {
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
    final List<String> jumpList = ['.json', '.apk', '.zip', '.log'];
    final List<String> files = [];

    try {
      final filesAndDirs = Directory(tempPath).listSync();

      for (final fileSystemEntity in filesAndDirs) {
        if (fileSystemEntity is File) {
          final fileName =
              fileSystemEntity.path.split(is_windows ? "\\" : '/').last;

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
    final tempDir = await xuan_getdataDirectory();
    final tempPath = tempDir.path;
    final List<String> keysToRemove = [];

    for (final entry in _localCacheList.entries) {
      final filePath =
          is_windows ? '$tempPath\\${entry.value}' : '$tempPath/${entry.value}';

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
      xuan_toast(msg: '清理了$count个缓存文件');
    } else {
      xuan_toast(msg: '没有可清理的缓存文件');
    }
  }

  /// 获取缓存大小（可选功能）
  Future<int> getCacheSize() async {
    final tempDir = await xuan_getdataDirectory();
    final tempPath = tempDir.path;

    final filesanddirs = Directory(tempPath).listSync();
    int totalSize = 0;
    List<String> jumpList = ['.json', '.apk', '.zip', '.log'];
    List<String> without = ['app.log'];

    for (var file in filesanddirs) {
      if (file is File &&
          !without.contains(file.path.split(is_windows ? "\\" : '/').last)) {
        bool jumpFlag = false;
        for (var jump in jumpList) {
          if (file.path.split(is_windows ? "\\" : '/').last.endsWith(jump)) {
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
