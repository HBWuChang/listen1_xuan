import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/controllers.dart';
import 'package:listen1_xuan/models/Playlist.dart';
import 'package:listen1_xuan/models/Track.dart';
import 'package:listen1_xuan/models/bootStrapTrackRes.dart';
import 'base.dart';
import 'netease.dart';
import 'myplaylist.dart';

Provider provider = Get.find<Provider>();
List<BaseProvider> get providers => Get.find<Provider>().getAllProviders();
List<BaseProvider> get supportShowPlaylistProviders => Get.find<Provider>()
    .getAllProviders()
    .where((p) => p.supportShowPlaylist)
    .toList();

class Provider extends GetxService {
  final List<BaseProvider> providers = [];
  @override
  void onInit() {
    super.onInit();
    // providers.addAll([Netease(), MyPlaylist()]);
    providers.addAll([Get.put(Netease()), Get.put(MyPlaylist())]);
  }

  int get indexOfFirstOnH {
    return supportShowPlaylistProviders.indexWhere((i) => i.isFirstOnH);
  }

  int get indexOfFirstOnV {
    return supportShowPlaylistProviders.indexWhere((i) => i.isFirstOnV);
  }

  MyPlaylist get myplaylist =>
      providers.firstWhere((i) => i.id == 'my') as MyPlaylist;

  BaseProvider getProviderByName(String name) {
    return providers.firstWhere((i) => i.name == name);
  }

  /// 与 [getProviderByName] 类似，但找不到时返回 null 而不是抛异常。
  BaseProvider? tryGetProviderByName(String name) {
    for (final provider in providers) {
      if (provider.name == name) return provider;
    }
    return null;
  }

  List<BaseProvider> getAllProviders() {
    return providers.where((i) => i.hidden != true).toList();
  }

  List<BaseProvider> getAllSearchProviders() {
    return providers.where((i) => i.searchable).toList();
  }

  String getProviderNameByItemId(String id) {
    if (id.length < 2) {
      throw Exception('Invalid id: $id');
    }
    final prefix = id.substring(0, 2);
    return providers.firstWhere((i) => i.id == prefix).name;
  }

  BaseProvider getProviderByItemId(String id) {
    return getProviderByName(getProviderNameByItemId(id));
  }

  // function queryStringify(options) {
  //   const query = JSON.parse(JSON.stringify(options));
  //   return new URLSearchParams(query).toString();
  // }
  String queryStringify(Map<String, dynamic> options) {
    // 移除值为 null 的键值对
    options.removeWhere((key, value) => value == null);
    debugPrint('options: $options');
    // 使用 Uri 来生成查询字符串
    // return Uri(queryParameters: options).query;
    return options.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  List<BaseProvider> getLoginProviders() {
    return providers.where((i) => i.hidden != true && i.supportLogin).toList();
  }

  void removeMyPlaylist(String id, String type) {
    return myplaylist.removeMyPlaylist(type, id);
  }

  PlayList? addMyPlaylist(String id, dynamic track) {
    return myplaylist.addTrackToMyPlaylist(id, track);
  }

  PlayList? insertTrackToMyPlaylist(
    String id,
    dynamic track,
    dynamic toTrack,
    String direction,
  ) {
    return myplaylist.insertTrackToMyPlaylist(id, track, toTrack, direction);
  }

  dynamic removeTrackFromMyPlaylist(String id, dynamic track) {
    return myplaylist.removeTrackFromMyPlaylist(id, track);
  }

  dynamic editMyPlaylist(String id, String title, String coverImgUrl) {
    return myplaylist.editMyPlaylist(id, title, coverImgUrl);
  }

  Future<dynamic> mergePlaylist(String source, String target) async {
    // final tarData = localStorage.getObject(target)['tracks'];
    // final srcData = localStorage.getObject(source)['tracks'];
    // for (var tarTrack in tarData) {
    //   if (!srcData.any((srcTrack) => srcTrack['id'] == tarTrack['id'])) {
    //     myplaylist.addTrackToMyPlaylist(source, tarTrack);
    //   }
    // }
    // return {
    //   'success': (Function fn) => fn(),
    // };
    // shared_preferences
    final SettingsController settingsController =
        Get.find<SettingsController>();
    final tarData = jsonDecode(
      (await settingsController.getString(target))!,
    )['tracks'];
    final srcData = jsonDecode(
      (await settingsController.getString(source))!,
    )['tracks'];
    for (var tarTrack in tarData) {
      if (!srcData.any((srcTrack) => srcTrack['id'] == tarTrack['id'])) {
        myplaylist.addTrackToMyPlaylist(source, tarTrack);
      }
    }
  }

  /// 引导播放：处理歌曲替换、选择对应 provider 并回调解缓存/失败逻辑。
  void bootstrapTrack(Track track, {bool start = true}) {
    Track? sTrack;

    void successCallback(BootSuccessRes res, Track track) {
      _playController.bootstrapTrackSuccess(
        res,
        track,
        start: start,
        sTrack: sTrack,
      );
    }

    final repTrack = _playController.songReplaceSettings.value
        .getReplacedTrack(track.id);
    if (repTrack != null) {
      sTrack = track;
      track = repTrack;
    }
    // 优先根据 track.id 的前缀定位 provider，失败时再回退到 track.source。
    BaseProvider? targetProvider;
    try {
      targetProvider = tryGetProviderByName(getProviderNameByItemId(track.id));
    } catch (_) {
      targetProvider = null;
    }
    targetProvider ??= tryGetProviderByName(track.source ?? '');
    if (targetProvider == null) {
      _playController.bootstrapTrackFail(track, start: start);
      return;
    }
    targetProvider.bootStrapTrack(
      track,
      successCallback,
      (track) =>
          _playController.bootstrapTrackFail(sTrack ?? track, start: start),
    );
  }

  PlayController get _playController => Get.find<PlayController>();
}
