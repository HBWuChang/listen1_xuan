import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen1_xuan/widgets/track_scrollbar.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

void main() {
  Future<void> pumpList(
    WidgetTester tester,
    ScrollController controller, {
    int count = 100,
    bool reverse = false,
    TextDirection direction = TextDirection.ltr,
    VoidCallback? onTap,
    ScrollController? outer,
    bool useSuperList = false,
  }) async {
    Widget list = SizedBox(
      width: 300,
      height: 400,
      child: TrackScrollbar(
        controller: controller,
        child: useSuperList ? SuperListView.builder(
          controller: controller,
          itemCount: count,
          extentEstimation: (_, __) => 40,
          itemBuilder: (_, index) => SizedBox(height: 40, child: Text('Song $index')),
        ) : ListView.builder(
          controller: controller,
          reverse: reverse,
          itemExtent: 40,
          itemCount: count,
          itemBuilder: (_, index) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Text('Song $index'),
          ),
        ),
      ),
    );
    if (outer != null) {
      list = SizedBox(
        width: 300,
        height: 400,
        child: ListView(
          controller: outer,
          children: [list, const SizedBox(height: 600)],
        ),
      );
    }
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Align(alignment: Alignment.topLeft, child: list),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('track press immediately centers thumb and follows pointer to both ends', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var taps = 0;
    await pumpList(tester, controller, onTap: () => taps++);
    final gesture = await tester.startGesture(const Offset(290, 300));
    // 400 高的轨道两端各留 2，最小滑块高 48。
    expect(controller.offset, closeTo((300 - 2 - 24) / (396 - 48) * 3600, 0.01));
    await tester.pump();
    final thumb = tester.widgetList<PositionedDirectional>(
      find.descendant(of: find.byType(TrackScrollbar), matching: find.byType(PositionedDirectional)),
    ).singleWhere((widget) => widget.height != null);
    expect(thumb.top! + thumb.height! / 2, closeTo(300, 0.01));
    await gesture.moveTo(const Offset(250, 450));
    expect(controller.offset, controller.position.maxScrollExtent);
    await gesture.moveTo(const Offset(275, -20));
    expect(controller.offset, 0);
    await gesture.up();
    expect(taps, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('list taps and ordinary swipes still work outside the rail', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var taps = 0;
    await pumpList(tester, controller, onTap: () => taps++);
    await tester.tapAt(const Offset(200, 20));
    expect(taps, 1);
    await tester.dragFrom(const Offset(200, 300), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(controller.offset, lessThan(1000));
  });

  testWidgets('rail owns dragging inside a nested scroll view', (tester) async {
    final controller = ScrollController();
    final outer = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(outer.dispose);
    await pumpList(tester, controller, outer: outer);
    final gesture = await tester.startGesture(const Offset(290, 100));
    await gesture.moveTo(const Offset(290, 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(2000));
    expect(outer.offset, 0);
  });

  testWidgets('short lists hide the rail and dimension changes restore it', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpList(tester, controller, count: 2);
    expect(find.byType(RawGestureDetector).evaluate().where(
      (element) => (element.widget as RawGestureDetector).gestures.containsKey(EagerGestureRecognizer),
    ), isEmpty);
    await tester.tapAt(const Offset(290, 300));
    expect(controller.offset, 0);
    await pumpList(tester, controller, count: 100);
    await tester.tapAt(const Offset(290, 300));
    expect(controller.offset, greaterThan(2000));
    await pumpList(tester, controller, count: 2);
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL and reversed lists map the rail to the correct scroll direction', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpList(tester, controller, reverse: true, direction: TextDirection.rtl);
    await tester.tapAt(const Offset(10, 5));
    expect(controller.offset, controller.position.maxScrollExtent);
    await tester.tapAt(const Offset(10, 395));
    expect(controller.offset, 0);
  });

  testWidgets('mouse wheel over the rail scrolls the inner list only', (tester) async {
    final controller = ScrollController();
    final outer = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(outer.dispose);
    await pumpList(tester, controller, outer: outer);
    await tester.sendEventToBinding(const PointerScrollEvent(
      position: Offset(290, 200),
      scrollDelta: Offset(0, 120),
      kind: PointerDeviceKind.mouse,
    ));
    await tester.pumpAndSettle();
    expect(controller.offset, 120);
    expect(outer.offset, 0);
  });

  testWidgets('SuperListView supports track dragging and cancellation', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpList(tester, controller, useSuperList: true);
    final first = await tester.startGesture(const Offset(290, 300));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(2000));
    await first.cancel();
    final second = await tester.startGesture(const Offset(290, 2));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    await second.up();
    expect(tester.takeException(), isNull);
  });

  double thumbOpacity(WidgetTester tester) => tester.widget<FadeTransition>(
    find.descendant(of: find.byType(TrackScrollbar), matching: find.byType(FadeTransition)),
  ).opacity.value;

  testWidgets('hidden thumb can be grabbed immediately and stays visible until release', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpList(tester, controller);
    expect(thumbOpacity(tester), 0);
    expect(tester.getSize(find.byType(ListView)).width, 300);
    // 只绘制滑块，没有轨道背景。
    expect(find.descendant(of: find.byType(TrackScrollbar), matching: find.byType(DecoratedBox)), findsOneWidget);
    final gesture = await tester.startGesture(const Offset(290, 300));
    expect(controller.offset, greaterThan(2000));
    await tester.pump(const Duration(seconds: 2));
    expect(thumbOpacity(tester), 1);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 125));
    expect(thumbOpacity(tester), greaterThan(0));
    expect(thumbOpacity(tester), lessThan(1));
    await tester.pump(const Duration(milliseconds: 125));
    expect(thumbOpacity(tester), 0);
    final next = await tester.startGesture(const Offset(290, 2));
    expect(controller.offset, 0);
    await tester.pump();
    expect(thumbOpacity(tester), 1);
    await next.cancel();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(thumbOpacity(tester), 0);
  });

  testWidgets('ordinary scrolling shows the thumb and idle scrolling fades it out', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpList(tester, controller);
    final gesture = await tester.startGesture(const Offset(200, 300));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    expect(thumbOpacity(tester), 1);
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(thumbOpacity(tester), 0);
    controller.jumpTo(1000);
    await tester.pump();
    expect(thumbOpacity(tester), 1);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(thumbOpacity(tester), 0);
  });
}
