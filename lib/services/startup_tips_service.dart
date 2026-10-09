import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StartupTipsService {
  static const defaultSearchHint = '请输入歌曲名，歌手或专辑';
  static const assetPath = 'assets/help/startup_tips.md';
  static const remoteUrl =
      'https://raw.githubusercontent.com/HBWuChang/listen1_xuan/main/assets/help/startup_tips.md';
  static const _cacheName = 'startup_tips.md';
  static const _lastSuccessKey = 'startup_tips_last_success';
  static const _refreshInterval = Duration(hours: 24);

  StartupTipsService({
    Future<Directory> Function()? supportDirectory,
    Future<String> Function()? bundledContent,
    DateTime Function()? now,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _bundledContent = bundledContent ?? (() => rootBundle.loadString(assetPath)),
       _now = now ?? DateTime.now;

  final Future<Directory> Function() _supportDirectory;
  final Future<String> Function() _bundledContent;
  final DateTime Function() _now;
  final ValueNotifier<List<String>> tips = ValueNotifier<List<String>>([]);
  final ValueNotifier<String?> searchHint = ValueNotifier<String?>(null);
  Future<void>? _loading;
  Future<void>? _refreshing;

  static List<String> parseTips(String content) {
    if (content.length > 65536) {
      throw const FormatException('技巧文件过大');
    }
    final result = <String>[];
    for (final line in content.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || RegExp(r'^#{1,6} ').hasMatch(trimmed)) {
        continue;
      }
      if (!trimmed.startsWith('- ')) {
        throw const FormatException('技巧文件包含无效行');
      }
      final tip = trimmed.substring(2).trim();
      if (tip.isEmpty || tip.contains(RegExp(r'[\x00-\x1f]'))) {
        throw const FormatException('技巧内容无效');
      }
      result.add(tip);
    }
    if (result.isEmpty) {
      throw const FormatException('技巧文件没有有效内容');
    }
    return List.unmodifiable(result);
  }

  Future<File> _cacheFile() async {
    final directory = await _supportDirectory();
    return File(p.join(directory.path, _cacheName));
  }

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final cache = await _cacheFile();
      if (await cache.exists()) {
        try {
          tips.value = parseTips(await cache.readAsString());
          return;
        } catch (error) {
          debugPrint('已缓存的使用技巧无效: $error');
        }
      }
      final backup = File('${cache.path}.bak');
      if (await backup.exists()) {
        try {
          tips.value = parseTips(await backup.readAsString());
          return;
        } catch (error) {
          debugPrint('使用技巧备份无效: $error');
        }
      }
    } catch (error) {
      debugPrint('读取使用技巧缓存失败: $error');
    }
    try {
      tips.value = parseTips(await _bundledContent());
    } catch (error) {
      debugPrint('读取内置使用技巧失败: $error');
    }
  }

  String? randomTip() {
    final currentTips = tips.value;
    if (currentTips.isEmpty) return null;
    return currentTips[Random().nextInt(currentTips.length)];
  }

  void updateSearchHint() {
    searchHint.value = randomTip();
  }

  String searchHintText({required bool showTips, String? tip}) =>
      showTips ? tip ?? defaultSearchHint : defaultSearchHint;

  Future<void> refreshIfDue(Dio dio) =>
      _refreshing ??= _refreshIfDue(dio).whenComplete(() {
        _refreshing = null;
      });

  Future<void> _refreshIfDue(Dio dio) async {
    await load();
    try {
      final preferences = await SharedPreferences.getInstance();
      final lastSuccess = preferences.getInt(_lastSuccessKey);
      if (lastSuccess != null) {
        final elapsed = _now().difference(
          DateTime.fromMillisecondsSinceEpoch(lastSuccess),
        );
        if (!elapsed.isNegative && elapsed < _refreshInterval) return;
      }
      final response = await dio.get<String>(
        remoteUrl,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final content = response.data;
      if (content == null) throw const FormatException('技巧文件为空');
      final parsed = parseTips(content);
      final cache = await _cacheFile();
      final temporary = File('${cache.path}.tmp');
      final backup = File('${cache.path}.bak');
      await temporary.writeAsString(content, flush: true);
      if (await cache.exists()) {
        var validCache = false;
        try {
          parseTips(await cache.readAsString());
          validCache = true;
        } catch (_) {}
        if (validCache) {
          if (await backup.exists()) await backup.delete();
          await cache.rename(backup.path);
        } else {
          await cache.delete();
        }
      }
      try {
        await temporary.rename(cache.path);
      } catch (_) {
        if (await backup.exists() && !await cache.exists()) {
          await backup.rename(cache.path);
        }
        rethrow;
      }
      try {
        if (await backup.exists()) await backup.delete();
      } catch (error) {
        debugPrint('清理使用技巧备份失败: $error');
      }
      tips.value = parsed;
      await preferences.setInt(
        _lastSuccessKey,
        _now().millisecondsSinceEpoch,
      );
    } catch (error) {
      debugPrint('更新使用技巧失败: $error');
    }
  }
}

final startupTipsService = StartupTipsService();
