import 'package:dio/dio.dart';
import 'package:listen1_xuan/controllers/play_controller.dart';
import 'dart:convert';
import 'dart:async';
import 'lowebutil.dart';
import 'dart:math';
import 'main.dart';

final kugou = Kugou();

class Kugou {
  // static kg_convert_song(song) {
  //   const track = {
  //     id: `kgtrack_${song.FileHash}`,
  //     title: song.SongName,
  //     artist: '',
  //     artist_id: '',
  //     album: song.AlbumName,
  //     album_id: `kgalbum_${song.AlbumID}`,
  //     source: 'kugou',
  //     source_url: `https://www.kugou.com/song/#hash=${song.FileHash}&album_id=${song.AlbumID}`,
  //     img_url: '',
  //     // url: `kgtrack_${song.FileHash}`,
  //     lyric_url: song.FileHash,
  //   };
  //   let singer_id = song.SingerId;
  //   let singer_name = song.SingerName;
  //   if (song.SingerId instanceof Array) {
  //     [singer_id] = singer_id;
  //     [singer_name] = singer_name.split('、');
  //   }
  //   track.artist = singer_name;
  //   track.artist_id = `kgartist_${singer_id}`;
  //   return track;
  // }
  Track kg_convert_song(song) {
    // final track = {
    //   'id': 'kgtrack_${song['FileHash']}',
    //   'title': song['SongName'],
    //   'artist': '',
    //   'artist_id': '',
    //   'album': song['AlbumName'],
    //   'album_id': 'kgalbum_${song['AlbumID']}',
    //   'source': 'kugou',
    //   'source_url':
    //       'https://www.kugou.com/song/#hash=${song['FileHash']}&album_id=${song['AlbumID']}',
    //   'img_url': '',
    //   // url: `kgtrack_${song.FileHash}`,
    //   'lyric_url': song['FileHash'],
    // };
    final track = Track(
      id: 'kgtrack_${song['FileHash']}',
      title: song['SongName'],
      artist: '',
      artist_id: '',
      album: song['AlbumName'],
      album_id: 'kgalbum_${song['AlbumID']}',
      source: 'kugou',
      source_url:
          'https://www.kugou.com/song/#hash=${song['FileHash']}&album_id=${song['AlbumID']}',
      img_url: '',
      lyric_url: song['FileHash'],
    );
    var singer_id = song['SingerId'];
    var singer_name = song['SingerName'];
    if (singer_id is List) {
      singer_id = singer_id[0];
      singer_name = singer_name.split('、')[0];
    }
    track.artist = singer_name;
    track.artist_id = 'kgartist_$singer_id';
    return track;
  }

  // static async_process_list(
  //   data_list,
  //   handler,
  //   handler_extra_param_list,
  //   callback
  // ) {
  // const fnDict = {};
  // data_list.forEach((item, index) => {
  //   fnDict[index] = (cb) =>
  //     handler(index, item, handler_extra_param_list, cb);
  // });
  // async.parallel(fnDict, (err, results) =>
  //   callback(
  //     null,
  //     data_list.map((item, index) => results[index])
  //   )
  // );
  // }
  Future<void> async_process_list(
    List data_list,
    Function handler,
    List handler_extra_param_list,
    Function callback,
  ) async {
    // 创建一个 Map 来存储异步任务
    final Map<int, Future> fnDict = {};

    // 使用 for 循环填充 fnDict
    for (int index = 0; index < data_list.length; index++) {
      final item = data_list[index];
      fnDict[index] = () {
        final completer = Completer();
        handler(index, item, handler_extra_param_list, (err, result) {
          if (err != null) {
            completer.completeError(err);
          } else {
            completer.complete(result);
          }
        });
        return completer.future;
      }();
    }

    // 等待所有异步任务完成
    try {
      final results = await Future.wait(fnDict.values);

      // 使用 for 循环将结果映射到 data_list 的索引
      final List<dynamic> finalResults = [];
      for (int index = 0; index < data_list.length; index++) {
        finalResults.add(results[index]);
      }

      // 调用最终的回调函数
      callback(null, finalResults);
    } catch (err) {
      // 如果有错误，调用回调并传递错误
      callback(err, null);
    }
  }

  // static kg_render_search_result_item(index, item, params, callback) {
  //   const track = kugou.kg_convert_song(item);
  //   // Add singer img
  //   const url = `${'https://www.kugou.com/yy/index.php?r=play/getdata&hash='}${
  //     track.lyric_url
  //   }`;
  //   axios.get(url).then((response) => {
  //     const { data } = response;
  //     track.img_url = data.data.img;
  //     callback(null, track);
  //   });
  // }
  Future<void> kg_render_search_result_item(
      int index, item, List params, Function callback) async {
    final track = kg_convert_song(item);
    // Add singer img
    final url =
        'https://www.kugou.com/yy/index.php?r=play/getdata&hash=${track.lyric_url}';
    final response = await dio_with_cookie_manager.get(url,
        options: Options(
          headers: {
            "User-Agent":
                "Mozilla/5.0 (iPhone; CPU iPhone OS 14_3 like Mac OS X) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30",
            "Connection": "keep-alive",
            "Accept": "application/json, text/plain, */*",
            "Accept-Encoding": "gzip, deflate, br",
            "accept-language": "zh-CN",
            "origin": "https://www.kugou.com/",
            "referer": "https://www.kugou.com/",
            "sec-fetch-dest": "empty",
            "sec-fetch-mode": "cors",
            "sec-fetch-site": "cross-site"
          },
        ));
    final data = response.data;
    try {
      track.img_url = data['data']['img'];
    } catch (e) {
      track.img_url = '';
    }
    callback(null, track);
  }

  // static search(url) {
  //   const keyword = getParameterByName('keywords', url);
  //   const curpage = getParameterByName('curpage', url);
  //   const searchType = getParameterByName('type', url);
  //   if (searchType === '1') {
  //     return {
  //       success: (fn) => {
  //         const target_url = `${'http://mobilecdnbj.kugou.com/api/v3/search/special?keyword='}${keyword}&pagesize=20&filter=0&page=${curpage}`;
  //         axios
  //           .get(target_url)
  //           .then((response) => {
  //             const result = response.data.data.info.map((item) => ({
  //               id: `kgplaylist_${item.specialid}`,
  //               title: item.specialname,
  //               source: 'kugou',
  //               source_url:
  //                 'https://www.kugou.com/yy/special/single/{size}.html'.replaceAll(
  //                   '{size}',
  //                   item.specialid
  //                 ),
  //               img_url: item.imgurl
  //                 ? item.imgurl.replaceAll('{size}', '400')
  //                 : '',
  //               url: `kgplaylist_${item.specialid}`,
  //               author: item.nickname,
  //               count: item.songcount,
  //             }));
  //             const { total } = response.data.data;
  //             return fn({
  //               result,
  //               total,
  //               type: searchType,
  //             });
  //           })
  //           .catch(() => {
  //             fn({
  //               result: [],
  //               total: 0,
  //               type: searchType,
  //             });
  //           });
  //       },
  //     };
  //   }
  //   return {
  //     success: (fn) => {
  //       const target_url = `${'https://songsearch.kugou.com/song_search_v2?keyword='}${keyword}&page=${curpage}`;
  //       axios
  //         .get(target_url)
  //         .then((response) => {
  //           const { data } = response;
  //           this.async_process_list(
  //             data.data.lists,
  //             this.kg_render_search_result_item,
  //             [],
  //             (err, tracks) =>
  //               fn({
  //                 result: tracks,
  //                 total: data.data.total,
  //                 type: searchType,
  //               })
  //           );
  //         })
  //         .catch(() =>
  //           fn({
  //             result: [],
  //             total: 0,
  //             type: searchType,
  //           })
  //         );
  //     },
  //   };
  // }
  Future<Map<String, Function>> search(String url) async {
    final keyword = getParameterByName('keywords', url);
    final curpage = getParameterByName('curpage', url);
    final searchType = getParameterByName('type', url);
    if (searchType == '1') {
      return {
        'success': (fn) async {
          final target_url =
              'http://mobilecdnbj.kugou.com/api/v3/search/special?keyword=$keyword&pagesize=20&filter=0&page=$curpage';
          final response = await dio_with_cookie_manager.get(target_url);
          final result = jsonDecode(response.data)['data']['info']
              .map((item) => ({
                    'id': 'kgplaylist_${item['specialid']}',
                    'title': item['specialname'],
                    'source': 'kugou',
                    'source_url':
                        'https://www.kugou.com/yy/special/single/${item['specialid']}.html',
                    'img_url': item['imgurl'] != null
                        ? item['imgurl'].replaceAll('{size}', '400')
                        : '',
                    'url': 'kgplaylist_${item['specialid']}',
                    'author': item['nickname'],
                    'count': item['songcount'],
                  }))
              .toList();
          final total = jsonDecode(response.data)['data']['total'];
          return fn({
            'result': result,
            'total': total,
            'type': searchType,
          });
        },
      };
    }
    return {
      'success': (fn) async {
        final target_url =
            'https://songsearch.kugou.com/song_search_v2?keyword=$keyword&page=$curpage';
        final response = await dio_with_cookie_manager.get(target_url);
        final data = jsonDecode(response.data);
        this.async_process_list(
          data['data']['lists'],
          this.kg_render_search_result_item,
          [],
          (err, tracks) => fn({
            'result': tracks,
            'total': data['data']['total'],
            'type': searchType,
          }),
        );
      },
    };
  }
  // static kg_render_playlist_result_item(index, item, params, callback) {
  //   const { hash } = item;

  //   let target_url = `${'https://m.kugou.com/app/i/getSongInfo.php?cmd=playInfo&hash='}${hash}`;
  //   const track = {
  //     id: `kgtrack_${hash}`,
  //     title: '',
  //     artist: '',
  //     artist_id: '',
  //     album: '',
  //     album_id: `kgalbum_${item.album_id}`,
  //     source: 'kugou',
  //     source_url: `https://www.kugou.com/song/#hash=${hash}&album_id=${item.album_id}`,
  //     img_url: '',
  //     lyric_url: hash,
  //   };
  //   // Fix song info
  //   axios.get(target_url).then((response) => {
  //     const { data } = response;
  //     track.title = data.songName;
  //     track.artist = data.singerId === 0 ? '未知' : data.singerName;
  //     track.artist_id = `kgartist_${data.singerId}`;
  //     if (data.album_img !== undefined) {
  //       track.img_url = data.album_img.replaceAll('{size}', '400');
  //     } else {
  //       // track['img_url'] = data.imgUrl.replaceAll('{size}', '400');
  //     }
  //     // Fix album
  //     target_url = `http://mobilecdnbj.kugou.com/api/v3/album/info?albumid=${item.album_id}`;
  //     axios.get(target_url).then((res) => {
  //       const { data: res_data } = res;
  //       if (
  //         res_data.status &&
  //         res_data.data !== undefined &&
  //         res_data.data !== null
  //       ) {
  //         track.album = res_data.data.albumname;
  //       } else {
  //         track.album = '';
  //       }
  //       return callback(null, track);
  //     });
  //   });
  // }
  Future<void> kg_render_playlist_result_item(
      int index, item, List params, Function callback) async {
    final hash = item['hash'];
    var target_url =
        'https://m.kugou.com/app/i/getSongInfo.php?cmd=playInfo&hash=$hash';
    final track = Track.fromJson({
      'id': 'kgtrack_$hash',
      'title': '',
      'artist': '',
      'artist_id': '',
      'album': '',
      'album_id': 'kgalbum_${item['album_id']}',
      'source': 'kugou',
      'source_url':
          'https://www.kugou.com/song/#hash=$hash&album_id=${item['album_id']}',
      'img_url': '',
      'lyric_url': hash,
    });
    // Fix song info
    final response = await dio_with_cookie_manager.get(target_url);
    final data = jsonDecode(response.data);
    track.title = data['songName'];
    track.artist = data['singerId'] == 0 ? '未知' : data['singerName'];
    track.artist_id = 'kgartist_${data['singerId']}';
    if (data['album_img'] != null) {
      track.img_url = data['album_img'].replaceAll('{size}', '400');
    } else {
      // track['img_url'] = data.imgUrl.replaceAll('{size}', '400');
    }
    // Fix album
    target_url =
        'http://mobilecdnbj.kugou.com/api/v3/album/info?albumid=${item['album_id']}';
    final res = await dio_with_cookie_manager.get(target_url);
    final res_data = jsonDecode(res.data);
    if (res_data['status'] != 0 && res_data['data'] != null) {
      track.album = res_data['data']['albumname'];
    } else {
      track.album = '';
    }
    callback(null, track);
  }
  // static kg_get_playlist(url) {
  //   return {
  //     success: (fn) => {
  //       const list_id = getParameterByName('list_id', url).split('_').pop();
  //       const target_url = `https://m.kugou.com/plist/list/${list_id}?json=true`;

  //       axios.get(target_url).then((response) => {
  //         const { data } = response;

  //         const info = {
  //           cover_img_url: data.info.list.imgurl
  //             ? data.info.list.imgurl.replaceAll('{size}', '400')
  //             : '',
  //           title: data.info.list.specialname,
  //           id: `kgplaylist_${data.info.list.specialid}`,
  //           source_url:
  //             'https://www.kugou.com/yy/special/single/{size}.html'.replaceAll(
  //               '{size}',
  //               data.info.list.specialid
  //             ),
  //         };

  //         this.async_process_list(
  //           data.list.list.info,
  //           this.kg_render_playlist_result_item,
  //           [],
  //           (err, tracks) =>
  //             fn({
  //               tracks,
  //               info,
  //             })
  //         );
  //       });
  //     },
  //   };
  // }
  Future<Map<String, Function>> kg_get_playlist(String url) async {
    return {
      'success': (fn) async {
        final list_id = getParameterByName('list_id', url).split('_').last;
        final target_url = 'https://m.kugou.com/plist/list/$list_id?json=true';
        // Mozilla/5.0 (iPhone; CPU iPhone OS 14_3 like Mac OS X) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30
        final dio = dio_with_cookie_manager;
        final response = await dio.get(
          target_url,
          options: Options(
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (iPhone; CPU iPhone OS 14_3 like Mac OS X) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30',
            },
            followRedirects: false, // 禁用自动重定向
            validateStatus: (status) {
              return status != null &&
                  status >= 200 &&
                  status < 400; // 允许 3xx 状态码
            },
          ),
        );
        Response lastResponse = response;
        var redirectUrl = null;
        Response redirectedResponse;
        while (lastResponse.statusCode != null &&
            lastResponse.statusCode! >= 300 &&
            lastResponse.statusCode! < 400) {
          redirectUrl = lastResponse.headers.value('location');
          if (redirectUrl != null) {
            redirectedResponse = await dio.get(
              redirectUrl,
              options: Options(
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (iPhone; CPU iPhone OS 14_3 like Mac OS X) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30',
                },
                followRedirects: false, // 禁用自动重定向
                validateStatus: (status) {
                  return status != null &&
                      status >= 200 &&
                      status < 400; // 允许 3xx 状态码
                },
              ),
            );
            // 使用 redirectedResponse 处理重定向后的响应
            lastResponse = redirectedResponse;
          } else {
            break; // 没有重定向地址，退出循环
          }
        }

        final data = jsonDecode(lastResponse.data);
        final info = {
          'cover_img_url': data['info']['list']['imgurl'] != null
              ? data['info']['list']['imgurl'].replaceAll('{size}', '400')
              : '',
          'title': data['info']['list']['specialname'],
          'id': 'kgplaylist_${data['info']['list']['specialid']}',
          'source_url':
              'https://www.kugou.com/yy/special/single/${data['info']['list']['specialid']}.html',
        };
        this.async_process_list(
          data['list']['list']['info'],
          kg_render_playlist_result_item,
          [],
          (err, tracks) => fn({
            'tracks': tracks,
            'info': info,
          }),
        );
      },
    };
  }

  // static kg_render_artist_result_item(index, item, params, callback) {
  //   const info = params[0];
  //   const track = {
  //     id: `kgtrack_${item.hash}`,
  //     title: '',
  //     artist: '',
  //     artist_id: info.id,
  //     album: '',
  //     album_id: `kgalbum_${item.album_id}`,
  //     source: 'kugou',
  //     source_url: `https://www.kugou.com/song/#hash=${item.hash}&album_id=${item.album_id}`,
  //     img_url: '',
  //     // url: `kgtrack_${item.hash}`,
  //     lyric_url: item.hash,
  //   };
  //   const one = item.filename.split('-');
  //   track.title = one[1].trim();
  //   track.artist = one[0].trim();
  //   // Fix album name and img
  //   const target_url = `${'https://www.kugou.com/yy/index.php?r=play/getdata&hash='}${
  //     item.hash
  //   }`;
  //   axios
  //     .get(
  //       `http://mobilecdnbj.kugou.com/api/v3/album/info?albumid=${item.album_id}`
  //     )
  //     .then((response) => {
  //       const { data } = response;
  //       if (data.status && data.data !== undefined) {
  //         track.album = data.data.albumname;
  //       } else {
  //         track.album = '';
  //       }
  //       axios.get(target_url).then((res) => {
  //         track.img_url = res.data.data.img;
  //         callback(null, track);
  //       });
  //     });
  // }
  Future<void> kg_render_artist_result_item(
      int index, item, List params, Function callback) async {
    final info = params[0];
    final track = Track.fromJson({
      'id': 'kgtrack_${item['hash']}',
      'title': '',
      'artist': '',
      'artist_id': info['id'],
      'album': '',
      'album_id': 'kgalbum_${item['album_id']}',
      'source': 'kugou',
      'source_url':
          'https://www.kugou.com/song/#hash=${item['hash']}&album_id=${item['album_id']}',
      'img_url': '',
      // url: `kgtrack_${item.hash}`,
      'lyric_url': item['hash'],
    });
    final one = item['filename'].split('-');
    track.title = one[1].trim();
    track.artist = one[0].trim();
    // Fix album name and img
    var target_url =
        'https://www.kugou.com/yy/index.php?r=play/getdata&hash=${item['hash']}';
    final response = await dio_with_cookie_manager.get(
        'http://mobilecdnbj.kugou.com/api/v3/album/info?albumid=${item['album_id']}');
    final data = jsonDecode(response.data);
    if (data['status'] != 0 && data['data'] != null) {
      track.album = data['data']['albumname'];
    } else {
      track.album = '';
    }
//     {
//   "Reqable-Id": "",
//   "Host": "",
//   "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 14_3 like Mac OS X) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30",
//   "Connection": "keep-alive",
//   "Accept": "application/json, text/plain, */*",
//   "Accept-Encoding": "gzip, deflate, br",
//   "accept-language": "zh-CN",
//   "cookie": "kg_mid=484ec51a91806ddadb5ca9612490b9ae",
//   "origin": "https://www.kugou.com/",
//   "referer": "https://www.kugou.com/",
//   "sec-fetch-dest": "empty",
//   "sec-fetch-mode": "cors",
//   "sec-fetch-site": "cross-site"
// }
    final response1 = await dio_with_cookie_manager.get(target_url,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 14_3 like Mac OS X) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30',
            'Accept': 'application/json, text/plain, */*',
            'accept-language': 'zh-CN',
            'origin': 'https://www.kugou.com/',
            'referer': 'https://www.kugou.com/',
          },
        ));
    track.img_url = response1.data['data']['img'];
    callback(null, track);
  }

  // static kg_artist(url) {
  //   return {
  //     success: (fn) => {
  //       const artist_id = getParameterByName('list_id', url).split('_').pop();
  //       let target_url = `http://mobilecdnbj.kugou.com/api/v3/singer/info?singerid=${artist_id}`;
  //       axios.get(target_url).then((response) => {
  //         const { data } = response;
  //         const info = {
  //           cover_img_url: data.data.imgurl.replaceAll('{size}', '400'),
  //           title: data.data.singername,
  //           id: `kgartist_${artist_id}`,
  //           source_url: 'https://www.kugou.com/singer/{id}.html'.replaceAll(
  //             '{id}',
  //             artist_id
  //           ),
  //         };
  //         target_url = `http://mobilecdnbj.kugou.com/api/v3/singer/song?singerid=${artist_id}&page=1&pagesize=30`;
  //         axios.get(target_url).then((res) => {
  //           this.async_process_list(
  //             res.data.data.info,
  //             this.kg_render_artist_result_item,
  //             [info],
  //             (err, tracks) =>
  //               fn({
  //                 tracks,
  //                 info,
  //               })
  //           );
  //         });
  //       });
  //     },
  //   };
  // }
  Future<Map<String, Function>> kg_artist(String url) async {
    return {
      'success': (fn) async {
        final artist_id = getParameterByName('list_id', url).split('_').last;
        var target_url =
            'http://mobilecdnbj.kugou.com/api/v3/singer/info?singerid=$artist_id';
        final response = await dio_with_cookie_manager.get(target_url);
        final data = jsonDecode(response.data);
        final info = {
          'cover_img_url': data['data']['imgurl'].replaceAll('{size}', '400'),
          'title': data['data']['singername'],
          'id': 'kgartist_$artist_id',
          'source_url': 'https://www.kugou.com/singer/$artist_id.html',
        };
        target_url =
            'http://mobilecdnbj.kugou.com/api/v3/singer/song?singerid=$artist_id&page=1&pagesize=30';
        final res = await dio_with_cookie_manager.get(target_url);
        this.async_process_list(
          jsonDecode(res.data)['data']['info'],
          kg_render_artist_result_item,
          [info],
          (err, tracks) => fn({
            'tracks': tracks,
            'info': info,
          }),
        );
      },
    };
  }

  // static getTimestampString() {
  //   return new Date().getTime().toString();
  // }
  String getTimestampString() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // static getRandomIntString() {
  //   return (Math.random() * 100).toString().replaceAll(/\D/g, '');
  // }
  String getRandomIntString() {
    return (Random().nextDouble() * 100)
        .toString()
        .replaceAll(RegExp(r'\D'), '');
  }

  // static getRandomHexString() {
  //   let result = '';
  //   const letters = '0123456789abcdef';
  //   for (let i = 0; i < 16; i += 1) {
  //     result += letters[Math.floor(Math.random() * 16)];
  //   }
  //   return result;
  // }
  String getRandomHexString() {
    final letters = '0123456789abcdef';
    return List.generate(16, (index) => letters[Random().nextInt(16)]).join();
  }
  // static bootstrap_track(track, success, failure) {
  //   const track_id = track.id.slice('kgtrack_'.length);

  //   const target_url = `https://m.kugou.com/app/i/getSongInfo.php?cmd=playInfo&hash=${track_id}`;

  //   axios.get(target_url).then((response) => {
  //     const { data: info } = response;

  //     const { url } = info;

  //     if (url === '') {
  //       return failure({});
  //     }

  //     return success({
  //       url,
  //       bitrate: `${info.bitRate}kbps`,
  //       platform: 'kugou',
  //     });
  //   });
  // }
  Future<void> bootstrap_track(
      Track track, Function success, Function failure) async {
    final track_id = track.id.substring('kgtrack_'.length);
    final target_url =
        'https://m.kugou.com/app/i/getSongInfo.php?cmd=playInfo&hash=$track_id';
    final response = await dio_with_cookie_manager.get(target_url);
    final info = jsonDecode(response.data);
    final url = info['url'];
    if (url == '') {
      return failure(track);
    }
    return success({
      'url': url,
      'bitrate': '${info['bitRate']}kbps',
      'platform': 'kugou',
    }, track);
  }

  // static lyric(url) {
  //   const track_id = getParameterByName('track_id', url).split('_').pop();
  //   const album_id = getParameterByName('album_id', url).split('_').pop();
  //   let lyric_url = `https://wwwapi.kugou.com/yy/index.php?r=play/getdata&callback=jQuery&mid=1&hash=${track_id}&platid=4&album_id=${album_id}`;
  //   const timstamp = +new Date();
  //   lyric_url += `&_=${timstamp}`;
  //   return {
  //     success: (fn) => {
  //       axios.get(lyric_url).then((response) => {
  //         const { data } = response;
  //         const jsonString = data.slice('jQuery('.length, data.length - 1 - 1);
  //         const info = JSON.parse(jsonString);
  //         return fn({
  //           lyric: info.data.lyrics,
  //         });
  //       });
  //     },
  //   };
  // }
  Future<Map<String, Function>> lyric(String url) async {
    final track_id = getParameterByName('track_id', url).split('_').last;
    final album_id = getParameterByName('album_id', url).split('_').last;
    var lyric_url =
        'https://wwwapi.kugou.com/yy/index.php?r=play/getdata&callback=jQuery&mid=1&hash=$track_id&platid=4&album_id=$album_id';
    final timstamp = DateTime.now().millisecondsSinceEpoch;
    lyric_url += '&_=$timstamp';
    return {
      'success': (fn) async {
        final response = await dio_with_cookie_manager.get(lyric_url);
        final data = jsonDecode(response.data);
        final jsonString =
            data.substring('jQuery('.length, data.length - 1 - 1);
        final info = json.decode(jsonString);
        return fn({
          'lyric': info['data']['lyrics'],
        });
      },
    };
  }

  // static kg_render_album_result_item(index, item, params, callback) {
  //   const info = params[0];
  //   const album_id = params[1];
  //   const track = {
  //     id: `kgtrack_${item.hash}`,
  //     title: '',
  //     artist: '',
  //     artist_id: '',
  //     album: info.title,
  //     album_id: `kgalbum_${album_id}`,
  //     source: 'kugou',
  //     source_url: `https://www.kugou.com/song/#hash=${item.hash}&album_id=${album_id}`,
  //     img_url: '',
  //     // url: `xmtrack_${item.hash}`,
  //     lyric_url: item.hash,
  //   };
  //   // Fix other data
  //   const target_url = `${'https://m.kugou.com/app/i/getSongInfo.php?cmd=playInfo&hash='}${
  //     item.hash
  //   }`;
  //   axios.get(target_url).then((response) => {
  //     const { data } = response;
  //     track.title = data.songName;
  //     track.artist = data.singerId === 0 ? '未知' : data.singerName;
  //     track.artist_id = `kgartist_${data.singerId}`;
  //     track.img_url = data.imgUrl.replaceAll('{size}', '400');
  //     callback(null, track);
  //   });
  // }
  Future<void> kg_render_album_result_item(
      int index, item, List params, Function callback) async {
    final info = params[0];
    final album_id = params[1];
    final track = Track.fromJson({
      'id': 'kgtrack_${item['hash']}',
      'title': '',
      'artist': '',
      'artist_id': '',
      'album': info['title'],
      'album_id': 'kgalbum_$album_id',
      'source': 'kugou',
      'source_url':
          'https://www.kugou.com/song/#hash=${item['hash']}&album_id=$album_id',
      'img_url': '',
      // url: `xmtrack_${item.hash}`,
      'lyric_url': item['hash'],
    });
    // Fix other data
    final target_url =
        'https://m.kugou.com/app/i/getSongInfo.php?cmd=playInfo&hash=${item['hash']}';
    final response = await dio_with_cookie_manager.get(target_url);
    final data = jsonDecode(response.data);
    track.title = data['songName'];
    track.artist = data['singerId'] == 0 ? '未知' : data['singerName'];
    track.artist_id = 'kgartist_${data['singerId']}';
    track.img_url = data['imgUrl'].replaceAll('{size}', '400');
    callback(null, track);
  }
  // static kg_album(url) {
  //   return {
  //     success: (fn) => {
  //       const album_id = getParameterByName('list_id', url).split('_').pop();
  //       let target_url = `${'http://mobilecdnbj.kugou.com/api/v3/album/info?albumid='}${album_id}`;

  //       let info;
  //       // info
  //       axios.get(target_url).then((response) => {
  //         const { data } = response;

  //         info = {
  //           cover_img_url: data.data.imgurl.replaceAll('{size}', '400'),
  //           title: data.data.albumname,
  //           id: `kgalbum_${data.data.albumid}`,
  //           source_url: 'https://www.kugou.com/album/{id}.html'.replaceAll(
  //             '{id}',
  //             data.data.albumid
  //           ),
  //         };

  //         target_url = `${'http://mobilecdnbj.kugou.com/api/v3/album/song?albumid='}${album_id}&page=1&pagesize=-1`;
  //         axios.get(target_url).then((res) => {
  //           this.async_process_list(
  //             res.data.data.info,
  //             this.kg_render_album_result_item,
  //             [info, album_id],
  //             (err, tracks) =>
  //               fn({
  //                 tracks,
  //                 info,
  //               })
  //           );
  //         });
  //       });
  //     },
  //   };
  // }
  Future<Map<String, Function>> kg_album(String url) async {
    return {
      'success': (fn) async {
        final album_id = getParameterByName('list_id', url).split('_').last;
        var target_url =
            'http://mobilecdnbj.kugou.com/api/v3/album/info?albumid=$album_id';
        var info;
        // info
        final response = await dio_with_cookie_manager.get(target_url);
        final data = jsonDecode(response.data);
        info = {
          'cover_img_url': data['data']['imgurl'].replaceAll('{size}', '400'),
          'title': data['data']['albumname'],
          'id': 'kgalbum_${data['data']['albumid']}',
          'source_url':
              'https://www.kugou.com/album/${data['data']['albumid']}.html',
        };
        target_url =
            'http://mobilecdnbj.kugou.com/api/v3/album/song?albumid=$album_id&page=1&pagesize=-1';
        final res = await dio_with_cookie_manager.get(target_url);
        this.async_process_list(
          jsonDecode(res.data)['data']['info'],
          kg_render_album_result_item,
          [info, album_id],
          (err, tracks) => fn({
            'tracks': tracks,
            'info': info,
          }),
        );
      },
    };
  }

  // static show_playlist(url) {
  //   let offset = getParameterByName('offset', url);
  //   if (offset === undefined) {
  //     offset = 0;
  //   }
  //   const page = offset / 30 + 1;
  //   const target_url = `${'https://m.kugou.com/plist/index&json=true&page='}${page}`;
  //   return {
  //     success: (fn) => {
  //       axios.get(target_url).then((response) => {
  //         const { data } = response;
  //         // const total = data.plist.total;
  //         const result = data.plist.list.info.map((item) => ({
  //           cover_img_url: item.imgurl
  //             ? item.imgurl.replaceAll('{size}', '400')
  //             : '',
  //           title: item.specialname,
  //           id: `kgplaylist_${item.specialid}`,
  //           source_url:
  //             'https://www.kugou.com/yy/special/single/{size}.html'.replaceAll(
  //               '{size}',
  //               item.specialid
  //             ),
  //         }));
  //         return fn({
  //           result,
  //         });
  //       });
  //     },
  //   };
  // }
  Future<Map<String, Function>> show_playlist(String url) async {
    var offset = int.tryParse(getParameterByName('offset', url));
    if (offset == null) {
      offset = 0;
    }
    final page = offset / 30 + 1;
    final target_url = 'https://m.kugou.com/plist/index&json=true&page=$page';
    return {
      'success': (fn) async {
        try {
          final response = await dio_with_cookie_manager.get(target_url);
          final data = jsonDecode(response.data);
          // const total = data.plist.total;
          final result = data['plist']['list']['info']
              .map((item) => ({
                    'cover_img_url': item['imgurl'] != null
                        ? item['imgurl']
                            .replaceAll('{size}', '400') // 使用 replaceAll
                        : '',
                    'title': item['specialname'],
                    'id': 'kgplaylist_${item['specialid']}',
                    'source_url':
                        'https://www.kugou.com/yy/special/single/${item['specialid']}.html',
                  }))
              .toList();
          return fn(
            result,
          );
        } catch (e) {
          print('Error fetching playlist: $e');
          return fn([]); // 返回空列表或处理错误
        }
      },
    };
  }

  // static parse_url(url) {
  //   let result;
  //   const match = /\/\/www.kugou.com\/yy\/special\/single\/([0-9]+).html/.exec(
  //     url
  //   );
  //   if (match != null) {
  //     const playlist_id = match[1];
  //     result = {
  //       type: 'playlist',
  //       id: `kgplaylist_${playlist_id}`,
  //     };
  //   }
  //   return {
  //     success: (fn) => {
  //       fn(result);
  //     },
  //   };
  // }
  Future<Map<String, Function>> parse_url(String url) async {
    Map<String, dynamic> result = {};
    final match = RegExp(r'//www.kugou.com/yy/special/single/([0-9]+).html')
        .firstMatch(url);
    if (match != null) {
      final playlist_id = match.group(1);
      result = {
        'type': 'playlist',
        'id': 'kgplaylist_$playlist_id',
      };
    }
    return {
      'success': (fn) => fn(result),
    };
  }

  // static get_playlist(url) {
  //   // eslint-disable-line no-unused-vars
  //   const list_id = getParameterByName('list_id', url).split('_')[0];
  //   switch (list_id) {
  //     case 'kgplaylist':
  //       return this.kg_get_playlist(url);
  //     case 'kgalbum':
  //       return this.kg_album(url);
  //     case 'kgartist':
  //       return this.kg_artist(url);
  //     default:
  //       return null;
  //   }
  // }
  Future<Map<String, Function>> get_playlist(String url) async {
    // eslint-disable-line no-unused-vars
    final list_id = getParameterByName('list_id', url).split('_')[0];
    switch (list_id) {
      case 'kgplaylist':
        return kg_get_playlist(url);
      case 'kgalbum':
        return kg_album(url);
      case 'kgartist':
        return kg_artist(url);
      default:
        return {};
    }
  }

  // static get_playlist_filters() {
  //   return {
  //     success: (fn) => fn({ recommend: [], all: [] }),
  //   };
  // }
  Future<Map<String, Function>> get_playlist_filters() async {
    return {
      'success': (fn) => fn({'recommend': [], 'all': []}),
    };
  }

  // static get_user() {
  //   return {
  //     success: (fn) => fn({ status: 'fail', data: {} }),
  //   };
  // }
  Future<Map<String, Function>> get_user() async {
    return {
      'success': (fn) => fn({'status': 'fail', 'data': {}}),
    };
  }

  // static get_login_url() {
  //   return `https://www.kugou.com`;
  // }
  String get_login_url() {
    return 'https://www.kugou.com';
  }
  // static logout() {}

  // return {
  //   show_playlist: kg_show_playlist,
  //   get_playlist_filters,
  //   get_playlist,
  //   parse_url: kg_parse_url,
  //   bootstrap_track: kg_bootstrap_track,
  //   search: kg_search,
  //   lyric: kg_lyric,
  //   get_user: kg_get_user,
  //   get_login_url: kg_get_login_url,
  //   logout: kg_logout,
  // };
}
