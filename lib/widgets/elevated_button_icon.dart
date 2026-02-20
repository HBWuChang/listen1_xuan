import 'dart:async';

import 'package:flutter/material.dart';

/// A small wrapper for `ElevatedButton.icon` that swaps icon/label while
/// `onPressed` is running.
class ElevatedButtonIcon extends StatefulWidget {
  const ElevatedButtonIcon({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.onHover,
    this.onFocusChange,
    this.style,
    this.focusNode,
    this.autofocus,
    this.clipBehavior,
    this.icon,
    required this.label,
    this.onPressedIcon,
    this.onPressedLabel,
    this.statesController,
    this.iconAlignment,
  });

  final FutureOr<void> Function()? onPressed;
  final FutureOr<void> Function()? onLongPress;
  final void Function(bool)? onHover;
  final void Function(bool)? onFocusChange;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool? autofocus;
  final Clip? clipBehavior;
  final Widget? icon;
  final Widget label;
  final Widget? onPressedIcon;
  final Widget? onPressedLabel;
  final WidgetStatesController? statesController;
  final IconAlignment? iconAlignment;

  @override
  State<ElevatedButtonIcon> createState() => _ElevatedButtonIconState();
}

class _ElevatedButtonIconState extends State<ElevatedButtonIcon> {
  bool _isRunning = false;

  Future<void> _handlePressed(FutureOr<void> Function() callback) async {
    setState(() => _isRunning = true);
    try {
      await Future.sync(callback);
    } finally {
      if (mounted) {
        setState(() => _isRunning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget baseIcon = widget.icon ?? const SizedBox.shrink();
    final Widget currentIcon = _isRunning
        ? (widget.onPressedIcon ?? baseIcon)
        : baseIcon;
    final Widget currentLabel = _isRunning
        ? (widget.onPressedLabel ?? widget.label)
        : widget.label;

    final onPressed = widget.onPressed;

    return ElevatedButton.icon(
      onPressed: onPressed == null || _isRunning
          ? null
          : () => _handlePressed(onPressed),
      onLongPress: widget.onLongPress == null
          ? null
          : () => _handlePressed(widget.onLongPress!),
      onHover: widget.onHover,
      onFocusChange: widget.onFocusChange,
      style: widget.style,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus ?? false,
      clipBehavior: widget.clipBehavior ?? Clip.none,
      icon: currentIcon,
      label: currentLabel,
      statesController: widget.statesController,
      iconAlignment: widget.iconAlignment,
    );
  }
}
