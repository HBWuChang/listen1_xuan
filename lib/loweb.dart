import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:async/async.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bl.dart';
import 'netease.dart';
import 'myplaylist.dart';
import 'play.dart';
import 'qq.dart';

class Provider {
  final String name;
  final dynamic instance;
  final bool searchable;
  final bool supportLogin;
  final String id;
  final bool? hidden;

  Provider({
    required this.name,
    required this.instance,
    required this.searchable,
    required this.supportLogin,
    required this.id,
    this.hidden,
  });
}

final List<Provider> providers = [
  Provider(
    name: 'netease',
    instance: netease,
    // instance: null,
    searchable: true,
    supportLogin: true,
    id: 'ne',
  ),
  Provider(
    name: 'xiami',
    // instance: xiami,
    instance: null,
    searchable: false,
    supportLogin: false,
    id: 'xm',
    hidden: true,
  ),
  Provider(
    name: 'qq',
    instance: qq,
    // instance: null,
    searchable: true,
    supportLogin: true,
    id: 'qq',
  ),
  Provider(
    name: 'kugou',
    // instance: kugou,
    instance: null,
    searchable: true,
    supportLogin: false,
    id: 'kg',
  ),
  Provider(
    name: 'kuwo',
    // instance: kuwo,
    instance: null,
    searchable: true,
    supportLogin: false,
    id: 'kw',
  ),
  Provider(
    name: 'bilibili',
    instance: bilibili,
    searchable: true,
    supportLogin: false,
    id: 'bi',
  ),
  Provider(
    name: 'migu',
    // instance: migu,
    instance: null,
    searchable: true,
    supportLogin: true,
    id: 'mg',
  ),
  Provider(
    name: 'taihe',
    // instance: taihe,
    instance: null,
    searchable: true,
    supportLogin: false,
    id: 'th',
  ),
  Provider(
    name: 'localmusic',
    // instance: localmusic,
    instance: null,
    searchable: false,
    supportLogin: false,
    id: 'lm',
    hidden: true,
  ),
  Provider(
    name: 'myplaylist',
    instance: myplaylist,
    // instance: null,
    searchable: false,
    supportLogin: false,
    id: 'my',
    hidden: true,
  ),
];

dynamic getProviderByName(String sourceName) {
  return providers.firstWhere((i) => i.name == sourceName).instance;
}

List<dynamic> getAllProviders() {
  return providers
      .where((i) => i.hidden != true)
      .map((i) => i.instance)
      .toList();
}

List<dynamic> getAllSearchProviders() {
  return providers.where((i) => i.searchable).map((i) => i.instance).toList();
}

String? getProviderNameByItemId(String itemId) {
  String prefix = itemId.substring(0, 2);
  return providers.firstWhere((i) => i.id == prefix).name;
}

dynamic getProviderByItemId(String itemId) {
  String prefix = itemId.substring(0, 2);
  return providers.firstWhere((i) => i.id == prefix).instance;
}

// function queryStringify(options) {
//   const query = JSON.parse(JSON.stringify(options));
//   return new URLSearchParams(query).toString();
// }
String queryStringify(Map<String, dynamic> options) {
  // 移除值为 null 的键值对
  options.removeWhere((key, value) => value == null);
  print('options: $options');
  // 使用 Uri 来生成查询字符串
  // return Uri(queryParameters: options).query;
  return options.entries.map((e) => '${e.key}=${e.value}').join('&');
}

class MediaService {
  static List<Provider> getLoginProviders() {
    return providers.where((i) => i.hidden != true && i.supportLogin).toList();
  }

  static Future<dynamic> search(
      String source, Map<String, dynamic> options) async {
    final url = '/search?${queryStringify(options)}';
    // if (source == 'allmusic') {
    //   final callbackArray = getAllSearchProviders().map((p) {
    //     return (Function fn) {
    //       p.search(url).then((r) {
    //         fn(null, r);
    //       });
    //     };
    //   }).toList();

    //   return {
    //     'success': (Function fn) {
    //       async.parallel(callbackArray, (err, platformResultArray) {
    //         final result = {
    //           'result': [],
    //           'total': 1000,
    //           'type': platformResultArray[0]['type'],
    //         };
    //         final maxLength = platformResultArray.map((elem) => elem['result'].length).reduce((a, b) => a > b ? a : b);
    //         for (var i = 0; i < maxLength; i++) {
    //           for (var elem in platformResultArray) {
    //             if (i < elem['result'].length) {
    //               result['result'].add(elem['result'][i]);
    //             }
    //           }
    //         }
    //         fn(result);
    //       });
    //     },
    //   };
    // }
    final provider = getProviderByName(source);
    // snapshot.data()?['name'] ?? ''
    return provider.search(url);
  }

  static Future<dynamic> showMyPlaylist() {
    return myplaylist.show_myplaylist('my');
  }

  static Future<dynamic> showPlaylistArray(
      String source, int offset, dynamic filterId) {
    final provider = getProviderByName(source);
    final url = '/show_playlist?${queryStringify({
          'offset': offset,
          'filter_id': filterId
        })}';
    return provider.show_playlist(url);
  }

  static Future<dynamic> getPlaylistFilters(String source) {
    final provider = getProviderByName(source);
    return provider.get_playlist_filters();
  }

  static Future<dynamic> getLyric(
      String trackId, String albumId, String lyricUrl, String tlyricUrl) {
    final provider = getProviderByItemId(trackId);
    final url = '/lyric?${queryStringify({
          'track_id': trackId,
          'album_id': albumId,
          'lyric_url': lyricUrl,
          'tlyric_url': tlyricUrl,
        })}';
    return provider.getLyric(url);
  }

  static Future<dynamic> showFavPlaylist() {
    return myplaylist.show_myplaylist('favorite');
  }

  static Future<dynamic> queryPlaylist(String listId, String type) {
    final result = myplaylist.myPlaylistContainers(type, listId);
    return result;
  }

  static Future<dynamic> getPlaylist(String listId,
      {bool useCache = true}) async {
    final provider = getProviderByItemId(listId);
    final url = '/playlist?list_id=$listId';
    var hit;
    // if (useCache) {
    //   hit = await playlistCache.get(listId);
    // }

    // if (hit != null) {
    //   return hit;
    // }
    // return {
    //   'success': (Function fn) {
    //     provider.getPlaylist(url).then((playlist) {
    //       if (provider != myplaylist && provider != localmusic) {
    //         playlistCache.set(listId, playlist);
    //       }
    //       fn(playlist);
    //     });
    //   },
    // };
    dynamic playlist = await provider.get_playlist(url);
    print('playlist: $playlist');
    return playlist;
    // return provider.getPlaylist(url);
  }

  static Future<dynamic> clonePlaylist(String id, String type) {
    final provider = getProviderByItemId(id);
    final url = '/playlist?list_id=$id';
    // return {
    //   'success': (Function fn) {
    //     provider.getPlaylist(url).then((data) {
    //       myplaylist.saveMyPlaylist(type, data);
    //       fn();
    //     });
    //   },
    // };
    return myplaylist.saveMyPlaylist(type, provider.get_playlist(url));
  }

  static Future<dynamic> removeMyPlaylist(String id, String type) {
    return myplaylist.removeMyPlaylist(type, id);
  }

  static Future<dynamic> addMyPlaylist(String id, dynamic track) {
    return myplaylist.addTrackToMyPlaylist(id, track);
  }

  static Future<dynamic> insertTrackToMyPlaylist(
      String id, dynamic track, dynamic toTrack, String direction) {
    return myplaylist.insertTrackToMyPlaylist(id, track, toTrack, direction);
  }

  static Future<dynamic> addPlaylist(String id, List<dynamic> tracks) {
    final provider = getProviderByItemId(id);
    return provider.addPlaylist(id, tracks);
  }

  static Future<dynamic> removeTrackFromMyPlaylist(String id, dynamic track) {
    return myplaylist.removeTrackFromMyPlaylist(id, track);
  }

  static Future<dynamic> removeTrackFromPlaylist(String id, dynamic track) {
    final provider = getProviderByItemId(id);
    return provider.removeFromPlaylist(id, track);
  }

  static Future<dynamic> createMyPlaylist(String title, dynamic track) {
    return myplaylist.createMyPlaylist(title, track);
  }

  static Future<dynamic> insertMyplaylistToMyplaylists(String playlistType,
      String playlistId, String toPlaylistId, String direction) {
    return myplaylist.insertMyPlaylistToMyPlaylists(
        playlistType, playlistId, toPlaylistId, direction);
  }

  static Future<dynamic> editMyPlaylist(
      String id, String title, String coverImgUrl) {
    return myplaylist.editMyPlaylist(id, title, coverImgUrl);
  }

  // static Future<Map< parseURL(String url) {
  static Future<Map<String, dynamic>> parseUrl(String url) {
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

  static Future<dynamic> mergePlaylist(String source, String target) async {
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
    final prefs = await SharedPreferences.getInstance();
    final tarData = jsonDecode(prefs.getString(target)!)['tracks'];
    final srcData = jsonDecode(prefs.getString(source)!)['tracks'];
    for (var tarTrack in tarData) {
      if (!srcData.any((srcTrack) => srcTrack['id'] == tarTrack['id'])) {
        myplaylist.addTrackToMyPlaylist(source, tarTrack);
      }
    }
  }

  static Future<dynamic> bootstrapTrack(dynamic track,
      Function playerSuccessCallback, Function playerFailCallback) async {
    final successCallback = playerSuccessCallback;
    final sound = {};
    void failureCallback(dynamic track) async {
      final prefs = await SharedPreferences.getInstance();
      // if (await localStorage.getObject('enable_auto_choose_source') == false) {
      // if (prefs.getBool('enable_auto_choose_source') == false) {
      //   playerFailCallback();
      //   return;
      // }
      final trackPlatform = getProviderNameByItemId(track['id']);
      // final failoverSourceList = (await getLocalStorageValue('auto_choose_source_list', ['kuwo', 'qq', 'migu'])).where((i) => i != trackPlatform).toList();
      // final failoverSourceList = prefs.getStringList('auto_choose_source_list')!.where((i) => i != trackPlatform).toList();
      // final getUrlPromises = failoverSourceList.map((source) {
      //   return Future(() async {
      //     if (track['source'] == source) {
      //       return;
      //     }
      //     final keyword = '${track['title']} ${track['artist']}';
      //     final curpage = 1;
      //     final url = '/search?keywords=$keyword&curpage=$curpage&type=0';
      //     final provider = getProviderByName(source);
      //     final data = await provider.search(url);
      //     for (var searchTrack in data['result']) {
      //       if (!searchTrack['disable'] && searchTrack['title'] == track['title'] && searchTrack['artist'] == track['artist']) {
      //         final response = await provider.bootstrapTrack(searchTrack);
      //         sound['url'] = response['url'];
      //         sound['bitrate'] = response['bitrate'];
      //         sound['platform'] = response['platform'];
      //         throw sound;
      //       }
      //     }
      //   });
      // }).toList();

      try {
        // await Future.wait(getUrlPromises);
        playerFailCallback(track);
      } catch (response) {
        playerSuccessCallback(response, track);
      }
    }

    if (await get_local_cache(track['id']) != '') {
      playerSuccessCallback(get_local_cache(track['id']), track);
    } else {
      final provider = getProviderByName(track['source']);
      provider.bootstrap_track(track, successCallback, failureCallback);
    }
  }

  static Future<dynamic> login(String source, Map<String, dynamic> options) {
    final url = '/login?${queryStringify(options)}';
    final provider = getProviderByName(source);
    return provider.login(url);
  }

  static Future<dynamic> getUser(String source) {
    final provider = getProviderByName(source);
    return provider.get_user();
  }

  static Future<dynamic> getLoginUrl(String source) {
    final provider = getProviderByName(source);
    return provider.getLoginUrl();
  }

  static Future<dynamic> getUserCreatedPlaylist(
      String source, Map<String, dynamic> options) {
    final provider = getProviderByName(source);
    final url = '/get_user_create_playlist?${queryStringify(options)}';
    return provider.getUserCreatedPlaylist(url);
  }

  static Future<dynamic> getUserFavoritePlaylist(
      String source, Map<String, dynamic> options) {
    final provider = getProviderByName(source);
    final url = '/get_user_favorite_playlist?${queryStringify(options)}';
    return provider.getUserFavoritePlaylist(url);
  }

  static Future<dynamic> getRecommendPlaylist(String source) {
    final provider = getProviderByName(source);
    return provider.getRecommendPlaylist();
  }

  static Future<dynamic> logout(String source) {
    final provider = getProviderByName(source);
    return provider.logout();
  }
}

final loWeb = MediaService();
