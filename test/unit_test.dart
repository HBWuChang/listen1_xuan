// This is an example unit test.
//
// A unit test tests a single function, method, or class. To learn more about
// writing unit tests, visit
// https://flutter.dev/to/unit-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:listen1_xuan/models/PlayListInfo.dart';
import 'package:listen1_xuan/pages/playlist_info/playlist_info_args.dart';

void main() {
  group('Plus Operator', () {
    test('should add two numbers together', () {
      expect(1 + 1, 2);
    });
  });

  group('PlaylistInfoArgs', () {
    test('uses a distinct controller tag for each route instance', () {
      final playlist = PlayListInfo(id: 'playlist_a');
      final firstRouteArgs = PlaylistInfoArgs(playListInfo: playlist);
      final secondRouteArgs = PlaylistInfoArgs(playListInfo: playlist);

      expect(firstRouteArgs.path, secondRouteArgs.path);
      expect(
        firstRouteArgs.controllerTag,
        isNot(secondRouteArgs.controllerTag),
      );
    });
  });
}
