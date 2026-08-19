import 'dart:io';

import 'package:listen1_xuan/controllers/cache_controller.dart';
import 'package:listen1_xuan/controllers/play_controller.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:listen1_xuan/services/cache_audio_metadata.dart';
import 'package:logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/websocket_client_controller.dart';
import 'package:path/path.dart';
import '../global_settings_animations.dart';
import 'settings_controller.dart';

class WsDownloadController extends GetxController {
  final Logger _logger = Logger();

  static const String _settingsKeyPrefix = 'DownloadController_';
  final toDownloadList = <String, String>{}.obs;
  String get toDownloadListKey => '${_settingsKeyPrefix}toDownloadList';
  final downloadingList = <String, String>{}.obs;
  String get downloadingListKey => '${_settingsKeyPrefix}downloadingList';
  final downloadedList = <String, String>{}.obs;
  String get downloadedListKey => '${_settingsKeyPrefix}downloadedList';
  final failedList = <String, String>{}.obs;
  String get failedListKey => '${_settingsKeyPrefix}failedList';
  final maxDownloads = 0.obs;
  String get maxDownloadsKey => '${_settingsKeyPrefix}maxDownloads';
  final downloadProcess = <String, dynamic>{}.obs;

  // UI 状态管理
  final isLoading = false.obs;
  final panelExpanded = [false, false, false, false].obs;

  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  Future<void> _download(String key) async {
    _logger.d('Try download for $key');
    if (downloadingList.containsKey(key)) return;
    if (!toDownloadList.containsKey(key)) return;
    _logger.d('Starting download for $key');
    MapEntry<String, String> entry = MapEntry(key, toDownloadList[key]!);
    File? partialFile;
    void onFail(e) {
      _logger.e('Download failed for $key', error: e);
      failedList[key] = entry.value;
      toDownloadList.remove(key);
      downloadingList.remove(key);
      downloadProcess.remove(key);
    }

    try {
      downloadingList[key] = toDownloadList[key]!;
      toDownloadList.remove(key);
      final cacheDirectory = await xuanGetdataDirectory();
      String filePath = join(cacheDirectory.path, entry.value);
      partialFile = File(CacheAudioMetadata.temporaryDownloadPath(filePath));
      if (await partialFile.exists()) await partialFile.delete();
      String serverAddress =
          Get.find<WebSocketClientController>().serverAddress;
      Uri uri = Uri(
        scheme: 'http',
        host: serverAddress.split(':')[0],
        port: int.parse(serverAddress.split(':')[1]),
        path: '/downloadById/${entry.key}',
      );

      await Dio().download(
        uri.toString(),
        partialFile.path,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            downloadProcess[key] = [received, total];
          }
        },
      );

      Track? track;
      for (final candidate in Get.find<PlayController>().current_playing) {
        if (candidate.id == entry.key) {
          track = candidate;
          break;
        }
      }
      final cacheController = Get.find<CacheController>();
      await cacheController.finalizeCacheFile(
        inputPath: partialFile.path,
        outputPath: filePath,
        track: track,
      );
      cacheController.setLocalCache(entry.key, entry.value);
      downloadedList[key] = entry.value;
      downloadingList.remove(key);
      downloadProcess.remove(key);
    } catch (e) {
      onFail(e);
    } finally {
      if (partialFile != null && await partialFile.exists()) {
        await partialFile.delete();
      }
    }
  }

  void checkAndStartDownloads() {
    if (toDownloadList.isEmpty) return;
    if (downloadingList.length >= maxDownloads.value) return;
    _download(toDownloadList.keys.first);
  }

  void loadSettings() async {
    final settings = Get.find<SettingsController>().settings;
    toDownloadList.value = Map<String, String>.from(
      settings[toDownloadListKey] ?? {},
    );
    downloadingList.value = Map<String, String>.from(
      settings[downloadingListKey] ?? {},
    );
    downloadedList.value = Map<String, String>.from(
      settings[downloadedListKey] ?? {},
    );
    failedList.value = Map<String, String>.from(settings[failedListKey] ?? {});
    everAll([toDownloadList, downloadingList, maxDownloads], (_) {
      checkAndStartDownloads();
    });
    everAll(
      [
        toDownloadList,
        downloadingList,
        downloadedList,
        failedList,
        maxDownloads,
      ],
      (_) {
        saveSettings();
      },
    );
    maxDownloads.value = settings[maxDownloadsKey] ?? 3;
  }

  void saveSettings() {
    final settings = Get.find<SettingsController>();
    settings.setSetting(toDownloadListKey, toDownloadList);
    settings.setSetting(downloadingListKey, downloadingList);
    settings.setSetting(downloadedListKey, downloadedList);
    settings.setSetting(failedListKey, failedList);
    settings.setSetting(maxDownloadsKey, maxDownloads.value);
  }

  Future<void> checkLocal(String key, String value) async {
    String localPath = await Get.find<CacheController>().getLocalCache(key);
    if (localPath.isEmpty) {
      downloadedList.remove(key);
      toDownloadList[key] = value;
    }
  }

  Future<void> addToDownloadList(
    Map<String, String> newItems, {
    Map<String, String> localFiles = const {},
  }) async {
    newItems.removeWhere((key, value) => localFiles.containsKey(key));
    Map<String, String> toAdd = {};
    newItems.forEach((key, value) {
      if (toDownloadList.containsKey(key) || downloadingList.containsKey(key)) {
        return;
      }
      // netrack_2612360323
      if (downloadedList.containsKey(key)) {
        downloadedList.remove(key);
      }
      if (failedList.containsKey(key)) {
        failedList.remove(key);
      }
      toAdd[key] = value;
    });
    toDownloadList.addAll(toAdd);
  }

  /// 切换面板展开状态
  void togglePanelExpansion(int index) {
    panelExpanded[index] = !panelExpanded[index];
  }
}
