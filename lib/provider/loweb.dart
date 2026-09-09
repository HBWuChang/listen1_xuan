import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/controllers.dart';
import 'package:listen1_xuan/models/Playlist.dart';
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

  List<BaseProvider> getAllProviders() {
    return providers.where((i) => i.hidden != true).toList();
  }

  List<BaseProvider> getAllSearchProviders() {
    return providers.where((i) => i.searchable).toList();
  }

  String getProviderNameByItemId(String id) {
    String prefix = id.substring(0, 2);
    return providers.firstWhere((i) => i.id == prefix).name;
  }

  BaseProvider getProviderByItemId(String id) {
    if (id.length < 2) {
      throw Exception('Invalid id: $id');
    }
    String prefix = id.substring(0, 2);
    return providers.firstWhere((i) => i.id == prefix);
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

  PlayController get _playController => Get.find<PlayController>();
}
