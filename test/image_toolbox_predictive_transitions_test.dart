import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen1_xuan/router/image_toolbox_predictive_transitions.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> sendBackGestureMethod(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    final message = const StandardMethodCodec().encodeMethodCall(
      MethodCall(method, arguments),
    );
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/backgesture',
      message,
      (ByteData? _) {},
    );
  }

  Future<void> startBackGesture() {
    return sendBackGestureMethod('startBackGesture', <String, Object?>{
      'touchOffset': <double>[5, 300],
      'progress': 0.0,
      'swipeEdge': 0,
    });
  }

  Future<void> updateBackGesture(double progress) {
    return sendBackGestureMethod('updateBackGestureProgress', <String, Object?>{
      'x': 100.0,
      'y': 300.0,
      'progress': progress,
      'swipeEdge': 0,
    });
  }

  Future<GlobalKey<NavigatorState>> pumpTwoPageApp(WidgetTester tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: ThemeData(
          platform: TargetPlatform.android,
          pageTransitionsTheme: imageToolboxPageTransitionsTheme,
        ),
        home: const Material(
          key: ValueKey<String>('page-a'),
          child: Center(child: Text('page a')),
        ),
      ),
    );

    navigatorKey.currentState!.push<void>(
      ThemedGetPageRoute<void>(
        settings: const RouteSettings(name: '/page-b'),
        page: () => const Material(
          key: ValueKey<String>('page-b'),
          child: Center(child: Text('page b')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return navigatorKey;
  }

  testWidgets(
    'predictive back follows the gesture and commits the Get route pop',
    (tester) async {
      await pumpTwoPageApp(tester);

      final pageBFinder = find.byKey(const ValueKey<String>('page-b'));
      expect(find.text('page a'), findsNothing);
      expect(pageBFinder, findsOneWidget);
      final startX = tester.getTopLeft(pageBFinder).dx;

      await startBackGesture();
      await tester.pump();
      await updateBackGesture(0.35);
      await tester.pump();

      expect(tester.getTopLeft(pageBFinder).dx, greaterThan(startX));
      expect(find.text('page a'), findsOneWidget);
      final pageAFinder = find.byKey(
        const ValueKey<String>('page-a'),
        skipOffstage: false,
      );
      final pageADragX = tester.getTopLeft(pageAFinder).dx;
      expect(pageADragX, lessThan(startX));

      await sendBackGestureMethod('commitBackGesture');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final pageACommitX = tester.getTopLeft(pageAFinder).dx;
      expect(pageACommitX, greaterThan(pageADragX));
      expect(pageACommitX, lessThan((pageADragX + startX) / 2));

      await tester.pumpAndSettle();

      expect(find.text('page a'), findsOneWidget);
      expect(pageBFinder, findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'canceling predictive back restores the current Get route',
    (tester) async {
      await pumpTwoPageApp(tester);

      final pageBFinder = find.byKey(const ValueKey<String>('page-b'));
      final startX = tester.getTopLeft(pageBFinder).dx;

      await startBackGesture();
      await tester.pump();
      await updateBackGesture(0.35);
      await tester.pump();
      expect(tester.getTopLeft(pageBFinder).dx, greaterThan(startX));

      await sendBackGestureMethod('cancelBackGesture');
      await tester.pumpAndSettle();

      expect(find.text('page b'), findsOneWidget);
      expect(find.text('page a'), findsNothing);
      expect(tester.getTopLeft(pageBFinder).dx, closeTo(startX, 0.01));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'commit still settles when gesture progress already dismissed the route',
    (tester) async {
      await pumpTwoPageApp(tester);

      final pageAFinder = find.byKey(
        const ValueKey<String>('page-a'),
        skipOffstage: false,
      );
      final pageBFinder = find.byKey(const ValueKey<String>('page-b'));

      await startBackGesture();
      await tester.pump();
      await updateBackGesture(1);
      await tester.pump();

      final dragX = tester.getTopLeft(pageAFinder).dx;
      expect(dragX, greaterThan(0));

      await sendBackGestureMethod('commitBackGesture');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      // At progress 1 Flutter disposes page B synchronously. Page A must keep
      // using the Navigator-owned settle animation instead of jumping to x=0.
      final settleX = tester.getTopLeft(pageAFinder).dx;
      expect(pageBFinder, findsNothing);
      expect(settleX, greaterThan(0));
      expect(settleX, lessThan(dragX));

      await tester.pumpAndSettle();
      expect(tester.getTopLeft(pageAFinder).dx, closeTo(0, 0.01));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'a root dialog takes priority over a nested predictive-back route',
    (tester) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final nestedNavigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: rootNavigatorKey,
          theme: ThemeData(
            platform: TargetPlatform.android,
            pageTransitionsTheme: imageToolboxPageTransitionsTheme,
          ),
          home: Navigator(
            key: nestedNavigatorKey,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const Material(
                key: ValueKey<String>('nested-page-a'),
                child: Center(child: Text('nested page a')),
              ),
            ),
          ),
        ),
      );

      nestedNavigatorKey.currentState!.push<void>(
        ThemedGetPageRoute<void>(
          settings: const RouteSettings(name: '/nested-page-b'),
          page: () => const Material(
            key: ValueKey<String>('nested-page-b'),
            child: Center(child: Text('nested page b')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      showDialog<void>(
        context: rootNavigatorKey.currentContext!,
        builder: (_) => const AlertDialog(content: Text('root dialog')),
      );
      await tester.pumpAndSettle();

      await startBackGesture();
      await tester.pump();
      await updateBackGesture(0.35);
      await tester.pump();
      await sendBackGestureMethod('commitBackGesture');
      await tester.pumpAndSettle();

      expect(find.text('root dialog'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('nested-page-b')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey<String>('nested-page-a')), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
