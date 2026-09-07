import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:async/async.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/bl.dart';
import 'package:listen1_xuan/constants/const.dart';
import 'package:listen1_xuan/controllers/controllers.dart';
import 'package:listen1_xuan/kugou.dart';
import 'package:listen1_xuan/myplaylist.dart';
import 'package:listen1_xuan/qq.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'base.dart';
import 'netease.dart';
import 'package:listen1_xuan/models/Track.dart';

final List<BaseProvider> providers = [];

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

dynamic queryPlaylist(String listId, String type) {
  final result = myplaylist.myPlaylistContainers(type, listId);
  return result;
}

dynamic removeMyPlaylist(String id, String type) {
  return myplaylist.removeMyPlaylist(type, id);
}

dynamic addMyPlaylist(String id, dynamic track) {
  return myplaylist.addTrackToMyPlaylist(id, track);
}

dynamic insertTrackToMyPlaylist(
  String id,
  dynamic track,
  dynamic toTrack,
  String direction,
) {
  return myplaylist.insertTrackToMyPlaylist(id, track, toTrack, direction);
}

Future<dynamic> addPlaylist(String id, List<dynamic> tracks) {
  final provider = getProviderByItemId(id);
  return provider.addPlaylist(id, tracks);
}

dynamic removeTrackFromMyPlaylist(String id, dynamic track) {
  return myplaylist.removeTrackFromMyPlaylist(id, track);
}

Future<dynamic> removeTrackFromPlaylist(String id, dynamic track) {
  final provider = getProviderByItemId(id);
  return provider.removeFromPlaylist(id, track);
}

dynamic editMyPlaylist(String id, String title, String coverImgUrl) {
  return myplaylist.editMyPlaylist(id, title, coverImgUrl);
}

// static Future<Map< parseURL(String url) {
Future<Map<String, dynamic>> parseUrl(String url) {
  // return {
  //   'success': (Function fn) {
  //     final providers = getAllProviders();
  //     Future.wait(providers.map((provider) {
  //       return provider.parseUrl(url).then((r) {
  //         if (r != null) {
  //           throw r;
  //         }
  //       });
  //     })).then((_) {
  //       fn({});
  //     }).catchError((result) {
  //       fn({'result': result});
  //     });
  //   },
  // };
  final providers = getAllProviders();
  for (var provider in providers) {
    final result = provider.parseUrl(url);
    if (result != null) {
      return result;
    }
  }
  return Future.value(<String, dynamic>{});
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
  final SettingsController settingsController = Get.find<SettingsController>();
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
void bootstrapTrack(Track track, {bool start = true}) {
  Track? sTrack;
  successCallback(dynamic res, Track track) {
    _playController.bootstrapTrackSuccess(
      res,
      track,
      start: start,
      sTrack: sTrack,
    );
  }

  Track? repTrack = _playController.songReplaceSettings.value.getReplacedTrack(
    track.id,
  );
  if (repTrack != null) {
    sTrack = track;
    track = repTrack;
  }
  final provider = getProviderByName(track.source!);
  if (provider == null) {
    _playController.bootstrapTrackFail(track, start: start);
    return;
  }
  provider.bootstrap_track(
    track,
    successCallback,
    (track) =>
        _playController.bootstrapTrackFail(sTrack ?? track, start: start),
  );
}

Future<dynamic> login(String source, Map<String, dynamic> options) {
  final url = '/login?${queryStringify(options)}';
  final provider = getProviderByName(source);
  return provider.login(url);
}

Future<dynamic> getUser(String source) {
  final provider = getProviderByName(source);
  return provider.get_user();
}

Future<dynamic> getLoginUrl(String source) {
  final provider = getProviderByName(source);
  return provider.getLoginUrl();
}

Future<dynamic> getUserCreatedPlaylist(
  String source,
  Map<String, dynamic> options,
) {
  final provider = getProviderByName(source);
  final url = '/get_user_create_playlist?${queryStringify(options)}';
  return provider.getUserCreatedPlaylist(url);
}

Future<dynamic> getUserFavoritePlaylist(
  String source,
  Map<String, dynamic> options,
) {
  final provider = getProviderByName(source);
  final url = '/get_user_favorite_playlist?${queryStringify(options)}';
  return provider.getUserFavoritePlaylist(url);
}

Future<dynamic> getRecommendPlaylist(String source) {
  final provider = getProviderByName(source);
  return provider.getRecommendPlaylist();
}

Future<dynamic> logout(String source) {
  final provider = getProviderByName(source);
  return provider.logout();
}

final loWeb = MediaService();
