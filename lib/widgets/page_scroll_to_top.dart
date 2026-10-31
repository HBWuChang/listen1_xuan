import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:status_bar_scroll_to_top/status_bar_scroll_to_top.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

/// Registers one page's active vertical viewport. Dialogs are deliberately excluded.
class PageScrollToTop extends StatefulWidget {
  const PageScrollToTop({
    super.key,
    required this.builder,
    this.scrollController,
    this.listController,
    this.superList = false,
    this.enabled = true,
    this.topInset = 0,
  });

  final Widget Function(BuildContext, ScrollController, ListController) builder;
  final ScrollController? scrollController;
  final ListController? listController;
  final bool superList;
  final bool enabled;

  /// Leading padding before item zero; animateToItem aligns the item, not this padding.
  final double topInset;

  @override
  State<PageScrollToTop> createState() => _PageScrollToTopState();
}

class _PageScrollToTopState extends State<PageScrollToTop> {
  final _ownedScroll = ScrollController();
  final _ownedList = ListController();
  ScrollController get scroll => widget.scrollController ?? _ownedScroll;
  ListController get list => widget.listController ?? _ownedList;

  @override
  void initState() {
    super.initState();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    // PageStorage and initialScrollOffset are applied during attachment/layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ownedScroll.dispose();
    _ownedList.dispose();
    super.dispose();
  }

  /// During rotation the same controller can briefly be attached to two
  /// viewports (old + new route). Reading `offset` / calling `jumpTo` would trip
  /// the "attached to multiple scroll views" assertion, so treat that state as
  /// "not ready" instead.
  ScrollPosition? get _singlePosition {
    if (!scroll.hasClients || scroll.positions.length != 1) return null;
    return scroll.positions.first;
  }

  Future<bool> _toTop() async {
    if (!mounted ||
        !widget.enabled ||
        _singlePosition == null ||
        Get.isDialogOpen == true ||
        Get.isBottomSheetOpen == true) {
      return false;
    }
    if (!widget.superList) {
      scroll.jumpTo(0);
      return scroll.hasClients && scroll.offset.abs() < 0.5;
    }
    if (!list.isAttached) {
      return false;
    }
    final controller = scroll;
    final position = controller.positions.first;
    await list.animateToItem(
      index: () =>
          mounted && list.isAttached && list.numberOfItems > 0 ? 0 : null,
      scrollController: controller,
      alignment: 0,
      duration: (_) => const Duration(milliseconds: 400),
      curve: (_) => Curves.easeOut,
      teleport: true,
      approachFactor: 1.0,
      precalculateTargetItemCount: true,
    );
    return mounted &&
        _singlePosition == position &&
        controller.offset <= widget.topInset + 0.5;
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.builder(context, scroll, list);
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return content;
    }
    return AnimatedBuilder(
      animation: scroll,
      child: content,
      builder: (context, child) {
        final position = _singlePosition;
        final threshold = (widget.superList ? widget.topInset : 0) + 0.5;
        return StatusBarScrollToTop(
          enabled: widget.enabled,
          canScrollToTop: position != null && position.pixels > threshold,
          onScrollToTop: _toTop,
          onDebugEvent: kDebugMode
              ? (event) => debugPrint('StatusBarScrollToTop: $event')
              : null,
          child: child!,
        );
      },
    );
  }
}
