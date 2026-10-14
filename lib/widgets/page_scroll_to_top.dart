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

  Future<bool> _toTop() async {
    if (!mounted ||
        !widget.enabled ||
        !scroll.hasClients ||
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
    final position = controller.position;
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
        controller.positions.contains(position) &&
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
      builder: (context, child) => StatusBarScrollToTop(
        enabled: widget.enabled,
        canScrollToTop:
            scroll.hasClients &&
            scroll.offset > (widget.superList ? widget.topInset : 0) + 0.5,
        onScrollToTop: _toTop,
        onDebugEvent: kDebugMode
            ? (event) => debugPrint('StatusBarScrollToTop: $event')
            : null,
        child: child!,
      ),
    );
  }
}
