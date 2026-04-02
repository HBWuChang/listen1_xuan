import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

enum CustomSideSheetEdge { left, right }

class CustomSideSheetType extends WoltModalType {
  CustomSideSheetType({
    this.width,
    this.edge = CustomSideSheetEdge.right,
    this.horizontalMargin = 16,
    ShapeBorder? shapeBorder,
    bool forceMaxHeight = true,
    Duration transitionDuration = const Duration(milliseconds: 300),
    Duration reverseTransitionDuration = const Duration(milliseconds: 250),
    WoltModalDismissDirection? dismissDirection,
    double minFlingVelocity = 365.0,
    double closeProgressThreshold = 0.5,
    bool? barrierDismissible,
  }) : assert(width == null || width > 0),
       assert(horizontalMargin >= 0),
       super(
         shapeBorder:
             shapeBorder ??
             (edge == CustomSideSheetEdge.right
                 ? const RoundedRectangleBorder(
                     borderRadius: BorderRadiusDirectional.only(
                       topStart: Radius.circular(16.0),
                       bottomStart: Radius.circular(16.0),
                     ),
                   )
                 : const RoundedRectangleBorder(
                     borderRadius: BorderRadiusDirectional.only(
                       topEnd: Radius.circular(16.0),
                       bottomEnd: Radius.circular(16.0),
                     ),
                   )),
         showDragHandle: false,
         forceMaxHeight: forceMaxHeight,
         transitionDuration: transitionDuration,
         reverseTransitionDuration: reverseTransitionDuration,
         dismissDirection:
             dismissDirection ??
             (edge == CustomSideSheetEdge.right
                 ? WoltModalDismissDirection.endToStart
                 : WoltModalDismissDirection.startToEnd),
         minFlingVelocity: minFlingVelocity,
         closeProgressThreshold: closeProgressThreshold,
         barrierDismissible: barrierDismissible,
       );

  final double? width;
  final CustomSideSheetEdge edge;
  final double horizontalMargin;

  @override
  String routeLabel(BuildContext context) =>
      MaterialLocalizations.of(context).drawerLabel;

  @override
  BoxConstraints layoutModal(Size availableSize) {
    final maxAllowedWidth = max(0.0, availableSize.width - horizontalMargin * 2);
    final resolvedWidth = width == null
        ? min(524.0, maxAllowedWidth)
        : width!.clamp(0.0, maxAllowedWidth).toDouble();

    return BoxConstraints(
      minWidth: resolvedWidth,
      maxWidth: resolvedWidth,
      minHeight: availableSize.height,
      maxHeight: availableSize.height,
    );
  }

  @override
  Offset positionModal(
    Size availableSize,
    Size modalContentSize,
    TextDirection textDirection,
  ) {
    final xOffset = edge == CustomSideSheetEdge.right
        ? max(0.0, availableSize.width - modalContentSize.width)
        : 0.0;
    return Offset(xOffset, 0);
  }

  @override
  Widget decoratePageContent(
    BuildContext context,
    Widget child,
    bool useSafeArea,
  ) {
    if (!useSafeArea) return child;

    return SafeArea(
      left: edge == CustomSideSheetEdge.left,
      right: edge == CustomSideSheetEdge.right,
      top: true,
      bottom: true,
      child: child,
    );
  }

  @override
  Widget decorateModal(BuildContext context, Widget modal, bool useSafeArea) =>
      modal;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final isClosing = animation.status == AnimationStatus.reverse;

    const enteringInterval = Interval(0.0, 100.0 / 300.0, curve: Curves.linear);
    const exitingInterval = Interval(100.0 / 250.0, 1.0, curve: Curves.linear);

    const enteringCubic = Cubic(0.2, 0.6, 0.4, 1.0);
    const exitingCubic = Cubic(0.5, 0, 0.7, 0.2);

    final interval = isClosing ? exitingInterval : enteringInterval;
    final reverseInterval = isClosing ? enteringInterval : exitingInterval;

    final cubic = isClosing ? exitingCubic : enteringCubic;
    final reverseCubic = isClosing ? enteringCubic : exitingCubic;

    final alphaAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: interval,
        reverseCurve: reverseInterval,
      ),
    );

    final fromOffset =
        edge == CustomSideSheetEdge.right
            ? const Offset(1.0, 0.0)
            : const Offset(-1.0, 0.0);

    final positionAnimation = Tween<Offset>(begin: fromOffset, end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: animation,
            curve: cubic,
            reverseCurve: reverseCubic,
          ),
        );

    return FadeTransition(
      opacity: alphaAnimation,
      child: SlideTransition(position: positionAnimation, child: child),
    );
  }
}