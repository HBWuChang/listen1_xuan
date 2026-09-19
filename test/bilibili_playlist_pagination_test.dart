import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:listen1_xuan/bodys.dart' show PlaylistController;
import 'package:listen1_xuan/controllers/DioController.dart';
import 'package:listen1_xuan/provider/bilibili.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DioController dio;
  late PlaylistController controller;
  late List<int> requestedPages;
  late Map<String, dynamic> Function(int page) responseForPage;

  Map<String, dynamic> response(List<int> ids, {int? total, int? pages}) => {
    'code': 0,
    'data': {
      if (total != null) 'totalSize': total,
      if (pages != null) 'pageCount': pages,
      'data': [
        for (final id in ids) {'menuId': id, 'title': 'playlist $id', 'cover': ''},
      ],
    },
  };

  setUp(() {
    dio = Get.put<DioController>(DioController());
    controller = PlaylistController(source: Bilibili());
    requestedPages = [];
    dio.dioWithCookieManager.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      final page = int.parse(options.uri.queryParameters['pn']!);
      requestedPages.add(page);
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: responseForPage(page)));
    }));
  });

  tearDown(() {
    controller.onClose();
    dio.dioWithCookieManager.close();
    Get.reset();
  });

  test('Bilibili repeated 11-item response beyond pageCount reaches no more', () async {
    responseForPage = (_) => response(List.generate(11, (i) => i), total: 11, pages: 1);
    await controller.loadData();
    expect(controller.playlists.length, 11);
    await controller.loadMoreData();
    expect(requestedPages, [1, 2]);
    expect(controller.playlists.length, 11);
    expect(controller.hasMore.value, isFalse);
    expect(controller.loadingMore.value, isFalse);
    expect(controller.loadMoreFailed.value, isFalse);
    await controller.loadMoreData();
    expect(requestedPages, [1, 2]);
    await controller.refreshData();
    expect(controller.playlists.length, 11);
    expect(controller.hasMore.value, isTrue);
    expect(requestedPages, [1, 2, 1]);
  });

  test('valid next page appends and totalSize stops a repeated final page', () async {
    responseForPage = (page) => response(
      page == 1 ? List.generate(20, (i) => i) : [20, 21, 22], total: 23,
    );
    await controller.loadData();
    await controller.loadMoreData();
    expect(controller.playlists.length, 23);
    expect(controller.hasMore.value, isTrue);
    await controller.loadMoreData();
    expect(requestedPages, [1, 2, 3]);
    expect(controller.playlists.length, 23);
    expect(controller.hasMore.value, isFalse);
  });

  test('missing pagination metadata still stops an entirely repeated page', () async {
    responseForPage = (_) => response([1, 2, 3]);
    await controller.loadData();
    await controller.loadMoreData();
    expect(controller.playlists.length, 3);
    expect(controller.hasMore.value, isFalse);
  });

  test('partially overlapping pages append new IDs without duplicate cards', () async {
    responseForPage = (page) => response(page == 1 ? [1, 2, 3] : [2, 3, 4, 4]);
    await controller.loadData();
    await controller.loadMoreData();
    expect(controller.playlists.map((playlist) => playlist.info.id), [
      'biplaylist_1', 'biplaylist_2', 'biplaylist_3', 'biplaylist_4',
    ]);
    expect(controller.hasMore.value, isTrue);
  });

  test('empty first page is terminal and does not request page one again', () async {
    responseForPage = (_) => response([], total: 0, pages: 0);
    await controller.loadData();
    expect(controller.hasMore.value, isFalse);
    await controller.loadMoreData();
    expect(requestedPages, [1]);
  });

  test('API errors are not treated as an empty successful page', () async {
    responseForPage = (_) => {'code': -400, 'msg': 'test failure', 'data': null};
    await expectLater(Bilibili().showPlaylist(offset: 20)!, throwsException);
  });
}
